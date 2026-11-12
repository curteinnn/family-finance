import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type PushPayload = {
  title: string;
  body: string;
  type: 'TRANSFER_CREATED' | 'TRANSFER_CONFIRMED' | 'EXPENSE_CREATED';
  transactionId: string;
};

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private readonly messaging: Messaging | null;

  constructor(private readonly prisma: PrismaService) {
    const rawAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!rawAccount) {
      this.messaging = null;
      this.logger.warn('FCM push is disabled until server credentials are configured.');
      return;
    }

    try {
      const account = JSON.parse(rawAccount) as Partial<ServiceAccount>;
      if (!account.project_id || !account.client_email || !account.private_key) {
        throw new Error('Required service account fields are missing.');
      }
      const name = 'family-finance-fcm';
      const app =
        getApps().find((candidate) => candidate.name === name) ??
        initializeApp(
          {
            credential: cert({
              projectId: account.project_id,
              clientEmail: account.client_email,
              privateKey: account.private_key,
            }),
            projectId: account.project_id,
          },
          name,
        );
      this.messaging = getMessaging(app);
    } catch {
      this.messaging = null;
      this.logger.error('FCM service account configuration is invalid; push is disabled.');
    }
  }

  async registerToken(userId: string, token: string, platform: string) {
    await this.prisma.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform, isActive: true },
      update: { userId, platform, isActive: true },
      select: { id: true },
    });
    return { registered: true };
  }

  async removeToken(userId: string, token: string) {
    await this.prisma.deviceToken.deleteMany({ where: { userId, token } });
    return { removed: true };
  }

  async sendToUser(userId: string, payload: PushPayload): Promise<void> {
    if (!this.messaging) return;
    try {
      const devices = await this.prisma.deviceToken.findMany({
        where: { userId, isActive: true },
        select: { token: true },
      });
      if (devices.length === 0) {
        this.logger.warn('No active FCM installations are registered for the recipient.');
        return;
      }
      await Promise.all(
        devices.map(async ({ token }) => {
          try {
            await this.messaging!.send({
              fid: token,
              notification: { title: payload.title, body: payload.body },
              data: {
                type: payload.type,
                transactionId: payload.transactionId,
              },
              android: { priority: 'high' },
            });
          } catch (error) {
            const code =
              typeof error === 'object' && error !== null && 'code' in error
                ? String(error.code)
                : 'unknown';
            if (
              code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-registration-token' ||
              code === 'messaging/installation-id-not-registered'
            ) {
              await this.prisma.deviceToken.updateMany({
                where: { token },
                data: { isActive: false },
              });
              return;
            }
            this.logger.warn(`FCM rejected a device message (${code}).`);
          }
        }),
      );
      this.logger.log(`FCM send attempted for ${devices.length} active installation(s).`);
    } catch {
      this.logger.error('FCM delivery failed; the saved transaction remains successful.');
    }
  }
}
