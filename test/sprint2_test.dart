import 'dart:async';
import 'dart:convert';

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
import 'package:filacero/screens/company_screen.dart';
import 'package:filacero/screens/users_screen.dart';

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
  String role = 'administrador';
  Completer<dynamic>? profileGate;
  List<AppRecord>? catalogue;
  @override
  Future<dynamic> query(String resource, [AppRecord params = const {}]) async {
    calls++;
    if (offline) throw Exception('Sin conexión');
    if (resource == 'options') {
      return {'empresas': [], 'ciudades': [], 'combustibles': []};
    }
    if (resource == 'catalog') {
      final page = params['page'] as int? ?? 0;
      final data = catalogue ?? <AppRecord>[];
      return {
        'rows': data.skip(page * 20).take(20).toList(),
        'has_more': data.length > (page + 1) * 20,
      };
    }
    if (resource == 'station')
      return catalogue!.firstWhere((s) => s['id'] == params['id']);
    if (resource == 'profile') {
      return profileGate?.future ??
          {
            'id': 'unit-user',
            'nombre': 'Persona de evaluación',
            'rol': role,
            'activo': true,
            'confirmado': true,
          };
    }
    if (['companies', 'users', 'history'].contains(resource)) return [];
    return null;
  }
}

class UiController extends AppController {
  final MemoryRepository memory;
  UiController(this.memory) : super(memory) {
    profile = {
      'id': 'unit-user',
      'nombre': 'Persona',
      'rol': memory.role,
      'activo': true,
      'confirmado': true,
    };
  }
  @override
  bool get signedIn => profile?['activo'] == true;
  @override
  Future<void> refreshProfile() async {
    profile = {
      'id': 'unit-user',
      'nombre': 'Persona',
      'rol': memory.role,
      'activo': true,
      'confirmado': true,
    };
    notifyListeners();
  }
}

// Local SDK session fixture. No network identity or database account is created.
Future<AppController> authenticatedMemory(MemoryRepository repo) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final jwt =
      '${encode({'alg': 'none'})}.${encode({'sub': 'unit-user', 'exp': 4102444800})}.unit';
  await repo.client.auth.recoverSession(
    jsonEncode({
      'access_token': jwt,
      'refresh_token': 'unit-only',
      'token_type': 'bearer',
      'user': {
        'id': 'unit-user',
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-11-17T00:00:00Z',
      },
    }),
  );
  final c = AppController(repo);
  await c.refreshProfile();
  return c;
}

void main() {
  testWidgets('Volver del detalle conserva páginas cargadas y posición', (
    t,
  ) async {
    final repo = MemoryRepository()
      ..catalogue = List.generate(
        45,
        (i) => <String, dynamic>{
          'id': 'station-$i',
          'codigo': 'EST-$i',
          'nombre': 'Estación $i',
          'direccion': 'Dirección de la prueba',
          'empresa': 'Operadora de la prueba',
          'ciudad': 'La Paz',
          'disponible': true,
          'activo': true,
          'favorita': false,
          'combustibles': <AppRecord>[],
        },
      );
    final c = AppController(repo);
    await t.pumpWidget(MaterialApp(home: CatalogScreen(controller: c)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Cargar más'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 50,
    );
    await t.tap(find.text('Cargar más'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Estación 25'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 50,
    );
    await t.ensureVisible(find.text('Estación 25'));
    await t.tap(find.text('Estación 25'));
    await t.pumpAndSettle();
    expect(find.text('Combustibles'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Estación 25').hitTestable(), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  test('Los enlaces copiados de Gmail se interpretan sin abrir Google', () {
    const direct =
        'https://oejouwwxngyafftzfkux.supabase.co/auth/v1/verify?token=unit-challenge&type=recovery';
    final wrapped = Uri.https('www.google.com', '/url', {
      'q': direct,
    }).toString();
    expect(verificationLink(wrapped), {
      'token': 'unit-challenge',
      'type': 'recovery',
    });
    expect(verificationLink(direct)['type'], 'recovery');
    expect(
      () => verificationLink(
        'https://example.com/auth/v1/verify?token=unit&type=recovery',
      ),
      throwsFormatException,
    );
  });
  test('Dos lecturas simultáneas esperan el mismo perfil', () async {
    final repo = MemoryRepository();
    final c = await authenticatedMemory(repo);
    repo.calls = 0;
    repo.profileGate = Completer<dynamic>();
    final first = c.refreshProfile(), second = c.refreshProfile();
    expect(repo.calls, 1);
    repo.profileGate!.complete({
      'id': 'unit-user',
      'nombre': 'Persona',
      'rol': 'administrador',
      'activo': true,
      'confirmado': true,
    });
    await Future.wait([first, second]);
    expect(c.admin, isTrue);
    c.dispose();
    await repo.client.dispose();
  });
  testWidgets(
    'Empresas, usuarios e historial cargan sin devolver futuros a setState',
    (t) async {
      final repo = MemoryRepository();
      final c = UiController(repo);
      for (final page in [
        CompanyScreen(controller: c),
        UsersScreen(controller: c),
        HistoryScreen(controller: c, id: 'station'),
      ]) {
        await t.pumpWidget(MaterialApp(home: page));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('Solo el responsable ve el formulario de publicación', (t) async {
    final repo = MemoryRepository();
    final c = UiController(repo);
    final page = AvailabilityScreen(
      controller: c,
      station: {
        'id': 'station',
        'nombre': 'Estación',
        'combustibles': [
          {'id': 'fuel', 'nombre': 'Gasolina Especial'},
        ],
      },
    );
    await t.pumpWidget(MaterialApp(home: page));
    await t.pumpAndSettle();
    expect(find.text('Publicar actualización'), findsNothing);
    repo.role = 'responsable';
    await c.refreshProfile();
    await t.pumpAndSettle();
    expect(find.text('Publicar actualización'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Disponibilidad limitada'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Sin actualizar'), findsNothing);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
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
