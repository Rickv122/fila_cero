import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

class AvailabilityScreen extends StatefulWidget {
  final AppController controller;
  final AppRecord station;
  const AvailabilityScreen({
    super.key,
    required this.controller,
    required this.station,
  });
  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final Map<String, String> values = {};
  final operation = newId();
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (values.isEmpty) {
      setState(
        () => error = 'Selecciona el estado de al menos un combustible.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.command('publish', {
        'id': widget.station['id'],
        'operation': operation,
        'changes': values.entries
            .map((e) => {'id': e.key, 'estado': e.value})
            .toList(),
      });
      if (mounted) {
        notice(context, 'Disponibilidad actualizada');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    managerOnly: true,
    child: Scaffold(
      appBar: AppBar(title: const Text('Actualizar disponibilidad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageTitle('Mis estaciones', widget.station['nombre']),
          const SizedBox(height: 8),
          ...rows(widget.station['combustibles']).map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['nombre'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...['disponible', 'limitada', 'agotado'].map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: busy
                                ? null
                                : () => setState(() => values[f['id']] = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: values[f['id']] == s
                                    ? statusColor(s).withValues(alpha: .1)
                                    : const Color(0xFFF6F8FB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: values[f['id']] == s
                                      ? statusColor(s)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    values[f['id']] == s
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: statusColor(s),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      statusLabel(s),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Guardando…' : 'Publicar actualización'),
          ),
        ],
      ),
    ),
  );
}

class HistoryScreen extends StatefulWidget {
  final AppController controller;
  final String id;
  const HistoryScreen({super.key, required this.controller, required this.id});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<dynamic> data;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() => setState(() {
    data = widget.controller.query('history', {'id': widget.id});
  });
  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    child: Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: FutureBuilder(
        future: data,
        builder: (c, s) {
          if (s.hasError) return ErrorPane(error: s.error!, retry: load);
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = rows(s.data);
          if (events.isEmpty) {
            return const EmptyPane('Sin publicaciones', icon: Icons.history);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (c, i) {
              final e = events[i];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.history, color: statusColor(e['estado'])),
                  title: Text(
                    '${e['combustible']} · ${statusLabel(e['estado'])}',
                  ),
                  subtitle: Text(
                    '${e['autor']} · ${e['autor_codigo']}\n${dateLabel(e['registrado_en'])}',
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
