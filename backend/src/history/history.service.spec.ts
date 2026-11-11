import { UserRole } from '../generated/prisma/client.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { HistoryService } from './history.service.js';

type TransferRow = {
  id: string;
  amount: { toFixed: (digits: number) => string };
  status: string;
  note: string | null;
  createdAt: Date;
  parent: { name: string };
  child: { name: string };
};

type ExpenseRow = {
  id: string;
  amount: { toFixed: (digits: number) => string };
  status: string;
  description: string | null;
  spentAt: Date;
  createdAt: Date;
  child: { name: string };
  category: { name: string };
};

const user: AuthenticatedUser = {
  id: 'parent-id',
  name: 'Parent',
  email: 'parent@example.test',
  role: UserRole.PARENT,
  familyId: 'family-id',
};

function amount(value: number) {
  return { toFixed: () => String(value) };
}

function makeTransfer(id: string, at: Date): TransferRow {
  return {
    id,
    amount: amount(100),
    status: 'CONFIRMED',
    note: null,
    createdAt: at,
    parent: { name: 'Parent' },
    child: { name: 'Child' },
  };
}

function makeExpense(id: string, at: Date): ExpenseRow {
  return {
    id,
    amount: amount(50),
    status: 'ACTIVE',
    description: null,
    spentAt: at,
    createdAt: at,
    child: { name: 'Child' },
    category: { name: 'Food' },
  };
}

function createService(transfers: TransferRow[], expenses: ExpenseRow[]) {
  const prisma = {
    fundTransfer: {
      findMany: vi.fn(async ({ take }: { take: number }) =>
        [...transfers]
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime() || b.id.localeCompare(a.id))
          .slice(0, take),
      ),
    },
    expense: {
      findMany: vi.fn(async ({ take }: { take: number }) =>
        [...expenses]
          .sort((a, b) => b.spentAt.getTime() - a.spentAt.getTime() || b.id.localeCompare(a.id))
          .slice(0, take),
      ),
    },
  } as unknown as PrismaService;

  return { service: new HistoryService(prisma), prisma };
}

describe('HistoryService pagination', () => {
  it('returns the first globally sorted page from mixed transfer and expense data', async () => {
    const { service } = createService(
      [makeTransfer('transfer-3', new Date('2026-01-03')), makeTransfer('transfer-1', new Date('2026-01-01'))],
      [makeExpense('expense-2', new Date('2026-01-02'))],
    );

    const result = await service.list(1, 2, user);

    expect(result.items.map((item) => `${item.type}:${item.id}`)).toEqual([
      'TRANSFER:transfer-3',
      'EXPENSE:expense-2',
    ]);
    expect(result.hasMore).toBe(true);
  });

  it('does not repeat or skip rows across pages of the combined stream', async () => {
    const { service } = createService(
      [makeTransfer('transfer-5', new Date('2026-01-05')), makeTransfer('transfer-2', new Date('2026-01-02'))],
      [makeExpense('expense-4', new Date('2026-01-04')), makeExpense('expense-3', new Date('2026-01-03')), makeExpense('expense-1', new Date('2026-01-01'))],
    );

    const first = await service.list(1, 2, user);
    const second = await service.list(2, 2, user);
    const last = await service.list(3, 2, user);
    const allIds = [...first.items, ...second.items, ...last.items].map((item) => `${item.type}:${item.id}`);

    expect(allIds).toEqual([
      'TRANSFER:transfer-5',
      'EXPENSE:expense-4',
      'EXPENSE:expense-3',
      'TRANSFER:transfer-2',
      'EXPENSE:expense-1',
    ]);
    expect(new Set(allIds).size).toBe(allIds.length);
    expect(first.hasMore).toBe(true);
    expect(second.hasMore).toBe(true);
    expect(last.hasMore).toBe(false);
  });

  it('uses a deterministic type tie-break when timestamps and IDs match', async () => {
    const timestamp = new Date('2026-01-01T00:00:00.000Z');
    const { service } = createService(
      [makeTransfer('same-id', timestamp)],
      [makeExpense('same-id', timestamp)],
    );

    const result = await service.list(1, 2, user);

    expect(result.items.map((item) => item.type)).toEqual(['EXPENSE', 'TRANSFER']);
  });

  it('returns an empty result and hasMore false when the requested page is empty', async () => {
    const { service } = createService([], []);

    const result = await service.list(1, 10, user);

    expect(result).toEqual({ items: [], page: 1, limit: 10, hasMore: false });
  });

  it('returns no rows and hasMore false for a page beyond the last row', async () => {
    const { service } = createService(
      [makeTransfer('transfer-1', new Date('2026-01-01'))],
      [],
    );

    const result = await service.list(2, 1, user);

    expect(result.items).toEqual([]);
    expect(result.hasMore).toBe(false);
  });
});
