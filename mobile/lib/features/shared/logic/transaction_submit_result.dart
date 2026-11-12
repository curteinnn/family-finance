class TransactionSubmitResult {
  const TransactionSubmitResult.success()
    : succeeded = true,
      error = null;

  const TransactionSubmitResult.failure(this.error) : succeeded = false;

  const TransactionSubmitResult.uncertain()
    : succeeded = false,
      error = null;

  final bool succeeded;
  final String? error;
  bool get isUncertain => !succeeded && error == null;
}
