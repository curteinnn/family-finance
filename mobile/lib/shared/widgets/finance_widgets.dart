import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

export '../../core/utils/formatters.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'CONFIRMED' || 'ACTIVE' => const Color(0xFF176B55),
      'REJECTED' || 'CANCELLED' || 'VOIDED' => const Color(0xFFB64B46),
      _ => const Color(0xFF8A6500),
    };
    return Chip(
      label: Text(roleLabel(status)),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: .1),
      labelStyle: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    );
  }
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );
}

class FinanceBalanceCard extends StatelessWidget {
  const FinanceBalanceCard({super.key, required this.totals});

  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primary,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo saat ini', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .8))),
          const SizedBox(height: 8),
          Text(formatRupiah(totals['balance']), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Transfer dihitung setelah dikonfirmasi child.', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .8))),
        ],
      ),
    ),
  );
}

class FinanceStatCard extends StatelessWidget {
  const FinanceStatCard({super.key, required this.title, required this.amount, required this.icon, required this.color});

  final String title;
  final dynamic amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(formatRupiah(amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}
