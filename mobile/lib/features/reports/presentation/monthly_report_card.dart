import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/finance_reports.dart';
import 'monthly_report_screen.dart';

class MonthlyReportCard extends StatelessWidget {
  const MonthlyReportCard({super.key, required this.report});

  final MonthlyReport? report;

  @override
  Widget build(BuildContext context) {
    final data = report?.data ?? const <String, dynamic>{};
    final year = data['year']?.toString();
    final month = data['month']?.toString().padLeft(2, '0');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: report == null ? null : () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => MonthlyReportScreen(report: report!))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laporan Bulan Ini', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (year != null && month != null) ...[
                      const SizedBox(height: 3),
                      Text('$month/$year · Lihat ringkasan dan kategori', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
