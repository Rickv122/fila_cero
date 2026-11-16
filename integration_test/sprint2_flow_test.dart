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
  const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL');
  const adminPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');
  const managerEmail = String.fromEnvironment('TEST_MANAGER_EMAIL');
  const managerPassword = String.fromEnvironment('TEST_MANAGER_PASSWORD');
  testWidgets('HU06 a HU10 contra Supabase en Android', (tester) async {
    expect(
      adminEmail,
      isNotEmpty,
      reason: 'Se requieren accesos privados mediante dart-define-from-file.',
    );
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    await Supabase.instance.client.auth.signOut();
    final repo = SupabaseRepository(Supabase.instance.client);
    final controller = AppController(repo);
    await controller.initialize();
    String? created;
    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    Future<void> shot(String name) async {
      await settle();
      await binding.takeScreenshot(name);
    }

    Future<void> visible(String text) async {
      await tester.scrollUntilVisible(
        find.text(text).first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }

    try {
      await tester.pumpWidget(FilaCeroApp(controller: controller));
      await settle();
      expect(find.text('Surtidor El Alto Central'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await shot('pantalla1-HU-09-lista');
      await visible('Surtidor Sopocachi');
      await tester.tap(find.text('Surtidor Sopocachi'));
      await settle();
      expect(find.text('Disponibilidad por combustible'), findsOneWidget);
      expect(find.text('Actualizar disponibilidad'), findsNothing);
      await shot('pantalla2-HU-09-detalle');
      await tester.pageBack();
      await settle();
      await tester.tap(find.byTooltip('Acceso de personal'));
      await settle();
      await shot('pantalla3-HU-07-inicio-sesion');
      await tester.enterText(find.byType(TextFormField).first, adminEmail);
      await tester.enterText(find.byType(TextFormField).last, adminPassword);
      await tester.tap(find.text('Iniciar sesión'));
      await settle();
      expect(controller.isAdmin, isTrue);
      await tester.tap(find.byTooltip('Mi cuenta'));
      await settle();
      await tester.tap(find.text('Administrar catálogo'));
      await settle();
      await shot('pantalla4-HU-06-catalogo');
      await tester.tap(find.text('Agregar gasolinera'));
      await settle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Gasolinera San Miguel',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Av. Ballivián, zona San Miguel',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '-16.541');
      await tester.enterText(find.byType(TextFormField).at(3), '-68.078');
      await visible('Diésel');
      await tester.tap(find.text('Diésel').first);
      await settle();
      await visible('Gasolina Especial');
      await tester.tap(find.text('Gasolina Especial').first);
      await settle();
      await tester.scrollUntilVisible(
        find.text('Datos generales'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await shot('pantalla5-HU-06-formulario');
      await visible('Guardar gasolinera');
      await tester.tap(find.text('Guardar gasolinera'));
      await settle();
      expect(find.text('Gasolinera San Miguel'), findsOneWidget);
      final record = await repo.stations(
        const StationQuery(name: 'Gasolinera San Miguel'),
      );
      created = record.stations.first.id;
      await tester.tap(find.text('Gasolinera San Miguel'));
      await settle();
      await visible('Asignar encargados');
      await tester.tap(find.text('Asignar encargados'));
      await settle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Encargado Sopocachi'),
      );
      await settle();
      await shot('pantalla6-HU-06-asignacion');
      await tester.pageBack();
      await settle();
      await visible('Desactivar gasolinera');
      await tester.tap(find.text('Desactivar gasolinera'));
      await settle();
      await shot('pantalla7-HU-10-confirmacion');
      await tester.tap(find.text('Confirmar'));
      await settle();
      expect(find.text('Gasolinera inactiva'), findsOneWidget);
      await tester.pageBack();
      await settle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Mostrar inactivas'),
      );
      await settle();
      await tester.enterText(
        find.byType(TextField).first,
        'Gasolinera San Miguel',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await settle();
      await shot('pantalla8-HU-10-inactivas');
      await tester.tap(find.text('Gasolinera San Miguel'));
      await settle();
      await visible('Reactivar gasolinera');
      await tester.tap(find.text('Reactivar gasolinera'));
      await settle();
      await tester.tap(find.text('Confirmar'));
      await settle();
      await tester.pageBack();
      await settle();
      await tester.pageBack();
      await settle();
      await controller.logout();
      await settle();
      await tester.tap(find.byTooltip('Acceso de personal'));
      await settle();
      await tester.enterText(find.byType(TextFormField).first, managerEmail);
      await tester.enterText(find.byType(TextFormField).last, managerPassword);
      await tester.tap(find.text('Iniciar sesión'));
      await settle();
      expect(controller.isManager, isTrue);
      await tester.tap(find.byTooltip('Mi cuenta'));
      await settle();
      await tester.tap(find.text('Mis gasolineras'));
      await settle();
      await shot('pantalla9-HU-08-mis-gasolineras');
      await tester.tap(find.text('Gasolinera San Miguel'));
      await settle();
      await visible('Actualizar disponibilidad');
      await tester.tap(find.text('Actualizar disponibilidad'));
      await settle();
      await tester.tap(find.byType(DropdownButtonFormField<FuelStatus>).first);
      await settle();
      await tester.tap(find.text('Hay').last);
      await settle();
      await shot('pantalla10-HU-08-disponibilidad');
      await tester.tap(find.text('Guardar disponibilidad'));
      await settle();
      await visible('Ver historial de disponibilidad');
      await tester.tap(find.text('Ver historial de disponibilidad'));
      await settle();
      expect(find.textContaining('Encargado Sopocachi'), findsWidgets);
      await shot('pantalla11-HU-08-historial');
      await tester.pageBack();
      await settle();
      await tester.pageBack();
      await settle();
      await tester.pageBack();
      await settle();
      await controller.logout();
      await settle();
      await tester.tap(find.byTooltip('Actualizar lista'));
      await settle();
      await tester.tap(find.text('Gasolinera San Miguel'));
      await settle();
      expect(find.text('Actualizar disponibilidad'), findsNothing);
      expect(
        find.textContaining('Informado por Encargado Sopocachi'),
        findsWidgets,
      );
      await shot('pantalla12-HU-09-consulta-actualizada');
    } finally {
      if (created != null) {
        await controller.login(adminEmail, adminPassword);
        await repo.setActive(created, false);
      }
      await controller.logout();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
