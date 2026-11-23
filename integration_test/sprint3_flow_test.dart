import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filacero/core/app_controller.dart';
import 'package:filacero/core/supabase_config.dart';
import 'package:filacero/data/supabase_repository.dart';
import 'package:filacero/data/travel_repository.dart';
import 'package:filacero/main.dart';
import 'package:filacero/models/domain.dart';
import 'package:filacero/screens/travel_map.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const onlyLocation = bool.fromEnvironment('TEST_LOCATION_ONLY');
  testWidgets(onlyLocation ? 'HU15 ubicación y guardado en Android' : 'HU11 a HU15 con APIs, BD y aviso real en Android', (t) async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    final client = Supabase.instance.client;
    await client.auth.signOut();
    final c = AppController(SupabaseRepository(client));
    await c.initialize();
    final manager = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await manager.auth.signInWithPassword(
      email: 'mateo.quispe@filacero.test',
      password: 'Encargado26',
    );
    const stationId = 'e315662c-caa0-426b-9791-ff16f2c738c7';
    const fuelId = '8d92b48f-1464-46aa-a633-c564f35ea2f9';
    Future<void> publish(String state) => manager.rpc(
      'fc_command',
      params: {
        'p_action': 'publish',
        'p_data': {
          'id': stationId,
          'operation': newId(),
          'changes': [
            {'id': fuelId, 'estado': state},
          ],
        },
      },
    );
    Future<void> frames() async {
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> wait(
      bool Function() predicate,
      String label, {
      int seconds = 45,
    }) async {
      debugPrint('CHECK: $label');
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!predicate() && DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 200));
      }
      if (!predicate()) {
        debugPrint(
          'UI: ${t.allWidgets.whereType<Text>().map((w) => w.data).whereType<String>().join(' | ')}',
        );
        await binding.takeScreenshot('fallo-sprint3');
      }
      expect(predicate(), isTrue, reason: label);
      debugPrint('PASS: $label');
      await frames();
    }

    Future<void> tap(String text) async {
      if (find.text(text).evaluate().isEmpty) {
        await t.scrollUntilVisible(
          find.text(text),
          260,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 20,
        );
      }
      await t.ensureVisible(find.text(text).last);
      await frames();
      await t.tap(find.text(text).last);
      await frames();
    }

    Future<void> shot(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await frames();
      await binding.takeScreenshot(name);
    }

    try {
      if (!onlyLocation) {
        await publish('limitada');
        await c.login('valentina.rojas@filacero.test', 'Conductor26');
      } else {
        await c.login('marcela.salvatierra@filacero.test', 'AdminAula26');
      }
      await t.pumpWidget(FilaCeroApp(controller: c));
      await frames();
      await binding.convertFlutterSurfaceToImage();
      await t.pump();
      if (!onlyLocation) {
      await tap('Mis preferencias');
      await wait(
        () => find.text('Guardar preferencias').evaluate().isNotEmpty,
        'Preferencias cargadas',
      );
      await tap('20 km');
      await shot('pantalla1-HU-11-preferencias');
      await tap('Guardar preferencias');
      await wait(
        () => find.text('Recomendaciones').evaluate().isNotEmpty,
        'Preferencias guardadas y retorno',
      );
      final pref = await TravelRepository(client).query('preferences');
      expect(pref['distancia_maxima_km'], 20);
      await tap('Recomendaciones');
      await wait(
        () => find.text('Elegir en mapa').evaluate().isNotEmpty,
        'Recomendaciones listas',
      );
      await tap('Elegir en mapa');
      await wait(
        () => find.byType(TravelMap).evaluate().isNotEmpty,
        'Selector de origen manual',
      );
      await t.tapAt(t.getCenter(find.byType(TravelMap)));
      await frames();
      await wait(
        () => find
            .byWidgetPredicate((w) => w is FilledButton && w.onPressed != null)
            .evaluate()
            .isNotEmpty,
        'Selección de origen preparada',
      );
      await tap('Elegir punto de partida');
      await wait(
        () => find.text('Cambiar origen').evaluate().isNotEmpty,
        'Origen manual seleccionado',
      );
      await tap('Buscar estaciones');
      await wait(
        () => find.text('Ver estación').evaluate().isNotEmpty,
        'Route Matrix respondió con estación elegible',
      );
      await shot('pantalla2-HU-12-recomendaciones');
      await tap('Cómo llegar');
      await wait(
        () => find.textContaining('estimados').evaluate().isNotEmpty,
        'Routing dibujado con distancia y tiempo',
      );
      await shot('pantalla3-HU-13-ruta');
      await t.pageBack();
      await frames();
      expect(find.text('Ver estación'), findsWidgets);
      await t.pageBack();
      await frames();
      await c.command('favorite', {'id': stationId, 'activo': true});
      await tap('Mis avisos');
      await wait(
        () => find.byType(SwitchListTile).evaluate().isNotEmpty,
        'Favoritas para avisos cargadas',
      );
      final switches = find.byType(SwitchListTile);
      if (find.text('Activar en este teléfono').evaluate().isNotEmpty) {
        await tap('Activar en este teléfono');
        await wait(
          () => c.push.identifier != null,
          'Este teléfono registrado en FCM',
          seconds: 70,
        );
      }
      final tile = switches
          .evaluate()
          .map((e) => e.widget as SwitchListTile)
          .firstWhere((s) => (s.title as Text).data == 'San Jorge');
      if (tile.value) {
        await t.ensureVisible(find.text('San Jorge'));
        await t.tap(find.text('San Jorge'));
        await wait(
          () => switches.evaluate().any((e) {
            final s = e.widget as SwitchListTile;
            return (s.title as Text).data == 'San Jorge' && !s.value;
          }),
          'Aviso desactivado',
        );
      }
      await t.ensureVisible(find.text('San Jorge'));
      await t.tap(find.text('San Jorge'));
      await frames();
      await wait(
        () =>
            c.push.identifier != null &&
            switches.evaluate().any((e) {
              final s = e.widget as SwitchListTile;
              return (s.title as Text).data == 'San Jorge' && s.value;
            }),
        'Aviso activado con registro FCM real',
        seconds: 70,
      );
      await shot('pantalla4-HU-14-avisos');
      await publish('disponible');
      await wait(
        () =>
            find.byType(SnackBar).evaluate().isNotEmpty &&
            find.text('Ver').evaluate().isNotEmpty,
        'Aviso recibido en primer plano desde publicación responsable',
        seconds: 100,
      );
      await shot('pantalla5-HU-14-aviso-recibido');
      await tap('Ver');
      await wait(
        () => find.text('Combustibles').evaluate().isNotEmpty,
        'Aviso abre detalle actualizado',
      );
      expect(find.text('Disponible'), findsWidgets);
      await t.pageBack();
      await frames();
      await t.pageBack();
      await frames();
      await c.logout();
      await frames();
      await c.login('marcela.salvatierra@filacero.test', 'AdminAula26');
      }
      await frames();
      await tap('Consultar estaciones');
      await wait(
        () => find.byType(TextField).evaluate().isNotEmpty,
        'Buscador del catálogo',
      );
      await t.enterText(find.byType(TextField).first, 'San Jorge');
      FocusManager.instance.primaryFocus?.unfocus();
      await frames();
      await wait(
        () => find.text('San Jorge').evaluate().isNotEmpty,
        'Catálogo administrativo',
      );
      await tap('San Jorge');
      await wait(
        () => find.text('Combustibles').evaluate().isNotEmpty,
        'Detalle administrativo',
      );
      await tap('Editar estación');
      await wait(
        () => find.text('Revisar ubicación en el mapa').evaluate().isNotEmpty,
        'Ubicación actual cargada',
      );
      await tap('Revisar ubicación en el mapa');
      await t.enterText(
        find.byType(TextField).first,
        'Estación de Servicio Automóvil Club Boliviano La Paz',
      );
      await t.tap(find.byIcon(Icons.search));
      await wait(
        () => find.byType(ListTile).evaluate().isNotEmpty,
        'Geocoding devuelve coincidencias',
      );
      await shot('pantalla6-HU-15-busqueda');
      await t.tap(find.byType(ListTile).first);
      await frames();
      await shot('pantalla7-HU-15-punto');
      await tap('Usar esta ubicación');
      await tap('Guardar estación');
      await wait(
        () => find.text('Editar estación').evaluate().isNotEmpty,
        'Ubicación guardada sin duplicar estación',
      );
      final location = await TravelRepository(client)
          .query('location', {'id': stationId});
      expect(location['id'], stationId);
      expect(location['latitud'], isNotNull);
      await shot('pantalla8-HU-15-estacion-guardada');
    } finally {
      await manager.auth.signOut();
      await manager.dispose();
      await c.logout();
      c.dispose();
    }
  });
}
