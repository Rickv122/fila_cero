import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';
import 'auth_screen.dart';
import 'station_detail_screen.dart';
import 'station_form_screen.dart';

class CatalogScreen extends StatefulWidget {
  final AppController controller;
  final String mode;
  final String? company;
  const CatalogScreen({
    super.key,
    required this.controller,
    this.mode = 'public',
    this.company,
  });
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  final scroll = ScrollController();
  Timer? debounce;
  List<AppRecord> items = [];
  AppRecord options = {};
  String? company, city, fuel;
  String status = 'all';
  bool loading = true, more = false, loadingMore = false;
  Object? error;
  Object? optionsError;
  int page = 0, generation = 0;
  @override
  void initState() {
    super.initState();
    company = widget.company;
    load();
    loadOptions();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> loadOptions() async {
    try {
      final result = row(await widget.controller.query('options'));
      if (mounted) {
        setState(() {
          options = result;
          optionsError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => optionsError = e);
    }
  }

  Future<void> load({bool next = false}) async {
    final g = ++generation;
    if (!next) {
      page = 0;
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => loadingMore = true);
    }
    try {
      final result = row(
        await widget.controller.query('catalog', {
          'mode': widget.mode,
          'name': search.text.trim(),
          'company': company,
          'city': city,
          'fuel': fuel,
          'status': status,
          'page': next ? page + 1 : 0,
        }),
      );
      if (!mounted || g != generation) return;
      setState(() {
        items = next
            ? [...items, ...rows(result['rows'])]
            : rows(result['rows']);
        more = result['has_more'] == true;
        if (next) page++;
        error = null;
      });
    } catch (e) {
      if (mounted && g == generation) setState(() => error = e);
    } finally {
      if (mounted && g == generation) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> favorite(AppRecord station) async {
    if (!widget.controller.signedIn) {
      final ok = await openPage<bool>(
        context,
        AuthScreen(controller: widget.controller),
      );
      if (ok != true || !widget.controller.signedIn) return;
    }
    try {
      await widget.controller.command('favorite', {
        'id': station['id'],
        'activo': station['favorita'] != true,
      });
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    }
  }

  Future<void> filters() async {
    if (optionsError != null) {
      await loadOptions();
      if (optionsError != null) {
        if (mounted) {
          notice(context, 'No se pudieron cargar los filtros. Reintenta.');
        }
        return;
      }
      if (!mounted) return;
    }
    String? chosenCompany = company, chosenCity = city, chosenFuel = fuel;
    String chosenStatus = status;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(c).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filtrar estaciones',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 22),
                _dropdown(
                  'Empresa',
                  rows(options['empresas']),
                  'denominacion',
                  chosenCompany,
                  (v) => set(() => chosenCompany = v),
                ),
                const SizedBox(height: 14),
                _dropdown(
                  'Ciudad',
                  rows(options['ciudades']),
                  'nombre',
                  chosenCity,
                  (v) => set(() => chosenCity = v),
                ),
                const SizedBox(height: 14),
                _dropdown(
                  'Combustible',
                  rows(options['combustibles']),
                  'nombre',
                  chosenFuel,
                  (v) => set(() => chosenFuel = v),
                ),
                const SizedBox(height: 14),
                if (widget.mode == 'admin')
                  DropdownButtonFormField<String>(
                    initialValue: chosenStatus,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                      DropdownMenuItem(value: 'active', child: Text('Activos')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactivos'),
                      ),
                    ],
                    onChanged: (v) => set(() => chosenStatus = v!),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Aplicar filtros'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      company = null;
                      city = null;
                      fuel = null;
                      status = 'all';
                      search.clear();
                    });
                    Navigator.pop(c, false);
                    load();
                  },
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted == true) {
      setState(() {
        company = chosenCompany;
        city = chosenCity;
        fuel = chosenFuel;
        status = chosenStatus;
      });
      await load();
    }
  }

  Widget _dropdown(
    String label,
    List<AppRecord> values,
    String field,
    String? selected,
    ValueChanged<String?> change,
  ) => DropdownButtonFormField<String>(
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('Todas las opciones'),
      ),
      ...values.map(
        (v) => DropdownMenuItem(
          value: v['id'] as String,
          child: Text(v[field], overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: change,
  );
  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      'admin' => 'Estaciones',
      'favorites' => 'Mis favoritas',
      'assigned' => 'Mis estaciones',
      _ => 'Encuentra tu estación',
    };
    Widget content = Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.mode == 'admin'
          ? FloatingActionButton.extended(
              onPressed: () async {
                await openPage(
                  context,
                  StationFormScreen(
                    controller: widget.controller,
                    initialCompany: company,
                  ),
                );
                await load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva estación'),
            )
          : null,
      body: Column(
        children: [
          if (widget.mode == 'public')
            const PageTitle('Explora', 'Una mejor parada'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar estación o empresa',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 350),
                        () => load(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Filtrar estaciones',
                  onPressed: filters,
                  icon: Badge(
                    isLabelVisible:
                        company != null ||
                        city != null ||
                        fuel != null ||
                        status != 'all',
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? ErrorPane(error: error!, retry: () => load())
                : items.isEmpty
                ? EmptyPane(
                    widget.mode == 'favorites'
                        ? 'Aún no tienes favoritas'
                        : widget.mode == 'assigned'
                        ? 'Sin estaciones asignadas'
                        : 'Sin resultados',
                    message: widget.mode == 'assigned'
                        ? 'El administrador debe asignarte una estación.'
                        : 'Puedes actualizar o cambiar los filtros.',
                    icon: widget.mode == 'favorites'
                        ? Icons.favorite_border
                        : Icons.local_gas_station_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: () => load(),
                    child: ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: items.length + (more ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (c, i) {
                        if (i == items.length) {
                          return OutlinedButton(
                            onPressed: loadingMore
                                ? null
                                : () => load(next: true),
                            child: Text(
                              loadingMore ? 'Cargando…' : 'Cargar más',
                            ),
                          );
                        }
                        final station = items[i],
                            available = station['disponible'] == true;
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: available || widget.mode == 'admin'
                                ? () async {
                                    await openPage(
                                      context,
                                      StationDetailScreen(
                                        controller: widget.controller,
                                        id: station['id'],
                                      ),
                                    );
                                    await load();
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: .08),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.local_gas_station_outlined,
                                          color: accent,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              station['nombre'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18,
                                                color: navy,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              available
                                                  ? '${station['empresa']} · ${station['ciudad']}'
                                                  : 'No disponible',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF728096),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: station['favorita'] == true
                                            ? 'Quitar favorita'
                                            : 'Guardar favorita',
                                        onPressed: () => favorite(station),
                                        icon: Icon(
                                          station['favorita'] == true
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border,
                                          color: station['favorita'] == true
                                              ? accent
                                              : Colors.blueGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (station['direccion'] != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      station['direccion'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  if (available) ...[
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: rows(station['combustibles'])
                                          .map((f) => FuelPill(f))
                                          .toList(),
                                    ),
                                  ],
                                  if (widget.mode == 'admin')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        station['activo'] == true
                                            ? 'Activa'
                                            : 'Inactiva',
                                        style: TextStyle(
                                          color: station['activo'] == true
                                              ? const Color(0xFF178167)
                                              : Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
    if (widget.mode != 'public') {
      content = ProtectedPage(
        controller: widget.controller,
        adminOnly: widget.mode == 'admin',
        child: content,
      );
    }
    return content;
  }
}
