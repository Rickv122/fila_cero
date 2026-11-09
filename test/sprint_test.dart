import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filacero/core/app_store.dart';
import 'package:filacero/core/app_strings.dart';
import 'package:filacero/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
    await store.load();
  });
  test(
    'HU01 registro persistente y rechazo de contraseña incorrecta',
    () async {
      expect(
        await store.register('Prueba', 'PRUEBA@example.test', 'Clave2026!'),
        isNull,
      );
      expect(store.currentUser!.email, 'prueba@example.test');
      store.logout();
      final loaded = AppStore(store.preferences);
      await loaded.load();
      expect(await loaded.login('prueba@example.test', 'Incorrecta'), isFalse);
      expect(loaded.currentUser, isNull);
      expect(await loaded.login('prueba@example.test', 'Clave2026!'), isTrue);
      expect(
        store.preferences.getString(AppStore.storageKey),
        isNot(contains('Clave2026!')),
      );
    },
  );
  test('HU01 correo duplicado e inválido no crean cuentas', () async {
    expect(await store.register('Test', 'mal', 'abcdefgh'), 'invalid');
    expect(
      await store.register('Test', AppStore.driverEmail, 'abcdefgh'),
      'duplicate',
    );
    expect(await store.register('X', 'nuevo@example.test', 'abc'), 'invalid');
  });
  test('HU05 visitante y conductor no pueden guardar surtidores', () async {
    final s = store.stations.first;
    store.enterGuest();
    await expectLater(store.saveStation(s), throwsStateError);
    await store.login(AppStore.driverEmail, AppStore.demoPassword);
    await expectLater(store.saveStation(s), throwsStateError);
  });
  test('HU05 alta y edición persisten sin duplicar ni perder fecha', () async {
    await store.login(AppStore.adminEmail, AppStore.demoPassword);
    const created = Station(
      id: 'test',
      name: 'Prueba',
      address: 'Av. Ejemplo',
      city: 'El Alto',
      latitude: -16.51,
      longitude: -68.16,
      fuels: ['Diésel'],
    );
    await store.saveStation(created);
    const edited = Station(
      id: 'test',
      name: 'Prueba editada',
      address: 'Av. Nueva',
      city: 'El Alto',
      latitude: -16.52,
      longitude: -68.17,
      fuels: ['GNV'],
    );
    await store.saveStation(edited);
    store.logout();
    store.enterGuest();
    expect(store.stations.where((s) => s.id == 'test').length, 1);
    final loaded = AppStore(store.preferences);
    await loaded.load();
    expect(loaded.stations.last.name, 'Prueba editada');
    expect(loaded.stations.last.fuels, ['GNV']);
    expect(loaded.hasAccess, isFalse);
  });
  test('HU05 rechaza coordenadas inválidas y formulario vacío', () async {
    await store.login(AppStore.adminEmail, AppStore.demoPassword);
    final count = store.stations.length;
    await expectLater(
      store.saveStation(
        const Station(
          id: 'x',
          name: '',
          address: '',
          city: 'La Paz',
          latitude: 91,
          longitude: 0,
          fuels: [],
        ),
      ),
      throwsArgumentError,
    );
    expect(store.stations.length, count);
  });
  test('HU03 cuatro estados y reporte vencido se muestran sin confusión', () {
    expect(
      store.stations.map((s) => s.effectiveStatus()).toSet(),
      FuelStatus.values.toSet(),
    );
    final old = Station(
      id: 'old',
      name: 'Old',
      address: 'A',
      city: 'La Paz',
      latitude: 0,
      longitude: 0,
      fuels: ['GNV'],
      status: FuelStatus.available,
      reportedAt: DateTime.now().subtract(const Duration(hours: 3)),
    );
    expect(old.effectiveStatus(), FuelStatus.unknown);
  });
  testWidgets('HU02 y HU04 visitante abre detalle y Reportar pide sesión', (
    tester,
  ) async {
    await tester.pumpWidget(FilaCeroApp(store: store, mapEnabled: false));
    await tester.tap(find.text(S.visitor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surtidor Plaza Villarroel').first);
    await tester.pumpAndSettle();
    expect(find.text(S.address), findsOneWidget);
    expect(find.text(S.latest), findsOneWidget);
    await tester.scrollUntilVisible(find.text(S.report), 250,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text(S.report));
    await tester.pumpAndSettle();
    expect(find.text(S.loginMessage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(360, 640), const Size(412, 915)]) {
    testWidgets('Bienvenida adaptable ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(FilaCeroApp(store: store, mapEnabled: false));
      await tester.ensureVisible(find.text(S.visitor));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
