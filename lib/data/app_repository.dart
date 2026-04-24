import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../models/review.dart';
import 'mock_crashpad_data.dart';

/// In-memory data source used to simulate authentication, listings,
/// reviews and theming state for the demo experience.
class AppRepository extends ChangeNotifier {
  AppRepository() {
    _seedData();
  }

  final Uuid _uuid = const Uuid();
  final List<AppUser> _users = [];
  final List<Crashpad> _crashpads = [];
  final List<BookingRecord> _bookings = [];
  final Map<String, List<Review>> _reviewsByCrashpad = {};
  AppUser? _currentUser;
  bool _isDarkTheme = true;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isDarkTheme => _isDarkTheme;

  List<Crashpad> get crashpads => List.unmodifiable(_crashpads);
  List<BookingRecord> get bookings => List.unmodifiable(_bookings);

  /// Dark mode is now the only supported product theme.
  void toggleTheme() {
    _isDarkTheme = true;
    notifyListeners();
  }

  /// Preserved for old callers while keeping the app dark-only.
  void setTheme(bool isDark) {
    _isDarkTheme = true;
    notifyListeners();
  }

  bool userExists(String email) =>
      _users.any((user) => user.email.toLowerCase() == email.toLowerCase());

  /// Authenticates a user with the provided credentials.
  Future<void> logIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final user = _users.firstWhere(
      (candidate) => candidate.email.toLowerCase() == email.toLowerCase(),
      orElse: () => throw AuthException('Account not found'),
    );

