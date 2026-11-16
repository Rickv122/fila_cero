import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain.dart';
import 'fila_repository.dart';

class SupabaseRepository implements FilaRepository {
  final SupabaseClient client;
  SupabaseRepository(this.client);
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});

  @override
  Future<StaffProfile?> profile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('perfiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row == null || row['activo'] != true) return null;
    return StaffProfile.fromJson(row);
  }

  @override
  Future<StaffProfile> login(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final value = await profile();
    if (value == null) {
      await client.auth.signOut();
      throw const AppFailure(
        'Tu cuenta no tiene un acceso de personal activo.',
      );
    }
    return value;
  }

  @override
  Future<void> logout() => client.auth.signOut();
  @override
  Future<({List<Station> stations, bool hasMore})> stations(
    StationQuery query,
  ) async {
    final result = Map<String, dynamic>.from(
      await client.rpc(
        'consultar_gasolineras',
        params: {
          'p_nombre': query.name,
          'p_ciudad': query.city,
          'p_combustible': query.fuelId,
          'p_inactivas': query.inactive,
          'p_asignadas': query.assigned,
          'p_pagina': query.page,
        },
      ) as Map,
    );
    return (
      stations: (result['elementos'] as List)
          .map((j) => Station.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
      hasMore: result['hay_mas'] == true,
    );
  }

  @override
  Future<Station?> station(String id) async {
    final j = await client
        .from('surtidores')
        .select('*,surtidor_combustible(*,combustibles(nombre,activo))')
        .eq('id', id)
        .maybeSingle();
    if (j == null) return null;
    final changed = DateTime.parse(j['cambiado_estado_en'] as String);
    j['combustibles'] = (j['surtidor_combustible'] as List)
        .where(
          (f) => f['activo'] == true && f['combustibles']['activo'] == true,
        )
        .map((f) {
          final at = DateTime.tryParse(f['actualizado_en'] as String? ?? '');
          return {
            'combustible_id': f['combustible_id'],
            'nombre': f['combustibles']['nombre'],
            'estado': at == null || at.isBefore(changed)
                ? 'sin_informacion'
                : f['estado'],
            'actualizado_en': f['actualizado_en'],
            'informado_por': f['informado_por'],
          };
        })
        .toList();
    return Station.fromJson(j);
  }

  @override
  Future<List<Map<String, dynamic>>> fuels() async => await client
      .from('combustibles')
      .select('id,nombre')
      .eq('activo', true)
      .order('nombre', ascending: true);
  @override
  Future<String> saveStation(StationDraft d) async {
    d.validate();
    return await client.rpc(
      'guardar_surtidor',
      params: {
        'p_id': d.id,
        'p_nombre': d.name.trim(),
        'p_direccion': d.address.trim(),
        'p_ciudad': d.city,
        'p_latitud': d.latitude,
        'p_longitud': d.longitude,
        'p_combustibles': d.fuelIds,
      },
    ) as String;
  }

  @override
  Future<void> setActive(String id, bool active) async {
    await client.rpc(
      'cambiar_estado_surtidor',
      params: {'p_id': id, 'p_activo': active},
    );
  }

  @override
  Future<List<StaffProfile>> managers() async =>
      (await client
              .from('perfiles')
              .select()
              .eq('rol', 'encargado')
              .eq('activo', true)
              .order('nombre', ascending: true))
          .map(StaffProfile.fromJson)
          .toList();
  @override
  Future<Set<String>> assignedManagers(String stationId) async =>
      (await client
              .from('asignaciones_encargado')
              .select('perfil_id')
              .eq('surtidor_id', stationId)
              .eq('activo', true))
          .map((r) => r['perfil_id'] as String)
          .toSet();
  @override
  Future<void> assignManager(
    String stationId,
    String profileId,
    bool active,
  ) async {
    await client.rpc(
      'asignar_encargado',
      params: {
        'p_surtidor': stationId,
        'p_perfil': profileId,
        'p_activo': active,
      },
    );
  }

  @override
  Future<void> updateAvailability(
    String stationId,
    Map<String, FuelStatus> changes,
  ) async {
    if (changes.isEmpty || changes.values.contains(FuelStatus.sinInformacion)) {
      throw const AppFailure(
        'Selecciona Hay, Poco o No hay para cada combustible que quieras actualizar.',
      );
    }
    await client.rpc(
      'actualizar_disponibilidad',
      params: {
        'p_surtidor': stationId,
        'p_cambios': changes.entries
            .map(
              (e) => {'combustible_id': e.key, 'estado': e.value.databaseValue},
            )
            .toList(),
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> history(String stationId) async =>
      await client
          .from('historial_disponibilidad')
          .select()
          .eq('surtidor_id', stationId)
          .order('creado_en', ascending: false)
          .limit(50);
}
