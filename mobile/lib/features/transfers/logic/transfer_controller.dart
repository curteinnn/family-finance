import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../shared/logic/transaction_submit_result.dart';
import '../data/transfer_repository.dart';

class TransferController extends ChangeNotifier {
  TransferController(this._repository);

  final TransferRepository _repository;

  Future<void> confirm(String id) => _repository.confirm(id);
  Future<void> reject(String id, String? reason) => _repository.reject(id, reason);
  Future<void> cancel(String id) => _repository.cancel(id);

  Future<TransactionSubmitResult> create({
    required String childId,
    required String amount,
    String? note,
  }) async {
    try {
      await _repository.create(childId: childId, amount: amount, note: note);
      return const TransactionSubmitResult.success();
    } on ApiException catch (error) {
      if (error.statusCode != null && error.statusCode! >= 400 && error.statusCode! < 500) {
        return TransactionSubmitResult.failure(error.message);
      }
      return const TransactionSubmitResult.uncertain();
    } catch (_) {
      return const TransactionSubmitResult.uncertain();
    }
  }
}
