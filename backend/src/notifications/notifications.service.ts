import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  list(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 100,
      select: { id: true, type: true, title: true, message: true, isRead: true, readAt: true, createdAt: true },
    });
  }

  async markRead(id: string, userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { id, userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    if (!result.count) {
      const exists = await this.prisma.notification.findFirst({ where: { id, userId }, select: { id: true } });
      if (!exists) throw new NotFoundException('Notifikasi tidak ditemukan.');
    }
    return this.prisma.notification.findFirstOrThrow({
      where: { id, userId },
      select: { id: true, isRead: true, readAt: true },
    });
  }
}
