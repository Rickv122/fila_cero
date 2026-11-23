import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../data/travel_repository.dart';
import '../models/domain.dart';
import 'common.dart';
import 'preferences_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final AppController controller;
  const NotificationsScreen({super.key, required this.controller});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final api = TravelRepository(widget.controller.client);
  List<AppRecord>? stations;
  AppRecord? preferences;
  Object? error;
  bool busy = false;
  Future<void> enableDevice() async {
    setState(() => busy = true);
    try {
      await widget.controller.push.enable();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        api.query('subscriptions'),
        api.query('preferences'),
      ]);
      if (!mounted) return;
      setState(() {
        stations = rows(values[0]);
        preferences = values[1] == null ? null : row(values[1]);
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> change(AppRecord station, bool value) async {
    setState(() => busy = true);
    try {
      if (value) await widget.controller.push.enable();
      await api.command('subscription_save', {
        'id': station['id'],
        'activo': value,
      });
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProtectedPage(
    controller: widget.controller,
    child: Scaffold(
      appBar: AppBar(title: const Text('Mis avisos')),
      body: error != null
          ? ErrorPane(error: error!, retry: load)
          : stations == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const PageTitle(
                    'Tus favoritas, al día',
                    'Avisos de disponibilidad',
                  ),
                  if (preferences == null ||
                      preferences!['combustible_activo'] != true)
                    FilledButton(
                      onPressed: () async {
                        await openPage(
                          context,
                          PreferencesScreen(controller: widget.controller),
                        );
                        await load();
                      },
                      child: const Text('Elegir mi combustible'),
                    )
                  else ...[
                    Text(
                      'Avísame cuando el responsable publique ${preferences!['combustible']} disponible.',
                      style: const TextStyle(color: navy, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    if (widget.controller.push.identifier == null) ...[
                      OutlinedButton.icon(
                        onPressed: busy ? null : enableDevice,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Activar en este teléfono'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (stations!.isEmpty)
                      const Text(
                        'Guarda una estación en favoritas para activar sus avisos.',
                      ),
                    ...stations!.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: SwitchListTile(
                            title: Text(s['nombre']),
                            subtitle: Text(s['empresa'] ?? ''),
                            value: s['activo'] == true,
                            onChanged:
                                busy ||
                                    (s['disponible'] != true &&
                                        s['activo'] != true)
                                ? null
                                : (v) => change(s, v),
                            secondary: const Icon(
                              Icons.notifications_outlined,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
