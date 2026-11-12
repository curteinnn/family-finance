import { Module } from '@nestjs/common';
import { TransfersController } from './transfers.controller.js';
import { TransfersService } from './transfers.service.js';
import { NotificationsModule } from '../notifications/notifications.module.js';

@Module({
  controllers: [TransfersController],
  providers: [TransfersService],
  imports: [NotificationsModule],
})
export class TransfersModule {}
