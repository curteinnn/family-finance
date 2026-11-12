import 'package:flutter/material.dart';

import '../../../../shared/widgets/finance_widgets.dart';
import '../../data/models/expense.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({super.key, required this.expense, required this.isParent, required this.working, required this.onVoid});

  final Expense expense;
  final bool isParent;
  final bool working;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final summary = [
      expense.categoryName ?? 'Pengeluaran',
      if (isParent && expense.childName != null) expense.childName!,
      if (expense.spentAt != null) formatShortDate(expense.spentAt),
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        title: Text(formatRupiah(expense.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$summary${expense.description == null ? '' : '\n${expense.description}'}'),
        isThreeLine: expense.description != null,
        trailing: isParent && expense.status == 'ACTIVE'
            ? IconButton(tooltip: 'Void', onPressed: working ? null : onVoid, icon: const Icon(Icons.undo))
            : StatusChip(status: expense.status),
      ),
    );
  }
}
