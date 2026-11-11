import { randomUUID } from 'node:crypto';
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { AttachmentStatus, UserRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { CreateAttachmentUploadDto } from './attachment.dto.js';

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const URL_TTL_SECONDS = 300;

@Injectable()
export class AttachmentsService {
  private s3Client?: S3Client;
  private bucketName?: string;

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  private storage() {
    if (this.s3Client && this.bucketName) return { bucket: this.bucketName, client: this.s3Client };
    const bucket = this.config.get<string>('S3_BUCKET');
    const region = this.config.get<string>('S3_REGION');
    if (!bucket || !region) throw new ServiceUnavailableException('S3_BUCKET dan S3_REGION perlu dikonfigurasi.');

    const endpoint = this.config.get<string>('S3_ENDPOINT');
    const accessKeyId = this.config.get<string>('S3_ACCESS_KEY_ID');
    const secretAccessKey = this.config.get<string>('S3_SECRET_ACCESS_KEY');
    if ((accessKeyId && !secretAccessKey) || (!accessKeyId && secretAccessKey)) {
      throw new ServiceUnavailableException('Kredensial S3 harus disiapkan berpasangan.');
    }
    this.s3Client = new S3Client({
      region,
      ...(endpoint ? { endpoint, forcePathStyle: true } : {}),
      ...(accessKeyId && secretAccessKey ? { credentials: { accessKeyId, secretAccessKey } } : {}),
    });
    this.bucketName = bucket;
    return { bucket, client: this.s3Client };
  }

  private async targetFamilyId(dto: CreateAttachmentUploadDto, actor: AuthenticatedUser) {
    if (!actor.familyId || actor.role === UserRole.ADMIN) throw new ForbiddenException();

    if (dto.targetType === 'EXPENSE') {
      const expense = await this.prisma.expense.findFirst({
        where: {
          id: dto.targetId,
          familyId: actor.familyId,
          ...(actor.role === UserRole.CHILD ? { childId: actor.id } : {}),
        },
        select: { familyId: true },
      });
      if (!expense) throw new NotFoundException('Pengeluaran tidak ditemukan.');
      return expense.familyId;
    }

    const transfer = await this.prisma.fundTransfer.findFirst({
      where: {
        id: dto.targetId,
        familyId: actor.familyId,
        ...(actor.role === UserRole.CHILD ? { childId: actor.id } : { parentId: actor.id }),
      },
      select: { familyId: true },
    });
    if (!transfer) throw new NotFoundException('Transfer tidak ditemukan.');
    return transfer.familyId;
  }

  async createUpload(dto: CreateAttachmentUploadDto, actor: AuthenticatedUser) {
    if (dto.fileSize > MAX_FILE_SIZE) throw new BadRequestException('Ukuran file maksimal 10 MB.');
    const familyId = await this.targetFamilyId(dto, actor);
    const { bucket, client } = this.storage();
    const safeName = dto.fileName.replace(/[^\p{L}\p{N}._ -]/gu, '_').slice(0, 255);
    const extension = safeName.includes('.') ? safeName.split('.').pop()?.replace(/[^a-zA-Z0-9]/g, '').slice(0, 10) : undefined;
    const storageKey = `${familyId}/${dto.targetType.toLowerCase()}/${dto.targetId}/${randomUUID()}${extension ? `.${extension}` : ''}`;

    const attachment = await this.prisma.attachment.create({
      data: {
        ...(dto.targetType === 'EXPENSE' ? { expenseId: dto.targetId } : { transferId: dto.targetId }),
        uploadedById: actor.id,
        fileName: safeName,
        storageKey,
        mimeType: dto.mimeType,
        fileSize: BigInt(dto.fileSize),
      },
      select: { id: true },
    });
    const uploadUrl = await getSignedUrl(
      client,
      new PutObjectCommand({ Bucket: bucket, Key: storageKey, ContentType: dto.mimeType }),
      { expiresIn: URL_TTL_SECONDS },
    );
    return { attachmentId: attachment.id, uploadUrl, method: 'PUT', headers: { 'Content-Type': dto.mimeType }, expiresIn: URL_TTL_SECONDS };
  }

  async complete(id: string, actor: AuthenticatedUser) {
    const attachment = await this.findAccessible(id, actor, true);
    if (attachment.status === AttachmentStatus.AVAILABLE) return { id, status: attachment.status };
    const { bucket, client } = this.storage();
    let head;
    try {
      head = await client.send(new HeadObjectCommand({ Bucket: bucket, Key: attachment.storageKey }));
    } catch {
      throw new BadRequestException('File belum berhasil diunggah ke storage.');
    }
    if (head.ContentLength !== Number(attachment.fileSize) || head.ContentType !== attachment.mimeType) {
      throw new BadRequestException('Ukuran atau tipe file di storage tidak sesuai metadata upload.');
    }
    const updated = await this.prisma.attachment.update({
      where: { id },
      data: { status: AttachmentStatus.AVAILABLE },
      select: { id: true, status: true, fileName: true, mimeType: true, fileSize: true },
    });
    await this.prisma.auditLog.create({
      data: {
        familyId: attachment.familyId,
        actorId: actor.id,
        action: 'ATTACHMENT_UPLOADED',
        entityType: 'Attachment',
        entityId: id,
      },
    });
    return { ...updated, fileSize: updated.fileSize.toString() };
  }

  async download(id: string, actor: AuthenticatedUser) {
    const attachment = await this.findAccessible(id, actor, false);
    if (attachment.status !== AttachmentStatus.AVAILABLE) throw new NotFoundException('File belum tersedia.');
    const { bucket, client } = this.storage();
    const downloadUrl = await getSignedUrl(
      client,
      new GetObjectCommand({
        Bucket: bucket,
        Key: attachment.storageKey,
        ResponseContentDisposition: `attachment; filename="${attachment.fileName.replace(/["\\\r\n]/g, '_')}"`,
        ResponseContentType: attachment.mimeType,
      }),
      { expiresIn: URL_TTL_SECONDS },
    );
    return { fileName: attachment.fileName, mimeType: attachment.mimeType, downloadUrl, expiresIn: URL_TTL_SECONDS };
  }

  private async findAccessible(id: string, actor: AuthenticatedUser, requireUploader: boolean) {
    if (!actor.familyId || actor.role === UserRole.ADMIN) throw new ForbiddenException();
    const attachment = await this.prisma.attachment.findFirst({
      where: {
        id,
        ...(requireUploader ? { uploadedById: actor.id } : {}),
        OR: [
          { expense: { is: { familyId: actor.familyId } } },
          { transfer: { is: { familyId: actor.familyId } } },
        ],
      },
      select: {
        id: true,
        status: true,
        storageKey: true,
        fileName: true,
        mimeType: true,
        fileSize: true,
        uploadedById: true,
        expense: { select: { familyId: true } },
        transfer: { select: { familyId: true } },
      },
    });
    if (!attachment) throw new NotFoundException('Lampiran tidak ditemukan.');
    const familyId = attachment.expense?.familyId ?? attachment.transfer?.familyId;
    if (!familyId) throw new NotFoundException('Target lampiran tidak ditemukan.');
    if (requireUploader && attachment.uploadedById !== actor.id) throw new ForbiddenException();
    return { ...attachment, familyId };
  }
}
