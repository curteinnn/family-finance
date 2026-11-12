import { Prisma, UserRole } from '../generated/prisma/client.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PushNotificationsService } from '../notifications/push-notifications.service.js';
import { TransfersService } from './transfers.service.js';

describe('TransfersService push delivery', () => {
  it('sends a transfer push to the target child after the transaction commits', async () => {
    let committed = false;
    const tx = {
      child: { findFirst: vi.fn().mockResolvedValue({ userId: 'child-id' }) },
      wallet: { findFirst: vi.fn().mockResolvedValue({ id: 'wallet-id' }) },
      fundTransfer: {
        create: vi.fn().mockResolvedValue({
          id: 'transfer-id',
          amount: new Prisma.Decimal(10000),
          note: null,
          status: 'PENDING',
          createdAt: new Date('2026-11-12T00:00:00.000Z'),
          child: { name: 'Alya' },
        }),
      },
      notification: { create: vi.fn() },
      auditLog: { create: vi.fn() },
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
    const service = new TransfersService(
      prisma as unknown as PrismaService,
      push as unknown as PushNotificationsService,
    );
    const parent: AuthenticatedUser = {
      id: 'parent-id',
      name: 'Parent',
      email: 'parent@example.test',
      familyId: 'family-id',
      role: UserRole.PARENT,
    };

    const result = await service.create(
      { childId: 'child-id', amount: '10000' },
      parent,
    );

    expect(result.id).toBe('transfer-id');
    expect(push.sendToUser).toHaveBeenCalledWith('child-id', {
      title: 'Uang Masuk',
      body: 'Parent mengirim uang sebesar Rp10000 kepada Anda. Konfirmasi jika uang sudah diterima.',
      type: 'TRANSFER_CREATED',
      transactionId: 'transfer-id',
    });
  });
});
