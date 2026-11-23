import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/travel_repository.dart';
import 'firebase_config.dart';

/// Registration is opt-in. A device belongs to one live application session.
class PushService {
  final SupabaseClient client;
  final String? Function() currentProfile;
  PushService(this.client, this.currentProfile);
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _seen = <String>{};
  void Function(RemoteMessage message, bool opened)? onMessage;
  bool available = false;
  String? identifier;
  Future<void>? _registration;
  int _generation = 0;
  TravelRepository get api => TravelRepository(client);

  Future<void> initialize() async {
    if (kIsWeb || FirebaseConfig.current == null) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.current);
      available = true;
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((m) => _receive(m, false)),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _receive(m, true)),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _receive(initial, true);
      await resume();
    } catch (_) {
      available = false;
    }
  }

  Future<void> _receive(RemoteMessage message, bool opened) async {
    final recipient = message.data['recipient_id'];
    if (currentProfile() == null || recipient != currentProfile()) return;
    final id =
        '${message.data['event_id'] ?? message.messageId}:${opened ? 'open' : 'show'}';
    if (!_seen.add(id)) return;
    if (_seen.length > 200) _seen.remove(_seen.first);
    final preferences = await SharedPreferences.getInstance();
    final key = 'push_seen:$recipient';
    final previous = preferences.getStringList(key) ?? [];
    if (previous.contains(id)) return;
    final saved = [...previous, id];
    await preferences.setStringList(
      key,
      saved.length > 100 ? saved.sublist(saved.length - 100) : saved,
    );
    if (currentProfile() != recipient) return;
    onMessage?.call(message, opened);
  }

  Future<void> resume() async {
    if (!available || currentProfile() == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('alerts:${currentProfile()}') == true) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        try {
          await register();
        } catch (_) {
          /* Retry explicitly from Alerts. */
        }
      }
    }
  }

  Future<void> enable() async {
    if (!available) {
      throw const FormatException(
        'Los avisos no están disponibles en este dispositivo.',
      );
    }
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw const FormatException(
        'Permite las notificaciones en Ajustes para activar los avisos.',
      );
    }
    await register();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alerts:${currentProfile()}', true);
  }

  Future<void> register() =>
      _registration ??= _register().whenComplete(() => _registration = null);
  Future<void> _register() async {
    final user = currentProfile();
    if (user == null) {
      throw const FormatException('Inicia sesión para activar los avisos.');
    }
    final ticket = _generation;
    final completer = Completer<String>();
    final listener = FirebaseMessaging.instance.onRegistered.listen((fid) {
      if (!completer.isCompleted) completer.complete(fid);
    });
    try {
      await FirebaseMessaging.instance.register().timeout(
        const Duration(seconds: 20),
      );
      final fid = await completer.future.timeout(const Duration(seconds: 20));
      if (ticket != _generation || currentProfile() != user) return;
      await api.command('device_register', {
        'identificador': fid,
        'tipo': 'fid',
        'plataforma': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
      identifier = fid;
    } on TimeoutException {
      throw const FormatException(
        'No pudimos activar los avisos. Revisa la conexión y reintenta.',
      );
    } finally {
      await listener.cancel();
    }
  }

  Future<void> detach() async {
    _generation++;
    if (_registration != null) {
      try {
        await _registration;
      } catch (_) {
        /* Nothing registered. */
      }
    }
    if (identifier != null && client.auth.currentSession != null) {
      await api.command('device_disable', {'identificador': identifier});
    }
    if (available && identifier != null) {
      // Server revocation above is authoritative. A stalled Play Services call
      // must not trap the person inside an already revoked account.
      try {
        await FirebaseMessaging.instance.unregister().timeout(
          const Duration(seconds: 12),
        );
      } catch (_) {
        /* The server no longer sends to this device binding. */
      }
    }
    identifier = null;
    _seen.clear();
  }

  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
  }
}
