abstract final class SupabaseConfig {
  // Esta clave es pública. Los permisos se controlan mediante RLS y funciones.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oejouwwxngyafftzfkux.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_L9O4WSZeVF2O-_F9-XvAag_yDxyI8Rb',
  );
}
