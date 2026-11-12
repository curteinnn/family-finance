import { Module } from '@nestjs/common';
import { ExpensesController } from './expenses.controller.js';
import { ExpensesService } from './expenses.service.js';
import { NotificationsModule } from '../notifications/notifications.module.js';

@Module({
  controllers: [ExpensesController],
  providers: [ExpensesService],
  imports: [NotificationsModule],
})
export class ExpensesModule {}
