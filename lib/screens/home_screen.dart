import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import 'common.dart';
import 'auth_screen.dart';
import 'catalog_screen.dart';
import 'account_screen.dart';
import 'company_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.signedIn) return _Welcome(controller: controller);
      return Scaffold(
        appBar: AppBar(
          title: const Text('FilaCero'),
          actions: [
            IconButton(
              tooltip: 'Mi cuenta',
              onPressed: () =>
                  openPage(context, AccountScreen(controller: controller)),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.refreshProfile,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PageTitle(
                'Hola, ${controller.name}',
                controller.admin
                    ? 'Todo en orden'
                    : controller.manager
                    ? 'Tu estación, al día'
                    : 'Tu próxima parada',
                subtitle: roleLabelForHome(controller),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.local_gas_station_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        'Información útil.\nDecisiones más claras.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _tile(
                context,
                Icons.explore_outlined,
                'Consultar estaciones',
                'Busca por ciudad, empresa o combustible.',
                CatalogScreen(controller: controller),
              ),
              _tile(
                context,
                Icons.favorite_border,
                'Mis favoritas',
                'Tus estaciones en un solo lugar.',
                CatalogScreen(controller: controller, mode: 'favorites'),
              ),
              if (controller.manager)
                _tile(
                  context,
                  Icons.edit_note_rounded,
                  'Mis estaciones',
                  'Actualiza los combustibles de tus estaciones.',
                  CatalogScreen(controller: controller, mode: 'assigned'),
                ),
              if (controller.admin) ...[
                _tile(
                  context,
                  Icons.business_outlined,
                  'Empresas',
                  'Organiza operadoras y estaciones.',
                  CompanyScreen(controller: controller),
                ),
                _tile(
                  context,
                  Icons.local_gas_station_outlined,
                  'Estaciones',
                  'Administra el catálogo y sus combustibles.',
                  CatalogScreen(controller: controller, mode: 'admin'),
                ),
                _tile(
                  context,
                  Icons.manage_accounts_outlined,
                  'Usuarios',
                  'Personal, roles y estaciones.',
                  UsersScreen(controller: controller),
                ),
              ],
              _tile(
                context,
                Icons.person_outline,
                'Mi cuenta',
                'Tu perfil y contraseña.',
                AccountScreen(controller: controller),
              ),
            ],
          ),
        ),
      );
    },
  );
  String roleLabelForHome(AppController c) => c.admin
      ? 'Panel administrativo'
      : c.manager
      ? 'Gestión de disponibilidad'
      : 'Tus estaciones favoritas te esperan.';
  Widget _tile(
    BuildContext c,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Icon(icon, color: accent, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: navy),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openPage(c, page),
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  final AppController controller;
  const _Welcome({required this.controller});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'FILA CERO',
                  style: TextStyle(
                    color: accent,
                    letterSpacing: 4,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  height: 215,
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        right: -25,
                        top: -45,
                        child: Icon(
                          Icons.circle_outlined,
                          size: 230,
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                      const Icon(
                        Icons.local_gas_station_rounded,
                        size: 102,
                        color: Colors.white,
                      ),
                      Positioned(
                        right: 38,
                        bottom: 32,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Antes de salir,\nelige mejor.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: navy,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Consulta estaciones y disponibilidad de combustible en La Paz y El Alto.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF67788D),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                if (controller.sessionError != null) ...[
                  Text(
                    controller.sessionError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  TextButton(
                    onPressed: controller.logout,
                    child: const Text('Cerrar sesión actual'),
                  ),
                ],
                FilledButton(
                  key: const Key('browse'),
                  onPressed: () =>
                      openPage(context, CatalogScreen(controller: controller)),
                  child: const Text('Consultar estaciones'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                  ),
                  onPressed: () =>
                      openPage(context, AuthScreen(controller: controller)),
                  child: const Text('Iniciar sesión'),
                ),
                TextButton(
                  onPressed: () => openPage(
                    context,
                    AuthScreen(controller: controller, initial: 'register'),
                  ),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
