import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_controller.dart';
import 'core/supabase_config.dart';
import 'data/supabase_repository.dart';
import 'screens/common.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final controller = AppController(
    SupabaseRepository(Supabase.instance.client),
  );
  await controller.initialize();
  runApp(FilaCeroApp(controller: controller));
}

class FilaCeroApp extends StatefulWidget {
  final AppController controller;
  const FilaCeroApp({super.key, required this.controller});
  @override
  State<FilaCeroApp> createState() => _FilaCeroAppState();
}

class _FilaCeroAppState extends State<FilaCeroApp> {
  final navigator = GlobalKey<NavigatorState>();
  String? previousUser;
  @override
  void initState() {
    super.initState();
    previousUser = widget.controller.profile?['id'];
    widget.controller.addListener(accountChanged);
  }

  void accountChanged() {
    final current = widget.controller.profile?['id'] as String?;
    if (previousUser != null && current != previousUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigator.currentState?.popUntil((route) => route.isFirst);
      });
    }
    previousUser = current;
  }

  @override
  void dispose() {
    widget.controller.removeListener(accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
    navigatorKey: navigator,
    title: 'FilaCero',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        secondary: navy,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF3F6FB),
        foregroundColor: navy,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: Colors.blueGrey.shade50),
    ),
    home: HomeScreen(controller: widget.controller),
  );
}
