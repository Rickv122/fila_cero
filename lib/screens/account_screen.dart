import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';
import 'catalog_screen.dart';

class AccountScreen extends StatefulWidget {
  final AppController controller;
  const AccountScreen({super.key, required this.controller});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AppRecord invitations = {};
  Object? error;
  bool loading = true, busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await widget.controller.refreshProfile();
      final result = row(await widget.controller.query('invitations'));
      if (mounted) {
        setState(() {
          invitations = result;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> reply(bool accept, {String? id}) async {
    if (!await confirm(
      context,
      accept ? 'Aceptar invitación' : 'Rechazar invitación',
      accept
          ? 'Habilitarás las funciones autorizadas para esta invitación.'
          : 'Conservarás tus funciones actuales.',
      action: accept ? 'Aceptar' : 'Rechazar',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.controller.command('invitation_reply', {
        'accept': accept,
        'id': id,
      });
      await load();
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editProfile() async {
    final name = TextEditingController(text: widget.controller.name),
        contact = TextEditingController(
          text: widget.controller.profile?['contacto'] ?? '',
        );
    final form = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Editar perfil'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                validator: requiredText,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contact,
                decoration: const InputDecoration(
                  labelText: 'Contacto (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await widget.controller.command('profile_save', {
                  'nombre': name.text,
                  'contacto': contact.text,
                });
                await widget.controller.refreshProfile();
                if (d.mounted) Navigator.pop(d);
              } catch (e) {
                if (d.mounted) notice(d, readableError(e));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Text fields may still animate out after the dialog future resolves.
  }

  Future<void> logout() async {
    try {
      await widget.controller.logout();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) notice(context, readableError(e));
    }
  }

  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        actions: [
          IconButton(
            onPressed: load,
            tooltip: 'Actualizar perfil',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
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
                const Icon(
                  Icons.account_circle_outlined,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.controller.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.controller.profile?['email'] ?? '',
                  style: const TextStyle(color: Color(0xFFC4D3E9)),
                ),
                const SizedBox(height: 8),
                Text(
                  roleLabel(widget.controller.profile?['rol']),
                  style: const TextStyle(color: Color(0xFFC4D3E9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar perfil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: editProfile,
                ),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Correo y contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openPage(
                    c,
                    SecurityScreen(controller: widget.controller),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Mis favoritas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openPage(
                    c,
                    CatalogScreen(
                      controller: widget.controller,
                      mode: 'favorites',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Invitaciones de personal',
            style: Theme.of(c).textTheme.titleLarge
                ?.copyWith(color: navy, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            ErrorPane(error: error!, retry: load)
          else ...[
            if (invitations['rol_invitado'] == 'administrador')
              _invitation(
                'Administración de FilaCero',
                null,
                invitations['vence'],
              ),
            ...rows(invitations['vinculos'])
                .where((v) => v['aceptada_en'] == null)
                .map((v) => _invitation(v['empresa'], v['id'], v['vence_en'])),
            if (invitations['rol_invitado'] != 'administrador' &&
                rows(invitations['vinculos'])
                    .where((v) => v['aceptada_en'] == null)
                    .isEmpty)
              const Text(
                'No tienes invitaciones pendientes.',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ...rows(invitations['vinculos'])
                .where((v) => v['aceptada_en'] != null)
                .map(
                  (v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_outlined, color: accent),
                    title: Text(v['empresa']),
                    subtitle: const Text('Vinculación aceptada'),
                  ),
                ),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    ),
  );
  Widget _invitation(String title, String? id, dynamic expires) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Vence: ${dateLabel(expires)}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => reply(true, id: id),
                  child: const Text('Aceptar'),
                ),
                TextButton(
                  onPressed: busy ? null : () => reply(false, id: id),
                  child: const Text('Rechazar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SecurityScreen extends StatefulWidget {
  final AppController controller;
  const SecurityScreen({super.key, required this.controller});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      repeat = TextEditingController();
  bool busy = false;
  String mode = 'password';
  String? error, info;
  @override
  void dispose() {
    for (final t in [current, email, password, repeat]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      final auth = widget.controller.client.auth;
      await auth.signInWithPassword(
        email: widget.controller.profile!['email'],
        password: current.text,
      );
      if (mode == 'password') {
        await auth.updateUser(UserAttributes(password: password.text));
        await auth.signOut(scope: SignOutScope.others);
        password.clear();
        repeat.clear();
        if (mounted) {
          setState(
            () => info =
                'Contraseña actualizada. Se cerraron las otras sesiones.',
          );
        }
      } else {
        await auth.updateUser(
          UserAttributes(email: email.text.trim()),
          emailRedirectTo: AppController.callback,
        );
        if (mounted) {
          setState(
            () => info = 'Revisa ambos correos para confirmar el cambio. Tu correo actual sigue vigente.',
          );
        }
      }
      current.clear();
      await widget.controller.refreshProfile();
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => ProtectedPage(
    controller: widget.controller,
    child: Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'password', label: Text('Contraseña')),
                ButtonSegment(value: 'email', label: Text('Correo')),
              ],
              selected: {mode},
              onSelectionChanged: busy
                  ? null
                  : (s) => setState(() {
                      mode = s.first;
                      error = null;
                      info = null;
                    }),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: current,
              obscureText: true,
              validator: requiredText,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 18),
            if (mode == 'password') ...[
              TextFormField(
                controller: password,
                obscureText: true,
                validator: passwordError,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: repeat,
                obscureText: true,
                validator: (s) => s != password.text
                    ? 'Las contraseñas no coinciden'
                    : passwordError(s),
                decoration: const InputDecoration(
                  labelText: 'Repite la nueva contraseña',
                ),
              ),
            ] else
              TextFormField(
                controller: email,
                validator: emailError,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Nuevo correo'),
              ),
            const SizedBox(height: 24),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            if (info != null) ...[
              Text(info!, style: const TextStyle(color: navy)),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? 'Procesando…'
                    : mode == 'email'
                    ? 'Solicitar cambio'
                    : 'Actualizar contraseña',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
