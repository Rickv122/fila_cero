import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

class StationFormScreen extends StatefulWidget {
  final AppController controller;
  final AppRecord? station;
  final String? initialCompany;
  const StationFormScreen({
    super.key,
    required this.controller,
    this.station,
    this.initialCompany,
  });
  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      address = TextEditingController(),
      license = TextEditingController(),
      source = TextEditingController();
  late String id;
  String? company, city;
  Set<String> fuels = {};
  AppRecord? options;
  Object? loadError;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final s = widget.station;
    id = s?['id'] ?? newId();
    company = s?['empresa_id'] ?? widget.initialCompany;
    city = s?['ciudad_id'];
    name.text = s?['nombre'] ?? '';
    address.text = s?['direccion'] ?? '';
    license.text = s?['licencia'] ?? '';
    source.text = s?['fuente_url'] ?? '';
    fuels = rows(s?['combustibles']).map((f) => f['id'] as String).toSet();
    load();
  }

  @override
  void dispose() {
    for (final c in [name, address, license, source]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final o = row(await widget.controller.query('options'));
      if (mounted) {
        setState(() {
          options = o;
          loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loadError = e);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (fuels.isEmpty) {
      setState(() => error = 'Selecciona al menos un combustible.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.command('station_save', {
        'id': id,
        'empresa_id': company,
        'ciudad_id': city,
        'nombre': name.text,
        'direccion': address.text,
        'licencia': license.text.trim(),
        'fuente_url': source.text.trim(),
        'combustibles': fuels.toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    adminOnly: true,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.station == null ? 'Nueva estación' : 'Editar estación',
        ),
      ),
      body: loadError != null
          ? ErrorPane(error: loadError!, retry: load)
          : options == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _text(name, 'Nombre de la estación'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: company,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Empresa operadora',
                    ),
                    validator: requiredText,
                    items: rows(options!['empresas'])
                        .map(
                          (e) => DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(
                              e['denominacion'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => company = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: city,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                    validator: requiredText,
                    items: rows(options!['ciudades'])
                        .map(
                          (e) => DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(e['nombre']),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => city = v),
                  ),
                  const SizedBox(height: 16),
                  _text(address, 'Dirección'),
                  const SizedBox(height: 24),
                  const Text(
                    'Combustibles habilitados',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...rows(options!['combustibles']).map(
                    (f) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(f['nombre']),
                      value: fuels.contains(f['id']),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                fuels.add(f['id']);
                              } else {
                                fuels.remove(f['id']);
                              }
                            }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _text(
                    license,
                    'Referencia de licencia (opcional)',
                    required: false,
                  ),
                  const SizedBox(height: 16),
                  _text(
                    source,
                    'Fuente del catálogo (opcional)',
                    required: false,
                  ),
                  const SizedBox(height: 24),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Guardando…' : 'Guardar estación'),
                  ),
                ],
              ),
            ),
    ),
  );
  Widget _text(
    TextEditingController ctrl,
    String label, {
    bool required = true,
  }) => TextFormField(
    controller: ctrl,
    enabled: !busy,
    validator: required ? requiredText : null,
    decoration: InputDecoration(labelText: label),
  );
}
