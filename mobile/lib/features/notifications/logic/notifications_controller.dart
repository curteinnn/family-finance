import 'package:flutter/foundation.dart';

import '../data/notifications_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository);

  final NotificationsRepository _repository;

  Future<void> markRead(String id) => _repository.markRead(id);
}
