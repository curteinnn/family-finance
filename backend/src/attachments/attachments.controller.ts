import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { AttachmentsService } from './attachments.service.js';
import { CreateAttachmentUploadDto } from './attachment.dto.js';

@Controller('attachments')
@UseGuards(JwtAuthGuard)
export class AttachmentsController {
  constructor(private readonly attachments: AttachmentsService) {}

  @Post('upload-url')
  createUpload(@Body() dto: CreateAttachmentUploadDto, @CurrentUser() user: AuthenticatedUser) {
    return this.attachments.createUpload(dto, user);
  }

  @Post(':id/complete')
  complete(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: AuthenticatedUser) {
    return this.attachments.complete(id, user);
  }

  @Get(':id/download-url')
  download(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: AuthenticatedUser) {
    return this.attachments.download(id, user);
  }
}
