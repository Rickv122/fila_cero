enum UserRole { administrador, encargado }

class StaffProfile {
  final String id, name;
  final UserRole role;
  final bool active;
  const StaffProfile({
    required this.id,
    required this.name,
    required this.role,
    this.active = true,
  });
  factory StaffProfile.fromJson(Map<String, dynamic> j) => StaffProfile(
    id: j['id'] as String,
    name: j['nombre'] as String,
    role: UserRole.values.byName(j['rol'] as String),
    active: j['activo'] as bool,
  );
}

enum FuelStatus { hay, poco, noHay, sinInformacion }

extension FuelStatusText on FuelStatus {
  String get label =>
      const ['Hay', 'Poco', 'No hay', 'Sin información vigente'][index];
  String get databaseValue =>
      const ['hay', 'poco', 'no_hay', 'sin_informacion'][index];
}

class FuelAvailability {
  final String fuelId, fuelName;
  final FuelStatus status;
  final DateTime? updatedAt;
  final String? author;
  const FuelAvailability({
    required this.fuelId,
    required this.fuelName,
    required this.status,
    this.updatedAt,
    this.author,
  });
  FuelStatus effectiveStatus([DateTime? now]) =>
      updatedAt == null ||
          !(now ?? DateTime.now()).isBefore(
            updatedAt!.add(const Duration(hours: 2)),
          )
      ? FuelStatus.sinInformacion
      : status;
  factory FuelAvailability.fromJson(Map<String, dynamic> j) => FuelAvailability(
    fuelId: j['combustible_id'] as String,
    fuelName: j['nombre'] as String,
    status: switch (j['estado']) {
      'hay' => FuelStatus.hay,
      'poco' => FuelStatus.poco,
      'no_hay' => FuelStatus.noHay,
      _ => FuelStatus.sinInformacion,
    },
    updatedAt: DateTime.tryParse(j['actualizado_en'] as String? ?? ''),
    author: j['informado_por'] as String?,
  );
}

class Station {
  final String id, name, address, city;
  final double latitude, longitude;
  final bool active;
  final List<FuelAvailability> fuels;
  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.active,
    required this.fuels,
  });
  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id: j['id'] as String,
    name: j['nombre'] as String,
    address: j['direccion'] as String,
    city: j['ciudad'] as String,
    latitude: (j['latitud'] as num).toDouble(),
    longitude: (j['longitud'] as num).toDouble(),
    active: j['activo'] as bool,
    fuels: (j['combustibles'] as List? ?? [])
        .map(
          (f) => FuelAvailability.fromJson(Map<String, dynamic>.from(f as Map)),
        )
        .toList(),
  );
}

class StationDraft {
  final String? id;
  final String name, address, city;
  final double latitude, longitude;
  final List<String> fuelIds;
  const StationDraft({
    this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.fuelIds,
  });
  void validate() {
    if (name.trim().isEmpty ||
        address.trim().isEmpty ||
        !['La Paz', 'El Alto'].contains(city) ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        fuelIds.isEmpty) {
      throw const AppFailure(
        'Revisa los campos obligatorios, coordenadas y combustibles.',
      );
    }
  }
}

class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}

class StationQuery {
  final String name;
  final String? city, fuelId;
  final bool inactive, assigned;
  final int page;
  const StationQuery({
    this.name = '',
    this.city,
    this.fuelId,
    this.inactive = false,
    this.assigned = false,
    this.page = 0,
  });
}
