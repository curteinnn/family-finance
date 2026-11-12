import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/models/auth_user.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_snapshot.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({required DashboardRepository repository, required AuthUser user})
    : _repository = repository,
      user = user;

  final DashboardRepository _repository;
  final AuthUser user;
  DashboardSnapshot snapshot = const DashboardSnapshot();
  bool loading = true;
  String? error;
  bool working = false;

  bool get isAdmin => user.role == 'ADMIN';
  bool get isParent => user.role == 'PARENT';
  bool get isChild => user.role == 'CHILD';

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await _repository.load(user);
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Tidak bisa memuat data. Periksa koneksi ke backend.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> perform(Future<void> Function() action) async {
    working = true;
    notifyListeners();
    try {
      await action();
      await load();
      return null;
    } on ApiException catch (exception) {
      return exception.message;
    } catch (_) {
      return 'Aksi gagal. Coba lagi.';
    } finally {
      working = false;
      notifyListeners();
    }
  }
}
