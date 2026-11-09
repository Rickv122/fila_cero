import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_store.dart';
import 'core/app_strings.dart';
import 'screens/sprint_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  runApp(FilaCeroApp(store: store));
}

class FilaCeroApp extends StatelessWidget {
  final AppStore store;
  final bool mapEnabled;
  const FilaCeroApp({super.key, required this.store, this.mapEnabled = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: S.appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF4511E)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
    ),
    home: AnimatedBuilder(
      animation: store,
      builder: (_, _) => store.hasAccess
          ? HomeScreen(store: store, mapEnabled: mapEnabled)
          : WelcomeScreen(store: store),
    ),
  );
}
