import '../../expenses/data/expense_repository.dart';
import '../../transfers/data/transfer_repository.dart';
import 'models/transaction_notification_detail.dart';

class TransactionNotificationRepository {
  const TransactionNotificationRepository({required TransferRepository transfers, required ExpenseRepository expenses})
    : _transfers = transfers,
      _expenses = expenses;

  final TransferRepository _transfers;
  final ExpenseRepository _expenses;

  Future<TransactionNotificationDetail> detail(String type, String id) async {
    final isTransfer = type.startsWith('TRANSFER_');
    final data = isTransfer ? await _transfers.detail(id) : await _expenses.detail(id);
    return TransactionNotificationDetail.fromJson(data, isTransfer: isTransfer);
  }
}
