import 'package:flutter/material.dart';

import '../../features/notifications/data/transaction_notification_repository.dart';
import '../../features/notifications/presentation/transaction_notification_detail_screen.dart';

class AppRouter {
  AppRouter(this._transactions);

  final TransactionNotificationRepository _transactions;
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> openNotification(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final transactionId = data['transactionId']?.toString();
    if (type == null || transactionId == null) return;
    if (type != 'TRANSFER_CREATED' &&
        type != 'TRANSFER_CONFIRMED' &&
        type != 'EXPENSE_CREATED') {
      return;
    }
    navigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionNotificationDetailScreen(
          repository: _transactions,
          notificationType: type,
          transactionId: transactionId,
        ),
      ),
    );
  }
}
