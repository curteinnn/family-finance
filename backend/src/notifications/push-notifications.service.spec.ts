import { PrismaService } from '../prisma/prisma.service.js';
import { PushNotificationsService } from './push-notifications.service.js';

describe('PushNotificationsService device registration', () => {
  afterEach(() => vi.unstubAllEnvs());

  it('associates a device token with the authenticated account', async () => {
    vi.stubEnv('FIREBASE_SERVICE_ACCOUNT_JSON', '');
    const prisma = {
      deviceToken: { upsert: vi.fn().mockResolvedValue({ id: 'device-id' }) },
    };
    const service = new PushNotificationsService(prisma as unknown as PrismaService);

    await expect(
      service.registerToken('user-id', 'fcm-installation-token-value', 'ANDROID'),
    ).resolves.toEqual({ registered: true });
    expect(prisma.deviceToken.upsert).toHaveBeenCalledWith({
      where: { token: 'fcm-installation-token-value' },
      create: {
        userId: 'user-id',
        token: 'fcm-installation-token-value',
        platform: 'ANDROID',
        isActive: true,
      },
      update: {
        userId: 'user-id',
        platform: 'ANDROID',
        isActive: true,
      },
      select: { id: true },
    });
  });

  it('removes only the device token owned by the authenticated account', async () => {
    vi.stubEnv('FIREBASE_SERVICE_ACCOUNT_JSON', '');
    const prisma = {
      deviceToken: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
    };
    const service = new PushNotificationsService(prisma as unknown as PrismaService);

    await expect(
      service.removeToken('user-id', 'fcm-installation-token-value'),
    ).resolves.toEqual({ removed: true });
    expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'user-id', token: 'fcm-installation-token-value' },
    });
  });
});
