import '../../../core/network/api_client.dart';
import '../../auth/data/models/auth_user.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/logic/expense_controller.dart';
import '../../family/data/family_repository.dart';
import '../../history/data/history_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/logic/notifications_controller.dart';
import '../../reports/data/reports_repository.dart';
import '../../transfers/data/transfer_repository.dart';
import '../../transfers/logic/transfer_controller.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_controller.dart';

class DashboardFeature {
  DashboardFeature({required ApiClient api, required AuthUser user}) {
    final families = FamilyRepository(api);
    final reports = ReportsRepository(api);
    final history = HistoryRepository(api);
    final transfers = TransferRepository(api);
    final expenses = ExpenseRepository(api);
    final notifications = NotificationsRepository(api);
    dashboard = DashboardController(
      repository: DashboardRepository(
        families: families,
        reports: reports,
        history: history,
        transfers: transfers,
        expenses: expenses,
        notifications: notifications,
      ),
      user: user,
    );
    transferActions = TransferController(transfers);
    expenseActions = ExpenseController(expenses);
    notificationActions = NotificationsController(notifications);
  }

  late final DashboardController dashboard;
  late final TransferController transferActions;
  late final ExpenseController expenseActions;
  late final NotificationsController notificationActions;

  void dispose() {
    dashboard.dispose();
    transferActions.dispose();
    expenseActions.dispose();
    notificationActions.dispose();
  }
}
