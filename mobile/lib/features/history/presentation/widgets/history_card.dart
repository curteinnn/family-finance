import 'package:flutter/material.dart';

import '../../../../shared/widgets/finance_widgets.dart';
import '../../data/models/history_entry.dart';

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final transfer = entry.type == 'TRANSFER';
    final title = transfer
        ? 'Transfer • ${entry.childName ?? ''}'
        : '${entry.categoryName ?? 'Pengeluaran'} • ${entry.childName ?? ''}';
    final description = entry.description;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(transfer ? Icons.swap_horiz : Icons.receipt_long_outlined)),
        title: Text(title),
        subtitle: Text('${roleLabel(entry.status)}${description == null || description.isEmpty ? '' : '\n$description'}'),
        isThreeLine: description != null && description.isNotEmpty,
        trailing: Text(formatRupiah(entry.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
