import 'dart:math';

typedef AppRecord = Map<String, dynamic>;
List<AppRecord> rows(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
AppRecord row(dynamic value) => Map<String, dynamic>.from(value as Map);
String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

String? requiredText(String? s) =>
    s == null || s.trim().isEmpty ? 'Completa este campo' : null;
String? emailError(String? s) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s?.trim() ?? '')
    ? null
    : 'Escribe un correo válido';
String? passwordError(String? s) =>
    (s?.length ?? 0) < 8 ? 'Usa al menos 8 caracteres' : null;
String roleLabel(String? s) => switch (s) {
  'administrador' => 'Administrador',
  'responsable' => 'Responsable de estación',
  _ => 'Conductor',
};
String statusLabel(String? s) => switch (s) {
  'disponible' => 'Disponible',
  'limitada' => 'Disponibilidad limitada',
  'agotado' => 'Agotado',
  _ => 'Sin actualizar',
};
String fuelShort(String s) =>
    s.replaceFirst('Gasolina ', '').replaceFirst('Super Etanol ', 'Etanol ');
String dateLabel(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Sin publicaciones';
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
}
