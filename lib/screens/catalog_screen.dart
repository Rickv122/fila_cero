import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'auth_screen.dart';
import 'common.dart';
import 'station_detail_screen.dart';
import 'station_form_screen.dart';

class CatalogScreen extends StatefulWidget {
  final AppController controller;
  final bool admin, assigned;
  const CatalogScreen({
    super.key,
    required this.controller,
    this.admin = false,
    this.assigned = false,
  });
  @override
  State<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends State<CatalogScreen> {
  final search = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> fuels = [];
  List<Station> rows = [];
  String? city, fuelId;
  bool inactive = false, busy = true, hasMore = false;
  int page = 0, generation = 0;
  Object? error;
  Timer? debounce, clock;
  @override
  void initState() {
    super.initState();
    load();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    clock?.cancel();
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (reset) {
      page = 0;
      if (scroll.hasClients) scroll.jumpTo(0);
    }
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final options = await widget.controller.repository.fuels();
      final result = await widget.controller.repository.stations(
        StationQuery(
          name: search.text,
          city: city,
          fuelId: fuelId,
          inactive: inactive,
          assigned: widget.assigned,
          page: page,
        ),
      );
      if (mounted && ticket == generation) {
        setState(() {
          fuels = options;
          rows = result.stations;
          hasMore = result.hasMore;
        });
      }
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) setState(() => busy = false);
    }
  }

  Future<void> openStation(Station station) async {
    await openPage(
      context,
      StationDetailScreen(controller: widget.controller, stationId: station.id),
    );
    if (mounted) load();
  }

  Widget content(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.admin
            ? 'Catálogo de gasolineras'
            : widget.assigned
            ? 'Mis gasolineras'
            : 'FilaCero',
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar lista',
          onPressed: busy ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
        if (!widget.admin && !widget.assigned)
          IconButton(
            tooltip: widget.controller.staff == null
                ? 'Acceso de personal'
                : 'Mi cuenta',
            onPressed: () => account(c),
            icon: Icon(
              widget.controller.staff == null
                  ? Icons.login
                  : Icons.account_circle_outlined,
            ),
          ),
      ],
    ),
    floatingActionButton: widget.admin
        ? FloatingActionButton.extended(
            onPressed: () async {
              final saved = await openPage<bool>(
                c,
                StationFormScreen(controller: widget.controller),
              );
              if (saved == true && mounted) load(reset: true);
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar gasolinera'),
          )
        : null,
    body: PageBody(
      child: RefreshIndicator(
        onRefresh: () => load(),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (!widget.admin && !widget.assigned)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [brand, Color(0xFFC63C46)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encuentra dónde abastecerte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Consulta combustible y disponibilidad informada por cada estación.',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            if (widget.assigned)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Actualiza la disponibilidad de las estaciones que tienes asignadas.',
                ),
              ),
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          search.clear();
                          load(reset: true);
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) {
                debounce?.cancel();
                setState(() {});
                debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => load(reset: true),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('city-${city ?? ''}'),
                    initialValue: city ?? '',
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Todas')),
                      DropdownMenuItem(value: 'La Paz', child: Text('La Paz')),
                      DropdownMenuItem(
                        value: 'El Alto',
                        child: Text('El Alto'),
                      ),
                    ],
                    onChanged: (v) {
                      city = v == '' ? null : v;
                      load(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('fuel-${fuelId ?? ''}-${fuels.length}'),
                    initialValue: fuelId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Combustible'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos')),
                      ...fuels.map(
                        (f) => DropdownMenuItem(
                          value: f['id'] as String,
                          child: Text(f['nombre'] as String),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      fuelId = v == '' ? null : v;
                      load(reset: true);
                    },
                  ),
                ),
              ],
            ),
            if (city != null || fuelId != null || search.text.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    search.clear();
                    city = null;
                    fuelId = null;
                    load(reset: true);
                  },
                  child: const Text('Limpiar filtros'),
                ),
              ),
            if (widget.admin)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar inactivas'),
                value: inactive,
                onChanged: (v) {
                  inactive = v;
                  load(reset: true);
                },
              ),
            const SizedBox(height: 20),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              ErrorPane(error: error!, retry: () => load())
            else if (!busy && rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_gas_station_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No se encontraron gasolineras',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Prueba otros filtros o vuelve a actualizar.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...rows.map(
                (s) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openStation(s),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_gas_station, color: brand),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${s.address} · ${s.city}'),
                          if (!s.active)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Inactiva',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: s.fuels
                                .map((f) => FuelBadge(fuel: f))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (!busy && error == null && (hasMore || page > 0))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: page == 0
                        ? null
                        : () {
                            page--;
                            load();
                          },
                    child: const Text('Anterior'),
                  ),
                  Text('Página ${page + 1}'),
                  TextButton(
                    onPressed: hasMore
                        ? () {
                            page++;
                            load();
                          }
                        : null,
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
  Future<void> account(BuildContext c) async {
    final controller = widget.controller;
    if (controller.staff == null) {
      await openPage(c, AuthScreen(controller: controller));
      if (mounted) load();
      return;
    }
    if (!c.mounted) return;
    final action = await showModalBottomSheet<String>(
      context: c,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(controller.staff!.name),
              subtitle: Text(
                controller.isAdmin
                    ? 'Administrador'
                    : 'Encargado de gasolinera',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(
                controller.isAdmin ? 'Administrar catálogo' : 'Mis gasolineras',
              ),
              onTap: () => Navigator.pop(c, 'panel'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => Navigator.pop(c, 'logout'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'panel') {
      await openPage(
        context,
        CatalogScreen(
          controller: controller,
          admin: controller.isAdmin,
          assigned: controller.isManager,
        ),
      );
      if (mounted) load();
    }
    if (action == 'logout') {
      try {
        await controller.logout();
        if (mounted) {
          message(context, 'Sesión cerrada');
          load();
        }
      } catch (e) {
        if (mounted) message(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    if (widget.admin || widget.assigned) {
      return StaffGuard(
        controller: widget.controller,
        role: widget.admin ? UserRole.administrador : UserRole.encargado,
        child: content(c),
      );
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, _) => content(c),
    );
  }
}
