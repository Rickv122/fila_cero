import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/domain.dart';
import 'common.dart';

class AuthScreen extends StatefulWidget {
  final AppController controller;
  final String initial;
  const AuthScreen({
    super.key,
    required this.controller,
    this.initial = 'login',
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      repeat = TextEditingController();
  late bool register;
  bool busy = false, hidden = true;
  String? error;
  @override
  void initState() {
    super.initState();
    register = widget.initial == 'register';
  }

  @override
  void dispose() {
    for (final t in [name, email, password, repeat]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        await widget.controller.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'nombre': name.text.trim()},
        );
        await widget.controller.refreshProfile();
        if (!widget.controller.signedIn) {
          throw Exception(
            'No se pudo completar el acceso. Intenta iniciar sesión.',
          );
        }
      } else {
        await widget.controller.login(email.text, password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('FilaCero')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            register ? Icons.person_add_alt_rounded : Icons.lock_outline,
            size: 42,
            color: accent,
          ),
          const SizedBox(height: 20),
          Text(
            register ? 'Crea tu cuenta' : 'Qué bueno verte',
            style: Theme.of(c).textTheme.headlineMedium
                ?.copyWith(color: navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            register
                ? 'Guarda tus estaciones favoritas.'
                : 'Ingresa para continuar.',
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 26),
          if (register) ...[
            TextFormField(
              controller: name,
              validator: requiredText,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: email,
            validator: emailError,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: hidden,
            autocorrect: false,
            enableSuggestions: false,
            validator: register ? passwordError : requiredText,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (register) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: repeat,
              obscureText: true,
              validator: (v) => v != password.text
                  ? 'Las contraseñas no coinciden'
                  : passwordError(v),
              decoration: const InputDecoration(
                labelText: 'Repite la contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (error != null) ...[
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
          ],
          FilledButton(
            key: const Key('auth-submit'),
            onPressed: busy ? null : submit,
            child: Text(
              busy
                  ? 'Procesando…'
                  : register
                  ? 'Crear cuenta'
                  : 'Iniciar sesión',
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    register = !register;
                    error = null;
                  }),
            child: Text(register ? 'Ya tengo una cuenta' : 'Crear una cuenta'),
          ),
          if (!register)
            TextButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (d) => AlertDialog(
                  title: const Text('Recuperar acceso'),
                  content: const Text(
                    'Solicita al administrador que restablezca tu contraseña.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              ),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
        ],
      ),
    ),
  );
}
