import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, TransferStatus, UserRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { CreateTransferDto, RejectTransferDto } from './create-transfer.dto.js';
import { CURRENCY_CODE } from '../common/currency.js';

function codeOf(error: unknown): string | undefined {
  return typeof error === 'object' && error !== null && 'code' in error && typeof error.code === 'string'
    ? error.code
    : undefined;
}

@Injectable()
export class TransfersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthenticatedUser) {
    if (!user.familyId || user.role === UserRole.ADMIN) {
      throw new ForbiddenException('Akun ini tidak memiliki akses transfer family.');
    }

    const where = user.role === UserRole.PARENT
      ? { familyId: user.familyId, parentId: user.id }
      : { familyId: user.familyId, childId: user.id };

    const transfers = await this.prisma.fundTransfer.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 100,
      select: {
        id: true,
        amount: true,
        note: true,
        status: true,
        confirmedAt: true,
        cancelledAt: true,
        rejectedAt: true,
        rejectionReason: true,
        createdAt: true,
        parent: { select: { name: true } },
        child: { select: { name: true } },
        wallet: { select: { id: true, name: true } },
      },
    });
    return transfers.map((transfer) => ({ ...transfer, amount: transfer.amount.toFixed(0), currency: CURRENCY_CODE }));
  }

  async create(dto: CreateTransferDto, actor: AuthenticatedUser) {
    if (actor.role !== UserRole.PARENT || !actor.familyId) {
      throw new ForbiddenException();
    }
    const familyId = actor.familyId;

    const amount = new Prisma.Decimal(dto.amount);
    if (amount.lte(0)) throw new BadRequestException('Jumlah transfer harus lebih dari 0.');

    try {
      return await this.prisma.$transaction(async (tx) => {
        const child = await tx.child.findFirst({
          where: { userId: dto.childId, familyId },
          select: { userId: true },
        });
        if (!child) throw new NotFoundException('Anak tidak ditemukan di family ini.');

        const wallet = await tx.wallet.findFirst({
          where: { childId: child.userId, familyId, isActive: true },
          select: { id: true },
        });
        if (!wallet) throw new ConflictException('Wallet anak tidak tersedia.');

        const transfer = await tx.fundTransfer.create({
          data: {
            familyId,
            walletId: wallet.id,
            parentId: actor.id,
            childId: child.userId,
            amount,
            note: dto.note?.trim() || null,
          },
          select: {
            id: true,
            amount: true,
            note: true,
            status: true,
            createdAt: true,
            child: { select: { name: true } },
          },
        });

        await tx.notification.create({
          data: {
            familyId,
            userId: child.userId,
            type: 'TRANSFER_RECEIVED',
            title: 'Uang baru diberikan',
            message: `Parent mengirim uang sebesar Rp${amount.toFixed(0)}.`,
          },
        });
        await tx.auditLog.create({
          data: {
            familyId,
            actorId: actor.id,
            action: 'TRANSFER_CREATED',
            entityType: 'FundTransfer',
            entityId: transfer.id,
            details: { amount: amount.toFixed(0), currency: CURRENCY_CODE, childId: child.userId },
          },
        });
        return { ...transfer, amount: transfer.amount.toFixed(0), currency: CURRENCY_CODE };
      });
    } catch (error) {
      if (codeOf(error) === 'P2034') throw new ConflictException('Data berubah bersamaan. Coba lagi.');
      throw error;
    }
  }

  async confirm(id: string, actor: AuthenticatedUser) {
    if (actor.role !== UserRole.CHILD || !actor.familyId) throw new ForbiddenException();
    const familyId = actor.familyId;

    return this.prisma.$transaction(async (tx) => {
      const transfer = await tx.fundTransfer.findFirst({
        where: { id, childId: actor.id, familyId },
        select: { id: true, parentId: true, amount: true, status: true },
      });
      if (!transfer) throw new NotFoundException('Transfer tidak ditemukan.');
      if (transfer.status !== TransferStatus.PENDING) throw new ConflictException('Transfer sudah diproses.');

      const changed = await tx.fundTransfer.updateMany({
        where: { id, childId: actor.id, familyId, status: TransferStatus.PENDING },
        data: { status: TransferStatus.CONFIRMED, confirmedByChildId: actor.id, confirmedAt: new Date() },
      });
      if (changed.count !== 1) throw new ConflictException('Transfer sudah diproses.');
      const updated = await tx.fundTransfer.findUniqueOrThrow({
        where: { id },
        select: { id: true, amount: true, status: true, confirmedAt: true },
      });
      await tx.notification.create({
        data: {
          familyId,
          userId: transfer.parentId,
          type: 'TRANSFER_CONFIRMED',
          title: 'Penerimaan uang dikonfirmasi',
          message: `${actor.name} mengonfirmasi uang sebesar Rp${transfer.amount.toFixed(0)}.`,
        },
      });
      await tx.auditLog.create({
        data: { familyId, actorId: actor.id, action: 'TRANSFER_CONFIRMED', entityType: 'FundTransfer', entityId: id },
      });
      return { ...updated, amount: updated.amount.toFixed(0), currency: CURRENCY_CODE };
    });
  }

  async cancel(id: string, actor: AuthenticatedUser) {
    if (actor.role !== UserRole.PARENT || !actor.familyId) throw new ForbiddenException();
    const familyId = actor.familyId;

    return this.prisma.$transaction(async (tx) => {
      const transfer = await tx.fundTransfer.findFirst({
        where: { id, parentId: actor.id, familyId },
        select: { id: true, childId: true, status: true },
      });
      if (!transfer) throw new NotFoundException('Transfer tidak ditemukan.');
      if (transfer.status !== TransferStatus.PENDING) throw new ConflictException('Hanya transfer pending yang dapat dibatalkan.');

      const changed = await tx.fundTransfer.updateMany({
        where: { id, parentId: actor.id, familyId, status: TransferStatus.PENDING },
        data: { status: TransferStatus.CANCELLED, cancelledAt: new Date() },
      });
      if (changed.count !== 1) throw new ConflictException('Transfer sudah diproses.');
      const updated = await tx.fundTransfer.findUniqueOrThrow({
        where: { id },
        select: { id: true, status: true, cancelledAt: true },
      });
      await tx.notification.create({
        data: {
          familyId,
          userId: transfer.childId,
          type: 'TRANSFER_CANCELLED',
          title: 'Transfer dibatalkan',
          message: 'Parent membatalkan transfer yang belum dikonfirmasi.',
        },
      });
      await tx.auditLog.create({
        data: { familyId, actorId: actor.id, action: 'TRANSFER_CANCELLED', entityType: 'FundTransfer', entityId: id },
      });
      return updated;
    });
  }

  async reject(id: string, dto: RejectTransferDto | undefined, actor: AuthenticatedUser) {
    if (actor.role !== UserRole.CHILD || !actor.familyId) throw new ForbiddenException();
    const familyId = actor.familyId;
    const reason = dto?.reason?.trim() || null;

    return this.prisma.$transaction(async (tx) => {
      const transfer = await tx.fundTransfer.findFirst({
        where: { id, childId: actor.id, familyId },
        select: { id: true, parentId: true, status: true },
      });
      if (!transfer) throw new NotFoundException('Transfer tidak ditemukan.');
      if (transfer.status !== TransferStatus.PENDING) throw new ConflictException('Hanya transfer pending yang dapat ditolak.');

      const changed = await tx.fundTransfer.updateMany({
        where: { id, childId: actor.id, familyId, status: TransferStatus.PENDING },
        data: { status: TransferStatus.REJECTED, rejectedAt: new Date(), rejectionReason: reason },
      });
      if (changed.count !== 1) throw new ConflictException('Transfer sudah diproses.');
      const updated = await tx.fundTransfer.findUniqueOrThrow({
        where: { id },
        select: { id: true, status: true, rejectedAt: true, rejectionReason: true },
      });
      await tx.notification.create({
        data: {
          familyId,
          userId: transfer.parentId,
          type: 'GENERAL',
          title: 'Transfer belum diterima',
          message: reason
            ? `${actor.name} melaporkan transfer belum diterima: ${reason}`
            : `${actor.name} melaporkan transfer belum diterima.`,
        },
      });
      await tx.auditLog.create({
        data: {
          familyId,
          actorId: actor.id,
          action: 'TRANSFER_REJECTED',
          entityType: 'FundTransfer',
          entityId: id,
          ...(reason ? { details: { reason } } : {}),
        },
      });
      return updated;
    });
  }
}
