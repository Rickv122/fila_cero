import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_controller.dart';
import '../data/travel_repository.dart';
import '../models/domain.dart';
import 'common.dart';
import 'travel_map.dart';

class LocationPickerScreen extends StatefulWidget {
  final AppController controller;
  final LatLng? initial;
  final String address, city;
  final bool station;
  const LocationPickerScreen({
    super.key,
    required this.controller,
    this.initial,
    this.address = '',
    this.city = '',
    this.station = false,
  });
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final api = TravelRepository(widget.controller.client);
  final map = MapController();
  final search = TextEditingController(), address = TextEditingController();
  LatLng? selected;
  List<AppRecord> results = [];
  String? error;
  bool searching = false, reversing = false, ready = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    selected = widget.initial;
    address.text = widget.address;
    search.text = widget.address;
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    address.dispose();
    map.dispose();
    super.dispose();
  }

  Future<void> find() async {
    final ticket = ++generation;
    setState(() {
      searching = true;
      error = null;
      results = [];
    });
    try {
      final data = await api.geo('search', {
        'text': '${search.text.trim()} ${widget.city} Bolivia'.trim(),
      });
      if (!mounted || ticket != generation) return;
      setState(() {
        results = rows(data['results']);
        if (results.isEmpty) error = 'No encontramos coincidencias. Prueba otra dirección o marca el punto.';
      });
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() => error = readableError(e));
      }
    } finally {
      if (mounted && ticket == generation) setState(() => searching = false);
    }
  }

  Future<void> choose(LatLng p, {String? suggested}) async {
    final ticket = ++generation;
    setState(() {
      selected = p;
      results = [];
      error = null;
      searching = false;
      reversing = suggested == null;
      if (suggested != null) address.text = suggested;
    });
    if (ready) map.move(p, map.camera.zoom < 15 ? 15 : map.camera.zoom);
    if (suggested != null) return;
    try {
      final data = await api.geo('reverse', {
        'point': {'lat': p.latitude, 'lon': p.longitude},
      });
      if (!mounted || ticket != generation) return;
      final matches = rows(data['results']);
      setState(() {
        if (matches.isNotEmpty) {
          address.text = matches.first['address'];
        } else {
          error = 'Revisa o escribe la dirección del punto elegido.';
        }
      });
    } catch (_) {
      if (mounted && ticket == generation) {
        setState(
          () => error = 'No pudimos sugerir una dirección. Puedes revisarla y escribirla.',
        );
      }
    } finally {
      if (mounted && ticket == generation) setState(() => reversing = false);
    }
  }

  void accept() {
    if (selected == null) {
      notice(context, 'Marca un punto en el mapa.');
      return;
    }
    if (widget.station && address.text.trim().length < 3) {
      notice(context, 'Revisa la dirección de la estación.');
      return;
    }
    Navigator.pop(context, {
      'latitud': selected!.latitude,
      'longitud': selected!.longitude,
      'direccion': address.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => ProtectedPage(
    controller: widget.controller,
    adminOnly: widget.station,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.station ? 'Ubicación de la estación' : 'Punto de partida',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => find(),
                decoration: InputDecoration(
                  hintText: 'Buscar una dirección',
                  suffixIcon: IconButton(
                    onPressed: searching ? null : find,
                    icon: searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.brown),
                ),
              ),
            if (results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView(
                  shrinkWrap: true,
                  children: results
                      .map(
                        (r) => ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(r['address']),
                          onTap: () => choose(
                            LatLng(
                              (r['lat'] as num).toDouble(),
                              (r['lon'] as num).toDouble(),
                            ),
                            suggested: r['address'],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Expanded(
              child: TravelMap(
                controller: map,
                center: selected ?? laPazCenter,
                onReady: () => ready = true,
                onTap: (_, p) => choose(p),
                markers: selected == null ? [] : [locationMarker(selected!)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.station) ...[
                    TextField(
                      controller: address,
                      enabled: !reversing,
                      decoration: InputDecoration(
                        labelText: 'Dirección',
                        suffixIcon: reversing
                            ? const Padding(
                                padding: EdgeInsets.all(15),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: reversing ? null : accept,
                      icon: const Icon(Icons.check),
                      label: Text(
                        widget.station
                            ? 'Usar esta ubicación'
                            : 'Elegir punto de partida',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
