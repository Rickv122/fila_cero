import '../models/domain.dart';

abstract interface class FilaRepository {
  Stream<void> get authChanges;
  Future<StaffProfile?> profile();
  Future<StaffProfile> login(String email, String password);
  Future<void> logout();
  Future<({List<Station> stations, bool hasMore})> stations(StationQuery query);
  Future<Station?> station(String id);
  Future<List<Map<String, dynamic>>> fuels();
  Future<String> saveStation(StationDraft draft);
  Future<void> setActive(String id, bool active);
  Future<List<StaffProfile>> managers();
  Future<Set<String>> assignedManagers(String stationId);
  Future<void> assignManager(String stationId, String profileId, bool active);
  Future<void> updateAvailability(
    String stationId,
    Map<String, FuelStatus> changes,
  );
  Future<List<Map<String, dynamic>>> history(String stationId);
}
