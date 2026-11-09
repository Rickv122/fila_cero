import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_store.dart';
import '../core/app_strings.dart';

const orange = Color(0xFFF4511E);
const gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF9800), orange, Color(0xFFC2185B)],
);
const statusColors = [
  Color(0xFF2E7D32),
  Color(0xFFFFA000),
  Color(0xFFC62828),
  Color(0xFF616161),
];
Future<void> openAuth(
  BuildContext c,
  AppStore store, {
  bool register = false,
}) => Navigator.of(c).push(
  MaterialPageRoute<void>(
    builder: (_) => AuthScreen(store: store, register: register),
  ),
);

class WelcomeScreen extends StatelessWidget {
  final AppStore store;
  const WelcomeScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: gradient),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  const CircleAvatar(
                    radius: 58,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.local_gas_station,
                      size: 62,
                      color: orange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    S.appName,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    S.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: orange,
                      ),
                      onPressed: () => openAuth(context, store),
                      child: const Text(S.login),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        minimumSize: const Size(48, 52),
                      ),
                      onPressed: () => openAuth(context, store, register: true),
                      child: const Text(S.register),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: store.enterGuest,
                    child: const Text(
                      S.visitor,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final AppStore store;
  final bool register;
  const AuthScreen({super.key, required this.store, this.register = false});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    for (final c in [name, email, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      String? message;
      if (widget.register) {
        final result = await widget.store.register(
          name.text,
          email.text,
          password.text,
        );
        message = result == 'duplicate'
            ? S.duplicate
            : result != null
            ? S.storageError
            : null;
      } else {
        if (!await widget.store.login(email.text, password.text)) {
          message = S.loginError;
        }
      }
      if (!mounted) return;
      if (message == null) {
        Navigator.pop(context);
      } else {
        setState(() => error = message);
      }
    } catch (_) {
      if (mounted) setState(() => error = S.storageError);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.register ? S.register : S.login)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: orange,
              ),
              const SizedBox(height: 16),
              const Text(
                S.localAccount,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 12),
              const Text(S.localHelp),
              const SizedBox(height: 24),
              if (widget.register) ...[
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: S.name,
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? S.nameError : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: S.email,
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) =>
                    AppStore.validEmail(v ?? '') ? null : S.emailError,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: S.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: S.showPassword,
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) => (v ?? '').length < 8 ? S.passwordError : null,
              ),
              const SizedBox(height: 16),
              if (widget.register) ...[
                TextFormField(
                  controller: confirm,
                  obscureText: obscure,
                  decoration: const InputDecoration(labelText: S.confirm),
                  validator: (v) => v != password.text ? S.confirmError : null,
                ),
                const SizedBox(height: 16),
              ],
              if (error != null) ...[
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.register ? S.register : S.enter),
              ),
              if (!widget.register)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AuthScreen(store: widget.store, register: true),
                          ),
                        ),
                  child: const Text(S.register),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  final AppStore store;
  final bool mapEnabled;
  const HomeScreen({super.key, required this.store, this.mapEnabled = true});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int index = 0;
  final controller = MapController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void detail(Station s) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => DetailScreen(store: widget.store, id: s.id),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, _) => Scaffold(
      appBar: AppBar(
        title: Text(index == 2 ? S.profile : S.appName),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: gradient),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                Column(
                  children: [
                    if (widget.store.guest)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              color: orange,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text(S.guest)),
                            TextButton(
                              onPressed: () => openAuth(context, widget.store),
                              child: const Text(S.login),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: widget.mapEnabled ? mapView() : stationList(),
                    ),
                  ],
                ),
                stationList(),
                profileView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: S.map),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            label: S.list,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: S.profile,
          ),
        ],
      ),
    ),
  );
  Widget mapView() => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: const MapOptions(
          initialCenter: LatLng(-16.512, -68.141),
          initialZoom: 12.3,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.filacero',
          ),
          MarkerLayer(
            markers: [
              for (final s in widget.store.stations)
                Marker(
                  point: LatLng(s.latitude, s.longitude),
                  width: 50,
                  height: 50,
                  child: Semantics(
                    label: '${s.name}, ${S.status[s.effectiveStatus().index]}',
                    button: true,
                    child: InkWell(
                      onTap: () => detail(s),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColors[s.effectiveStatus().index],
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          Icons.local_gas_station,
                          color: statusColors[s.effectiveStatus().index],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SimpleAttributionWidget(source: Text(S.mapCredit)),
        ],
      ),
      Positioned(
        left: 12,
        bottom: 36,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: statusColors[i], size: 12),
                        const SizedBox(width: 6),
                        Text(S.status[i], style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 12,
        top: 12,
        child: Column(
          children: [
            FloatingActionButton.small(
              heroTag: 'zoomIn',
              onPressed: () => controller.move(
                controller.camera.center,
                controller.camera.zoom + 1,
              ),
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'zoomOut',
              onPressed: () => controller.move(
                controller.camera.center,
                controller.camera.zoom - 1,
              ),
              child: const Icon(Icons.remove),
            ),
          ],
        ),
      ),
    ],
  );
  Widget stationList() => widget.store.stations.isEmpty
      ? const Center(child: Text(S.noStations))
      : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: widget.store.stations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = widget.store.stations[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Icon(
                  Icons.local_gas_station,
                  color: statusColors[s.effectiveStatus().index],
                ),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${s.city}\n${S.status[s.effectiveStatus().index]}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => detail(s),
              ),
            );
          },
        );
  Widget profileView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.account_circle, size: 76, color: orange),
      const SizedBox(height: 16),
      Text(
        widget.store.currentUser?.name ?? S.guest,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        widget.store.currentUser?.email ?? S.readonly,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      if (widget.store.currentUser != null)
        Text(
          widget.store.isAdmin ? S.adminRole : S.accountRole,
          textAlign: TextAlign.center,
        ),
      const SizedBox(height: 24),
      if (widget.store.isAdmin)
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminScreen(store: widget.store),
            ),
          ),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text(S.admin),
        ),
      if (widget.store.guest)
        FilledButton(
          onPressed: () => openAuth(context, widget.store),
          child: const Text(S.login),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: widget.store.logout,
        icon: const Icon(Icons.logout),
        label: Text(widget.store.guest ? S.back : S.logout),
      ),
      const SizedBox(height: 20),
    ],
  );
}

class DetailScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  const DetailScreen({super.key, required this.store, required this.id});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) {
      final s = store.stations.firstWhere((s) => s.id == id);
      final status = s.effectiveStatus();
      return Scaffold(
        appBar: AppBar(title: const Text(S.details)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.local_gas_station,
              size: 72,
              color: statusColors[status.index],
            ),
            const SizedBox(height: 16),
            Text(
              s.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Chip(
              avatar: Icon(
                Icons.circle,
                size: 14,
                color: statusColors[status.index],
              ),
              label: Text(S.status[status.index]),
            ),
            const SizedBox(height: 16),
            const Text(
              S.address,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${s.address}\n${s.city}'),
            const SizedBox(height: 18),
            const Text(S.fuels, style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [for (final f in s.fuels) Chip(label: Text(f))],
            ),
            const SizedBox(height: 18),
            const Text(S.latest, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              s.reportedAt == null
                  ? S.noReports
                  : '${S.reportAuthor}\n${S.ago(s.reportedAt!)}\n${S.date(s.reportedAt!)}',
            ),
            if (s.reportedAt != null && status == FuelStatus.unknown)
              const Text(S.expired),
            const SizedBox(height: 20),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(store.guest ? S.loginRequired : S.report),
                  content: Text(store.guest ? S.loginMessage : S.futureReport),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text(S.ok),
                    ),
                    if (store.guest)
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(c);
                          openAuth(context, store);
                        },
                        child: const Text(S.login),
                      ),
                  ],
                ),
              ),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text(S.report),
            ),
            if (store.isAdmin)
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => StationForm(store: store, station: s),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text(S.edit),
              ),
          ],
        ),
      );
    },
  );
}

class AdminScreen extends StatelessWidget {
  final AppStore store;
  const AdminScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) => Scaffold(
      appBar: AppBar(title: const Text(S.admin)),
      body: !store.isAdmin
          ? const Center(child: Text(S.permissions))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(S.adminHelp),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => StationForm(store: store),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(S.add),
                ),
                const SizedBox(height: 16),
                for (final s in store.stations)
                  Card(
                    child: ListTile(
                      title: Text(s.name),
                      subtitle: Text(s.city),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => StationForm(store: store, station: s),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class StationForm extends StatefulWidget {
  final AppStore store;
  final Station? station;
  const StationForm({super.key, required this.store, this.station});
  @override
  State<StationForm> createState() => _StationFormState();
}

class _StationFormState extends State<StationForm> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, address, lat, lon;
  late String city;
  late Set<String> fuels;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final s = widget.station;
    name = TextEditingController(text: s?.name);
    address = TextEditingController(text: s?.address);
    lat = TextEditingController(text: s?.latitude.toString());
    lon = TextEditingController(text: s?.longitude.toString());
    city = s?.city ?? 'La Paz';
    fuels = {...?s?.fuels};
  }

  @override
  void dispose() {
    for (final c in [name, address, lat, lon]) {
      c.dispose();
    }
    super.dispose();
  }

  double? parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    if (fuels.isEmpty) {
      setState(() => error = S.fuelError);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final old = widget.station;
    try {
      await widget.store.saveStation(
        Station(
          id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.trim(),
          address: address.text.trim(),
          city: city,
          latitude: parse(lat.text)!,
          longitude: parse(lon.text)!,
          fuels: fuels.toList(),
          status: old?.status ?? FuelStatus.unknown,
          reportedAt: old?.reportedAt,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(S.saved)));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) setState(() => error = S.storageError);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.station == null ? S.add : S.edit)),
    body: !widget.store.isAdmin
        ? const Center(child: Text(S.permissions))
        : Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: S.stationName),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? S.required : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: S.address),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? S.required : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: city,
                  decoration: const InputDecoration(labelText: S.city),
                  items: [
                    for (final c in ['La Paz', 'El Alto'])
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => city = v!),
                ),
                const SizedBox(height: 16),
                const Text(S.coordinateHelp),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lat,
                  decoration: const InputDecoration(labelText: S.latitude),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    final n = parse(v ?? '');
                    return n == null || !n.isFinite || n.abs() > 90
                        ? S.latitudeError
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lon,
                  decoration: const InputDecoration(labelText: S.longitude),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    final n = parse(v ?? '');
                    return n == null || !n.isFinite || n.abs() > 180
                        ? S.longitudeError
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  S.fuels,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in S.fuelOptions)
                      FilterChip(
                        label: Text(f),
                        selected: fuels.contains(f),
                        onSelected: (selected) => setState(
                          () => selected ? fuels.add(f) : fuels.remove(f),
                        ),
                      ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: busy
                      ? const CircularProgressIndicator()
                      : const Text(S.save),
                ),
              ],
            ),
          ),
  );
}
