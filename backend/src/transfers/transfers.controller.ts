import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '../generated/prisma/enums.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { CreateTransferDto, RejectTransferDto } from './create-transfer.dto.js';
import { TransfersService } from './transfers.service.js';

@Controller('transfers')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TransfersController {
  constructor(private readonly transfers: TransfersService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.transfers.list(user);
  }

  @Post()
  @Roles(UserRole.PARENT)
  create(
    @Body() dto: CreateTransferDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transfers.create(dto, user);
  }

  @Patch(':id/confirm')
  @Roles(UserRole.CHILD)
  confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transfers.confirm(id, user);
  }

  @Patch(':id/reject')
  @Roles(UserRole.CHILD)
  reject(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectTransferDto | undefined,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transfers.reject(id, dto, user);
  }

  @Patch(':id/cancel')
  @Roles(UserRole.PARENT)
  cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transfers.cancel(id, user);
  }
}
