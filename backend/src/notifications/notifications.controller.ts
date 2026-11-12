import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { NotificationsService } from './notifications.service.js';
import { PushNotificationsService } from './push-notifications.service.js';
import { RegisterDeviceTokenDto, RemoveDeviceTokenDto } from './register-device-token.dto.js';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly push: PushNotificationsService,
  ) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.notifications.list(user.id);
  }

  @Patch(':id/read')
  markRead(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: AuthenticatedUser) {
    return this.notifications.markRead(id, user.id);
  }

  @Post('devices')
  registerDevice(@Body() dto: RegisterDeviceTokenDto, @CurrentUser() user: AuthenticatedUser) {
    return this.push.registerToken(user.id, dto.token, dto.platform);
  }

  @Delete('devices')
  removeDevice(@Body() dto: RemoveDeviceTokenDto, @CurrentUser() user: AuthenticatedUser) {
    return this.push.removeToken(user.id, dto.token);
  }
}
