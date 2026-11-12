import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../family/data/models/family_info.dart';
import '../../../shared/logic/transaction_submit_result.dart';
import '../../../shared/presentation/transaction_dialog_outcome.dart';

typedef TransferSubmit = Future<TransactionSubmitResult> Function({
  required String childId,
  required String amount,
  String? note,
});

class CreateTransferDialog extends StatefulWidget {
  const CreateTransferDialog({super.key, required this.children, required this.onSubmit});

  final List<FamilyChild> children;
  final TransferSubmit onSubmit;

  @override
  State<CreateTransferDialog> createState() => _CreateTransferDialogState();
}

class _CreateTransferDialogState extends State<CreateTransferDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _childId;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final values = {'childId': _childId!, 'amount': _amount.text, 'note': _note.text};
    setState(() { _submitting = true; _error = null; });
    final result = await widget.onSubmit(childId: values['childId']!, amount: values['amount']!, note: values['note']);
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
      title: const Text('Buat transfer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _childId,
            decoration: const InputDecoration(labelText: 'Anak'),
            items: widget.children.map((child) => DropdownMenuItem(value: child.userId, child: Text(child.name))).toList(),
            onChanged: (value) => setState(() => _childId = value),
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
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('transaction-error')),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _submitting || _childId == null || _amount.text.isEmpty ? null : _submit,
          child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kirim'),
        ),
      ],
    ),
  );
}
