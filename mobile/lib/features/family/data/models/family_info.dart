class FamilyInfo {
  const FamilyInfo({required this.name, required this.children});

  final String name;
  final List<FamilyChild> children;

  factory FamilyInfo.fromJson(Map<String, dynamic> json) => FamilyInfo(
    name: json['name']?.toString() ?? 'Family',
    children: _maps(json['children']).map(FamilyChild.fromJson).toList(),
  );
}

class FamilyChild {
  const FamilyChild({
    required this.userId,
    required this.name,
    this.walletName,
    this.walletActive = false,
  });

  final String userId;
  final String name;
  final String? walletName;
  final bool walletActive;

  factory FamilyChild.fromJson(Map<String, dynamic> json) {
    final wallet = _map(json['wallet']);
    return FamilyChild(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Child',
      walletName: wallet['name']?.toString(),
      walletActive: wallet['isActive'] == true,
    );
  }
}

class FamilyListItem {
  const FamilyListItem({required this.id, required this.name, required this.childCount});

  final String id;
  final String name;
  final int childCount;

  factory FamilyListItem.fromJson(Map<String, dynamic> json) => FamilyListItem(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Family',
    childCount: int.tryParse(_map(json['_count'])['children']?.toString() ?? '') ?? 0,
  );
}

class ChildWalletSummary {
  const ChildWalletSummary({
    required this.childId,
    required this.name,
    required this.walletName,
    required this.walletActive,
    this.balance,
  });

  final String childId;
  final String name;
  final String walletName;
  final bool walletActive;
  final String? balance;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
    : <Map<String, dynamic>>[];
