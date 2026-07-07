class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hrhdddtwnnipodqiszbo.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_wKLJpkV4RSgV300CpVPgww_SOz-RRQq',
  );
}
