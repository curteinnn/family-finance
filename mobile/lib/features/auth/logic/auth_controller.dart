import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;
  AuthUser? user;
  bool loading = true;

  Future<void> restoreSession() async {
    try {
      user = await _repository.currentUser();
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _repository.clearSession();
    } catch (_) {
      // Preserve the existing behavior: show login when the API is offline.
    }
    loading = false;
    notifyListeners();
  }

  Future<AuthUser> signIn(String email, String password) async {
    user = await _repository.signIn(email, password);
    return user!;
  }

  Future<void> signOut() async {
    await _repository.signOut();
    user = null;
    notifyListeners();
  }
}
