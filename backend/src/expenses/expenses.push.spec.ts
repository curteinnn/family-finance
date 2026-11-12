import { Prisma, UserRole } from '../generated/prisma/client.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PushNotificationsService } from '../notifications/push-notifications.service.js';
import { ExpensesService } from './expenses.service.js';

describe('ExpensesService push delivery', () => {
  it('sends an expense push to the family parent after the transaction commits', async () => {
    let committed = false;
    const tx = {
      wallet: { findFirst: vi.fn().mockResolvedValue({ id: 'wallet-id' }) },
      category: { findFirst: vi.fn().mockResolvedValue({ id: 'category-id' }) },
      fundTransfer: {
        aggregate: vi.fn().mockResolvedValue({ _sum: { amount: new Prisma.Decimal(20000) } }),
      },
      expense: {
        aggregate: vi.fn().mockResolvedValue({ _sum: { amount: new Prisma.Decimal(0) } }),
        create: vi.fn().mockResolvedValue({
          id: 'expense-id',
          amount: new Prisma.Decimal(5000),
          description: 'Roti',
          spentAt: new Date('2026-11-12T00:00:00.000Z'),
          status: 'ACTIVE',
          createdAt: new Date('2026-11-12T00:00:00.000Z'),
          category: { name: 'Makanan' },
        }),
      },
      auditLog: { create: vi.fn() },
      parent: { findUnique: vi.fn().mockResolvedValue({ userId: 'parent-id' }) },
      notification: { create: vi.fn() },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (transaction: typeof tx) => unknown) => {
        const result = await callback(tx);
        committed = true;
        return result;
      }),
    };
    const push = {
      sendToUser: vi.fn(async () => {
        expect(committed).toBe(true);
      }),
    };
    const service = new ExpensesService(
      prisma as unknown as PrismaService,
      push as unknown as PushNotificationsService,
    );
    const child: AuthenticatedUser = {
      id: 'child-id',
      name: 'Alya',
      email: 'child@example.test',
      familyId: 'family-id',
      role: UserRole.CHILD,
    };

    const result = await service.create(
      { categoryId: 'category-id', amount: '5000', description: 'Roti' },
      child,
    );

    expect(result.id).toBe('expense-id');
    expect(push.sendToUser).toHaveBeenCalledWith('parent-id', {
      title: 'Pengeluaran Baru',
      body: 'Anak Anda mencatat pengeluaran sebesar Rp5000.',
      type: 'EXPENSE_CREATED',
      transactionId: 'expense-id',
    });
  });
});
