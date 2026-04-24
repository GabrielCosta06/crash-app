import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../models/review.dart';

/// Supabase-ready contract for replacing the current in-memory demo auth.
///
/// The project does not currently include `supabase_flutter`, so this contract
/// intentionally avoids importing Supabase classes. A future adapter can map
/// Supabase Auth sessions into [AppUser] without changing UI widgets.
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

/// Supabase-ready data access boundary for marketplace and owner workflows.
abstract class CrashpadGateway {
  Future<List<Crashpad>> fetchCrashpads();

  Future<List<Crashpad>> fetchOwnerCrashpads(String ownerId);

  Future<Crashpad> createCrashpad(Crashpad crashpad);

  Future<void> deleteCrashpads(Set<String> crashpadIds);

  Future<List<Review>> fetchReviews(String crashpadId);
}
