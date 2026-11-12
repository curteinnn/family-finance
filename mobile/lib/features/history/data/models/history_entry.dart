class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    this.description,
    this.childName,
    this.categoryName,
  });

  final String id;
  final String type;
  final String amount;
  final String status;
  final String? description;
  final String? childName;
  final String? categoryName;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    amount: json['amount']?.toString() ?? '0',
    status: json['status']?.toString() ?? '',
    description: json['description']?.toString(),
    childName: json['child']?.toString(),
    categoryName: json['category']?.toString(),
  );
}
