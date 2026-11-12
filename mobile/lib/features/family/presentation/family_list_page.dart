import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_widgets.dart';
import '../data/models/family_info.dart';

class FamilyListPage extends StatelessWidget {
  const FamilyListPage({super.key, required this.families, required this.onRefresh});

  final List<FamilyListItem> families;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Keluarga terdaftar', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (families.isEmpty) const EmptyMessage('Belum ada family.'),
        ...families.map((family) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.family_restroom)),
            title: Text(family.name),
            subtitle: Text('${family.childCount} anak'),
          ),
        )),
      ],
    ),
  );
}
