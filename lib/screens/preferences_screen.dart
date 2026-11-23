import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../data/travel_repository.dart';
import '../models/domain.dart';
import 'common.dart';

class PreferencesScreen extends StatefulWidget {
  final AppController controller;
  const PreferencesScreen({super.key, required this.controller});
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final api = TravelRepository(widget.controller.client);
  List<AppRecord>? fuels;
  String? fuel;
  int maximum = 10;
  Object? error;
  String? saveError;
  bool busy = false;
  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.controller.query('options'),
        api.query('preferences'),
      ]);
      final items = rows(row(values[0])['combustibles'])
          .where((f) => f['activo'] == true)
          .toList();
      final pref = values[1] == null ? null : row(values[1]);
      if (!mounted) return;
      setState(() {
        fuels = items;
        fuel = items.any((f) => f['id'] == (pref?['combustible_id']))
            ? (pref?['combustible_id'] as String?)
            : null;
        maximum = (pref?['distancia_maxima_km'] as num?)?.toInt() ?? 10;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> save() async {
    if (fuel == null) {
      setState(() => saveError = 'Selecciona el combustible que utilizas.');
      return;
    }
    setState(() {
      busy = true;
      saveError = null;
    });
    try {
      await api.command('preferences_save', {
        'combustible_id': fuel,
        'distancia_maxima_km': maximum,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => saveError = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProtectedPage(
    controller: widget.controller,
    child: Scaffold(
      appBar: AppBar(title: const Text('Mis preferencias')),
      body: error != null
          ? ErrorPane(error: error!, retry: load)
          : fuels == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const PageTitle('A tu medida', 'Tu próxima parada'),
                DropdownButtonFormField<String>(
                  key: ValueKey(fuel),
                  initialValue: fuel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Combustible que utilizas',
                  ),
                  items: fuels!
                      .map(
                        (f) => DropdownMenuItem(
                          value: f['id'] as String,
                          child: Text(f['nombre']),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : (v) => setState(() => fuel = v),
                ),
                const SizedBox(height: 24),
                Text(
                  'Distancia máxima por carretera',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    for (final km in [5, 10, 20])
                      ButtonSegment(value: km, label: Text('$km km')),
                  ],
                  selected: {maximum},
                  onSelectionChanged: busy
                      ? null
                      : (v) => setState(() => maximum = v.first),
                ),
                const SizedBox(height: 24),
                if (saveError != null) ...[
                  Text(saveError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Guardando…' : 'Guardar preferencias'),
                ),
              ],
            ),
    ),
  );
}
