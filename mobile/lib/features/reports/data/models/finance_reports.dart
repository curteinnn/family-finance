class FinanceOverview {
  const FinanceOverview({required this.totals, required this.children});

  final Map<String, dynamic> totals;
  final List<Map<String, dynamic>> children;

  factory FinanceOverview.fromJson(Map<String, dynamic> json) => FinanceOverview(
    totals: _map(json['totals']),
    children: _maps(json['children']),
  );
}

class MonthlyReport {
  const MonthlyReport({required this.data});

  final Map<String, dynamic> data;

  factory MonthlyReport.fromJson(Map<String, dynamic> json) =>
      MonthlyReport(data: Map<String, dynamic>.from(json));
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
    : <Map<String, dynamic>>[];
