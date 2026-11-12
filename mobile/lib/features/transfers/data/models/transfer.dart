class Transfer {
  const Transfer({
    required this.id,
    required this.amount,
    required this.status,
    this.note,
    this.createdAt,
    this.parentName,
    this.childName,
  });

  final String id;
  final String amount;
  final String status;
  final String? note;
  final String? createdAt;
  final String? parentName;
  final String? childName;

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
    id: json['id']?.toString() ?? '',
    amount: json['amount']?.toString() ?? '0',
    status: json['status']?.toString() ?? '',
    note: json['note']?.toString(),
    createdAt: json['createdAt']?.toString(),
    parentName: _map(json['parent'])['name']?.toString(),
    childName: _map(json['child'])['name']?.toString(),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
