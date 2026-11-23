import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_controller.dart';
import '../data/travel_repository.dart';
import '../models/domain.dart';
import '../models/travel.dart';
import 'common.dart';
import 'location_picker_screen.dart';
import 'preferences_screen.dart';
import 'route_screen.dart';
import 'station_detail_screen.dart';
import 'travel_map.dart';

class RecommendationsScreen extends StatefulWidget {
  final AppController controller;
  const RecommendationsScreen({super.key, required this.controller});
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  late final api = TravelRepository(widget.controller.client);
  AppRecord? preferences;
  LatLng? origin;
  List<AppRecord> stations = [];
  Object? error;
  bool initialized = false, busy = false, hasSearched = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> loadPreferences() async {
    try {
      final p = await api.query('preferences');
      if (mounted) {
        setState(() {
          preferences = p == null ? null : row(p);
          initialized = true;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          initialized = true;
        });
      }
    }
  }

  Future<void> editPreferences() async {
    final changed = await openPage<bool>(
      context,
      PreferencesScreen(controller: widget.controller),
    );
    if (!mounted) return;
    if (changed == true) {
      generation++;
      setState(() {
        stations = [];
        hasSearched = false;
      });
      await loadPreferences();
      if (origin != null) await recommend();
    }
  }

  Future<void> chooseOrigin({bool gps = false}) async {
    if (busy) return;
    try {
      LatLng? p;
      if (gps) {
        setState(() => busy = true);
        p = await api.currentPosition();
      } else {
        final picked = await openPage<AppRecord>(
          context,
          LocationPickerScreen(controller: widget.controller, initial: origin),
        );
        if (picked != null) p = recordPoint(picked);
      }
      if (!mounted || p == null) return;
      generation++;
      setState(() {
        origin = p;
        stations = [];
        error = null;
        hasSearched = false;
      });
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recommend() async {
    if (origin == null) {
      notice(context, 'Elige tu punto de partida.');
      return;
    }
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
      stations = [];
      hasSearched = true;
    });
    try {
      final data = await api.recommend(origin!);
      if (!mounted || ticket != generation) return;
      setState(() {
        stations = rows(data['stations']);
        preferences = row(data['preferences']);
      });
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProtectedPage(
    controller: widget.controller,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones para ti'),
        actions: [
          IconButton(
            tooltip: 'Preferencias',
            onPressed: busy ? null : editPreferences,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: !initialized
          ? const Center(child: CircularProgressIndicator())
          : preferences == null || preferences?['combustible_activo'] != true
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_gas_station_outlined,
                      size: 56,
                      color: navy,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Elige el combustible que utilizas',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: editPreferences,
                      child: const Text('Configurar preferencias'),
                    ),
                    if (error != null)
                      TextButton(
                        onPressed: loadPreferences,
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: recommend,
              child: ListView(
                padding: const EdgeInsets.all(18),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    preferences!['combustible'],
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: navy),
                  ),
                  Text(
                    'Hasta ${preferences!['distancia_maxima_km']} km por carretera',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => chooseOrigin(gps: true),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Mi ubicación'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : chooseOrigin,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          origin == null ? 'Elegir en mapa' : 'Cambiar origen',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : recommend,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.near_me_outlined),
                    label: Text(
                      busy ? 'Comparando recorridos…' : 'Buscar estaciones',
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (origin != null)
                    SizedBox(
                      height: 250,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: TravelMap(
                          key: ValueKey(
                            '${origin!.latitude}/${origin!.longitude}',
                          ),
                          center: origin!,
                          markers: [
                            locationMarker(origin!, origin: true),
                            for (final s in stations)
                              if (recordPoint(s) != null)
                                locationMarker(
                                  recordPoint(s)!,
                                  color: statusColor(s['estado']),
                                  onTap: () => openPage(
                                    context,
                                    StationDetailScreen(
                                      controller: widget.controller,
                                      id: s['id'],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            readableError(error!),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: busy ? null : recommend,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  if (hasSearched && !busy && error == null && stations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 25),
                      child: Text(
                        'No hay estaciones con disponibilidad vigente dentro de esta distancia. Puedes ampliar la distancia o cambiar el origen.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final s in stations)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s['nombre'],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: navy,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    travelTime(s['time_s']),
                                    style: const TextStyle(
                                      color: accent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${s['station']['empresa']} · ${roadDistance(s['distance_m'])}',
                              ),
                              Text(s['combustible']),
                              const SizedBox(height: 10),
                              Text(
                                statusLabel(s['estado']),
                                style: TextStyle(
                                  color: statusColor(s['estado']),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                dateLabel(s['registrado_en']),
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => openPage(
                                        context,
                                        StationDetailScreen(
                                          controller: widget.controller,
                                          id: s['id'],
                                        ),
                                      ),
                                      child: const Text('Ver estación'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => openPage(
                                        context,
                                        RouteScreen(
                                          controller: widget.controller,
                                          id: s['id'],
                                          initialOrigin: origin,
                                        ),
                                      ),
                                      icon: const Icon(Icons.directions),
                                      label: const Text('Cómo llegar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    ),
  );
}
