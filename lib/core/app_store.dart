import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FuelStatus { available, low, empty, unknown }

class Station {
  final String id, name, address, city;
  final double latitude, longitude;
  final List<String> fuels;
  final FuelStatus status;
  final DateTime? reportedAt;
  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.fuels,
    this.status = FuelStatus.unknown,
    this.reportedAt,
  });
  FuelStatus effectiveStatus([DateTime? now]) =>
      reportedAt == null ||
          (now ?? DateTime.now()).difference(reportedAt!).inHours >= 2
      ? FuelStatus.unknown
      : status;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'fuels': fuels,
    'status': status.name,
    'reportedAt': reportedAt?.toIso8601String(),
  };
  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id: j['id'],
    name: j['name'],
    address: j['address'],
    city: j['city'],
    latitude: j['latitude'],
    longitude: j['longitude'],
    fuels: List<String>.from(j['fuels']),
    status: FuelStatus.values.byName(j['status']),
    reportedAt: DateTime.tryParse(j['reportedAt'] ?? ''),
  );
}

class LocalUser {
  final String name, email, salt, passwordHash;
  final bool admin;
  const LocalUser(
    this.name,
    this.email,
    this.salt,
    this.passwordHash, {
    this.admin = false,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'salt': salt,
    'hash': passwordHash,
    'admin': admin,
  };
  factory LocalUser.fromJson(Map<String, dynamic> j) => LocalUser(
    (j['name'] as String).replaceAll(' de prueba', ''),
    (j['email'] as String).replaceAll('@filacero.demo', '@filacero.test'),
    j['salt'],
    j['hash'],
    admin: j['admin'],
  );
}

class AppStore extends ChangeNotifier {
  static const storageKey = 'filacero_sprint1_v1';
  static const demoPassword = 'FilaCero2026!';
  static const adminEmail = 'admin@filacero.test';
  static const driverEmail = 'conductor@filacero.test';
  final SharedPreferences preferences;
  final List<Station> _stations = [];
  final List<LocalUser> _users = [];
  LocalUser? currentUser;
  bool guest = false;
  AppStore(this.preferences);
  List<Station> get stations => List.unmodifiable(_stations);
  bool get isAdmin => currentUser?.admin ?? false;
  bool get hasAccess => currentUser != null || guest;
  static String normalizeEmail(String email) => email.trim().toLowerCase();
  static bool validEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizeEmail(email));
  Future<String> _hash(String password, String salt) async {
    final key =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 120000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(password)),
          nonce: base64Decode(salt),
        );
    return base64Encode(await key.extractBytes());
  }

  Future<LocalUser> _makeUser(
    String name,
    String email,
    String password, {
    bool admin = false,
  }) async {
    final salt = base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    return LocalUser(
      name.trim(),
      normalizeEmail(email),
      salt,
      await _hash(password, salt),
      admin: admin,
    );
  }

  Future<void> load() async {
    final raw = preferences.getString(storageKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _stations.addAll(
        (data['stations'] as List).map((j) => Station.fromJson(j)),
      );
      _users.addAll((data['users'] as List).map((j) => LocalUser.fromJson(j)));
    } else {
      final now = DateTime.now();
      const rows = [
        [
          '1',
          'Surtidor Plaza Villarroel',
          'Av. Busch y plaza Villarroel',
          'La Paz',
          -16.5083,
          -68.1264,
          0,
          12,
        ],
        [
          '2',
          'Surtidor Sopocachi',
          'Av. Arce y calle Rosendo Gutiérrez',
          'La Paz',
          -16.5120,
          -68.1310,
          1,
          28,
        ],
        [
          '3',
          'Surtidor Miraflores',
          'Av. Saavedra y calle Díaz Romero',
          'La Paz',
          -16.5000,
          -68.1180,
          2,
          37,
        ],
        [
          '4',
          'Surtidor Villa Fátima',
          'Av. Las Américas',
          'La Paz',
          -16.4960,
          -68.1220,
          0,
          8,
        ],
        [
          '5',
          'Surtidor Obrajes',
          'Av. Hernando Siles y calle 17',
          'La Paz',
          -16.5260,
          -68.1010,
          3,
          0,
        ],
        [
          '6',
          'Surtidor El Alto Central',
          'Av. 6 de Marzo',
          'El Alto',
          -16.5100,
          -68.1640,
          1,
          18,
        ],
      ];
      for (final r in rows) {
        _stations.add(
          Station(
            id: r[0] as String,
            name: r[1] as String,
            address: r[2] as String,
            city: r[3] as String,
            latitude: r[4] as double,
            longitude: r[5] as double,
            fuels: const ['Especial', 'Diésel'],
            status: FuelStatus.values[r[6] as int],
            reportedAt: r[6] == 3
                ? null
                : now.subtract(Duration(minutes: r[7] as int)),
          ),
        );
      }
      _users.add(
        await _makeUser('Administrador', adminEmail, demoPassword, admin: true),
      );
      _users.add(await _makeUser('Conductor', driverEmail, demoPassword));
      await _persist(_stations, _users);
    }
  }

  Future<void> _persist(List<Station> stations, List<LocalUser> users) async {
    final ok = await preferences.setString(
      storageKey,
      jsonEncode({
        'stations': stations.map((s) => s.toJson()).toList(),
        'users': users.map((u) => u.toJson()).toList(),
      }),
    );
    if (!ok) throw StateError('storage');
  }

  void enterGuest() {
    guest = true;
    currentUser = null;
    notifyListeners();
  }

  void logout() {
    guest = false;
    currentUser = null;
    notifyListeners();
  }

  Future<String?> register(String name, String email, String password) async {
    final mail = normalizeEmail(email);
    if (name.trim().length < 2 || !validEmail(mail) || password.length < 8) {
      return 'invalid';
    }
    if (_users.any((u) => u.email == mail)) return 'duplicate';
    final user = await _makeUser(name, mail, password);
    await _persist(_stations, [..._users, user]);
    _users.add(user);
    currentUser = user;
    guest = false;
    notifyListeners();
    return null;
  }

  Future<bool> login(String email, String password) async {
    final matches = _users.where((u) => u.email == normalizeEmail(email));
    if (matches.isEmpty) return false;
    final user = matches.first;
    if (await _hash(password, user.salt) != user.passwordHash) return false;
    currentUser = user;
    guest = false;
    notifyListeners();
    return true;
  }

  Future<void> saveStation(Station station) async {
    if (!isAdmin) throw StateError('forbidden');
    if (station.name.trim().isEmpty ||
        station.address.trim().isEmpty ||
        !['La Paz', 'El Alto'].contains(station.city) ||
        station.fuels.isEmpty ||
        !station.latitude.isFinite ||
        !station.longitude.isFinite ||
        station.latitude.abs() > 90 ||
        station.longitude.abs() > 180) {
      throw ArgumentError('invalid');
    }
    final next = [..._stations];
    final index = next.indexWhere((s) => s.id == station.id);
    if (index < 0) {
      next.add(station);
    } else {
      next[index] = station;
    }
    await _persist(next, _users);
    _stations
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}
