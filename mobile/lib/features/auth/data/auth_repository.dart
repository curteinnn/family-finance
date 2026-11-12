import '../../../core/network/api_client.dart';
import '../data/models/auth_user.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthUser> signIn(String email, String password) async {
    await _api.login(email, password);
    return currentUser();
  }

  Future<AuthUser> currentUser() async {
    final response = await _api.get('/auth/me');
    return AuthUser.fromJson(_map(response['user']));
  }

  Future<void> signOut() => _api.logout();

  Future<void> clearSession() => _api.clearSession();
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
