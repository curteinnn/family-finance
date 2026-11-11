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
import { CreateExpenseDto, VoidExpenseDto } from './create-expense.dto.js';
import { ExpensesService } from './expenses.service.js';

@Controller('expenses')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ExpensesController {
  constructor(private readonly expenses: ExpensesService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.expenses.list(user);
  }

  @Post()
  @Roles(UserRole.CHILD)
  create(@Body() dto: CreateExpenseDto, @CurrentUser() user: AuthenticatedUser) {
    return this.expenses.create(dto, user);
  }

  @Patch(':id/void')
  @Roles(UserRole.PARENT)
  void(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: VoidExpenseDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.expenses.void(id, dto, user);
  }
}
