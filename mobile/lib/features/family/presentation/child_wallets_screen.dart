import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/family_info.dart';

class ChildWalletsScreen extends StatelessWidget {
  const ChildWalletsScreen({super.key, required this.wallets});

  final List<ChildWalletSummary> wallets;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wallet Anak')),
    body: wallets.isEmpty
        ? const EmptyMessage('Belum ada anak dengan wallet.')
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: wallets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.child_care_outlined)),
                  title: Text(wallet.name),
                  subtitle: Text('${wallet.walletName} · ${wallet.walletActive ? 'Aktif' : 'Nonaktif'}'),
                  trailing: Text(wallet.balance == null ? '—' : formatRupiah(wallet.balance), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              );
            },
          ),
  );
}
