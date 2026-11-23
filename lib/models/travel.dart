import 'package:latlong2/latlong.dart';

import 'domain.dart';

LatLng? recordPoint(AppRecord value) {
  final lat = value['latitud'], lon = value['longitud'];
  if (lat is! num ||
      lon is! num ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    return null;
  }
  return LatLng(lat.toDouble(), lon.toDouble());
}

AppRecord pointJson(LatLng point) => {
  'lat': point.latitude,
  'lon': point.longitude,
};

String roadDistance(num meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
String travelTime(num seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '${minutes < 1 ? 1 : minutes} min';
  return '${minutes ~/ 60} h ${minutes % 60} min';
}

List<LatLng> routePoints(dynamic value) {
  if (value is! List || value.length < 2) {
    throw const FormatException('No se recibió un recorrido válido.');
  }
  return value.map((item) {
    if (item is! List || item.length != 2 || item[0] is! num || item[1] is! num) {
      throw const FormatException('El recorrido recibido no es válido.');
    }
    final point = recordPoint({'latitud': item[0], 'longitud': item[1]});
    if (point == null) {
      throw const FormatException('El recorrido recibido no es válido.');
    }
    return point;
  }).toList();
}
