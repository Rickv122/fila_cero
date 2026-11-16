import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

class AssignmentsScreen extends StatefulWidget {
  final AppController controller;
  final Station station;
  const AssignmentsScreen({
    super.key,
    required this.controller,
    required this.station,
  });
  @override
  State<AssignmentsScreen> createState() => _AssignmentsState();
}

class _AssignmentsState extends State<AssignmentsScreen> {
  List<StaffProfile> managers = [];
  Set<String> assigned = {};
  bool busy = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final m = await widget.controller.repository.managers();
      final a = await widget.controller.repository.assignedManagers(
        widget.station.id,
      );
      if (mounted) {
        setState(() {
          managers = m;
          assigned = a;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> assign(StaffProfile profile, bool active) async {
    setState(() => busy = true);
    try {
      await widget.controller.repository.assignManager(
        widget.station.id,
        profile.id,
        active,
      );
      if (mounted) {
        message(context, 'Asignación actualizada');
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
  Widget build(BuildContext c) => StaffGuard(
    controller: widget.controller,
    role: UserRole.administrador,
    child: Scaffold(
      appBar: AppBar(title: const Text('Encargados asignados')),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.station.name,
              style: Theme.of(c).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecciona las cuentas autorizadas que pueden actualizar esta gasolinera. Cada cambio se guarda al seleccionarlo.',
            ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              ErrorPane(error: error!, retry: load)
            else if (!busy && managers.isEmpty)
              const Text('No hay encargados activos disponibles.'),
            ...managers.map(
              (m) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.name),
                subtitle: Text(
                  assigned.contains(m.id)
                      ? 'Asignación activa'
                      : 'Sin asignación',
                ),
                value: assigned.contains(m.id),
                onChanged: busy ? null : (v) => assign(m, v),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HistoryScreen extends StatefulWidget {
  final AppController controller;
  final Station station;
  const HistoryScreen({
    super.key,
    required this.controller,
    required this.station,
  });
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> data;
  @override
  void initState() {
    super.initState();
    data = widget.controller.repository.history(widget.station.id);
  }

  String fuelName(String id) =>
      widget.station.fuels.where((f) => f.fuelId == id).firstOrNull?.fuelName ??
      'Combustible';
  String stateLabel(String value) => switch (value) {
    'hay' => 'Hay',
    'poco' => 'Poco',
    'no_hay' => 'No hay',
    _ => 'Sin información vigente',
  };
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.controller,
    builder: (_, _) => widget.controller.staff == null
        ? Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('Inicia sesión para consultar el historial.'),
            ),
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Historial de disponibilidad')),
            body: PageBody(
              child: FutureBuilder(
                future: data,
                builder: (c, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return ErrorPane(
                      error: s.error!,
                      retry: () => setState(
                        () => data = widget.controller.repository.history(
                          widget.station.id,
                        ),
                      ),
                    );
                  }
                  if (s.data!.isEmpty) {
                    return const Center(
                      child: Text('Aún no hay actualizaciones registradas.'),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.station.name,
                        style: Theme.of(c).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Últimas 50 actualizaciones',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...s.data!.map(
                        (r) => Card(
                          child: ListTile(
                            isThreeLine: true,
                            leading: const Icon(Icons.history, color: brand),
                            title: Text(
                              '${fuelName(r['combustible_id'] as String)}: ${stateLabel(r['estado_nuevo'] as String)}',
                            ),
                            subtitle: Text(
                              'Antes: ${stateLabel(r['estado_anterior'] as String)}\n${r['autor_nombre']} · ${dateText(DateTime.parse(r['creado_en'] as String))}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
  );
}
