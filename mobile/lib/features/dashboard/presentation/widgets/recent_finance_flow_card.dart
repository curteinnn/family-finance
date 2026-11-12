import 'package:flutter/material.dart';

import '../../../expenses/data/models/expense.dart';
import '../../../expenses/presentation/widgets/expense_card.dart';
import '../../../transfers/data/models/transfer.dart';
import '../../../transfers/presentation/widgets/transfer_card.dart';

class RecentFinanceFlowCard extends StatefulWidget {
  const RecentFinanceFlowCard({
    super.key,
    required this.transfers,
    required this.expenses,
    required this.isParent,
    required this.isChild,
    required this.working,
    required this.onConfirmTransfer,
    required this.onRejectTransfer,
    required this.onCancelTransfer,
    required this.onVoidExpense,
    required this.onShowHistory,
  });

  final List<Transfer> transfers;
  final List<Expense> expenses;
  final bool isParent;
  final bool isChild;
  final bool working;
  final ValueChanged<Transfer> onConfirmTransfer;
  final ValueChanged<Transfer> onRejectTransfer;
  final ValueChanged<Transfer> onCancelTransfer;
  final ValueChanged<Expense> onVoidExpense;
  final VoidCallback onShowHistory;

  @override
  State<RecentFinanceFlowCard> createState() => _RecentFinanceFlowCardState();
}

class _RecentFinanceFlowCardState extends State<RecentFinanceFlowCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final transfers = widget.transfers.take(3).toList();
    final expenses = widget.expenses.take(3).toList();
    final isTransferTab = _tab == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Arus Keuangan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _tabButton('Transfer Terbaru', 0)),
              Expanded(child: _tabButton('Pengeluaran Terbaru', 1)),
            ]),
            if ((isTransferTab && transfers.isEmpty) || (!isTransferTab && expenses.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text(isTransferTab ? 'Belum ada transfer.' : 'Belum ada pengeluaran.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
              )
            else if (isTransferTab)
              ...transfers.map((transfer) => TransferCard(
                transfer: transfer,
                isParent: widget.isParent,
                isChild: widget.isChild,
                working: widget.working,
                onConfirm: () => widget.onConfirmTransfer(transfer),
                onReject: () => widget.onRejectTransfer(transfer),
                onCancel: () => widget.onCancelTransfer(transfer),
              ))
            else
              ...expenses.map((expense) => ExpenseCard(
                expense: expense,
                isParent: widget.isParent,
                working: widget.working,
                onVoid: () => widget.onVoidExpense(expense),
              )),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: widget.onShowHistory, child: const Text('Lihat semua aktivitas')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _tab = index),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(color: selected ? colors.secondaryContainer : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? colors.onSecondaryContainer : null, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
