import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filacero/core/app_controller.dart';
import 'package:filacero/core/supabase_config.dart';
import 'package:filacero/data/supabase_repository.dart';
import 'package:filacero/models/domain.dart';
import 'package:filacero/main.dart';

// Uses two controlled identities. Does not send email or publish invented stock.
// The previous role is restored and the evaluation assignment is closed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Conductor, invitación aceptada y responsable con revocación real',
    (t) async {
      const ownerEmail = String.fromEnvironment('TEST_ADMIN_EMAIL');
      const ownerPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');
      const bootstrapEmail = String.fromEnvironment('TEST_BOOTSTRAP_EMAIL');
      const bootstrapPassword = String.fromEnvironment(
        'TEST_BOOTSTRAP_PASSWORD',
      );
      expect(bootstrapEmail, isNotEmpty);
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      final client = Supabase.instance.client;
      await client.auth.signOut();
      final operator = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
      await operator.auth.signInWithPassword(
        email: bootstrapEmail,
        password: bootstrapPassword,
      );
      final admin = SupabaseRepository(operator);
      final owner = rows(
        await admin.query('lookup_email', {'email': ownerEmail}),
      ).single;
      final originalRole = owner['rol'];
      final options = row(await admin.query('options'));
      final company = rows(options['empresas'])
          .firstWhere((e) => e['denominacion'] == 'Automóvil Club Boliviano');
      final catalog = row(
        await admin.query('catalog', {
          'mode': 'admin',
          'company': company['id'],
          'status': 'active',
        }),
      );
      final station = rows(catalog['rows'])
          .firstWhere((s) => s['nombre'] == 'San Jorge');
      final c = AppController(SupabaseRepository(client));
      await c.initialize();
      String? memberId, assignmentId;
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
        expect(predicate(), isTrue, reason: label);
        await settle();
      }

      Future<void> tap(String label) async {
        if (find.text(label).evaluate().isEmpty) {
          await t.scrollUntilVisible(
            find.text(label),
            220,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await t.ensureVisible(find.text(label).last);
        await t.tap(find.text(label).last);
        await settle();
      }

      Future<void> shot(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        await binding.takeScreenshot(name);
      }

      try {
        await admin.command('user_role', {
          'id': owner['id'],
          'rol': 'conductor',
        });
        await c.login(ownerEmail, ownerPassword);
        await t.pumpWidget(FilaCeroApp(controller: c));
        await settle();
        if (defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          await t.pump();
        }
        expect(c.manager, isFalse);
        expect(c.admin, isFalse);
        await shot('pantalla15-HU-07-inicio-conductor');
        await tap('Mis favoritas');
        await waitFor(
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
          'Favoritas del conductor',
        );
        await shot('pantalla16-HU-10-favoritas-conductor');
        await t.pageBack();
        await settle();
        final invitation = await admin.staff({
          'action': 'invite',
          'nombre': owner['nombre'],
          'email': ownerEmail,
          'rol': 'responsable',
          'empresa_id': company['id'],
        });
        expect(invitation['id'], owner['id']);
        await tap('Mi cuenta');
        await waitFor(
          () => find.text('Aceptar').evaluate().isNotEmpty,
          'Invitación reutiliza la identidad existente',
        );
        await shot('pantalla17-HU-08-aceptar-vinculacion');
        await tap('Aceptar');
        await tap('Aceptar');
        await waitFor(
          () => c.manager,
          'La aceptación habilita el rol responsable',
        );
        final memberships = rows(
          await admin.query('memberships', {'id': owner['id']}),
        );
        final member = memberships.firstWhere(
          (m) =>
              m['empresa_id'] == company['id'] &&
              m['activo'] == true &&
              m['aceptada_en'] != null,
        );
        memberId = member['id'];
        assignmentId = newId();
        await admin.command('assignment_add', {
          'id': assignmentId,
          'vinculacion_id': memberId,
          'estacion_id': station['id'],
        });
        await t.pageBack();
        await settle();
        await tap('Mis estaciones');
        await waitFor(
          () => find.text('San Jorge').evaluate().isNotEmpty,
          'Solo estación asignada',
        );
        await shot('pantalla18-HU-09-mis-estaciones');
        await tap('San Jorge');
        await waitFor(
          () => find.text('Actualizar disponibilidad').evaluate().isNotEmpty,
          'Detalle autorizado',
        );
        await tap('Actualizar disponibilidad');
        await shot('pantalla19-HU-09-publicacion');
        await t.tap(find.text('Disponible').first);
        await settle();
        // Withdraw permission before saving. No fabricated availability reaches the catalogue.
        await admin.command('assignment_end', {'id': assignmentId});
        await tap('Publicar actualización');
        await waitFor(
          () => find
              .text('No tienes una asignación vigente para esta estación')
              .evaluate()
              .isNotEmpty,
          'Revocación con JWT todavía vigente',
        );
        await shot('pantalla20-HU-09-revocacion');
        final history = rows(
          await admin.query('history', {'id': station['id']}),
        );
        expect(
          history,
          isEmpty,
          reason: 'La prueba no debe crear existencias ficticias',
        );
        await admin.command('user_state', {'id': owner['id'], 'activo': false});
        await c.refreshProfile();
        await settle();
        expect(find.text('Acceso no disponible'), findsOneWidget);
        await admin.command('user_state', {'id': owner['id'], 'activo': true});
      } finally {
        if (memberId != null) {
          await admin.command('membership_end', {'id': memberId});
        }
        await admin.command('user_state', {'id': owner['id'], 'activo': true});
        await admin.command('user_role', {
          'id': owner['id'],
          'rol': originalRole,
        });
        await client.auth.signOut();
        c.dispose();
        await operator.auth.signOut();
        await operator.dispose();
      }
    },
  );
}
