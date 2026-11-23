import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/supabase_config.dart';
import 'common.dart';

const laPazCenter = LatLng(-16.5000, -68.1333);

class TravelMap extends StatefulWidget {
  final LatLng center;
  final List<Marker> markers;
  final List<LatLng> route;
  final MapController? controller;
  final void Function(TapPosition, LatLng)? onTap;
  final VoidCallback? onReady;
  const TravelMap({
    super.key,
    this.center = laPazCenter,
    this.markers = const [],
    this.route = const [],
    this.controller,
    this.onTap,
    this.onReady,
  });
  @override
  State<TravelMap> createState() => _TravelMapState();
}

class _TravelMapState extends State<TravelMap> {
  final reset = StreamController<void>.broadcast();
  bool incomplete = false;
  @override
  void dispose() {
    reset.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.center,
        route = widget.route,
        markers = widget.markers;
    final controller = widget.controller,
        onTap = widget.onTap,
        onReady = widget.onReady;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        minZoom: 5,
        maxZoom: 18,
        initialCameraFit: route.length > 1
            ? CameraFit.coordinates(
                coordinates: route,
                padding: const EdgeInsets.all(35),
              )
            : null,
        onTap: onTap,
        onMapReady: onReady,
      ),
      children: [
        TileLayer(
          urlTemplate:
              '${SupabaseConfig.url}/functions/v1/geo/tile/{z}/{x}/{y}.png',
          userAgentPackageName: 'bo.filacero.mobile',
          maxNativeZoom: 19,
          reset: reset.stream,
          evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
          errorTileCallback: (_, _, _) {
            if (mounted && !incomplete) setState(() => incomplete = true);
          },
        ),
        if (route.length > 1)
          PolylineLayer(
            polylines: [Polyline(points: route, color: accent, strokeWidth: 5)],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
            TextSourceAttribution(
              'Geoapify',
              onTap: () => launchUrl(Uri.parse('https://www.geoapify.com/')),
            ),
          ],
        ),
        if (incomplete)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              child: TextButton.icon(
                onPressed: () {
                  setState(() => incomplete = false);
                  reset.add(null);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recargar mapa'),
              ),
            ),
          ),
      ],
    );
  }
}

Marker locationMarker(
  LatLng p, {
  bool origin = false,
  VoidCallback? onTap,
  Color? color,
}) => Marker(
  point: p,
  width: 46,
  height: 46,
  child: GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 8),
        ],
      ),
      child: Icon(
        origin ? Icons.my_location : Icons.local_gas_station,
        color: color ?? accent,
        size: 27,
      ),
    ),
  ),
);
