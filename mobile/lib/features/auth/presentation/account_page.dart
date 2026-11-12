import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/auth_user.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.user, required this.working, required this.onSignOut});

  final AuthUser user;
  final bool working;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(user.name),
          subtitle: Text('${user.email}\n${roleLabel(user.role)}'),
          isThreeLine: true,
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: working ? null : onSignOut,
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
      ),
    ],
  );
}
