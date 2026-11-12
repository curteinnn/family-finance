import '../../auth/data/models/auth_user.dart';
import '../../expenses/data/models/expense.dart';
import '../../expenses/data/expense_repository.dart';
import '../../family/data/models/family_info.dart';
import '../../family/data/family_repository.dart';
import '../../history/data/history_repository.dart';
import '../../notifications/data/models/app_notification.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../reports/data/models/finance_reports.dart';
import '../../reports/data/reports_repository.dart';
import '../../transfers/data/models/transfer.dart';
import '../../transfers/data/transfer_repository.dart';
import 'dashboard_snapshot.dart';

class DashboardRepository {
  const DashboardRepository({
    required FamilyRepository families,
    required ReportsRepository reports,
    required HistoryRepository history,
    required TransferRepository transfers,
    required ExpenseRepository expenses,
    required NotificationsRepository notifications,
  }) : _families = families,
       _reports = reports,
       _history = history,
       _transfers = transfers,
       _expenses = expenses,
       _notifications = notifications;

  final FamilyRepository _families;
  final ReportsRepository _reports;
  final HistoryRepository _history;
  final TransferRepository _transfers;
  final ExpenseRepository _expenses;
  final NotificationsRepository _notifications;

  Future<DashboardSnapshot> load(AuthUser user) async {
    if (user.role == 'ADMIN') {
      final families = await _families.listFamilies();
      final notifications = await _notifications.list();
      return DashboardSnapshot(families: families, notifications: notifications);
    }

    final now = DateTime.now().toUtc();
    final values = await Future.wait<dynamic>([
      _families.myFamily(),
      _reports.overview(),
      _reports.monthly(now),
      _history.list(page: 1, limit: 50),
      _transfers.list(),
      _expenses.list(),
      _expenses.categories(),
      _notifications.list(),
    ]);
    return DashboardSnapshot(
      family: values[0] as FamilyInfo,
      overview: values[1] as FinanceOverview,
      monthlyReport: values[2] as MonthlyReport,
      history: values[3] as HistoryPage,
      transfers: values[4] as List<Transfer>,
      expenses: values[5] as List<Expense>,
      categories: values[6] as List<ExpenseCategory>,
      notifications: values[7] as List<AppNotification>,
    );
  }
}
