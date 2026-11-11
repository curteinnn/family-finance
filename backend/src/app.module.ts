import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { ConfigModule } from "@nestjs/config";
import { AuthModule } from './auth/auth.module.js';
import { FamiliesModule } from './families/families.module.js';
import { TransfersModule } from './transfers/transfers.module.js';
import { ExpensesModule } from './expenses/expenses.module.js';
import { CategoriesModule } from './categories/categories.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { ReportsModule } from './reports/reports.module.js';
import { HistoryModule } from './history/history.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    AuthModule,
    FamiliesModule,
    TransfersModule,
    ExpensesModule,
    CategoriesModule,
    NotificationsModule,
    ReportsModule,
    HistoryModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
