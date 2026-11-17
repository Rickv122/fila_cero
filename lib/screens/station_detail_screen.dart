import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';
import 'auth_screen.dart';
import 'station_form_screen.dart';
import 'availability_screen.dart';

class StationDetailScreen extends StatefulWidget {
  final AppController controller;
  final String id;
  const StationDetailScreen({
    super.key,
    required this.controller,
    required this.id,
  });
  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  AppRecord? station;
  Object? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = row(
        await widget.controller.query('station', {'id': widget.id}),
      );
      if (mounted) {
        setState(() {
          station = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> favorite() async {
    if (!widget.controller.signedIn) {
      if (await openPage<bool>(
            context,
            AuthScreen(controller: widget.controller),
          ) !=
          true) {
        return;
      }
    }
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.controller.command('favorite', {
        'id': widget.id,
        'activo': station?['favorita'] != true,
      });
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeState() async {
    final active = station!['activo'] == true;
    if (!await confirm(
      context,
      active ? 'Desactivar estación' : 'Reactivar estación',
      '${station!['nombre']}\n${active ? 'Dejará de mostrarse en el catálogo y no admitirá publicaciones.' : 'Volverá a estar disponible si su empresa está activa. Las publicaciones anteriores no se renuevan.'}',
      action: active ? 'Desactivar' : 'Reactivar',
    )) {
      return;
    }
    try {
      await widget.controller.command('station_state', {
        'id': widget.id,
        'activo': !active,
      });
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = station;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: error != null
          ? ErrorPane(error: error!, retry: load)
          : s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_gas_station_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: s['favorita'] == true
                                ? 'Quitar favorita'
                                : 'Guardar favorita',
                            onPressed: busy ? null : favorite,
                            icon: Icon(
                              s['favorita'] == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        s['nombre'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s['empresa'],
                        style: const TextStyle(color: Color(0xFFB9CCE7)),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: Color(0xFFB9CCE7),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s['direccion']}\n${s['ciudad']}',
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Combustibles',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, color: navy),
                ),
                const SizedBox(height: 14),
                ...rows(s['combustibles']).map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FuelCard(fuel: f),
                  ),
                ),
                if (s['puede_publicar'] == true) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      await openPage(
                        context,
                        AvailabilityScreen(
                          controller: widget.controller,
                          station: s,
                        ),
                      );
                      await load();
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Actualizar disponibilidad'),
                  ),
                ],
                if (s['puede_publicar'] == true || widget.controller.admin)
                  TextButton.icon(
                    onPressed: () => openPage(
                      context,
                      HistoryScreen(
                        controller: widget.controller,
                        id: widget.id,
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('Ver historial'),
                  ),
                if (widget.controller.admin) ...[
                  const Divider(height: 34),
                  Text(
                    s['activo'] == true ? 'Activa' : 'Inactiva',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await openPage(
                        context,
                        StationFormScreen(
                          controller: widget.controller,
                          station: s,
                        ),
                      );
                      await load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar estación'),
                  ),
                  TextButton(
                    onPressed: changeState,
                    child: Text(
                      s['activo'] == true
                          ? 'Desactivar estación'
                          : 'Reactivar estación',
                    ),
                  ),
                ],
                if ((s['licencia'] as String? ?? '').isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Referencia del catálogo',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      SelectableText(
                        '${s['licencia']}\n${s['fuente_url']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class FuelCard extends StatelessWidget {
  final AppRecord fuel;
  const FuelCard({super.key, required this.fuel});
  @override
  Widget build(BuildContext context) {
    final status = fuel['estado'] as String?;
    final target = switch (status) {
      'disponible' => .78,
      'limitada' => .28,
      _ => 0.0,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Semantics(
              label:
                  '${fuel['nombre']}: ${statusLabel(status)}. Nivel cualitativo.',
              child: TweenAnimationBuilder<double>(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 430),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: target),
                builder: (c, v, _) => CustomPaint(
                  size: const Size(48, 64),
                  painter: _TankPainter(
                    v,
                    statusColor(status),
                    status == 'sin_actualizar',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fuel['nombre'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: statusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dateLabel(fuel['registrado_en']),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  final double level;
  final Color color;
  final bool unknown;
  _TankPainter(this.level, this.color, this.unknown);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 14, size.width - 10, size.height - 19),
      const Radius.circular(7),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: .08));
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRect(
      Rect.fromLTWH(
        5,
        size.height - 5 - (size.height - 19) * level,
        size.width - 10,
        (size.height - 19) * level,
      ),
      Paint()..color = color.withValues(alpha: .8),
    );
    canvas.restore();
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 5, 19, 10),
        const Radius.circular(2),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final symbol = unknown
        ? '?'
        : level == 0
        ? '−'
        : '';
    if (symbol.isNotEmpty) {
      final text = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset((size.width - text.width) / 2, 25));
    }
  }

  @override
  bool shouldRepaint(covariant _TankPainter old) =>
      level != old.level || color != old.color || unknown != old.unknown;
}
