import '../../../core/network/api_client.dart';
import 'models/family_info.dart';

class FamilyRepository {
  const FamilyRepository(this._api);

  final ApiClient _api;

  Future<FamilyInfo> myFamily() async =>
      FamilyInfo.fromJson(await _api.get('/families/me'));

  Future<List<FamilyListItem>> listFamilies() async =>
      (await _api.getList('/families'))
          .whereType<Map>()
          .map((row) => FamilyListItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();
}
