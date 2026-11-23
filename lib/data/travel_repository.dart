import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain.dart';
import '../models/travel.dart';

class TravelRepository {
  final SupabaseClient client;
  TravelRepository(this.client);
  Future<dynamic> query(String resource, [AppRecord params = const {}]) =>
      client.rpc(
        'fc3_query',
        params: {'p_resource': resource, 'p_params': params},
      );
  Future<dynamic> command(String action, AppRecord data) =>
      client.rpc('fc3_command', params: {'p_action': action, 'p_data': data});
  Future<AppRecord> geo(String action, [AppRecord data = const {}]) async {
    try {
      final response = await client.functions
          .invoke('geo', body: {'action': action, ...data})
          .timeout(const Duration(seconds: 32));
      final value = row(response.data);
      if (value['error'] != null) {
        throw FormatException(value['error'].toString());
      }
      return value;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw FormatException(details['error'].toString());
      }
      throw const FormatException(
        'No se pudo completar la consulta. Reintenta.',
      );
    } on TimeoutException {
      throw const FormatException(
        'La consulta tardó demasiado. Vuelve a intentar.',
      );
    }
  }

  Future<LatLng> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const FormatException(
        'Activa la ubicación o elige un punto en el mapa.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const FormatException(
        'Puedes elegir tu punto de partida en el mapa.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  Future<AppRecord> recommend(LatLng origin) =>
      geo('recommend', {'origin': pointJson(origin)});
  Future<AppRecord> route(String id, LatLng origin) =>
      geo('route', {'id': id, 'origin': pointJson(origin)});
}
