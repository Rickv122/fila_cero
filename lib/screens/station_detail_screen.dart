import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'availability_screen.dart';
import 'common.dart';
import 'station_form_screen.dart';
import 'station_staff_screen.dart';

class StationDetailScreen extends StatefulWidget {
  final AppController controller;
  final String stationId;
  const StationDetailScreen({
    super.key,
    required this.controller,
    required this.stationId,
  });
  @override
  State<StationDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<StationDetailScreen> {
  Station? station;
  bool busy = true, assigned = false;
  Object? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = await widget.controller.repository.station(widget.stationId);
      final own = widget.controller.isManager
          ? (await widget.controller.repository.assignedManagers(
              widget.stationId,
            )).contains(widget.controller.staff!.id)
          : false;
      if (mounted) {
        setState(() {
          station = s;
          assigned = own;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleActive() async {
    final s = station!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          s.active ? 'Desactivar gasolinera' : 'Reactivar gasolinera',
        ),
        content: Text(
          s.active
              ? '¿Desactivar ${s.name}? Dejará de aparecer en las consultas públicas. Sus datos e historial se conservarán.'
              : '¿Reactivar ${s.name}? El encargado deberá publicar información vigente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.controller.repository.setActive(s.id, !s.active);
      if (mounted) {
        message(
          context,
          s.active ? 'Gasolinera desactivada' : 'Gasolinera reactivada',
        );
        await load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        message(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.controller,
    builder: (_, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de gasolinera'),
        actions: [
          IconButton(
            tooltip: 'Actualizar detalle',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PageBody(
        child: busy
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? ErrorPane(error: error!, retry: load)
            : station == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Esta gasolinera ya no está disponible para consulta.',
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_gas_station, size: 60, color: brand),
                    const SizedBox(height: 16),
                    Text(
                      station!.name,
                      style: Theme.of(c).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(station!.address),
                    Text(station!.city),
                    if (!station!.active)
                      const Text(
                        'Gasolinera inactiva',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Disponibilidad por combustible',
                      style: Theme.of(c).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...station!.fuels.map(
                      (f) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FuelBadge(fuel: f),
                              const SizedBox(height: 8),
                              Text(
                                f.updatedAt == null
                                    ? 'Aún no se informó disponibilidad.'
                                    : 'Última actualización: ${dateText(f.updatedAt!)}',
                              ),
                              if (f.author != null)
                                Text('Informado por ${f.author}'),
                              if (f.updatedAt != null &&
                                  f.effectiveStatus() ==
                                      FuelStatus.sinInformacion)
                                const Text(
                                  'Consulta una actualización vigente antes de decidir.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'La disponibilidad corresponde a lo informado por el encargado y tiene una vigencia de dos horas.',
                    ),
                    const SizedBox(height: 24),
                    if (widget.controller.isManager &&
                        assigned &&
                        station!.active)
                      FilledButton.icon(
                        onPressed: () async {
                          await openPage(
                            c,
                            AvailabilityScreen(
                              controller: widget.controller,
                              station: station!,
                            ),
                          );
                          if (mounted) load();
                        },
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Actualizar disponibilidad'),
                      ),
                    if (widget.controller.isAdmin) ...[
                      FilledButton.icon(
                        onPressed: () async {
                          await openPage(
                            c,
                            StationFormScreen(
                              controller: widget.controller,
                              station: station!,
                            ),
                          );
                          if (mounted) load();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar datos generales'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await openPage(
                            c,
                            AssignmentsScreen(
                              controller: widget.controller,
                              station: station!,
                            ),
                          );
                          if (mounted) load();
                        },
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Asignar encargados'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: toggleActive,
                        icon: Icon(
                          station!.active
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        label: Text(
                          station!.active
                              ? 'Desactivar gasolinera'
                              : 'Reactivar gasolinera',
                        ),
                      ),
                    ],
                    if (widget.controller.isAdmin ||
                        (widget.controller.isManager && assigned))
                      TextButton.icon(
                        onPressed: () => openPage(
                          c,
                          HistoryScreen(
                            controller: widget.controller,
                            station: station!,
                          ),
                        ),
                        icon: const Icon(Icons.history),
                        label: const Text('Ver historial de disponibilidad'),
                      ),
                  ],
                ),
              ),
      ),
    ),
  );
}
