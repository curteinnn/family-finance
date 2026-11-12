import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../shared/logic/transaction_submit_result.dart';
import '../data/expense_repository.dart';

class ExpenseController extends ChangeNotifier {
  ExpenseController(this._repository);

  final ExpenseRepository _repository;

  Future<void> voidExpense(String id, String reason) =>
      _repository.voidExpense(id, reason);

  Future<TransactionSubmitResult> create({
    required String categoryId,
    required String amount,
    String? description,
  }) async {
    try {
      await _repository.create(
        categoryId: categoryId,
        amount: amount,
        description: description,
      );
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
