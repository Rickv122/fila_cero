import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

class AvailabilityScreen extends StatefulWidget {
  final AppController controller;
  final Station station;
  const AvailabilityScreen({
    super.key,
    required this.controller,
    required this.station,
  });
  @override
  State<AvailabilityScreen> createState() => _AvailabilityState();
}

class _AvailabilityState extends State<AvailabilityScreen> {
  final changes = <String, FuelStatus>{};
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (changes.isEmpty) {
      setState(
        () => error = 'Selecciona al menos un combustible para actualizar.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.repository.updateAvailability(
        widget.station.id,
        changes,
      );
      if (mounted) {
        message(context, 'Disponibilidad actualizada');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => StaffGuard(
    controller: widget.controller,
    role: UserRole.encargado,
    child: Scaffold(
      appBar: AppBar(title: const Text('Actualizar disponibilidad')),
      body: PageBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.station.name,
                style: Theme.of(c).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Indica la disponibilidad actual de los combustibles que deseas actualizar.',
              ),
              const SizedBox(height: 24),
              ...widget.station.fuels.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: DropdownButtonFormField<FuelStatus>(
                    decoration: InputDecoration(
                      labelText: f.fuelName,
                      helperText: 'Actual: ${f.effectiveStatus().label}',
                    ),
                    isExpanded: true,
                    items: FuelStatus.values
                        .where((s) => s != FuelStatus.sinInformacion)
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => changes[f.fuelId] = v!),
                  ),
                ),
              ),
              const Text(
                'La fecha y el responsable se registran al guardar. Cada actualización conserva el historial.',
              ),
              const SizedBox(height: 20),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(c).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Guardando…' : 'Guardar disponibilidad'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
