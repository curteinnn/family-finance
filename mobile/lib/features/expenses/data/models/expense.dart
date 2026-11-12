class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.status,
    this.description,
    this.spentAt,
    this.categoryId,
    this.categoryName,
    this.childName,
  });

  final String id;
  final String amount;
  final String status;
  final String? description;
  final String? spentAt;
  final String? categoryId;
  final String? categoryName;
  final String? childName;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final category = _map(json['category']);
    final child = _map(json['child']);
    return Expense(
      id: json['id']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString(),
      spentAt: json['spentAt']?.toString(),
      categoryId: category['id']?.toString(),
      categoryName: category['name']?.toString(),
      childName: child['name']?.toString(),
    );
  }
}

class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) => ExpenseCategory(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Kategori',
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
