import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filacero/core/app_controller.dart';
import 'package:filacero/core/supabase_config.dart';
import 'package:filacero/data/supabase_repository.dart';
import 'package:filacero/main.dart';
import 'package:filacero/models/domain.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL'),
      adminPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');
  const managerEmail = String.fromEnvironment('TEST_MANAGER_EMAIL'),
      managerPassword = String.fromEnvironment('TEST_MANAGER_PASSWORD');
  const driverEmail = String.fromEnvironment('TEST_DRIVER_EMAIL'),
      driverPassword = String.fromEnvironment('TEST_DRIVER_PASSWORD');
  const unassignedEmail = String.fromEnvironment('TEST_UNASSIGNED_EMAIL');
  testWidgets(
    'Alta directa, permisos del responsable y consulta del conductor',
    (t) async {
      expect(
        [
          adminEmail,
          adminPassword,
          managerEmail,
          managerPassword,
          driverEmail,
          driverPassword,
          unassignedEmail,
        ].every((s) => s.isNotEmpty),
        isTrue,
      );
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
        const Duration(seconds: 35),
      );
      Future<void> waitFor(bool Function() ready, String label) async {
        final end = DateTime.now().add(const Duration(seconds: 45));
        while (!ready() && DateTime.now().isBefore(end)) {
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(ready(), isTrue, reason: label);
        await settle();
      }

      Future<void> tap(String label) async {
        await t.ensureVisible(find.text(label).last);
        await settle();
        await t.tap(find.text(label).last);
        await settle();
      }

      Future<void> shot(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        await binding.takeScreenshot(name);
      }

      Future<void> switchUser(String email, String password) async {
        await c.logout();
        await settle();
        await c.login(email, password);
        await settle();
      }

      try {
        await t.pumpWidget(FilaCeroApp(controller: c));
        await settle();
        if (defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          await t.pump();
        }
        await c.login(adminEmail, adminPassword);
        await settle();
        final existing = rows(
          await c.query('lookup_email', {
            'email': 'andrea.paredes@filacero.test',
          }),
        );
        await tap('Usuarios');
        await waitFor(
          () =>
              find.text('Registrar personal').evaluate().isNotEmpty &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty,
          'Usuarios',
        );
        await tap('Registrar personal');
        await waitFor(
          () => find.text('Empresa operadora').evaluate().isNotEmpty,
          'Formulario único',
        );
        if (existing.isEmpty) {
          final fields = find.byType(TextFormField);
          await t.enterText(fields.at(0), 'Andrea Paredes Soto');
          await t.enterText(fields.at(1), 'andrea.paredes@filacero.test');
          await t.enterText(fields.at(3), managerPassword);
          FocusManager.instance.primaryFocus?.unfocus();
          await settle();
          await t.ensureVisible(
            find.byType(DropdownButtonFormField<String>).last,
          );
          await t.tap(find.byType(DropdownButtonFormField<String>).last);
          await settle();
          await tap('Automóvil Club Boliviano');
          await waitFor(
            () =>
                find.text('San Jorge').evaluate().isNotEmpty &&
                !find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
            'Estaciones de la empresa',
          );
          await tap('San Jorge');
          await shot('pantalla17-HU-08-asignaciones');
          await tap('Registrar cuenta');
          await waitFor(
            () => find.text('Registrar personal').evaluate().isNotEmpty,
            'Alta directa completada',
          );
        } else {
          await t.pageBack();
          await settle();
        }
        final created = rows(
          await c.query('lookup_email', {
            'email': 'andrea.paredes@filacero.test',
          }),
        );
        expect(created.single['rol'], 'responsable');
        expect(created.single['estado'], 'active');
        final assigns = rows(
          await c.query('assignments', {'id': created.single['id']}),
        );
        expect(assigns.any((a) => a['activo'] == true), isTrue);
        await t.enterText(
          find.byType(TextField).first,
          'andrea.paredes@filacero.test',
        );
        await t.testTextInput.receiveAction(TextInputAction.done);
        await waitFor(
          () => find.text('Andrea Paredes Soto').evaluate().isNotEmpty,
          'Cuenta nueva visible',
        );
        await tap('Andrea Paredes Soto');
        await waitFor(
          () => find.text('Editar acceso y estaciones').evaluate().isNotEmpty,
          'Ficha directa',
        );
        await shot('pantalla21-HU-08-ficha-usuario');
        expect(find.textContaining('Invitación'), findsNothing);
        expect(find.textContaining(RegExp(r'(EST|EMP|PER)-\d+')), findsNothing);
        if (existing.isNotEmpty) {
          await tap('Editar acceso y estaciones');
          await waitFor(
            () => find.text('San Jorge').evaluate().isNotEmpty,
            'Asignaciones editables',
          );
          await shot('pantalla17-HU-08-asignaciones');
        }
        await switchUser(managerEmail, managerPassword);
        expect(c.manager, isTrue);
        await tap('Mis estaciones');
        await waitFor(
          () => find.text('San Jorge').evaluate().isNotEmpty,
          'Estaciones del responsable',
        );
        await shot('pantalla18-HU-09-mis-estaciones');
        await tap('San Jorge');
        await waitFor(
          () => find.text('Actualizar disponibilidad').evaluate().isNotEmpty,
          'Detalle autorizado',
        );
        await tap('Actualizar disponibilidad');
        await tap('Disponible');
        await shot('pantalla19-HU-09-publicacion');
        await tap('Publicar actualización');
        await waitFor(
          () => find.text('Actualizar disponibilidad').evaluate().isNotEmpty,
          'Publicación guardada',
        );
        await switchUser(unassignedEmail, managerPassword);
        await tap('Mis estaciones');
        await waitFor(
          () => find.text('Sin estaciones asignadas').evaluate().isNotEmpty,
          'Responsable sin asignaciones',
        );
        await shot('pantalla20-HU-09-sin-asignar');
        await switchUser(driverEmail, driverPassword);
        expect(c.admin, isFalse);
        expect(c.manager, isFalse);
        await shot('pantalla15-HU-07-inicio-conductor');
        expect(find.text('Usuarios'), findsNothing);
        await tap('Mis favoritas');
        await waitFor(
          () => find.text('Calacoto').evaluate().isNotEmpty,
          'Favoritas persistentes',
        );
        await shot('pantalla16-HU-10-favoritas-conductor');
        await c.logout();
        await settle();
        expect(c.signedIn, isFalse);
      } finally {
        await client.auth.signOut();
        await t.pumpWidget(const SizedBox());
        c.dispose();
      }
    },
  );
}
