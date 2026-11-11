import { ForbiddenException, Injectable } from '@nestjs/common';
import { UserRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { CURRENCY_CODE } from '../common/currency.js';

@Injectable()
export class HistoryService {
  constructor(private readonly prisma: PrismaService) {}

  async list(page: number, limit: number, user: AuthenticatedUser) {
    if (!user.familyId || user.role === UserRole.ADMIN) throw new ForbiddenException();
    const offset = (page - 1) * limit;
    // Fetch enough rows from each source to cover the requested slice of the
    // globally merged list. Applying `skip` independently in either table
    // would omit rows because page boundaries belong to the combined stream.
    const take = offset + limit + 1;
    const scope = user.role === UserRole.PARENT
      ? { familyId: user.familyId }
      : { familyId: user.familyId, childId: user.id };

    const [transfers, expenses] = await Promise.all([
      this.prisma.fundTransfer.findMany({
        where: scope,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take,
        select: {
          id: true, amount: true, status: true, note: true, createdAt: true,
          parent: { select: { name: true } }, child: { select: { name: true } },
        },
      }),
      this.prisma.expense.findMany({
        where: scope,
        orderBy: [{ spentAt: 'desc' }, { id: 'desc' }],
        take,
        select: {
          id: true, amount: true, status: true, description: true, spentAt: true, createdAt: true,
          child: { select: { name: true } }, category: { select: { name: true } },
        },
      }),
    ]);

    const entries = [
      ...transfers.map((item) => ({
        id: item.id, type: 'TRANSFER' as const, amount: item.amount.toFixed(0), currency: CURRENCY_CODE, status: item.status,
        description: item.note, occurredAt: item.createdAt, parent: item.parent.name, child: item.child.name,
      })),
      ...expenses.map((item) => ({
        id: item.id, type: 'EXPENSE' as const, amount: item.amount.toFixed(0), currency: CURRENCY_CODE, status: item.status,
        description: item.description, occurredAt: item.spentAt, createdAt: item.createdAt,
        child: item.child.name, category: item.category.name,
      })),
    ].sort((a, b) =>
      b.occurredAt.getTime() - a.occurredAt.getTime() ||
      b.id.localeCompare(a.id) ||
      a.type.localeCompare(b.type),
    );
    return {
      items: entries.slice(offset, offset + limit),
      page,
      limit,
      hasMore: entries.length > offset + limit,
    };
  }
}