    if (user.password != password) {
      throw AuthException('Incorrect password');
    }
    _currentUser = user;
    notifyListeners();
  }

  /// Signs out the active user.
  Future<void> logOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
    notifyListeners();
  }

  /// Registers a new account and authenticates the user on success.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String countryOfBirth,
    required DateTime dateOfBirth,
    required AppUserType userType,
    String? company,
    String? badgeNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final alreadyExists = _users.any(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
    if (alreadyExists) {
      throw AuthException('An account with this email already exists');
    }

    final newUser = AppUser(
      id: _uuid.v4(),
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      countryOfBirth: countryOfBirth,
      dateOfBirth: dateOfBirth,
      userType: userType,
      company: company,
      badgeNumber: badgeNumber,
    );
    _users.add(newUser);
    _currentUser = newUser;
    notifyListeners();
  }

  /// Returns the list of available crashpads.
  Future<List<Crashpad>> fetchCrashpads() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_crashpads);
  }

  /// Fetches listings owned by the provided email.
  Future<List<Crashpad>> fetchOwnerCrashpads(String ownerEmail) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _crashpads
        .where((crashpad) =>
            crashpad.owner.contact?.toLowerCase() == ownerEmail.toLowerCase())
        .toList();
  }

  Future<List<BookingRecord>> fetchGuestBookings(String guestEmail) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _bookings
        .where(
          (booking) =>
              booking.guestEmail.toLowerCase() == guestEmail.toLowerCase(),
        )
        .toList();
  }

  Future<List<BookingRecord>> fetchOwnerBookings(String ownerEmail) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _bookings
        .where(
          (booking) =>
              booking.ownerEmail.toLowerCase() == ownerEmail.toLowerCase(),
        )
        .toList();
  }

  /// Creates a new crashpad owned by the authenticated owner.
  Future<void> addCrashpad({
    required String name,
    required String description,
    required String location,
    required String nearestAirport,
    required String bedType,
    required double price,
    required List<String> imageUrls,
    required List<CrashpadRoom> rooms,
    required List<String> amenities,
    required List<String> houseRules,
    List<CrashpadService> services = const <CrashpadService>[],
    List<CrashpadCheckoutCharge> checkoutCharges =
        const <CrashpadCheckoutCharge>[],
    int minimumStayNights = 1,
    double? distanceToAirportMiles,
  }) async {
    final owner = _currentUser;
    if (owner == null || !owner.isOwner) {
      throw AuthException('Only authenticated owners can create listings.');
    }
    if (rooms.isEmpty) {
      throw ArgumentError('At least one room is required.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final newCrashpad = Crashpad(
      id: _uuid.v4(),
      name: name,
      description: description,
      location: location,
      nearestAirport: nearestAirport,
      owner: Owner(name: owner.displayName, contact: owner.email),
      imageUrls: imageUrls,
      dateAdded: DateTime.now(),
      bedType: bedType,
      price: price,
      clickCount: 0,
      rooms: rooms,
      amenities: amenities,
      houseRules: houseRules,
      services: services,
      checkoutCharges: checkoutCharges,
      minimumStayNights: minimumStayNights,
      distanceToAirportMiles: distanceToAirportMiles,
    );
    _crashpads.insert(0, newCrashpad);
    notifyListeners();
  }

  /// Deletes multiple crashpads and their reviews.
  Future<void> deleteCrashpads(Set<String> crashpadIds) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _crashpads.removeWhere((crashpad) => crashpadIds.contains(crashpad.id));
    _bookings
        .removeWhere((booking) => crashpadIds.contains(booking.crashpadId));
    for (final id in crashpadIds) {
      _reviewsByCrashpad.remove(id);
    }
    notifyListeners();
  }

  Future<BookingRecord> createBooking({
    required Crashpad crashpad,
    required BookingDraft draft,
    required PaymentSummary paymentSummary,
  }) async {
    final guest = _currentUser;
    if (guest == null || !guest.isEmployee) {
      throw AuthException('Only authenticated crew members can book stays.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final capturedPayment = paymentSummary.copyWith(status: PaymentStatus.paid);
    final booking = BookingRecord(
      id: _uuid.v4(),
      crashpadId: crashpad.id,
      crashpadName: crashpad.name,
      ownerEmail: crashpad.owner.contact ?? '',
      guestId: guest.id,
      guestName: guest.displayName,
      guestEmail: guest.email,
      nights: draft.nights,
      guestCount: draft.guestCount,
      paymentSummary: capturedPayment,
      createdAt: DateTime.now(),
      status: BookingStatus.confirmed,
    );
    _bookings.insert(0, booking);
    notifyListeners();
    return booking;
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) return;
    _bookings[index] = _bookings[index].copyWith(status: status);
    notifyListeners();
  }

  /// Records a click on the provided crashpad identifier.
  Future<void> incrementClickCount(String crashpadId) async {
    final index =
        _crashpads.indexWhere((crashpad) => crashpad.id == crashpadId);
    if (index == -1) return;
    final updated = _crashpads[index]
        .copyWith(clickCount: _crashpads[index].clickCount + 1);
    _crashpads[index] = updated;
    notifyListeners();
  }

  /// Retrieves reviews for the given crashpad.
  Future<List<Review>> fetchReviews(String crashpadId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_reviewsByCrashpad[crashpadId] ?? []);
  }

  /// Persists a new review for the supplied crashpad.
  Future<void> addReview({
    required String crashpadId,
    required String employeeName,
    required String comment,
    required double rating,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final review = Review(
      employeeName: employeeName,
      comment: comment,
      rating: rating,
      createdAt: DateTime.now(),
    );
    _reviewsByCrashpad.putIfAbsent(crashpadId, () => []).add(review);
    notifyListeners();
  }

  /// Marks the active user as subscribed to premium features.
  Future<void> subscribeCurrentUser() async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to subscribe.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _users.indexWhere((user) => user.id == current.id);
    if (index == -1) return;
    final updated = current.copyWith(isSubscribed: true);
    _users[index] = updated;
    if (identical(_currentUser, current)) {
      _currentUser = updated;
    }
    notifyListeners();
  }

  /// Updates the avatar for the authenticated user.
  Future<void> updateProfileAvatar(String base64Image) async {
    final current = _currentUser;
    if (current == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final updated = current.copyWith(avatarBase64: base64Image);
    final index = _users.indexWhere((user) => user.id == current.id);
    if (index != -1) {
      _users[index] = updated;
    }
    _currentUser = updated;
    notifyListeners();
  }

  double calculateAverageRating(String crashpadId) {
    final reviews = _reviewsByCrashpad[crashpadId];
    if (reviews == null || reviews.isEmpty) return 0.0;
    final total = reviews.fold<double>(
      0.0,
      (sum, review) => sum + review.rating,
    );
    return total / reviews.length;
  }

  void _seedData() {
    final users = MockCrashpadSeed.users(_uuid);
    final owner = users.firstWhere((user) => user.isOwner);

    _users
      ..clear()
      ..addAll(users);

    _currentUser = null;

    _crashpads
      ..clear()
      ..addAll(
        MockCrashpadSeed.crashpads(
          _uuid,
          Owner(name: owner.displayName, contact: owner.email),
        ),
      );

    _reviewsByCrashpad
      ..clear()
      ..addAll(MockCrashpadSeed.reviewsByCrashpad(_crashpads));

    _bookings.clear();
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => jsonEncode({'message': message});
}
