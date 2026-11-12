import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/logic/transaction_submit_result.dart';
import '../../../shared/presentation/transaction_dialog_outcome.dart';
import '../../data/models/expense.dart';

typedef ExpenseSubmit = Future<TransactionSubmitResult> Function({
  required String categoryId,
  required String amount,
  String? description,
});

class CreateExpenseDialog extends StatefulWidget {
  const CreateExpenseDialog({super.key, required this.categories, required this.onSubmit});

  final List<ExpenseCategory> categories;
  final ExpenseSubmit onSubmit;

  @override
  State<CreateExpenseDialog> createState() => _CreateExpenseDialogState();
}

class _CreateExpenseDialogState extends State<CreateExpenseDialog> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _categoryId;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final values = {'categoryId': _categoryId!, 'amount': _amount.text, 'description': _description.text};
    setState(() { _submitting = true; _error = null; });
    final result = await widget.onSubmit(categoryId: values['categoryId']!, amount: values['amount']!, description: values['description']);
    if (!mounted) return;
    if (result.error != null) {
      setState(() { _error = result.error; _submitting = false; });
      return;
    }
    Navigator.of(context).pop(TransactionDialogOutcome(values: values, succeeded: result.succeeded));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: const Text('Catat pengeluaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: widget.categories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.name))).toList(),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)', prefixText: 'Rp '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Keterangan')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('transaction-error')),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _submitting || _categoryId == null || _amount.text.isEmpty ? null : _submit,
          child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    ),
  );
}
