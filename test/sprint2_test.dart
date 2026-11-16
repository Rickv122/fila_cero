import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filacero/core/app_controller.dart';
import 'package:filacero/data/fila_repository.dart';
import 'package:filacero/main.dart';
import 'package:filacero/models/domain.dart';
import 'package:filacero/screens/availability_screen.dart';
import 'package:filacero/screens/station_form_screen.dart';

class FakeRepository implements FilaRepository {
  StaffProfile? current;
  bool offline = false;
  int logins = 0, saves = 0;
  StationQuery? lastQuery;
  final changes = StreamController<void>.broadcast();
  late Station item = Station(
    id: 's1',
    name: 'Estación Central',
    address: 'Av. Central 100',
    city: 'La Paz',
    latitude: -16.5,
    longitude: -68.1,
    active: true,
    fuels: [
      FuelAvailability(
        fuelId: 'f1',
        fuelName: 'Diésel',
        status: FuelStatus.hay,
        updatedAt: DateTime.now(),
        author: 'Encargado Central',
      ),
    ],
  );
  @override
  Stream<void> get authChanges => changes.stream;
  @override
  Future<StaffProfile?> profile() async => current;
  @override
  Future<StaffProfile> login(String email, String password) async {
    logins++;
    if (password != 'correcta') {
      throw const AppFailure('Correo o contraseña incorrectos');
    }
    current = StaffProfile(
      id: email,
      name: 'Personal autorizado',
      role: email == 'admin@test.com'
          ? UserRole.administrador
          : UserRole.encargado,
    );
    return current!;
  }

  @override
  Future<void> logout() async {
    current = null;
  }

  @override
  Future<({List<Station> stations, bool hasMore})> stations(
    StationQuery query,
  ) async {
    if (offline) throw Exception('offline');
    lastQuery = query;
    return (
      stations: query.name == 'inexistente' ? <Station>[] : [item],
      hasMore: false,
    );
  }

  @override
  Future<Station?> station(String id) async => item;
  @override
  Future<List<Map<String, dynamic>>> fuels() async => [
    {'id': 'f1', 'nombre': 'Diésel'},
  ];
  @override
  Future<String> saveStation(StationDraft d) async {
    d.validate();
    saves++;
    return 's1';
  }

  @override
  Future<void> setActive(String id, bool active) async {}
  @override
  Future<List<StaffProfile>> managers() async => [];
  @override
  Future<Set<String>> assignedManagers(String stationId) async => {
    'manager@test.com',
  };
  @override
  Future<void> assignManager(
    String stationId,
    String profileId,
    bool active,
  ) async {}
  @override
  Future<void> updateAvailability(
    String stationId,
    Map<String, FuelStatus> changes,
  ) async {
    saves++;
  }

  @override
  Future<List<Map<String, dynamic>>> history(String stationId) async => [];
}

