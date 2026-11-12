import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/models/auth_user.dart';
import '../features/auth/logic/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/logic/dashboard_feature.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/expenses/data/expense_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/data/transaction_notification_repository.dart';
import '../features/transfers/data/transfer_repository.dart';
import '../services/push_notification_service.dart';
import 'navigation/app_router.dart';

class FamilyFinanceApp extends StatefulWidget {
  const FamilyFinanceApp({super.key});

  @override
  State<FamilyFinanceApp> createState() => _FamilyFinanceAppState();
}

class _FamilyFinanceAppState extends State<FamilyFinanceApp> {
  late final ApiClient _api;
  late final AuthController _auth;
  late final PushNotificationService _push;
  late final AppRouter _router;
  DashboardFeature? _dashboardFeature;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _auth = AuthController(AuthRepository(_api));
    _push = PushNotificationService();
    final transactionNotifications = TransactionNotificationRepository(
      transfers: TransferRepository(_api),
      expenses: ExpenseRepository(_api),
    );
    _router = AppRouter(transactionNotifications);
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    await _auth.restoreSession();
    final user = _auth.user;
    if (user != null) {
      _dashboardFeature = DashboardFeature(api: _api, user: user);
      if (mounted) setState(() {});
      await _initializePush();
    }
  }

  void _signedIn(AuthUser user) {
    _dashboardFeature?.dispose();
    _dashboardFeature = DashboardFeature(api: _api, user: user);
    setState(() {});
    unawaited(_initializePush());
  }

  Future<void> _initializePush() async {
    try {
      await _push.initialize(
        notifications: NotificationsRepository(_api),
        onOpened: _router.openNotification,
      );
    } catch (error) {
      debugPrint('Push initialization failed: $error');
      // A Firebase setup problem must not block login or app usage.
    }
  }

  Future<void> _signedOut() async {
    await _push.unregister();
    _dashboardFeature?.dispose();
    _dashboardFeature = null;
    await _auth.signOut();
  }

  @override
  void dispose() {
    unawaited(_push.dispose());
    _dashboardFeature?.dispose();
    _auth.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _auth,
    builder: (context, _) => MaterialApp(
      navigatorKey: _router.navigatorKey,
      title: 'Family Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B55)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: _auth.loading || (_auth.user != null && _dashboardFeature == null)
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _auth.user == null
              ? LoginScreen(controller: _auth, onSignedIn: _signedIn)
              : HomeScreen(feature: _dashboardFeature!, user: _auth.user!, onSignOut: _signedOut),
    ),
  );
}
