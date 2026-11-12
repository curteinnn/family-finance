import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/finance_reports.dart';

class MonthlyReportScreen extends StatelessWidget {
  const MonthlyReportScreen({super.key, required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final data = report.data;
    final totals = _map(data['totals']);
    final categories = _maps(data['expensesByCategory']);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Bulan Ini')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${data['month'] ?? ''}/${data['year'] ?? ''}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _ReportTotalRow(label: 'Pemasukan terkonfirmasi', value: formatRupiah(totals['confirmedIncome'])),
                  _ReportTotalRow(label: 'Pengeluaran aktif', value: formatRupiah(totals['activeExpenses'])),
                  const Divider(height: 24),
                  _ReportTotalRow(label: 'Selisih', value: formatRupiah(totals['net']), emphasize: true),
                  const SizedBox(height: 10),
                  Text('${totals['transferCount'] ?? 0} transfer · ${totals['expenseCount'] ?? 0} pengeluaran', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pengeluaran per kategori', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (categories.isEmpty)
                    const EmptyMessage('Belum ada pengeluaran bulan ini.')
                  else
                    ...categories.map((category) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(category['categoryName']?.toString() ?? 'Kategori'),
                      subtitle: Text('${category['count'] ?? 0} transaksi'),
                      trailing: Text(formatRupiah(category['amount'])),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTotalRow extends StatelessWidget {
  const _ReportTotalRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: emphasize ? Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700) : null)),
        Text(value, style: emphasize ? Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700) : const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : <Map<String, dynamic>>[];
