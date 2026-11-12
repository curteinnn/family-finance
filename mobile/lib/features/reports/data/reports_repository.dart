import '../../../core/network/api_client.dart';
import 'models/finance_reports.dart';

class ReportsRepository {
  const ReportsRepository(this._api);

  final ApiClient _api;

  Future<FinanceOverview> overview() async =>
      FinanceOverview.fromJson(await _api.get('/reports/overview'));

  Future<MonthlyReport> monthly(DateTime date) async => MonthlyReport.fromJson(
    await _api.get('/reports/monthly?year=${date.year}&month=${date.month}'),
  );
}
