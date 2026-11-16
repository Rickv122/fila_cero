import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/fila_repository.dart';
import '../models/domain.dart';

String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is AuthException) {
    return 'Correo o contraseña incorrectos, o acceso de personal no disponible.';
  }
  if (error is PostgrestException && ['42501', '22023'].contains(error.code)) {
    return error.message;
  }
  return 'No se pudo completar la operación. Revisa tu conexión y vuelve a intentar.';
}

class AppController extends ChangeNotifier {
  final FilaRepository repository;
  StaffProfile? staff;
  StreamSubscription<void>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  AppController(this.repository);
  bool get isAdmin =>
      staff?.active == true && staff?.role == UserRole.administrador;
  bool get isManager =>
      staff?.active == true && staff?.role == UserRole.encargado;
  Future<void> initialize() async {
    try {
      staff = await repository.profile();
    } catch (_) {
      staff = null;
    }
    _subscription = repository.authChanges.listen((_) {
      refreshProfile();
    });
  }

  Future<void> refreshProfile() async {
    final ticket = ++_generation;
    StaffProfile? next;
    try {
      next = await repository.profile();
    } catch (_) {
      next = null;
    }
    if (_disposed || ticket != _generation) return;
    staff = next;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    staff = await repository.login(email, password);
    notifyListeners();
  }

  Future<void> logout() async {
    _generation++;
    staff = null;
    notifyListeners();
    await repository.logout();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
