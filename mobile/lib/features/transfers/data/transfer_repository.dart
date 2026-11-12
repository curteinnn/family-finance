import '../../../core/network/api_client.dart';
import 'models/transfer.dart';

class TransferRepository {
  const TransferRepository(this._api);

  final ApiClient _api;

  Future<List<Transfer>> list() async =>
      (await _api.getList('/transfers'))
          .whereType<Map>()
          .map((row) => Transfer.fromJson(Map<String, dynamic>.from(row)))
          .toList();

  Future<void> create({required String childId, required String amount, String? note}) async {
    await _api.post('/transfers', {
      'childId': childId,
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> confirm(String id) async => _api.patch('/transfers/$id/confirm');

  Future<void> reject(String id, String? reason) async => _api.patch(
    '/transfers/$id/reject',
    reason == null || reason.trim().isEmpty ? null : {'reason': reason.trim()},
  );

  Future<void> cancel(String id) async => _api.patch('/transfers/$id/cancel');

  Future<Map<String, dynamic>> detail(String id) => _api.get('/transfers/$id');
}
