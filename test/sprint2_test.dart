import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filacero/core/app_controller.dart';
import 'package:filacero/data/supabase_repository.dart';
import 'package:filacero/models/domain.dart';
import 'package:filacero/main.dart';
import 'package:filacero/screens/catalog_screen.dart';
import 'package:filacero/screens/auth_screen.dart';
import 'package:filacero/screens/availability_screen.dart';

class MemoryRepository extends SupabaseRepository {
  MemoryRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'public-unit-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  bool offline = false;
  int calls = 0;
  @override
  Future<dynamic> query(String resource, [AppRecord params = const {}]) async {
    calls++;
    if (offline) throw Exception('Sin conexión');
    if (resource == 'options') {
      return {'empresas': [], 'ciudades': [], 'combustibles': []};
    }
    if (resource == 'catalog') return {'rows': [], 'has_more': false};
    return null;
  }
}

void main() {
  test('Correo exige un arroba, dominio y ausencia de espacios', () {
    for (final s in [
      'ana',
      'ana@@gmail.com',
      'ana @gmail.com',
      'ana@gmail',
      '',
    ]) {
      expect(emailError(s), isNotNull);
    }
    expect(emailError('ana@gmail.com'), isNull);
  });
  test('Contraseña y campos obligatorios', () {
    expect(passwordError('1234567'), isNotNull);
    expect(passwordError('12345678'), isNull);
    expect(requiredText('  '), isNotNull);
  });
  test('Identidades UUID completas y distintas', () {
    final values = List.generate(100, (_) => newId());
    expect(values.toSet().length, 100);
    for (final id in values) {
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
      );
    }
  });
  test('Agotado y sin actualizar mantienen categorías distintas', () {
    expect(statusLabel('agotado'), 'Agotado');
    expect(statusLabel('sin_actualizar'), 'Sin actualizar');
    expect(roleLabel('responsable'), 'Responsable de estación');
  });
  testWidgets('La bienvenida ofrece consulta, registro y acceso', (t) async {
    final c = AppController(MemoryRepository());
    await t.pumpWidget(FilaCeroApp(controller: c));
    expect(find.text('Consultar estaciones'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(c.client.auth.currentSession, isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('Registro público no permite elegir rol y valida los campos', (
    t,
  ) async {
    final c = AppController(MemoryRepository());
    await t.pumpWidget(
      MaterialApp(
        home: AuthScreen(controller: c, initial: 'register'),
      ),
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await t.ensureVisible(find.byKey(const Key('auth-submit')));
    await t.tap(find.byKey(const Key('auth-submit')));
    await t.pumpAndSettle();
    expect(find.text('Completa este campo'), findsOneWidget);
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Usa al menos 8 caracteres'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'El catálogo distingue error de lista sin resultados y permite reintentar',
    (t) async {
      final repo = MemoryRepository()..offline = true;
      final c = AppController(repo);
      await t.pumpWidget(MaterialApp(home: CatalogScreen(controller: c)));
      await t.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Sin resultados'), findsNothing);
      repo.offline = false;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('Un visitante no abre la publicación protegida', (t) async {
    final c = AppController(MemoryRepository());
    await t.pumpWidget(
      MaterialApp(
        home: AvailabilityScreen(
          controller: c,
          station: {'id': 's', 'nombre': 'Estación', 'combustibles': []},
        ),
      ),
    );
    expect(find.text('Acceso no disponible'), findsOneWidget);
    expect(find.text('Publicar actualización'), findsNothing);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
