import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, Max, Min } from 'class-validator';
import { CurrentUser } from '../auth/current-user.decorator.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { HistoryService } from './history.service.js';

class HistoryQueryDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 50;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  page = 1;
}

@Controller('history')
@UseGuards(JwtAuthGuard)
export class HistoryController {
  constructor(private readonly history: HistoryService) {}

  @Get()
  list(@Query() query: HistoryQueryDto, @CurrentUser() user: AuthenticatedUser) {
    return this.history.list(query.page, query.limit, user);
  }
}
