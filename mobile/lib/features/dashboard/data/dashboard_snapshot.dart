import '../../expenses/data/models/expense.dart';
import '../../family/data/models/family_info.dart';
import '../../history/data/history_repository.dart';
import '../../notifications/data/models/app_notification.dart';
import '../../reports/data/models/finance_reports.dart';
import '../../transfers/data/models/transfer.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    this.family,
    this.overview,
    this.monthlyReport,
    this.families = const [],
    this.transfers = const [],
    this.expenses = const [],
    this.categories = const [],
    this.notifications = const [],
    this.history,
  });

  final FamilyInfo? family;
  final FinanceOverview? overview;
  final MonthlyReport? monthlyReport;
  final List<FamilyListItem> families;
  final List<Transfer> transfers;
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final List<AppNotification> notifications;
  final HistoryPage? history;
}
