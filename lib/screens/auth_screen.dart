import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      repeat = TextEditingController(),
      token = TextEditingController();
  late String mode;
  bool busy = false, hidden = true;
  String? error;
  String? info;
  @override
  void initState() {
    super.initState();
    mode = widget.initial;
  }

  @override
  void dispose() {
    for (final x in [name, email, password, repeat, token]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      final auth = widget.controller.client.auth;
      switch (mode) {
        case 'login':
          await widget.controller.login(email.text, password.text);
          if (mounted) Navigator.pop(context, true);
        case 'register':
          await auth.signUp(
            email: email.text.trim(),
            password: password.text,
            data: {'nombre': name.text.trim()},
            emailRedirectTo: AppController.callback,
          );
          if (mounted) {
            setState(() {
              mode = 'verify';
              info = 'Revisa tu correo para confirmar tu cuenta.';
            });
          }
        case 'forgot':
          await auth.resetPasswordForEmail(
            email.text.trim(),
            redirectTo: AppController.callback,
          );
          if (mounted) {
            setState(() {
              mode = 'recovery-code';
              info = 'Si el correo corresponde a una cuenta, recibirás las instrucciones.';
            });
          }
        case 'verify':
        case 'invite-code':
        case 'recovery-code':
          final entered = token.text.trim();
          final uri = Uri.tryParse(entered);
          if (uri != null && uri.scheme == 'https') {
            if (uri.host != 'oejouwwxngyafftzfkux.supabase.co' ||
                uri.path != '/auth/v1/verify' ||
                uri.queryParameters['token'] == null) {
              throw Exception('El enlace no corresponde a FilaCero.');
            }
            final kind = uri.queryParameters['type'];
            if (!['signup', 'email', 'invite', 'recovery'].contains(kind)) {
              throw Exception('Tipo de enlace no admitido aquí.');
            }
            await auth.verifyOTP(
              tokenHash: uri.queryParameters['token'],
              type: kind == 'invite'
                  ? OtpType.invite
                  : kind == 'recovery'
                  ? OtpType.recovery
                  : OtpType.email,
            );
            if (kind == 'recovery' || kind == 'invite') mode = 'reset';
          } else {
            await auth.verifyOTP(
              email: email.text.trim(),
              token: entered,
              type: mode == 'verify'
                  ? OtpType.email
                  : mode == 'invite-code'
                  ? OtpType.invite
                  : OtpType.recovery,
            );
          }
          await widget.controller.refreshProfile();
          if (mounted) {
            if (mode == 'recovery-code' ||
                mode == 'invite-code' ||
                mode == 'reset') {
              setState(() {
                mode = 'reset';
              });
            } else {
              Navigator.pop(context, true);
            }
          }
        case 'reset':
          await auth.updateUser(
            UserAttributes(
              password: password.text,
              data: {'password_configurada': true},
            ),
          );
          await widget.controller.logout();
          if (mounted) {
            setState(() {
              mode = 'login';
              password.clear();
              repeat.clear();
              info = 'Contraseña actualizada. Inicia sesión.';
            });
          }
      }
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    setState(() => busy = true);
    try {
      await widget.controller.client.auth.resend(
        type: OtpType.signup,
        email: email.text.trim(),
        emailRedirectTo: AppController.callback,
      );
      if (mounted) {
        setState(
          () => info = 'Correo reenviado. Revisa también la carpeta de spam.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      'register' => 'Crea tu cuenta',
      'forgot' => 'Recupera tu acceso',
      'verify' => 'Confirma tu correo',
      'recovery-code' => 'Revisa tu correo',
      'invite-code' => 'Acepta tu acceso',
      'reset' => 'Nueva contraseña',
      _ => 'Qué bueno verte',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('FilaCero')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.local_gas_station_rounded,
                        size: 44,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: navy, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(switch (mode) {
                      'register' => 'Guarda tus estaciones favoritas y revísalas cuando las necesites.',
                      'verify' =>
                        'Abre el enlace del correo en la app o cópialo aquí.',
                      'recovery-code' => 'Abre el enlace de recuperación en la app o cópialo aquí.',
                      _ => 'Consulta lo que necesitas, a tu ritmo.',
                    }, style: TextStyle(color: Colors.blueGrey.shade600)),
                    const SizedBox(height: 28),
                    if (mode == 'register') ...[
                      _field(
                        name,
                        'Nombre completo',
                        requiredText,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (mode != 'reset') ...[
                      _field(
                        email,
                        'Correo electrónico',
                        emailError,
                        Icons.alternate_email,
                        keyboard: TextInputType.emailAddress,
                        readOnly:
                            mode == 'verify' ||
                            mode == 'recovery-code' ||
                            mode == 'invite-code',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (['login', 'register', 'reset'].contains(mode)) ...[
                      TextFormField(
                        controller: password,
                        obscureText: hidden,
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: mode == 'login'
                            ? requiredText
                            : passwordError,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                      const SizedBox(height: 16),
                      if (mode != 'login') ...[
                        _field(
                          repeat,
                          'Repite la contraseña',
                          (v) => v != password.text
                              ? 'Las contraseñas no coinciden'
                              : passwordError(v),
                          Icons.lock_outline,
                          secret: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (mode == 'verify' ||
                        mode == 'recovery-code' ||
                        mode == 'invite-code') ...[
                      _field(
                        token,
                        'Enlace o código del correo',
                        requiredText,
                        Icons.pin_outlined,
                        keyboard: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (error != null) ...[
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                    ],
                    if (info != null) ...[
                      Text(info!, style: const TextStyle(color: navy)),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      key: const Key('auth-submit'),
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(switch (mode) {
                              'register' => 'Crear cuenta',
                              'forgot' => 'Enviar instrucciones',
                              'verify' => 'Verificar correo',
                              'recovery-code' => 'Verificar código',
                              'reset' => 'Guardar contraseña',
                              _ => 'Iniciar sesión',
                            }),
                    ),
                    if (mode == 'login') ...[
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                mode = 'invite-code';
                                error = null;
                              }),
                        child: const Text('Tengo una invitación de personal'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                mode = 'forgot';
                                error = null;
                              }),
                        child: const Text('Olvidé mi contraseña'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                mode = 'register';
                                error = null;
                              }),
                        child: const Text('Crear cuenta'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                mode = 'verify';
                                error = null;
                              }),
                        child: const Text('Tengo una verificación pendiente'),
                      ),
                    ],
                    if (mode == 'register')
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                mode = 'login';
                                error = null;
                              }),
                        child: const Text('Ya tengo una cuenta'),
                      ),
                    if (mode == 'verify')
                      TextButton(
                        onPressed: busy ? null : resend,
                        child: const Text('Reenviar correo'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String? Function(String?) validator,
    IconData icon, {
    bool secret = false,
    bool readOnly = false,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    obscureText: secret,
    readOnly: readOnly,
    keyboardType: keyboard,
    autocorrect: !secret,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}

class PasswordRecoveryScreen extends StatelessWidget {
  final AppController controller;
  const PasswordRecoveryScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      AuthScreen(controller: controller, initial: 'reset');
}
