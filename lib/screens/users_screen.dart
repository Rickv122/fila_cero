import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

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
          load();
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Invitar personal'),
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
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pendientes'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => status = v!);
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
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                roleLabel(s),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => role = v);
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
                          backgroundColor: Color(0xFFE8EFFE),
                          child: Icon(Icons.person_outline, color: accent),
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
                          load();
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

String userState(AppRecord u) => u['activo'] != true
    ? 'Inactivo'
    : u['confirmado'] != true
    ? 'Correo pendiente'
    : u['rol_invitado'] != null
    ? 'Invitación pendiente'
    : 'Activo';

class StaffFormScreen extends StatefulWidget {
  final AppController controller;
  final AppRecord? existing;
  const StaffFormScreen({super.key, required this.controller, this.existing});
  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      email = TextEditingController();
  String role = 'responsable';
  String? company;
  List<AppRecord>? companies;
  Object? loadError;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name.text = widget.existing?['nombre'] ?? '';
    email.text = widget.existing?['email'] ?? '';
    load();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final o = row(await widget.controller.query('options'));
      if (mounted) {
        setState(
          () =>
              companies = rows(o['empresas'])
                  .where((e) => e['activo'] == true)
                  .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => loadError = e);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.controller.repository.staff({
        'action': 'invite',
        'nombre': name.text.trim(),
        'email': email.text.trim(),
        'rol': role,
        'empresa_id': company,
      });
      if (mounted) {
        notice(context, result['message'] ?? 'Invitación preparada');
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
      appBar: AppBar(title: const Text('Invitar personal')),
      body: loadError != null
          ? ErrorPane(error: loadError!, retry: load)
          : companies == null
          ? const Center(child: CircularProgressIndicator())
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
                      labelText: 'Correo de la persona',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Función autorizada',
                    ),
                    items: ['responsable', 'administrador']
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(roleLabel(r)),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (s) => setState(() => role = s!),
                  ),
                  const SizedBox(height: 16),
                  if (role == 'responsable')
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
                          : (v) => setState(() => company = v),
                    ),
                  const SizedBox(height: 22),
                  const Text(
                    'La persona deberá confirmar su acceso y aceptar la invitación. Después podrás asignarle estaciones.',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Preparando…' : 'Enviar invitación'),
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
  List<AppRecord> memberships = [], assignments = [], audit = [];
  Object? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await Future.wait([
        widget.controller.query('user', {'id': widget.id}),
        widget.controller.query('memberships', {'id': widget.id}),
        widget.controller.query('assignments', {'id': widget.id}),
        widget.controller.query('audit', {'id': widget.id}),
      ]);
      if (mounted) {
        setState(() {
          user = row(result[0]);
          memberships = rows(result[1]);
          assignments = rows(result[2]);
          audit = rows(result[3]);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> run(String action, AppRecord data) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.controller.command(action, data);
      await load();
      await widget.controller.refreshProfile();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> state() async {
    final active = user!['activo'] == true;
    if (await confirm(
      context,
      active ? 'Desactivar cuenta' : 'Reactivar cuenta',
      '${user!['nombre']}\n${user!['email']}\n\n${active ? 'Se bloquearán sus siguientes operaciones protegidas. Se conservan sus datos e historial.' : 'No confirma el correo ni recupera asignaciones retiradas.'}',
      action: active ? 'Desactivar' : 'Reactivar',
    )) {
      await run('user_state', {'id': widget.id, 'activo': !active});
    }
  }

  Future<void> edit() async {
    final name = TextEditingController(text: user!['nombre']),
        contact = TextEditingController(text: user!['contacto']);
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Editar datos'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                validator: requiredText,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contact,
                decoration: const InputDecoration(labelText: 'Contacto'),
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await run('user_save', {
        'id': widget.id,
        'nombre': name.text,
        'contacto': contact.text,
      });
    }
  }

  Future<void> changeRole() async {
    String role = user!['rol'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Cambiar rol'),
        content: DropdownButtonFormField<String>(
          initialValue: role,
          isExpanded: true,
          items: ['administrador', 'responsable', 'conductor']
              .map((r) => DropdownMenuItem(value: r, child: Text(roleLabel(r))))
              .toList(),
          onChanged: (s) => role = s!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (ok != true || role == user!['rol'] || !mounted) return;
    if (await confirm(
      context,
      'Confirmar cambio de rol',
      '${user!['nombre']} pasará a ${roleLabel(role)}. Se cerrarán sus asignaciones vigentes; no se recuperan automáticamente.',
    )) {
      await run('user_role', {'id': widget.id, 'rol': role});
    }
  }

  Future<void> staffAction(String action) async {
    if (!await confirm(
      context,
      action == 'recover' ? 'Enviar recuperación' : 'Reenviar invitación',
      'Se enviará un correo a ${user!['email']}.',
      action: 'Enviar',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.controller.repository.staff({
        'action': action,
        'id': widget.id,
      });
      if (mounted) notice(context, result['message'] ?? 'Solicitud procesada');
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> assign(AppRecord member) async {
    try {
      final stations = <AppRecord>[];
      var page = 0;
      var hasMore = true;
      while (hasMore) {
        final result = row(
          await widget.controller.query('catalog', {
            'mode': 'admin',
            'status': 'active',
            'company': member['empresa_id'],
            'page': page,
          }),
        );
        stations.addAll(rows(result['rows']));
        hasMore = result['has_more'] == true;
        page++;
      }
      if (!mounted) return;
      String? chosen;
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Asignar estación'),
          content: stations.isEmpty
              ? const Text('No hay estaciones activas en esta empresa.')
              : DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estación'),
                  items: stations
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['nombre']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => chosen = v,
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      );
      if (ok == true && chosen != null) {
        await run('assignment_add', {
          'id': newId(),
          'vinculacion_id': member['id'],
          'estacion_id': chosen,
        });
      }
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    }
  }

  @override
  Widget build(BuildContext c) {
    final u = user;
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
                  PageTitle(u['codigo'], u['nombre'], subtitle: u['email']),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roleLabel(u['rol']),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(userState(u)),
                          if ((u['contacto'] as String).isNotEmpty)
                            Text(u['contacto']),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: busy ? null : edit,
                                child: const Text('Editar datos'),
                              ),
                              TextButton(
                                onPressed: busy ? null : changeRole,
                                child: const Text('Cambiar rol'),
                              ),
                              TextButton(
                                onPressed: busy ? null : state,
                                child: Text(
                                  u['activo'] == true
                                      ? 'Desactivar cuenta'
                                      : 'Reactivar cuenta',
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => staffAction('recover'),
                            icon: const Icon(Icons.mail_outline),
                            label: const Text(
                              'Recuperar acceso / revisar correo',
                            ),
                          ),
                          if (u['rol_invitado'] != null ||
                              u['confirmado'] != true) ...[
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => staffAction('resend'),
                              child: const Text('Reenviar invitación'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await confirm(
                                        c,
                                        'Cancelar invitación',
                                        'No se concederán los permisos pendientes.',
                                      )) {
                                        await run('invite_cancel', {
                                          'id': widget.id,
                                        });
                                      }
                                    },
                              child: const Text(
                                'Cancelar habilitación pendiente',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _heading('Vinculaciones empresariales'),
                  ...memberships.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['empresa'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                m['activo'] != true
                                    ? 'Finalizada'
                                    : m['aceptada_en'] == null
                                    ? 'Pendiente de aceptación'
                                    : 'Aceptada',
                              ),
                              if (m['activo'] == true)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (m['aceptada_en'] != null)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => assign(m),
                                        child: const Text('Asignar estación'),
                                      ),
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              if (await confirm(
                                                c,
                                                'Finalizar vinculación',
                                                'Se retirarán las asignaciones de esta empresa.',
                                              )) {
                                                await run('membership_end', {
                                                  'id': m['id'],
                                                });
                                              }
                                            },
                                      child: const Text('Finalizar vínculo'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
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
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Invitar a empresa o función'),
                  ),
                  const SizedBox(height: 24),
                  _heading('Asignaciones'),
                  if (assignments.isEmpty)
                    const Text(
                      'Sin asignaciones.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ...assignments.map(
                    (a) => Card(
                      child: ListTile(
                        title: Text(a['estacion']),
                        subtitle: Text(
                          '${a['empresa']} · ${a['activo'] == true ? 'Vigente' : 'Retirada'}',
                        ),
                        trailing: a['activo'] == true
                            ? IconButton(
                                tooltip: 'Retirar asignación',
                                onPressed: busy
                                    ? null
                                    : () async {
                                        if (await confirm(
                                          c,
                                          'Retirar asignación',
                                          a['estacion'],
                                        )) {
                                          await run('assignment_end', {
                                            'id': a['id'],
                                          });
                                        }
                                      },
                                icon: const Icon(Icons.link_off),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _heading('Historial administrativo'),
                  if (audit.isEmpty)
                    const Text(
                      'Sin eventos administrativos.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ...audit.map(
                    (a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(
                        auditLabel(a['accion']),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${a['actor'] ?? 'Sistema'} · ${dateLabel(a['registrado_en'])}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _heading(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      s,
      style: const TextStyle(
        color: navy,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String auditLabel(String action) => switch (action) {
  'cuenta_creada' => 'Creación de cuenta',
  'user_state' => 'Cambio de estado',
  'user_role' => 'Cambio de rol',
  'user_save' => 'Edición de datos',
  'invite_stage' => 'Invitación de personal',
  'invite_cancel' => 'Invitación cancelada',
  'invitacion_aceptada' => 'Invitación aceptada',
  'invitacion_rechazada' => 'Invitación rechazada',
  'membership_end' => 'Vinculación finalizada',
  'assignment_add' => 'Estación asignada',
  'assignment_end' => 'Asignación retirada',
  _ => action,
};