void main() {
  late FakeRepository repo;
  late AppController controller;
  setUp(() {
    repo = FakeRepository();
    controller = AppController(repo);
  });
  tearDown(() async {
    controller.dispose();
    await repo.changes.close();
  });
  test('HU08 la vigencia expira exactamente a las dos horas', () {
    final now = DateTime.utc(2026, 11, 16, 12);
    final fuel = FuelAvailability(
      fuelId: 'x',
      fuelName: 'GNV',
      status: FuelStatus.hay,
      updatedAt: now.subtract(const Duration(hours: 2)),
    );
    expect(fuel.effectiveStatus(now), FuelStatus.sinInformacion);
    expect(
      fuel.effectiveStatus(now.subtract(const Duration(seconds: 1))),
      FuelStatus.hay,
    );
  });
  test('HU06 rechaza coordenadas no finitas y fuera de rango', () {
    for (final lat in [double.nan, double.infinity, 91.0, -91.0]) {
      expect(
        () => StationDraft(
          name: 'A',
          address: 'B',
          city: 'La Paz',
          latitude: lat,
          longitude: 0,
          fuelIds: ['f1'],
        ).validate(),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      () => const StationDraft(
        name: 'A',
        address: 'B',
        city: 'La Paz',
        latitude: 0,
        longitude: 181,
        fuelIds: ['f1'],
      ).validate(),
      throwsA(isA<AppFailure>()),
    );
  });
  test('HU06 valida nombre, dirección y al menos un combustible', () {
    expect(
      () => const StationDraft(
        name: ' ',
        address: 'B',
        city: 'La Paz',
        latitude: 0,
        longitude: 0,
        fuelIds: ['f1'],
      ).validate(),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => const StationDraft(
        name: 'A',
        address: 'B',
        city: 'La Paz',
        latitude: 0,
        longitude: 0,
        fuelIds: [],
      ).validate(),
      throwsA(isA<AppFailure>()),
    );
  });
  test('HU07 cerrar sesión elimina los permisos locales', () async {
    await controller.login('admin@test.com', 'correcta');
    expect(controller.isAdmin, isTrue);
    await controller.logout();
    expect(controller.staff, isNull);
    expect(controller.isAdmin, isFalse);
  });
  testWidgets('HU09 consulta pública con lista y sin acciones de publicación', (
    tester,
  ) async {
    await tester.pumpWidget(FilaCeroApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Estación Central'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);
    await tester.tap(find.text('Estación Central'));
    await tester.pumpAndSettle();
    expect(find.text('Disponibilidad por combustible'), findsOneWidget);
    expect(find.text('Actualizar disponibilidad'), findsNothing);
    expect(find.text('Reportar'), findsNothing);
    expect(find.text('Editar datos generales'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('HU09 buscar y limpiar filtros actualiza la consulta', (
    tester,
  ) async {
    await tester.pumpWidget(FilaCeroApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'inexistente');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repo.lastQuery!.name, 'inexistente');
    expect(find.text('No se encontraron gasolineras'), findsOneWidget);
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(repo.lastQuery!.name, '');
    expect(find.text('Estación Central'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('HU09 error de conexión ofrece reintentar sin datos inventados', (
    tester,
  ) async {
    repo.offline = true;
    await tester.pumpWidget(FilaCeroApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Estación Central'), findsNothing);
    repo.offline = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Estación Central'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'HU07 formulario rechaza correo inválido antes de iniciar sesión',
    (tester) async {
      await tester.pumpWidget(FilaCeroApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Acceso de personal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'incorrecto');
      await tester.enterText(find.byType(TextFormField).last, 'algo');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un correo válido'), findsOneWidget);
      expect(repo.logins, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'HU08 administrador no recibe acción para publicar disponibilidad',
    (tester) async {
      await controller.login('admin@test.com', 'correcta');
      await tester.pumpWidget(FilaCeroApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estación Central'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Editar datos generales'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Actualizar disponibilidad'), findsNothing);
      expect(find.text('Editar datos generales'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('HU08 encargado asignado recibe acción de disponibilidad', (
    tester,
  ) async {
    await controller.login('manager@test.com', 'correcta');
    await tester.pumpWidget(FilaCeroApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estación Central'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Actualizar disponibilidad'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Actualizar disponibilidad'), findsOneWidget);
    expect(find.text('Editar datos generales'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('HU06 un visitante no abre el formulario protegido', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: StationFormScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acceso protegido'), findsOneWidget);
    expect(find.text('Guardar gasolinera'), findsNothing);
  });
  testWidgets('HU08 cerrar sesión retira pantalla protegida', (tester) async {
    await controller.login('manager@test.com', 'correcta');
    await tester.pumpWidget(
      MaterialApp(
        home: AvailabilityScreen(controller: controller, station: repo.item),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardar disponibilidad'), findsOneWidget);
    await controller.logout();
    await tester.pumpAndSettle();
    expect(find.text('Acceso protegido'), findsOneWidget);
    expect(find.text('Guardar disponibilidad'), findsNothing);
  });
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Lista adaptable sin desbordamiento $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(FilaCeroApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
