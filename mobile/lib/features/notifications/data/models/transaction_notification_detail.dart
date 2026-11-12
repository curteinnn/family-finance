class TransactionNotificationDetail {
  const TransactionNotificationDetail({
    required this.amount,
    required this.status,
    required this.isTransfer,
    this.otherPartyName,
    this.parentName,
    this.createdAt,
    this.spentAt,
    this.confirmedAt,
    this.note,
    this.description,
  });

  final String amount;
  final String status;
  final bool isTransfer;
  final String? otherPartyName;
  final String? parentName;
  final String? createdAt;
  final String? spentAt;
  final String? confirmedAt;
  final String? note;
  final String? description;

  factory TransactionNotificationDetail.fromJson(Map<String, dynamic> json, {required bool isTransfer}) {
    final other = _map(json[isTransfer ? 'child' : 'category']);
    final parent = _map(json['parent']);
    return TransactionNotificationDetail(
      amount: json['amount']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isTransfer: isTransfer,
      otherPartyName: other['name']?.toString(),
      parentName: parent['name']?.toString(),
      createdAt: json['createdAt']?.toString(),
      spentAt: json['spentAt']?.toString(),
      confirmedAt: json['confirmedAt']?.toString(),
      note: json['note']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
