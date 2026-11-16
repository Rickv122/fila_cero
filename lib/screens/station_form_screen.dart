import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

class StationFormScreen extends StatefulWidget {
  final AppController controller;
  final Station? station;
  const StationFormScreen({super.key, required this.controller, this.station});
  @override
  State<StationFormScreen> createState() => _StationFormState();
}

class _StationFormState extends State<StationFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, address, latitude, longitude;
  String city = 'La Paz';
  final selected = <String>{};
  List<Map<String, dynamic>> fuels = [];
  bool busy = false, loading = true;
  Object? error;
  String? validation;
  @override
  void initState() {
    super.initState();
    final s = widget.station;
    name = TextEditingController(text: s?.name);
    address = TextEditingController(text: s?.address);
    latitude = TextEditingController(text: s?.latitude.toString());
    longitude = TextEditingController(text: s?.longitude.toString());
    city = s?.city ?? 'La Paz';
    selected.addAll(s?.fuels.map((f) => f.fuelId) ?? <String>[]);
    load();
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await widget.controller.repository.fuels();
      if (mounted) setState(() => fuels = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double? coordinate(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  String? checkCoordinate(String? value, double limit) {
    final n = coordinate(value ?? '');
    return n == null || !n.isFinite || n.abs() > limit
        ? 'Usa un número entre -$limit y $limit'
        : null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (selected.isEmpty) {
      setState(() => validation = 'Selecciona al menos un combustible.');
      return;
    }
    setState(() {
      busy = true;
      validation = null;
    });
    try {
      await widget.controller.repository.saveStation(
        StationDraft(
          id: widget.station?.id,
          name: name.text,
          address: address.text,
          city: city,
          latitude: coordinate(latitude.text)!,
          longitude: coordinate(longitude.text)!,
          fuelIds: selected.toList(),
        ),
      );
      if (mounted) {
        message(context, 'Gasolinera guardada');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => validation = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => StaffGuard(
    controller: widget.controller,
    role: UserRole.administrador,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.station == null ? 'Registrar gasolinera' : 'Editar gasolinera',
        ),
      ),
      body: PageBody(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? ErrorPane(error: error!, retry: load)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Datos generales',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la gasolinera',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Completa el nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: address,
                        enabled: !busy,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Completa la dirección'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: city,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                        items: const [
                          DropdownMenuItem(
                            value: 'La Paz',
                            child: Text('La Paz'),
                          ),
                          DropdownMenuItem(
                            value: 'El Alto',
                            child: Text('El Alto'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() => city = v!),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Ubicación de la gasolinera',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: latitude,
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitud',
                          hintText: '-16.512',
                        ),
                        validator: (v) => checkCoordinate(v, 90),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: longitude,
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitud',
                          hintText: '-68.131',
                        ),
                        validator: (v) => checkCoordinate(v, 180),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Combustibles habilitados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...fuels.map(
                        (f) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(f['nombre'] as String),
                          value: selected.contains(f['id']),
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    selected.add(f['id'] as String);
                                  } else {
                                    selected.remove(f['id']);
                                  }
                                }),
                        ),
                      ),
                      if (validation != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            validation!,
                            style: TextStyle(
                              color: Theme.of(c).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: busy ? null : save,
                        child: Text(busy ? 'Guardando…' : 'Guardar gasolinera'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
