import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain.dart';
import 'fila_repository.dart';

class SupabaseRepository implements FilaRepository {
  final SupabaseClient client;
  SupabaseRepository(this.client);
  @override
  Future<dynamic> query(String resource, [AppRecord params = const {}]) =>
      client.rpc(
        'fc_query',
        params: {'p_resource': resource, 'p_params': params},
      );
  @override
  Future<dynamic> command(String action, AppRecord data) =>
      client.rpc('fc_command', params: {'p_action': action, 'p_data': data});
  Future<AppRecord> staff(AppRecord data) async {
    final response = await client.functions.invoke('staff-admin', body: data);
    final result = row(response.data);
    if (result['error'] != null) throw Exception(result['error']);
    return result;
  }
}
