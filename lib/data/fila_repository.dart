import '../models/domain.dart';

abstract interface class FilaRepository {
  Future<dynamic> query(String resource, [AppRecord params = const {}]);
  Future<dynamic> command(String action, AppRecord data);
}
