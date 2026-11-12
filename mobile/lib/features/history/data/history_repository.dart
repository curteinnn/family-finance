import '../../../core/network/api_client.dart';
import 'models/history_entry.dart';

class HistoryPage {
  const HistoryPage({required this.items, required this.page, required this.limit, required this.hasMore});

  final List<HistoryEntry> items;
  final int page;
  final int limit;
  final bool hasMore;
}

class HistoryRepository {
  const HistoryRepository(this._api);

  final ApiClient _api;

  Future<HistoryPage> list({int page = 1, int limit = 50}) async {
    final response = await _api.get('/history?page=$page&limit=$limit');
    final rows = response['items'];
    return HistoryPage(
      items: rows is List
          ? rows.whereType<Map>().map((row) => HistoryEntry.fromJson(Map<String, dynamic>.from(row))).toList()
          : const [],
      page: int.tryParse(response['page']?.toString() ?? '') ?? page,
      limit: int.tryParse(response['limit']?.toString() ?? '') ?? limit,
      hasMore: response['hasMore'] == true,
    );
  }
}
