import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';
import 'catalog_screen.dart';

class CompanyScreen extends StatefulWidget {
  final AppController controller;
  const CompanyScreen({super.key, required this.controller});
  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final search = TextEditingController();
  String status = 'all';
  late Future<dynamic> data;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void load() => setState(() {
    data = widget.controller.query('companies', {
      'name': search.text.trim(),
      'status': status,
    });
  });
  Future<void> edit([AppRecord? e]) async {
    await openPage(
      context,
      CompanyFormScreen(controller: widget.controller, company: e),
    );
    load();
  }

  Future<void> state(AppRecord e) async {
    final active = e['activo'] == true;
    if (!await confirm(
      context,
      active ? 'Desactivar empresa' : 'Reactivar empresa',
      '${e['denominacion']}\n${active ? 'Sus estaciones dejarán de mostrarse al público y no admitirán publicaciones. Las cuentas se conservan.' : 'Las estaciones mantienen su estado propio y requieren nuevas publicaciones.'}',
      action: active ? 'Desactivar' : 'Reactivar',
    )) {
      return;
    }
    try {
      await widget.controller.command('company_state', {
        'id': e['id'],
        'activo': !active,
      });
      load();
    } catch (err) {
      if (mounted) notice(context, readableError(err));
    }
  }

  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    adminOnly: true,
    child: Scaffold(
      appBar: AppBar(title: const Text('Empresas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva empresa'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: search,
              decoration: const InputDecoration(
                labelText: 'Buscar empresa',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => load(),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Todas')),
              ButtonSegment(value: 'active', label: Text('Activas')),
              ButtonSegment(value: 'inactive', label: Text('Inactivas')),
            ],
            selected: {status},
            onSelectionChanged: (v) {
              setState(() => status = v.first);
              load();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder(
              future: data,
              builder: (c, s) {
                if (s.hasError) return ErrorPane(error: s.error!, retry: load);
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = rows(s.data);
                if (list.isEmpty) return const EmptyPane('Sin empresas');
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (c, i) {
                    final e = list[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e['denominacion'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              e['activo'] == true ? 'Activa' : 'Inactiva',
                              style: TextStyle(
                                color: e['activo'] == true
                                    ? const Color(0xFF178167)
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => openPage(
                                    c,
                                    CatalogScreen(
                                      controller: widget.controller,
                                      mode: 'admin',
                                      company: e['id'],
                                    ),
                                  ),
                                  child: const Text('Estaciones'),
                                ),
                                TextButton(
                                  onPressed: () => edit(e),
                                  child: const Text('Editar'),
                                ),
                                TextButton(
                                  onPressed: () => state(e),
                                  child: Text(
                                    e['activo'] == true
                                        ? 'Desactivar'
                                        : 'Reactivar',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class CompanyFormScreen extends StatefulWidget {
  final AppController controller;
  final AppRecord? company;
  const CompanyFormScreen({super.key, required this.controller, this.company});
  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      source = TextEditingController();
  late String id;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    id = widget.company?['id'] ?? newId();
    name.text = widget.company?['denominacion'] ?? '';
    source.text = widget.company?['fuente_url'] ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.controller.command('company_save', {
        'id': id,
        'denominacion': name.text,
        'fuente_url': source.text,
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
          widget.company == null ? 'Nueva empresa' : 'Editar empresa',
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: name,
              validator: requiredText,
              decoration: const InputDecoration(
                labelText: 'Denominación de la operadora',
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: source,
              decoration: const InputDecoration(
                labelText: 'Fuente verificada (opcional)',
              ),
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Guardando…' : 'Guardar empresa'),
            ),
          ],
        ),
      ),
    ),
  );
}
