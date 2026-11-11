import { ForbiddenException, Injectable } from '@nestjs/common';
import { ExpenseStatus, Prisma, TransferStatus, UserRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { CURRENCY_CODE } from '../common/currency.js';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(user: AuthenticatedUser) {
    if (!user.familyId || user.role === UserRole.ADMIN) throw new ForbiddenException();
    const familyId = user.familyId;
    const childScope = user.role === UserRole.CHILD ? { childId: user.id } : {};
    const transferWhere = { familyId, status: TransferStatus.CONFIRMED, ...childScope };
    const expenseWhere = { familyId, status: ExpenseStatus.ACTIVE, ...childScope };

    const [transferTotals, expenseTotals, byCategory, children, childIncomes, childExpenses] = await Promise.all([
      this.prisma.fundTransfer.aggregate({ where: transferWhere, _sum: { amount: true }, _count: { _all: true } }),
      this.prisma.expense.aggregate({ where: expenseWhere, _sum: { amount: true }, _count: { _all: true } }),
      this.prisma.expense.groupBy({
        by: ['categoryId'],
        where: expenseWhere,
        _sum: { amount: true },
        _count: { _all: true },
        orderBy: { _sum: { amount: 'desc' } },
      }),
      user.role === UserRole.PARENT
        ? this.prisma.child.findMany({
            where: { familyId },
            orderBy: { name: 'asc' },
            select: { userId: true, name: true, wallet: { select: { id: true, isActive: true } } },
          })
        : Promise.resolve([]),
      user.role === UserRole.PARENT
        ? this.prisma.fundTransfer.groupBy({
            by: ['childId'],
            where: { familyId, status: TransferStatus.CONFIRMED },
            _sum: { amount: true },
          })
        : Promise.resolve([]),
      user.role === UserRole.PARENT
        ? this.prisma.expense.groupBy({
            by: ['childId'],
            where: { familyId, status: ExpenseStatus.ACTIVE },
            _sum: { amount: true },
          })
        : Promise.resolve([]),
    ]);

    const categoryIds = byCategory.map((item) => item.categoryId);
    const categories = await this.prisma.category.findMany({
      where: { id: { in: categoryIds } },
      select: { id: true, name: true },
    });
    const categoryNames = new Map(categories.map((category) => [category.id, category.name]));
    const incomeByChild = new Map(childIncomes.map((row) => [row.childId, row._sum.amount ?? new Prisma.Decimal(0)]));
    const expensesByChild = new Map(childExpenses.map((row) => [row.childId, row._sum.amount ?? new Prisma.Decimal(0)]));
    const income = transferTotals._sum.amount ?? new Prisma.Decimal(0);
    const expenses = expenseTotals._sum.amount ?? new Prisma.Decimal(0);

    return {
      currency: CURRENCY_CODE,
      totals: {
        confirmedIncome: income.toFixed(0),
        activeExpenses: expenses.toFixed(0),
        balance: income.sub(expenses).toFixed(0),
        transferCount: transferTotals._count._all,
        expenseCount: expenseTotals._count._all,
      },
      expensesByCategory: byCategory.map((item) => ({
        categoryId: item.categoryId,
        categoryName: categoryNames.get(item.categoryId) ?? 'Kategori dihapus',
        amount: item._sum.amount?.toFixed(0) ?? '0',
        count: item._count._all,
      })),
      ...(user.role === UserRole.PARENT ? {
        children: children.map((child) => {
          const childIncome = incomeByChild.get(child.userId) ?? new Prisma.Decimal(0);
          const childSpent = expensesByChild.get(child.userId) ?? new Prisma.Decimal(0);
          return {
            childId: child.userId,
            name: child.name,
            walletActive: child.wallet?.isActive ?? false,
            balance: childIncome.sub(childSpent).toFixed(0),
          };
        }),
      } : {}),
    };
  }

  async monthly(year: number, month: number, user: AuthenticatedUser) {
    if (!user.familyId || user.role === UserRole.ADMIN) throw new ForbiddenException();
    const familyId = user.familyId;
    const start = new Date(Date.UTC(year, month - 1, 1));
    const end = new Date(Date.UTC(year, month, 1));
    const childScope = user.role === UserRole.CHILD ? { childId: user.id } : {};
    const [income, expenses, byCategory] = await Promise.all([
      this.prisma.fundTransfer.aggregate({
        where: {
          familyId,
          status: TransferStatus.CONFIRMED,
          confirmedAt: { gte: start, lt: end },
          ...childScope,
        },
        _sum: { amount: true },
        _count: { _all: true },
      }),
      this.prisma.expense.aggregate({
        where: {
          familyId,
          status: ExpenseStatus.ACTIVE,
          spentAt: { gte: start, lt: end },
          ...childScope,
        },
        _sum: { amount: true },
        _count: { _all: true },
      }),
      this.prisma.expense.groupBy({
        by: ['categoryId'],
        where: {
          familyId,
          status: ExpenseStatus.ACTIVE,
          spentAt: { gte: start, lt: end },
          ...childScope,
        },
        _sum: { amount: true },
        _count: { _all: true },
        orderBy: { _sum: { amount: 'desc' } },
      }),
    ]);
    const names = await this.prisma.category.findMany({
      where: { id: { in: byCategory.map((row) => row.categoryId) } },
      select: { id: true, name: true },
    });
    const nameById = new Map(names.map((row) => [row.id, row.name]));
    const totalIncome = income._sum?.amount ?? new Prisma.Decimal(0);
    const totalExpenses = expenses._sum?.amount ?? new Prisma.Decimal(0);
    return {
      currency: CURRENCY_CODE,
      year,
      month,
      period: { start: start.toISOString(), endExclusive: end.toISOString() },
      totals: {
        confirmedIncome: totalIncome.toFixed(0),
        activeExpenses: totalExpenses.toFixed(0),
        net: totalIncome.sub(totalExpenses).toFixed(0),
        transferCount: income._count._all,
        expenseCount: expenses._count._all,
      },
      expensesByCategory: byCategory.map((row) => ({
        categoryId: row.categoryId,
        categoryName: nameById.get(row.categoryId) ?? 'Kategori dihapus',
        amount: row._sum.amount?.toFixed(0) ?? '0',
        count: row._count._all,
      })),
    };
  }
}
