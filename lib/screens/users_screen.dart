import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

String userState(AppRecord u) => u['activo'] == true ? 'Activo' : 'Inactivo';

class UsersScreen extends StatefulWidget {
  final AppController controller;
  const UsersScreen({super.key, required this.controller});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final search = TextEditingController();
  String status = 'active';
  String? role;
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
    data = widget.controller.query('users', {
      'name': search.text.trim(),
      'status': status,
      'role': role,
    });
  });
  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    adminOnly: true,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            onPressed: load,
            tooltip: 'Actualizar usuarios',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await openPage(c, StaffFormScreen(controller: widget.controller));
          if (mounted) load();
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Registrar personal'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: search,
                  onSubmitted: (_) => load(),
                  decoration: const InputDecoration(
                    labelText: 'Buscar nombre o correo',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos')),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Activos'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactivos'),
                          ),
                        ],
                        onChanged: (v) {
                          status = v!;
                          load();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: role,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...['administrador', 'responsable', 'conductor'].map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                roleLabel(r),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          role = v;
                          load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: data,
              builder: (c, s) {
                if (s.hasError) return ErrorPane(error: s.error!, retry: load);
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = rows(s.data);
                if (list.isEmpty) {
                  return const EmptyPane('Sin usuarios con estos filtros');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (c, i) {
                    final u = list[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(
                          u['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${u['email']}\n${roleLabel(u['rol'])} · ${userState(u)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await openPage(
                            c,
                            UserDetailScreen(
                              controller: widget.controller,
                              id: u['id'],
                            ),
                          );
                          if (mounted) load();
                        },
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

class StaffFormScreen extends StatefulWidget {
  final AppController controller;
  final AppRecord? existing;
  const StaffFormScreen({super.key, required this.controller, this.existing});
  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      contact = TextEditingController(),
      password = TextEditingController();
  final operation = newId();
  final selected = <String>{};
  List<AppRecord>? companies;
  List<AppRecord> stations = [];
  String role = 'responsable';
  String? company, error;
  bool busy = false, loadingStations = false, hidden = true;
  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    name.text = u?['nombre'] ?? '';
    email.text = u?['email'] ?? '';
    contact.text = u?['contacto'] ?? '';
    role = u?['rol'] ?? 'responsable';
    load();
  }

  @override
  void dispose() {
    for (final t in [name, email, contact, password]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final opts = row(await widget.controller.query('options'));
      final active = rows(opts['empresas'])
          .where((e) => e['activo'] == true)
          .toList();
      if (widget.existing != null) {
        final links = rows(
          await widget.controller.query('memberships', {
            'id': widget.existing!['id'],
          }),
        ).where((m) => m['activo'] == true).toList();
        if (links.isNotEmpty &&
            active.any((e) => e['id'] == links.first['empresa_id'])) {
          company = links.first['empresa_id'];
        }
        final assigns = rows(
          await widget.controller.query('assignments', {
            'id': widget.existing!['id'],
          }),
        );
        selected.addAll(
          assigns
              .where((a) => a['activo'] == true)
              .map((a) => a['estacion_id'] as String),
        );
      }
      if (mounted) setState(() => companies = active);
      if (company != null) await loadStations();
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    }
  }

  Future<void> loadStations() async {
    setState(() => loadingStations = true);
    final requested = company;
    try {
      final list = <AppRecord>[];
      var page = 0, more = true;
      while (more) {
        final value = row(
          await widget.controller.query('catalog', {
            'mode': 'admin',
            'status': 'active',
            'company': requested,
            'page': page++,
          }),
        );
        list.addAll(rows(value['rows']));
        more = value['has_more'] == true;
      }
      if (mounted && company == requested) {
        setState(() {
          stations = list;
          selected.removeWhere((id) => !list.any((s) => s['id'] == id));
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted && company == requested) {
        setState(() => loadingStations = false);
      }
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || loadingStations) return;
    if (widget.existing != null && role != widget.existing!['rol']) {
      if (!await confirm(
        context,
        'Cambiar rol',
        '${name.text} pasará a ${roleLabel(role)}. Sus permisos se actualizarán con este formulario.',
      )) {
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.controller.repository.staff({
        'action': 'save',
        'id': widget.existing?['id'],
        'operation': operation,
        'nombre': name.text.trim(),
        'email': email.text.trim(),
        'contacto': contact.text.trim(),
        'password': password.text,
        'rol': role,
        'empresa_id': role == 'responsable' ? company : null,
        'station_ids': role == 'responsable' ? selected.toList() : <String>[],
      });
      if (mounted) {
        notice(context, result['message']);
        Navigator.pop(context, true);
      }
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
          widget.existing == null
              ? 'Registrar personal'
              : 'Editar acceso y estaciones',
        ),
      ),
      body: companies == null
          ? (error != null
                ? ErrorPane(error: Exception(error), retry: load)
                : const Center(child: CircularProgressIndicator()))
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: name,
                    validator: requiredText,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: email,
                    readOnly: widget.existing != null,
                    validator: emailError,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contact,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  if (widget.existing == null) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: hidden,
                      validator: passwordError,
                      decoration: InputDecoration(
                        labelText: 'Contraseña inicial',
                        suffixIcon: IconButton(
                          tooltip: hidden
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(() => hidden = !hidden),
                          icon: Icon(
                            hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items:
                        (widget.existing == null
                                ? ['responsable', 'administrador']
                                : ['responsable', 'administrador', 'conductor'])
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(roleLabel(r)),
                              ),
                            )
                            .toList(),
                    onChanged: busy ? null : (v) => setState(() => role = v!),
                  ),
                  if (role == 'responsable') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: company,
                      isExpanded: true,
                      validator: requiredText,
                      decoration: const InputDecoration(
                        labelText: 'Empresa operadora',
                      ),
                      items: companies!
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
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() {
                                company = v;
                                selected.clear();
                                stations = [];
                                error = null;
                              });
                              loadStations();
                            },
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Estaciones asignadas',
                      style: Theme.of(c).textTheme.titleMedium
                          ?.copyWith(color: navy, fontWeight: FontWeight.w700),
                    ),
                    if (loadingStations)
                      const Padding(
                        padding: EdgeInsets.all(15),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (company != null && !loadingStations && stations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Esta empresa no tiene estaciones activas.',
                        ),
                      ),
                    ...stations.map(
                      (s) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s['nombre']),
                        subtitle: Text(s['direccion']),
                        value: selected.contains(s['id']),
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                if (v == true) {
                                  selected.add(s['id']);
                                } else {
                                  selected.remove(s['id']);
                                }
                              }),
                      ),
                    ),
                    if (selected.isEmpty && !loadingStations)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Sin asignar',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                  ],
                  const SizedBox(height: 22),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 14),
                  ],
                  FilledButton(
                    onPressed: busy || loadingStations ? null : save,
                    child: Text(
                      busy
                          ? 'Guardando…'
                          : widget.existing == null
                          ? 'Registrar cuenta'
                          : 'Guardar cambios',
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}

class UserDetailScreen extends StatefulWidget {
  final AppController controller;
  final String id;
  const UserDetailScreen({
    super.key,
    required this.controller,
    required this.id,
  });
  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  AppRecord? user;
  List<AppRecord> memberships = [], assignments = [];
  Object? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.controller.query('user', {'id': widget.id}),
        widget.controller.query('memberships', {'id': widget.id}),
        widget.controller.query('assignments', {'id': widget.id}),
      ]);
      if (mounted) {
        setState(() {
          user = row(values[0]);
          memberships = rows(values[1]);
          assignments = rows(values[2]);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> state() async {
    final active = user!['activo'] == true;
    if (!await confirm(
      context,
      active ? 'Desactivar cuenta' : 'Reactivar cuenta',
      '${user!['nombre']}\n${active ? 'Se bloqueará su acceso a las funciones protegidas.' : 'Volverá a utilizar sus permisos vigentes.'}',
      action: active ? 'Desactivar' : 'Reactivar',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.controller.command('user_state', {
        'id': widget.id,
        'activo': !active,
      });
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final password = TextEditingController(), repeat = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user!['nombre']),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: true,
                validator: passwordError,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: repeat,
                obscureText: true,
                validator: (s) => s != password.text
                    ? 'Las contraseñas no coinciden'
                    : passwordError(s),
                decoration: const InputDecoration(
                  labelText: 'Repite la contraseña',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(d, true);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await widget.controller.repository.staff({
        'action': 'password',
        'id': widget.id,
        'password': password.text,
      });
      if (mounted) notice(context, 'Contraseña actualizada.');
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final u = user;
    final activeAssignments = assignments
        .where((a) => a['activo'] == true)
        .toList();
    final own = widget.controller.profile?['id'] == widget.id;
    return ProtectedPage(
      controller: widget.controller,
      adminOnly: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ficha de usuario'),
          actions: [
            IconButton(
              onPressed: load,
              tooltip: 'Actualizar ficha',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: error != null
            ? ErrorPane(error: error!, retry: load)
            : u == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PageTitle(
                    roleLabel(u['rol']),
                    u['nombre'],
                    subtitle: u['email'],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userState(u),
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((u['contacto'] ?? '').toString().isNotEmpty)
                            Text(u['contacto']),
                          const SizedBox(height: 14),
                          if (!own) ...[
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      await openPage(
                                        c,
                                        StaffFormScreen(
                                          controller: widget.controller,
                                          existing: u,
                                        ),
                                      );
                                      await load();
                                    },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar acceso y estaciones'),
                            ),
                            TextButton(
                              onPressed: busy ? null : state,
                              child: Text(
                                u['activo'] == true
                                    ? 'Desactivar cuenta'
                                    : 'Reactivar cuenta',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: busy ? null : resetPassword,
                              icon: const Icon(Icons.lock_reset),
                              label: const Text('Restablecer contraseña'),
                            ),
                          ] else
                            const Text(
                              'Edita tu perfil y contraseña desde Mi cuenta.',
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (u['rol'] == 'responsable') ...[
                    const SizedBox(height: 24),
                    Text(
                      'Empresa',
                      style: Theme.of(c).textTheme.titleLarge
                          ?.copyWith(color: navy, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ...memberships
                        .where((m) => m['activo'] == true)
                        .map((m) => Text(m['empresa'])),
                    const SizedBox(height: 24),
                    Text(
                      'Estaciones asignadas',
                      style: Theme.of(c).textTheme.titleLarge
                          ?.copyWith(color: navy, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (activeAssignments.isEmpty)
                      const Text(
                        'Sin asignar',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ...activeAssignments.map(
                      (a) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_gas_station_outlined),
                          title: Text(a['estacion']),
                          subtitle: Text(a['empresa']),
                          trailing: IconButton(
                            tooltip: 'Retirar asignación',
                            onPressed: busy
                                ? null
                                : () async {
                                    if (await confirm(
                                      c,
                                      'Retirar asignación',
                                      a['estacion'],
                                    )) {
                                      try {
                                        await widget.controller.command(
                                          'assignment_end',
                                          {'id': a['id']},
                                        );
                                        await load();
                                      } catch (e) {
                                        if (c.mounted) {
                                          notice(c, readableError(e));
                                        }
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.link_off),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
