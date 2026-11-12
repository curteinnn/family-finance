import 'package:flutter/material.dart';

import '../../../../shared/widgets/finance_widgets.dart';
import '../../data/models/transfer.dart';

class TransferCard extends StatelessWidget {
  const TransferCard({
    super.key,
    required this.transfer,
    required this.isParent,
    required this.isChild,
    required this.working,
    required this.onConfirm,
    required this.onReject,
    required this.onCancel,
  });

  final Transfer transfer;
  final bool isParent;
  final bool isChild;
  final bool working;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final participant = isParent ? transfer.childName : transfer.parentName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: Color(0xFF176B55)),
                const SizedBox(width: 10),
                Expanded(child: Text(formatRupiah(transfer.amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                StatusChip(status: transfer.status),
              ],
            ),
            if (transfer.note != null && transfer.note!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(left: 34, top: 4), child: Text(transfer.note!)),
            if (participant != null || transfer.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4),
                child: Text(
                  [
                    if (participant != null) isParent ? 'Untuk $participant' : 'Dari $participant',
                    if (transfer.createdAt != null) formatShortDate(transfer.createdAt),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            if (isChild && transfer.status == 'PENDING')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: working ? null : onReject, child: const Text('Belum masuk')),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: working ? null : onConfirm, child: const Text('Sudah masuk')),
                  ],
                ),
              ),
            if (isParent && transfer.status == 'PENDING')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: working ? null : onCancel, icon: const Icon(Icons.cancel_outlined), label: const Text('Batalkan')),
              ),
          ],
        ),
      ),
    );
  }
}
