import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { PrismaModule } from '../prisma/prisma.module.js';
import { FamiliesController } from './families.controller.js';
import { FamiliesService } from './families.service.js';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [FamiliesController],
  providers: [FamiliesService],
})
export class FamiliesModule {}
