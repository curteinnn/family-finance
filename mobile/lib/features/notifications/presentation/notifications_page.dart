import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/app_notification.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.notifications, required this.onRefresh, required this.onMarkRead});

  final List<AppNotification> notifications;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onMarkRead;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (notifications.isEmpty) const EmptyMessage('Belum ada notifikasi.'),
        ...notifications.map((notification) => Card(
          child: ListTile(
            leading: Icon(notification.isRead ? Icons.notifications_none : Icons.notifications_active_outlined),
            title: Text(notification.title),
            subtitle: Text(notification.message),
            trailing: notification.isRead ? null : IconButton(
              tooltip: 'Tandai dibaca',
              icon: const Icon(Icons.check),
              onPressed: () => onMarkRead(notification.id),
            ),
          ),
        )),
      ],
    ),
  );
}
