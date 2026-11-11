import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ExpenseStatus, Prisma, TransferStatus, UserRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { CreateExpenseDto, VoidExpenseDto } from './create-expense.dto.js';
import { CURRENCY_CODE } from '../common/currency.js';

function codeOf(error: unknown): string | undefined {
  return typeof error === 'object' && error !== null && 'code' in error && typeof error.code === 'string'
    ? error.code
    : undefined;
}

@Injectable()
export class ExpensesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthenticatedUser) {
    if (!user.familyId || user.role === UserRole.ADMIN) throw new ForbiddenException();
    const expenses = await this.prisma.expense.findMany({
      where: user.role === UserRole.PARENT
        ? { familyId: user.familyId }
        : { familyId: user.familyId, childId: user.id },
      orderBy: [{ spentAt: 'desc' }, { id: 'desc' }],
      take: 100,
      select: {
        id: true,
        amount: true,
        description: true,
        spentAt: true,
        status: true,
        voidedAt: true,
        voidReason: true,
        createdAt: true,
        child: { select: { name: true } },
        category: { select: { id: true, name: true } },
      },
    });
    return expenses.map((expense) => ({ ...expense, amount: expense.amount.toFixed(0), currency: CURRENCY_CODE }));
  }

  async create(dto: CreateExpenseDto, actor: AuthenticatedUser) {
    if (actor.role !== UserRole.CHILD || !actor.familyId) throw new ForbiddenException();
    const familyId = actor.familyId;
    const amount = new Prisma.Decimal(dto.amount);
    if (amount.lte(0)) throw new BadRequestException('Jumlah pengeluaran harus lebih dari 0.');

    try {
      return await this.prisma.$transaction(async (tx) => {
        const wallet = await tx.wallet.findFirst({
          where: { childId: actor.id, familyId, isActive: true },
          select: { id: true },
        });
        if (!wallet) throw new ConflictException('Wallet tidak tersedia.');

        const category = await tx.category.findFirst({
          where: { id: dto.categoryId, isActive: true },
          select: { id: true },
        });
        if (!category) throw new NotFoundException('Kategori tidak ditemukan atau tidak aktif.');

        const [transfers, expenses] = await Promise.all([
          tx.fundTransfer.aggregate({
            where: { familyId, walletId: wallet.id, status: TransferStatus.CONFIRMED },
            _sum: { amount: true },
          }),
          tx.expense.aggregate({
            where: { familyId, walletId: wallet.id, status: ExpenseStatus.ACTIVE },
            _sum: { amount: true },
          }),
        ]);
        const income = transfers._sum?.amount ?? new Prisma.Decimal(0);
        const spent = expenses._sum?.amount ?? new Prisma.Decimal(0);
        if (income.sub(spent).lt(amount)) throw new BadRequestException('Saldo wallet tidak mencukupi.');

        const expense = await tx.expense.create({
          data: {
            familyId,
            walletId: wallet.id,
            childId: actor.id,
            categoryId: category.id,
            amount,
            description: dto.description?.trim() || null,
            spentAt: dto.spentAt ? new Date(dto.spentAt) : new Date(),
          },
          select: {
            id: true,
            amount: true,
            description: true,
            spentAt: true,
            status: true,
            createdAt: true,
            category: { select: { id: true, name: true } },
          },
        });
        await tx.auditLog.create({
          data: {
            familyId,
            actorId: actor.id,
            action: 'EXPENSE_CREATED',
            entityType: 'Expense',
            entityId: expense.id,
            details: { amount: amount.toFixed(0), currency: CURRENCY_CODE, categoryId: category.id },
          },
        });
        const parent = await tx.parent.findUnique({
          where: { familyId },
          select: { userId: true },
        });
        if (parent) {
          await tx.notification.create({
            data: {
              familyId,
              userId: parent.userId,
              type: 'GENERAL',
              title: 'Pengeluaran baru dicatat',
              message: `${actor.name} mencatat pengeluaran sebesar Rp${amount.toFixed(0)}.`,
            },
          });
        }
        return {
          ...expense,
          amount: expense.amount.toFixed(0),
          balanceAfter: income.sub(spent).sub(amount).toFixed(0),
          currency: CURRENCY_CODE,
        };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (codeOf(error) === 'P2034') throw new ConflictException('Saldo berubah bersamaan. Periksa saldo lalu coba lagi.');
      throw error;
    }
  }

  async void(id: string, dto: VoidExpenseDto, actor: AuthenticatedUser) {
    if (actor.role !== UserRole.PARENT || !actor.familyId) throw new ForbiddenException();
    const familyId = actor.familyId;
    const reason = dto.reason.trim();
    if (!reason) throw new BadRequestException('Alasan pembatalan wajib diisi.');

    return this.prisma.$transaction(async (tx) => {
      const expense = await tx.expense.findFirst({
        where: { id, familyId },
        select: { id: true, childId: true, status: true },
      });
      if (!expense) throw new NotFoundException('Pengeluaran tidak ditemukan.');
      if (expense.status !== ExpenseStatus.ACTIVE) throw new ConflictException('Pengeluaran sudah dibatalkan.');

      const updated = await tx.expense.update({
        where: { id },
        data: { status: ExpenseStatus.VOIDED, voidedByUserId: actor.id, voidedAt: new Date(), voidReason: reason },
        select: { id: true, status: true, voidedAt: true, voidReason: true },
      });
      await tx.auditLog.create({
        data: { familyId, actorId: actor.id, action: 'EXPENSE_VOIDED', entityType: 'Expense', entityId: id, details: { reason } },
      });
      await tx.notification.create({
        data: {
          familyId,
          userId: expense.childId,
          type: 'GENERAL',
          title: 'Pengeluaran dibatalkan',
          message: `Parent membatalkan pengeluaran: ${reason}`,
        },
      });
      return updated;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
}
