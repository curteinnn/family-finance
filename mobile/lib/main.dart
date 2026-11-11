import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyFinanceApp());
}

class FamilyFinanceApp extends StatefulWidget {
  const FamilyFinanceApp({super.key});

  @override
  State<FamilyFinanceApp> createState() => _FamilyFinanceAppState();
}

class _FamilyFinanceAppState extends State<FamilyFinanceApp> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final response = await _api.get('/auth/me');
      _user = Map<String, dynamic>.from(response['user'] as Map);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _api.clearSession();
    } catch (_) {
      // Login stays available when the local API is offline.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _signedIn(Map<String, dynamic> user) => setState(() => _user = user);

  Future<void> _signedOut() async {
    await _api.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B55)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null
          ? LoginScreen(api: _api, onSignedIn: _signedIn)
          : HomeScreen(api: _api, user: _user!, onSignOut: _signedOut),
    );
  }
}
