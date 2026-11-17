import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filacero/core/app_controller.dart';
import 'package:filacero/core/supabase_config.dart';
import 'package:filacero/data/supabase_repository.dart';
import 'package:filacero/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL');
  const adminPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');
  testWidgets('Recorridos revisados de Sprint 2 en dispositivo', (t) async {
    expect(adminEmail, isNotEmpty);
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    final client = Supabase.instance.client;
    await client.auth.signOut();
    final c = AppController(SupabaseRepository(client));
    await c.initialize();
    Future<void> settle() => t.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    Future<void> waitFor(bool Function() predicate, String label) async {
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (!predicate() && DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 200));
      }
      if (!predicate()) {
        debugPrint(
          'ESTADO: sesión=${c.client.auth.currentSession != null}; rol=${c.profile?['rol']}; error=${c.sessionError}',
        );
        await binding.takeScreenshot('fallo-recorrido');
      }
      expect(predicate(), isTrue, reason: label);
      await settle();
    }

    Future<void> shot(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await binding.takeScreenshot(name);
    }

    Future<void> tapText(String text) async {
      await t.ensureVisible(find.text(text).last);
      await t.tap(find.text(text).last);
      await settle();
    }

    try {
      await t.pumpWidget(FilaCeroApp(controller: c));
      await settle();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await binding.convertFlutterSurfaceToImage();
        await t.pump();
      }
      await shot('pantalla1-HU-07-bienvenida');
      await tapText('Crear cuenta');
      expect(find.text('Nombre completo'), findsOneWidget);
      await shot('pantalla2-HU-07-registro');
      await t.pageBack();
      await settle();
      await tapText('Consultar estaciones');
      await waitFor(
        () => find.text('Calacoto').evaluate().isNotEmpty,
        'Catálogo público cargado',
      );
      await shot('pantalla3-HU-10-lista');
      await t.tap(find.byTooltip('Filtrar estaciones'));
      await settle();
      await shot('pantalla4-HU-10-filtros');
      await tapText('Aplicar filtros');
      await waitFor(
        () => find.text('Calacoto').evaluate().isNotEmpty,
        'Lista filtrada',
      );
      await tapText('Calacoto');
      await waitFor(
        () => find.text('Combustibles').evaluate().isNotEmpty,
        'Detalle cargado',
      );
      expect(find.text('Actualizar disponibilidad'), findsNothing);
      await shot('pantalla5-HU-10-detalle');
      await t.tap(find.byTooltip('Guardar favorita'));
      await settle();
      await shot('pantalla6-HU-07-acceso');
      await t.enterText(find.byType(TextFormField).first, adminEmail);
      await t.enterText(find.byType(TextFormField).last, adminPassword);
      await t.ensureVisible(find.byKey(const Key('auth-submit')));
      await t.tap(find.byKey(const Key('auth-submit')));
      await waitFor(
        () => c.admin && find.byType(TextFormField).evaluate().isEmpty,
        'Acceso y retorno al detalle',
      );
      await waitFor(
        () => find.byTooltip('Quitar favorita').evaluate().isNotEmpty,
        'Se recupera intención de guardar',
      );
      await shot('pantalla7-HU-10-favorita');
      await t.tap(find.byTooltip('Quitar favorita'));
      await waitFor(
        () => find.byTooltip('Guardar favorita').evaluate().isNotEmpty,
        'Baja lógica de favorita',
      );
      await t.pageBack();
      await settle();
      await t.pageBack();
      await settle();
      expect(find.text('Panel administrativo'), findsOneWidget);
      await shot('pantalla8-HU-07-panel');
      await tapText('Empresas');
      await waitFor(
        () => find.text('Automóvil Club Boliviano').evaluate().isNotEmpty,
        'Empresas cargadas',
      );
      await shot('pantalla9-HU-06-empresas');
      await tapText('Nueva empresa');
      await shot('pantalla10-HU-06-formulario-empresa');
      await t.pageBack();
      await settle();
      await t.pageBack();
      await settle();
      await tapText('Estaciones');
      await waitFor(
        () => find.text('Calacoto').evaluate().isNotEmpty,
        'Administración de estaciones',
      );
      await tapText('Nueva estación');
      await waitFor(
        () => find.text('Empresa operadora').evaluate().isNotEmpty,
        'Formulario de estación cargado',
      );
      expect(find.text('Latitud'), findsNothing);
      expect(find.text('Longitud'), findsNothing);
      await shot('pantalla11-HU-06-formulario-estacion');
      await t.pageBack();
      await settle();
      await t.pageBack();
      await settle();
      await tapText('Usuarios');
      await waitFor(
        () =>
            find.text('Registrar personal').evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
        'Usuarios cargados',
      );
      await shot('pantalla12-HU-08-usuarios');
      await tapText(c.name);
      await waitFor(
        () => find
            .text('Edita tu perfil y contraseña desde Mi cuenta.')
            .evaluate()
            .isNotEmpty,
        'Ficha de usuario cargada',
      );
      expect(find.text('Historial administrativo'), findsNothing);
      await shot('pantalla21-HU-08-ficha-usuario');
      await t.pageBack();
      await settle();
      await tapText('Registrar personal');
      await waitFor(
        () => find.text('Rol').evaluate().isNotEmpty,
        'Formulario de personal',
      );
      await shot('pantalla13-HU-08-registro-personal');
      await t.pageBack();
      await settle();
      await t.pageBack();
      await settle();
      await tapText('Mi cuenta');
      await waitFor(
        () => find.text('Cambiar contraseña').evaluate().isNotEmpty,
        'Mi cuenta cargada',
      );
      await shot('pantalla14-HU-07-mi-cuenta');
      await tapText('Cerrar sesión');
      await waitFor(
        () =>
            !c.signedIn &&
            find.text('Consultar estaciones').evaluate().isNotEmpty,
        'Salida limpia a bienvenida',
      );
      expect(find.text('Usuarios'), findsNothing);
    } finally {
      await client.auth.signOut();
      c.dispose();
    }
  });
}
