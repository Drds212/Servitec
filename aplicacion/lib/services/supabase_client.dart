import 'package:supabase_flutter/supabase_flutter.dart';

const SUPABASE_URL = 'https://tyacsmgagiisodzrmuxj.supabase.co';
const SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5YWNzbWdhZ2lpc29kenJtdXhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MzI0MzQsImV4cCI6MjA3NTQwODQzNH0.iu6E5jNxKw4YKajXXnPPEtW3SFAF_U_a4PkQfEDyHmQ';

// Cliente Supabase global para acceder fácilmente desde cualquier parte
// Solo se inicializará una vez en main.dart
final supabase = Supabase.instance.client;
