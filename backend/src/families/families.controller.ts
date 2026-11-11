import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '../generated/prisma/enums.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import type { AuthenticatedUser } from '../auth/auth.types.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { CreateFamilyDto } from './create-family.dto.js';
import { CreateFamilyUserDto } from './create-family-user.dto.js';
import { FamiliesService } from './families.service.js';

@Controller('families')
@UseGuards(JwtAuthGuard, RolesGuard)
export class FamiliesController {
  constructor(private readonly familiesService: FamiliesService) {}

  @Get()
  @Roles(UserRole.ADMIN)
  listFamilies() {
    return this.familiesService.listFamilies();
  }

  @Get('me')
  getMyFamily(@CurrentUser() user: AuthenticatedUser) {
    return this.familiesService.getMyFamily(user);
  }

  @Post()
  @Roles(UserRole.ADMIN)
  createFamily(
    @Body() dto: CreateFamilyDto,
    @CurrentUser() admin: AuthenticatedUser,
  ) {
    return this.familiesService.createFamily(dto, admin);
  }

  @Post(':familyId/parents')
  @Roles(UserRole.ADMIN)
  createParent(
    @Param('familyId', ParseUUIDPipe) familyId: string,
    @Body() dto: CreateFamilyUserDto,
    @CurrentUser() admin: AuthenticatedUser,
  ) {
    return this.familiesService.createParent(familyId, dto, admin);
  }

  @Post(':familyId/children')
  @Roles(UserRole.ADMIN)
  createChild(
    @Param('familyId', ParseUUIDPipe) familyId: string,
    @Body() dto: CreateFamilyUserDto,
    @CurrentUser() admin: AuthenticatedUser,
  ) {
    return this.familiesService.createChild(familyId, dto, admin);
  }
}
