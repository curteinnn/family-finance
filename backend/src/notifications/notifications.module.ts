import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { PushNotificationsService } from './push-notifications.service.js';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, PushNotificationsService],
  exports: [PushNotificationsService],
})
export class NotificationsModule {}
