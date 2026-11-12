import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../features/auth/data/models/auth_user.dart';
import '../features/dashboard/logic/dashboard_feature.dart';
import '../features/dashboard/presentation/home_screen.dart' as feature;

/// Backward-compatible constructor for existing widget tests and imports.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.user, required this.onSignOut});

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DashboardFeature _feature;
  late final AuthUser _user;

  @override
  void initState() {
    super.initState();
    _user = AuthUser.fromJson(widget.user);
    _feature = DashboardFeature(api: widget.api, user: _user);
  }

  @override
  void dispose() {
    _feature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => feature.HomeScreen(
    feature: _feature,
    user: _user,
    onSignOut: widget.onSignOut,
  );
}
