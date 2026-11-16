import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';

const brand = Color(0xFFF4511E);
const statusColors = [
  Color(0xFF247546),
  Color(0xFF956400),
  Color(0xFFB32A30),
  Color(0xFF606776),
];
String dateText(DateTime value) {
  final t = value.toLocal();
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

void message(BuildContext c, String text) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));
Future<T?> openPage<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => page));

class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({super.key, required this.child});
  @override
  Widget build(BuildContext c) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: child,
    ),
  );
}

class ErrorPane extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const ErrorPane({super.key, required this.error, required this.retry});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 38),
        const SizedBox(height: 12),
        Text(friendlyError(error), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );
}

class StaffGuard extends StatelessWidget {
  final AppController controller;
  final UserRole role;
  final Widget child;
  const StaffGuard({
    super.key,
    required this.controller,
    required this.role,
    required this.child,
  });
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) =>
        controller.staff?.active == true && controller.staff?.role == role
        ? child
        : Scaffold(
            appBar: AppBar(title: const Text('Acceso protegido')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Inicia sesión con una cuenta autorizada para acceder a esta función.',
                ),
              ),
            ),
          ),
  );
}

class FuelBadge extends StatelessWidget {
  final FuelAvailability fuel;
  const FuelBadge({super.key, required this.fuel});
  @override
  Widget build(BuildContext c) {
    final status = fuel.effectiveStatus();
    return Chip(
      avatar: Icon(Icons.circle, size: 11, color: statusColors[status.index]),
      label: Text('${fuel.fuelName}: ${status.label}'),
      visualDensity: VisualDensity.compact,
      backgroundColor: statusColors[status.index].withValues(alpha: 0.07),
      side: BorderSide.none,
    );
  }
}
