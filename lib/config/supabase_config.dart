class SupabaseConfig {
  // Fill these in from your Supabase project:
  // Dashboard → Settings → API → Project URL / anon public key
  static const String url     = 'https://qidhhjzospwfjoboidse.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpZGhoanpvc3B3ZmpvYm9pZHNlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMDA2NTIsImV4cCI6MjA5Mjc3NjY1Mn0.Mm-h9BE9NzsxB3lkFzOBofAL6eEMuCoeefsqcxGOCl8';

  // Storage bucket names — create these in Supabase Dashboard → Storage
  static const String memoriesBucket = 'memories';
  static const String avatarsBucket  = 'avatars';
}
