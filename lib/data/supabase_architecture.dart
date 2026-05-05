import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../models/review.dart';

/// Contract for Supabase-backed authentication.
///
/// The app repository now uses `supabase_flutter` directly, but this boundary
/// remains useful for future adapter-based tests or service extraction.
abstract class AuthGateway {
  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required AppUserType userType,
  });

  Future<void> signOut();
}

/// Data access boundary for marketplace and owner workflows.
abstract class CrashpadGateway {
  Future<List<Crashpad>> fetchCrashpads();

  Future<List<Crashpad>> fetchOwnerCrashpads(String ownerId);

  Future<Crashpad> createCrashpad(Crashpad crashpad);

  Future<void> deleteCrashpads(Set<String> crashpadIds);

  Future<List<Review>> fetchReviews(String crashpadId);
}
