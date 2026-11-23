import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_controller.dart';
import '../data/travel_repository.dart';
import '../models/domain.dart';
import '../models/travel.dart';
import 'common.dart';
import 'location_picker_screen.dart';
import 'travel_map.dart';

class RouteScreen extends StatefulWidget {
  final AppController controller;
  final String id;
  final LatLng? initialOrigin;
  const RouteScreen({
    super.key,
    required this.controller,
    required this.id,
    this.initialOrigin,
  });
  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final api = TravelRepository(widget.controller.client);
  late LatLng? origin = widget.initialOrigin;
  AppRecord? result, station;
  List<LatLng> points = [];
  Object? error;
  bool busy = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    if (origin != null) {
      calculate();
    } else {
      loadStation();
    }
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> loadStation() async {
    try {
      final value = await api.query('location', {'id': widget.id});
      if (mounted) setState(() => station = value == null ? null : row(value));
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> pick({bool gps = false}) async {
    if (busy) return;
    try {
      LatLng? next;
      if (gps) {
        setState(() => busy = true);
        next = await api.currentPosition();
      } else {
        final p = await openPage<AppRecord>(
          context,
          LocationPickerScreen(controller: widget.controller, initial: origin),
        );
        if (p != null) next = recordPoint(p);
      }
      if (!mounted || next == null) return;
      generation++;
      setState(() {
        origin = next;
        result = null;
        points = [];
        error = null;
        busy = false;
      });
      await calculate();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> calculate() async {
    if (origin == null) return;
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
      result = null;
      points = [];
    });
    try {
      final data = await api.route(widget.id, origin!);
      final coordinates = routePoints(data['points']);
      if (!mounted || ticket != generation) return;
      setState(() {
        result = data;
        station = row(data['station']);
        points = coordinates;
      });
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = station == null ? null : recordPoint(station!);
    final fuels = station == null
        ? <AppRecord>[]
        : rows(station!['station']['combustibles']);
    return ProtectedPage(
      controller: widget.controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cómo llegar'),
          actions: [
            IconButton(
              tooltip: 'Actualizar recorrido',
              onPressed: busy || origin == null ? null : calculate,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station?['nombre'] ?? 'Tu destino',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: navy, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => pick(gps: true),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Mi ubicación'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : pick,
                          icon: const Icon(Icons.place_outlined),
                          label: Text(
                            origin == null ? 'Elegir origen' : 'Cambiar origen',
                          ),
                        ),
                      ],
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        readableError(error!),
                        style: const TextStyle(color: Colors.brown),
                      ),
                      TextButton(
                        onPressed: origin == null ? loadStation : calculate,
                        child: const Text('Reintentar'),
                      ),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${roadDistance(result!['distance_m'])} · ${travelTime(result!['time_s'])} estimados',
                        style: const TextStyle(
                          color: accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: TravelMap(
                  key: ValueKey(
                    '${origin?.latitude}/${origin?.longitude}/${result?['calculated_at']}',
                  ),
                  center: origin ?? destination ?? laPazCenter,
                  route: points,
                  markers: [
                    if (origin != null) locationMarker(origin!, origin: true),
                    if (destination != null) locationMarker(destination),
                  ],
                ),
              ),
              if (fuels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: fuels
                        .map(
                          (f) => Text(
                            '${fuelShort(f['nombre'])}: ${statusLabel(f['estado'])}',
                            style: TextStyle(
                              color: statusColor(f['estado']),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
