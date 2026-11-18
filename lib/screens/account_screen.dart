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
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await widget.controller.refreshProfile();
    if (mounted) setState(() {});
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
                  title: const Text('Cambiar contraseña'),
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
      password = TextEditingController(),
      repeat = TextEditingController();
  bool busy = false;
  String? error, info;
  @override
  void dispose() {
    for (final t in [current, password, repeat]) {
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
      await auth.updateUser(UserAttributes(password: password.text));
      await auth.signOut(scope: SignOutScope.others);
      current.clear();
      password.clear();
      repeat.clear();
      if (mounted) setState(() => info = 'Contraseña actualizada.');
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
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: current,
              obscureText: true,
              validator: requiredText,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: password,
              obscureText: true,
              validator: passwordError,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
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
            const SizedBox(height: 24),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (info != null) Text(info!, style: const TextStyle(color: navy)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Procesando…' : 'Actualizar contraseña'),
            ),
          ],
        ),
      ),
    ),
  );
}
