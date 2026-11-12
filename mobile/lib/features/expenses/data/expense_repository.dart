import '../../../core/network/api_client.dart';
import 'models/expense.dart';

class ExpenseRepository {
  const ExpenseRepository(this._api);

  final ApiClient _api;

  Future<List<Expense>> list() async =>
      (await _api.getList('/expenses'))
          .whereType<Map>()
          .map((row) => Expense.fromJson(Map<String, dynamic>.from(row)))
          .toList();

  Future<List<ExpenseCategory>> categories() async =>
      (await _api.getList('/categories'))
          .whereType<Map>()
          .map((row) => ExpenseCategory.fromJson(Map<String, dynamic>.from(row)))
          .toList();

  Future<void> create({required String categoryId, required String amount, String? description}) async {
    await _api.post('/expenses', {
      'categoryId': categoryId,
      'amount': amount,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  Future<void> voidExpense(String id, String reason) async =>
      _api.patch('/expenses/$id/void', {'reason': reason.trim()});

  Future<Map<String, dynamic>> detail(String id) => _api.get('/expenses/$id');
}
