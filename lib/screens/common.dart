import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';

const navy = Color(0xFF102A47);
const accent = Color(0xFF3167E3);
Color statusColor(String? s) => switch (s) {
  'disponible' => const Color(0xFF178167),
  'limitada' => const Color(0xFFB77912),
  'agotado' => const Color(0xFFB7454E),
  _ => const Color(0xFF738399),
};
String readableError(Object error) {
  if (error is FormatException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '23505') return 'Ya existe un registro con estos datos.';
    if (error.code == '23514' || error.code == '23502') {
      return 'Revisa los campos obligatorios y sus valores.';
    }
    return error.message;
  }
  if (error is AuthException) {
    if (error.code == 'invalid_credentials') {
      return 'Correo o contraseña incorrectos.';
    }
    if (error.code == 'email_not_confirmed') {
      return 'Confirma tu correo antes de iniciar sesión.';
    }
    if (error.code == 'over_email_send_rate_limit') {
      return 'Espera unos minutos antes de solicitar otro correo.';
    }
    if (error.code == 'email_address_not_authorized') {
      return 'El envío de correo requiere configurar el servicio de la aplicación.';
    }
    return error.message;
  }
  final s = error.toString().replaceFirst('Exception: ', '');
  if (s.contains('SocketException') || s.contains('ClientException')) {
    return 'No se pudo conectar. Revisa tu conexión y reintenta.';
  }
  return s;
}

void notice(BuildContext c, String message) => ScaffoldMessenger.of(c)
    .showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
Future<T?> openPage<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => page));
Future<bool> confirm(
  BuildContext c,
  String title,
  String message, {
  String action = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class ErrorPane extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const ErrorPane({super.key, required this.error, required this.retry});
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: navy),
          const SizedBox(height: 16),
          Text(readableError(error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class EmptyPane extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyPane(
    this.title, {
    super.key,
    this.message = '',
    this.icon = Icons.search_off_rounded,
  });
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: navy.withValues(alpha: .45)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(c).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

class PageTitle extends StatelessWidget {
  final String eyebrow, title;
  final String? subtitle;
  const PageTitle(this.eyebrow, this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(c).textTheme.headlineMedium
              ?.copyWith(color: navy, fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: TextStyle(color: Colors.blueGrey.shade600)),
        ],
      ],
    ),
  );
}

class ProtectedPage extends StatelessWidget {
  final AppController controller;
  final Widget child;
  final bool adminOnly;
  final bool managerOnly;
  const ProtectedPage({
    super.key,
    required this.controller,
    required this.child,
    this.adminOnly = false,
    this.managerOnly = false,
  });
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: controller,
    builder: (c, _) =>
        controller.signedIn &&
            (!adminOnly || controller.admin) &&
            (!managerOnly || controller.manager)
        ? child
        : Scaffold(
            appBar: AppBar(title: const Text('Acceso restringido')),
            body: EmptyPane(
              'Acceso no disponible',
              message:
                  controller.sessionError ??
                  'Inicia sesión con una cuenta autorizada.',
              icon: Icons.lock_outline,
            ),
          ),
  );
}

class FuelPill extends StatelessWidget {
  final AppRecord fuel;
  const FuelPill(this.fuel, {super.key});
  @override
  Widget build(BuildContext c) {
    final status = fuel['estado'] as String?;
    final color = statusColor(status);
    return Tooltip(
      message: '${fuel['nombre']}: ${statusLabel(status)}',
      child: Semantics(
        label: '${fuel['nombre']}: ${statusLabel(status)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == 'agotado'
                    ? Icons.remove_circle_outline
                    : status == 'sin_actualizar'
                    ? Icons.schedule_rounded
                    : Icons.circle,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                fuelShort(fuel['nombre']),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
