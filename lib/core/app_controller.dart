import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain.dart';
import '../data/supabase_repository.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  final SupabaseRepository repository;
  AppRecord? profile;
  bool recovery = false;
  String? sessionError;
  int _generation = 0;
  Future<void>? _profileRequest;
  StreamSubscription<AuthState>? _subscription;
  static const callback = 'filacero://auth-callback';
  AppController(this.repository);
  SupabaseClient get client => repository.client;
  bool get signedIn =>
      client.auth.currentSession != null &&
      profile?['activo'] == true &&
      sessionError == null;
  bool get admin => signedIn && profile?['rol'] == 'administrador';
  bool get manager => signedIn && profile?['rol'] == 'responsable';
  String get name => profile?['nombre'] ?? 'Mi cuenta';
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _subscription = client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) recovery = true;
      if (event.event == AuthChangeEvent.signedOut) {
        _generation++;
        _profileRequest = null;
        profile = null;
        sessionError = null;
        recovery = false;
        notifyListeners();
      } else {
        unawaited(refreshProfile());
      }
    });
    await refreshProfile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshProfile());
  }

  Future<void> refreshProfile() {
    if (_profileRequest != null) return _profileRequest!;
    final request = _loadProfile();
    _profileRequest = request;
    return request.whenComplete(() {
      if (identical(_profileRequest, request)) _profileRequest = null;
    });
  }

  Future<void> _loadProfile() async {
    final generation = ++_generation;
    if (client.auth.currentSession == null) {
      profile = null;
      sessionError = null;
      notifyListeners();
      return;
    }
    try {
      final result = await repository.query('profile');
      if (generation != _generation) return;
      profile = result == null ? null : row(result);
      sessionError = profile == null
          ? 'No se pudo habilitar el perfil. Vuelve a intentar.'
          : profile?['activo'] != true
          ? 'Tu cuenta está desactivada. Contacta al administrador.'
          : null;
    } catch (_) {
      if (generation != _generation) return;
      sessionError = 'No se pudo verificar tu cuenta. Revisa la conexión.';
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await refreshProfile();
    if (!signedIn) {
      throw Exception(sessionError ?? 'No se pudo iniciar sesión.');
    }
  }

  Future<void> logout() async {
    await client.auth.signOut();
    _generation++;
    profile = null;
    recovery = false;
    sessionError = null;
    notifyListeners();
  }

  Future<dynamic> query(String resource, [AppRecord params = const {}]) =>
      repository.query(resource, params);
  Future<dynamic> command(String action, AppRecord data) =>
      repository.command(action, data);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}
