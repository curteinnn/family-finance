import '../../../core/network/api_client.dart';
import 'models/app_notification.dart';

class NotificationsRepository {
  const NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> list() async =>
      (await _api.getList('/notifications'))
          .whereType<Map>()
          .map((row) => AppNotification.fromJson(Map<String, dynamic>.from(row)))
          .toList();

  Future<void> markRead(String id) async =>
      _api.patch('/notifications/$id/read');

  Future<void> registerDevice(String fid) async => _api.post(
    '/notifications/devices',
    {'token': fid, 'platform': 'ANDROID'},
  );

  Future<void> removeDevice(String fid) async =>
      _api.delete('/notifications/devices', {'token': fid});
}
