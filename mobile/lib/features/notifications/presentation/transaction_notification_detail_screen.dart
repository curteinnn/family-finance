import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/transaction_notification_detail.dart';
import '../data/transaction_notification_repository.dart';

class TransactionNotificationDetailScreen extends StatefulWidget {
  const TransactionNotificationDetailScreen({super.key, required this.repository, required this.notificationType, required this.transactionId});

  final TransactionNotificationRepository repository;
  final String notificationType;
  final String transactionId;

  @override
  State<TransactionNotificationDetailScreen> createState() => _TransactionNotificationDetailScreenState();
}

class _TransactionNotificationDetailScreenState extends State<TransactionNotificationDetailScreen> {
  late final Future<TransactionNotificationDetail> _transaction = widget.repository.detail(widget.notificationType, widget.transactionId);

  String _date(String? value) => value == null ? 'Tidak tersedia' : formatShortDate(value).isEmpty ? 'Tidak tersedia' : formatShortDate(value);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.notificationType.startsWith('TRANSFER_') ? 'Detail Transfer' : 'Detail Pengeluaran')),
    body: FutureBuilder<TransactionNotificationDetail>(
      future: _transaction,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Transaksi tidak ditemukan atau akun ini tidak memiliki akses.', textAlign: TextAlign.center)));
        }
        final transaction = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatRupiah(transaction.amount, fallback: 'Tidak tersedia'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    _DetailRow(label: 'Status', value: transaction.status.isEmpty ? '—' : transaction.status),
                    _DetailRow(label: transaction.isTransfer ? 'Anak' : 'Kategori', value: transaction.otherPartyName ?? '—'),
                    if (transaction.isTransfer && transaction.parentName != null) _DetailRow(label: 'Parent', value: transaction.parentName!),
                    _DetailRow(label: transaction.isTransfer ? 'Dibuat' : 'Tanggal', value: _date(transaction.isTransfer ? transaction.createdAt : transaction.spentAt)),
                    if (transaction.confirmedAt != null) _DetailRow(label: 'Dikonfirmasi', value: _date(transaction.confirmedAt)),
                    if (transaction.note != null) _DetailRow(label: 'Catatan', value: transaction.note!),
                    if (transaction.description != null) _DetailRow(label: 'Keterangan', value: transaction.description!),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
