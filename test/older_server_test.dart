// A snapshot part is skipped only when the server really doesn't have it
// yet; a network hiccup fails the refresh instead (the screen keeps what it
// had: no photos lost, no switches flipping).
import 'package:drivetalk/real/supabase_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('only a missing part counts as an older server', () {
    bool older(Object e) => SupabaseRealBackend.isOlderServer(e);
    PostgrestException pg(String code) =>
        PostgrestException(message: 'x', code: code);
    for (final code in ['42703', '42P01', '42883', 'PGRST200', 'PGRST202']) {
      expect(older(pg(code)), isTrue, reason: code);
    }
    expect(older(pg('PGRST205')), isTrue);
    expect(
      older(
        const PostgrestException(
          message: 'Could not find the function public.my_pauses',
        ),
      ),
      isTrue,
    );
    // No permission, sign-in expired, server busy, no network: not older.
    for (final code in ['42501', 'PGRST301', '503', '57014']) {
      expect(older(pg(code)), isFalse, reason: code);
    }
    expect(older(Exception('SocketException: Failed host lookup')), isFalse);
    expect(older(const AuthException('expired')), isFalse);
  });
}
