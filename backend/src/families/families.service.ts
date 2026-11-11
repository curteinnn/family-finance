import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, UserRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import type { CreateFamilyDto } from './create-family.dto.js';
import type { CreateFamilyUserDto } from './create-family-user.dto.js';
import * as bcrypt from 'bcrypt';

function prismaErrorCode(error: unknown): string | undefined {
  if (typeof error !== 'object' || error === null || !('code' in error)) {
    return undefined;
  }

  return typeof error.code === 'string' ? error.code : undefined;
}

@Injectable()
export class FamiliesService {
  constructor(private readonly prisma: PrismaService) {}

  listFamilies() {
    return this.prisma.family.findMany({
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 100,
      select: {
        id: true,
        name: true,
        createdAt: true,
        parent: { select: { userId: true, name: true } },
        _count: { select: { children: true } },
      },
    });
  }

  async createFamily(
    dto: CreateFamilyDto,
    actor: AuthenticatedUser,
  ) {
    return this.prisma.$transaction(async (transaction) => {
      const family = await transaction.family.create({
        data: { name: dto.name.trim() },
      });

      await transaction.auditLog.create({
        data: {
          familyId: family.id,
          actorId: actor.id,
          action: 'FAMILY_CREATED',
          entityType: 'Family',
          entityId: family.id,
        },
      });

      return family;
    });
  }

  async getMyFamily(actor: AuthenticatedUser) {
    if (!actor.familyId || actor.role === UserRole.ADMIN) {
      throw new BadRequestException('Akun ini belum terhubung ke family.');
    }

    const family = await this.prisma.family.findUnique({
      where: { id: actor.familyId },
      select: {
        id: true,
        name: true,
        createdAt: true,
        parent: { select: { userId: true, name: true } },
        children: {
          orderBy: { name: 'asc' },
          select: { userId: true, name: true, wallet: { select: { id: true, name: true, isActive: true } } },
        },
      },
    });
    if (!family) throw new NotFoundException('Family tidak ditemukan.');
    return { ...family, currentUserId: actor.id, currentRole: actor.role };
  }

  async createParent(
    familyId: string,
    dto: CreateFamilyUserDto,
    actor: AuthenticatedUser,
  ) {
    const passwordHash = await this.hashPassword(dto.password);

    try {
      return await this.prisma.$transaction(
        async (transaction) => {
          await this.requireFamily(transaction, familyId);

          const existingParent = await transaction.parent.findUnique({
            where: { familyId },
            select: { userId: true },
          });

          if (existingParent) {
            throw new ConflictException(
              'Family ini sudah memiliki akun parent.',
            );
          }

          const user = await transaction.user.create({
            data: {
              email: dto.email.trim().toLowerCase(),
              passwordHash,
              role: UserRole.PARENT,
              parent: {
                create: {
                  familyId,
                  name: dto.name.trim(),
                },
              },
            },
            select: {
              id: true,
              email: true,
              role: true,
              createdAt: true,
              parent: {
                select: { name: true, familyId: true },
              },
            },
          });

          if (!user.parent) {
            throw new Error('Parent profile was not created.');
          }

          await transaction.auditLog.create({
            data: {
              familyId,
              actorId: actor.id,
              action: 'FAMILY_USER_CREATED',
              entityType: 'User',
              entityId: user.id,
              details: { role: UserRole.PARENT },
            },
          });

          return {
            id: user.id,
            name: user.parent.name,
            email: user.email,
            role: user.role,
            familyId: user.parent.familyId,
            createdAt: user.createdAt,
          };
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      );
    } catch (error) {
      this.throwMappedPrismaError(error);
    }
  }

  async createChild(
    familyId: string,
    dto: CreateFamilyUserDto,
    actor: AuthenticatedUser,
  ) {
    const passwordHash = await this.hashPassword(dto.password);

    try {
      return await this.prisma.$transaction(async (transaction) => {
        await this.requireFamily(transaction, familyId);

        const user = await transaction.user.create({
          data: {
            email: dto.email.trim().toLowerCase(),
            passwordHash,
            role: UserRole.CHILD,
            child: {
              create: {
                familyId,
                name: dto.name.trim(),
                wallet: {
                  create: { familyId },
                },
              },
            },
          },
          select: {
            id: true,
            email: true,
            role: true,
            createdAt: true,
            child: {
              select: {
                name: true,
                familyId: true,
                wallet: {
                  select: {
                    id: true,
                    name: true,
                    isActive: true,
                  },
                },
              },
            },
          },
        });

        if (!user.child) {
          throw new Error('Child profile was not created.');
        }

        await transaction.auditLog.create({
          data: {
            familyId,
            actorId: actor.id,
            action: 'FAMILY_USER_CREATED',
            entityType: 'User',
            entityId: user.id,
            details: { role: UserRole.CHILD },
          },
        });

        return {
          id: user.id,
          name: user.child.name,
          email: user.email,
          role: user.role,
          familyId: user.child.familyId,
          createdAt: user.createdAt,
          wallet: user.child.wallet,
        };
      });
    } catch (error) {
      this.throwMappedPrismaError(error);
    }
  }

  private async requireFamily(
    transaction: Prisma.TransactionClient,
    familyId: string,
  ): Promise<void> {
    const family = await transaction.family.findUnique({
      where: { id: familyId },
      select: { id: true },
    });

    if (!family) {
      throw new NotFoundException('Family tidak ditemukan.');
    }
  }

  private async hashPassword(password: string): Promise<string> {
    if (Buffer.byteLength(password, 'utf8') > 72) {
      throw new BadRequestException(
        'Password tidak boleh lebih dari 72 byte untuk bcrypt.',
      );
    }

    return bcrypt.hash(password, 12);
  }

  private throwMappedPrismaError(error: unknown): never {
    const code = prismaErrorCode(error);

    if (code === 'P2002') {
      throw new ConflictException('Email sudah digunakan.');
    }

    if (code === 'P2034') {
      throw new ConflictException(
        'Data family berubah bersamaan. Coba ulangi permintaan.',
      );
    }

    throw error;
  }
}
