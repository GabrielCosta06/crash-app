import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../models/review.dart';
import '../models/message_thread.dart';
import '../services/availability_service.dart';
import '../services/payment_service.dart';
import 'supabase_mappers.dart';

/// Repository facade used by the UI.
///
/// Production callers must provide a Supabase client so first-user data is
/// always persisted. Tests can use [AppRepository.testSeeded] with fixtures.
class AppRepository extends ChangeNotifier {
  AppRepository({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient {
    _hydrateSupabaseSessionUser();
  }

  AppRepository.testSeeded({required AppRepositorySeed seed})
      : _supabase = null {
    _seedData(seed);
  }

  final Uuid _uuid = const Uuid();
  final SupabaseClient? _supabase;
  final List<AppUser> _users = [];
  final List<Crashpad> _crashpads = [];
  final List<BookingRecord> _bookings = [];
  final Map<String, List<Review>> _reviewsByCrashpad = {};
  final List<MessageThread> _messageThreads = [];
  final AvailabilityService _availabilityService = const AvailabilityService();
  final PaymentService _paymentService = const PaymentService();
  AppUser? _currentUser;
  bool _isDarkTheme = true;

  bool get _usesSupabase => _supabase != null;
  SupabaseClient get _client => _supabase!;
  bool get usesSupabase => _usesSupabase;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isDarkTheme => _isDarkTheme;

  List<Crashpad> get crashpads => List.unmodifiable(_crashpads);
  List<BookingRecord> get bookings => List.unmodifiable(_bookings);
  List<MessageThread> get messageThreads => List.unmodifiable(_messageThreads);
  List<MessageThread> get currentUserMessageThreads {
    final user = _currentUser;
    if (user == null) return const <MessageThread>[];
    final threads = _messageThreads
        .where((thread) => thread.includesUser(user.id))
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return List.unmodifiable(threads);
  }

  Future<void> initialize() async {
    if (!_usesSupabase) return;
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    try {
      _currentUser = await _fetchProfile(authUser.id);
      await Future.wait(<Future<void>>[
        _refreshCrashpads(),
        _refreshBookings(),
        _refreshMessageThreads(),
      ]);
      notifyListeners();
    } catch (_) {
      await _client.auth.signOut();
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> refreshAccountState() async {
    if (!_usesSupabase) return;
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    _currentUser = await _fetchProfile(authUser.id);
    await Future.wait(<Future<void>>[
      _refreshBookings(),
      _refreshMessageThreads(),
    ]);
    notifyListeners();
  }

  void _hydrateSupabaseSessionUser() {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    _currentUser = AppUser(
      id: authUser.id,
      email: authUser.email ?? '',
      password: '',
      firstName: metadata['first_name']?.toString() ?? '',
      lastName: metadata['last_name']?.toString() ?? '',
      countryOfBirth: metadata['country_of_birth']?.toString() ?? '',
      dateOfBirth: DateTime.tryParse(
            metadata['date_of_birth']?.toString() ?? '',
          ) ??
          DateTime(1990),
      userType: metadata['user_type']?.toString() == AppUserType.owner.name
          ? AppUserType.owner
          : AppUserType.employee,
      company: metadata['company']?.toString(),
      badgeNumber: metadata['badge_number']?.toString(),
    );
  }

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

  bool userExists(String email) {
    if (_usesSupabase) return true;
    return _users.any(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
  }

  /// Authenticates a user with the provided credentials.
  Future<void> logIn(String email, String password) async {
    if (_usesSupabase) {
      try {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final userId = response.user?.id;
        if (userId == null) throw AuthException('Account not found');
        _currentUser = await _fetchProfile(userId);
        await Future.wait(<Future<void>>[
          _refreshCrashpads(),
          _refreshBookings(),
          _refreshMessageThreads(),
        ]);
        notifyListeners();
        return;
      } on AuthException {
        rethrow;
      } catch (_) {
        throw AuthException('Incorrect password');
      }
    }

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
    if (_usesSupabase) {
      await _client.auth.signOut();
      _currentUser = null;
      _bookings.clear();
      _messageThreads.clear();
      notifyListeners();
      return;
    }

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
    if (_usesSupabase) {
      try {
        final response = await _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: <String, dynamic>{
            'first_name': firstName,
            'last_name': lastName,
            'country_of_birth': countryOfBirth,
            'date_of_birth': dateOfBirth.toIso8601String(),
            'user_type': userType.name,
            'company': company,
            'badge_number': badgeNumber,
          },
        );
        final authUser = response.user;
        if (authUser == null) {
          throw AuthException('Could not create account.');
        }
        final newUser = AppUser(
          id: authUser.id,
          email: email.trim(),
          password: '',
          firstName: firstName,
          lastName: lastName,
          countryOfBirth: countryOfBirth,
          dateOfBirth: dateOfBirth,
          userType: userType,
          company: company,
          badgeNumber: badgeNumber,
        );
        await _client.from('profiles').upsert(profileToRow(newUser));
        _currentUser = newUser;
        await _refreshCrashpads();
        notifyListeners();
        return;
      } catch (error) {
        throw AuthException('Could not create account: $error');
      }
    }

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
    if (_usesSupabase) {
      await _refreshCrashpads();
      return List.unmodifiable(_crashpads);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_crashpads);
  }

  /// Fetches listings owned by the provided email.
  Future<List<Crashpad>> fetchOwnerCrashpads(String ownerEmail) async {
    if (_usesSupabase) {
      await _refreshCrashpads();
      return _crashpads
          .where(
            (crashpad) =>
                crashpad.owner.contact?.toLowerCase() ==
                ownerEmail.toLowerCase(),
          )
          .toList();
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _crashpads
        .where((crashpad) =>
            crashpad.owner.contact?.toLowerCase() == ownerEmail.toLowerCase())
        .toList();
  }

  Future<List<BookingRecord>> fetchGuestBookings(String guestEmail) async {
    if (_usesSupabase) {
      await _refreshBookings();
      return _bookings
          .where(
            (booking) =>
                booking.guestEmail.toLowerCase() == guestEmail.toLowerCase(),
          )
          .toList();
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _bookings
        .where(
          (booking) =>
              booking.guestEmail.toLowerCase() == guestEmail.toLowerCase(),
        )
        .toList();
  }

  Future<List<BookingRecord>> fetchOwnerBookings(String ownerEmail) async {
    if (_usesSupabase) {
      await _refreshBookings();
      return _bookings
          .where(
            (booking) =>
                booking.ownerEmail.toLowerCase() == ownerEmail.toLowerCase(),
          )
          .toList();
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _bookings
        .where(
          (booking) =>
              booking.ownerEmail.toLowerCase() == ownerEmail.toLowerCase(),
        )
        .toList();
  }

  Crashpad? findCrashpadById(String crashpadId) {
    for (final crashpad in _crashpads) {
      if (crashpad.id == crashpadId) return crashpad;
    }
    return null;
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
    double? latitude,
    double? longitude,
  }) async {
    final owner = _currentUser;
    if (owner == null || !owner.isOwner) {
      throw AuthException('Only authenticated owners can create listings.');
    }
    if (rooms.isEmpty) {
      throw ArgumentError('At least one room is required.');
    }
    if (_usesSupabase) {
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
        latitude: latitude,
        longitude: longitude,
      );
      await _client
          .from('listings')
          .insert(crashpadToRow(newCrashpad, owner.id));
      _crashpads.insert(0, newCrashpad);
      notifyListeners();
      return;
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
      latitude: latitude,
      longitude: longitude,
    );
    _crashpads.insert(0, newCrashpad);
    notifyListeners();
  }

  ListingDeletionImpact bookingImpactForListingDeletion(
    Set<String> crashpadIds,
  ) {
    final affected = _bookings
        .where((booking) => crashpadIds.contains(booking.crashpadId))
        .toList();
    return ListingDeletionImpact(
      selectedListingCount: crashpadIds.length,
      pendingCount: affected
          .where((booking) => booking.status == BookingStatus.pending)
          .length,
      confirmedCount: affected
          .where((booking) => booking.status == BookingStatus.confirmed)
          .length,
      activeCount: affected
          .where((booking) => booking.status == BookingStatus.active)
          .length,
      completedCount: affected
          .where((booking) => booking.status == BookingStatus.completed)
          .length,
      cancelledCount: affected
          .where((booking) => booking.status == BookingStatus.cancelled)
          .length,
    );
  }

  /// Deletes owner listings only when no live bookings would be orphaned.
  Future<void> deleteCrashpads(Set<String> crashpadIds) async {
    final owner = _requireOwner();
    final selected = _crashpads
        .where((crashpad) => crashpadIds.contains(crashpad.id))
        .toList();
    if (selected.length != crashpadIds.length) {
      throw StateError('One or more listings could not be found.');
    }
    for (final crashpad in selected) {
      if (crashpad.owner.contact?.toLowerCase() != owner.email.toLowerCase()) {
        throw AuthException('You can only delete listings you own.');
      }
    }
    final impact = bookingImpactForListingDeletion(crashpadIds);
    if (!impact.canDelete) {
      throw StateError(
        'Resolve pending, confirmed, or active bookings before deleting.',
      );
    }
    if (_usesSupabase) {
      await _client
          .from('listings')
          .delete()
          .inFilter('id', crashpadIds.toList());
      _crashpads.removeWhere((crashpad) => crashpadIds.contains(crashpad.id));
      for (final id in crashpadIds) {
        _reviewsByCrashpad.remove(id);
      }
      notifyListeners();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    _crashpads.removeWhere((crashpad) => crashpadIds.contains(crashpad.id));
    for (final id in crashpadIds) {
      _reviewsByCrashpad.remove(id);
    }
    notifyListeners();
  }

  Future<Crashpad> updateCrashpad(Crashpad updatedCrashpad) async {
    final owner = _currentUser;
    if (owner == null || !owner.isOwner) {
      throw AuthException('Only authenticated owners can edit listings.');
    }
    final index = _crashpads.indexWhere(
      (crashpad) => crashpad.id == updatedCrashpad.id,
    );
    if (index == -1) {
      throw StateError('Listing not found.');
    }
    final existing = _crashpads[index];
    if (existing.owner.contact?.toLowerCase() != owner.email.toLowerCase()) {
      throw AuthException('You can only edit listings you own.');
    }
    canEditListingWithoutConflicts(updatedCrashpad);
    if (_usesSupabase) {
      final saved = updatedCrashpad.copyWith(
        owner: Owner(name: owner.displayName, contact: owner.email),
      );
      await _client
          .from('listings')
          .update(
            crashpadToRow(saved, owner.id)..remove('id'),
          )
          .eq('id', saved.id);
      _crashpads[index] = saved;
      notifyListeners();
      return saved;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    _crashpads[index] = updatedCrashpad.copyWith(
      owner: Owner(name: owner.displayName, contact: owner.email),
    );
    notifyListeners();
    return _crashpads[index];
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
    if (!draft.checkOutDate.isAfter(draft.checkInDate)) {
      throw ArgumentError(
        'Booking request needs a check-out date after check-in.',
      );
    }
    if (draft.crashpadId != crashpad.id) {
      throw ArgumentError('Booking request does not match this listing.');
    }
    if (draft.guestId != guest.id) {
      throw AuthException('You can only create bookings for your account.');
    }
    if (draft.guestCount < 1) {
      throw ArgumentError('Booking request needs at least one guest.');
    }
    if (draft.nights < crashpad.minimumStayNights) {
      throw ArgumentError(
        'This listing requires at least ${crashpad.minimumStayNights} nights.',
      );
    }
    if (_reservableCapacity(crashpad, draft.checkInDate, draft.checkOutDate) <
        draft.guestCount) {
      throw StateError('This listing does not have enough availability.');
    }
    final ownerEmail = crashpad.owner.contact;
    if (ownerEmail == null || ownerEmail.trim().isEmpty) {
      throw StateError('This listing is missing owner contact information.');
    }
    if (_usesSupabase) {
      final booking = BookingRecord(
        id: _uuid.v4(),
        crashpadId: crashpad.id,
        crashpadName: crashpad.name,
        ownerEmail: ownerEmail,
        guestId: guest.id,
        guestName: guest.displayName,
        guestEmail: guest.email,
        checkInDate: draft.checkInDate,
        checkOutDate: draft.checkOutDate,
        guestCount: draft.guestCount,
        paymentSummary: paymentSummary.copyWith(status: PaymentStatus.draft),
        createdAt: DateTime.now(),
        status: BookingStatus.pending,
      );
      await _client.from('bookings').insert(bookingToRow(booking));
      _bookings.insert(0, booking);
      notifyListeners();
      return booking;
    }

    await Future<void>.delayed(const Duration(milliseconds: 240));
    final bookingPayment = paymentSummary.copyWith(status: PaymentStatus.draft);
    final booking = BookingRecord(
      id: _uuid.v4(),
      crashpadId: crashpad.id,
      crashpadName: crashpad.name,
      ownerEmail: ownerEmail,
      guestId: guest.id,
      guestName: guest.displayName,
      guestEmail: guest.email,
      checkInDate: draft.checkInDate,
      checkOutDate: draft.checkOutDate,
      guestCount: draft.guestCount,
      paymentSummary: bookingPayment,
      createdAt: DateTime.now(),
      status: BookingStatus.pending,
    );
    _bookings.insert(0, booking);
    notifyListeners();
    return booking;
  }

  Future<void> approveBooking(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final owner = _requireOwner();
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    _ensureOwnerCanManage(owner, booking);
    if (booking.status != BookingStatus.pending) {
      throw StateError('This booking cannot move to awaiting payment.');
    }
    final updated = booking.copyWith(
      status: BookingStatus.awaitingPayment,
      paymentSummary:
          _paymentService.markAwaitingPayment(booking.paymentSummary),
    );
    _bookings[index] = updated;
    await _persistBooking(updated);
    notifyListeners();
  }

  Future<void> declineBooking(String bookingId) async {
    await _ownerCancel(bookingId, allowedStatuses: const <BookingStatus>{
      BookingStatus.pending,
    });
  }

  Future<void> checkInBooking(String bookingId) async {
    await _ownerTransition(
      bookingId: bookingId,
      from: BookingStatus.confirmed,
      to: BookingStatus.active,
    );
  }

  Future<void> cancelBooking(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to cancel a booking.');
    }
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    final allowedStatuses = <BookingStatus>{
      BookingStatus.pending,
      BookingStatus.awaitingPayment,
      BookingStatus.confirmed,
    };
    if (!allowedStatuses.contains(booking.status)) {
      throw StateError('Only pending or confirmed bookings can be cancelled.');
    }
    if (current.isOwner) {
      _ensureOwnerCanManage(current, booking);
    } else if (current.isEmployee) {
      if (booking.guestEmail.toLowerCase() != current.email.toLowerCase()) {
        throw AuthException('You can only cancel your own bookings.');
      }
      _ensureGuestCancellationWindow(booking);
    } else {
      throw AuthException('This account cannot cancel bookings.');
    }
    _bookings[index] = _cancelledBooking(booking);
    await _persistBooking(_bookings[index]);
    notifyListeners();
  }

  Future<void> assessCheckoutCharges({
    required String bookingId,
    required List<ChargeLineItem> charges,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final owner = _requireOwner();
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    _ensureOwnerCanManage(owner, booking);
    if (booking.status != BookingStatus.active) {
      throw StateError('Checkout charges can only be assessed during a stay.');
    }
    _bookings[index] = booking.copyWith(
      paymentSummary: _paymentService.assessCheckoutCharges(
        booking.paymentSummary,
        charges,
      ),
      checkoutChargePaymentStatus:
          charges.isEmpty ? PaymentStatus.draft : PaymentStatus.awaitingPayment,
    );
    await _persistBooking(_bookings[index]);
    notifyListeners();
  }

  Future<void> assignBookingBed({
    required String bookingId,
    required String roomId,
    String? bedId,
    String assignmentNote = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final owner = _requireOwner();
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    _ensureOwnerCanManage(owner, booking);
    if (booking.status != BookingStatus.confirmed &&
        booking.status != BookingStatus.active) {
      throw StateError(
        'Manual assignment is only available for confirmed or active stays.',
      );
    }
    final crashpad = findCrashpadById(booking.crashpadId);
    if (crashpad == null) {
      throw StateError('Listing not found for this booking.');
    }
    final room = crashpad.rooms.cast<CrashpadRoom?>().firstWhere(
          (candidate) => candidate?.id == roomId,
          orElse: () => null,
        );
    if (room == null) {
      throw StateError('Selected room is not part of this listing.');
    }

    CrashpadBed? bed;
    if (room.bedModel == CrashpadBedModel.cold) {
      if (bedId == null || bedId.trim().isEmpty) {
        throw StateError('Cold-bed assignments require a specific bed.');
      }
      bed = room.beds.cast<CrashpadBed?>().firstWhere(
            (candidate) => candidate?.id == bedId,
            orElse: () => null,
          );
      if (bed == null) {
        throw StateError('Selected bed is not part of this room.');
      }
      if (bed.isAssigned || !bed.isAvailable) {
        throw StateError('Selected cold bed is not available for assignment.');
      }
    } else if (bedId != null && bedId.trim().isNotEmpty) {
      bed = room.beds.cast<CrashpadBed?>().firstWhere(
            (candidate) => candidate?.id == bedId,
            orElse: () => null,
          );
      if (bed == null) {
        throw StateError('Selected bed is not part of this room.');
      }
    }

    _bookings[index] = booking.copyWith(
      assignedRoomId: room.id,
      assignedRoomName: room.name,
      assignedBedId: bed?.id,
      assignedBedLabel: bed?.label,
      assignmentNote:
          assignmentNote.trim().isEmpty ? null : assignmentNote.trim(),
    );
    await _persistBooking(_bookings[index]);
    notifyListeners();
  }

  Future<void> submitCheckoutReport({
    required String bookingId,
    required String notes,
    required List<CheckoutPhoto> photos,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final guest = _currentUser;
    if (guest == null || !guest.isEmployee) {
      throw AuthException('Only guests can submit checkout reports.');
    }
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    if (booking.guestEmail.toLowerCase() != guest.email.toLowerCase()) {
      throw AuthException('You can only update your own checkout report.');
    }
    if (booking.status != BookingStatus.confirmed &&
        booking.status != BookingStatus.active) {
      throw StateError(
        'Checkout reports can only be submitted for confirmed or active stays.',
      );
    }
    if (notes.trim().isEmpty && photos.isEmpty) {
      throw ArgumentError('Add a note or photo before submitting checkout.');
    }
    _bookings[index] = booking.copyWith(
      checkoutReport: CheckoutReport(
        notes: notes.trim(),
        photos: List.unmodifiable(photos),
        submittedAt: DateTime.now(),
      ),
    );
    await _persistBooking(_bookings[index]);
    notifyListeners();
  }

  Future<void> completeBooking({
    required String bookingId,
    List<ChargeLineItem> checkoutCharges = const <ChargeLineItem>[],
    String ownerCheckoutNote = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final owner = _requireOwner();
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    _ensureOwnerCanManage(owner, booking);
    if (booking.status != BookingStatus.active) {
      throw StateError('Only checked-in bookings can be completed.');
    }
    _validateCheckoutEvidence(
      booking: booking,
      checkoutCharges: checkoutCharges,
      ownerCheckoutNote: ownerCheckoutNote,
    );
    final assessed = _paymentService.assessCheckoutCharges(
      booking.paymentSummary,
      checkoutCharges,
    );
    if (checkoutCharges.isNotEmpty) {
      _bookings[index] = booking.copyWith(
        paymentSummary: assessed,
        checkoutChargePaymentStatus: PaymentStatus.awaitingPayment,
        ownerCheckoutNote:
            ownerCheckoutNote.trim().isEmpty ? null : ownerCheckoutNote.trim(),
      );
      await _persistBooking(_bookings[index]);
      notifyListeners();
      return;
    }
    final paid = _paymentService.markPaid(assessed);
    _bookings[index] = booking.copyWith(
      status: BookingStatus.completed,
      paymentSummary: paid,
      checkoutChargePaymentStatus: PaymentStatus.draft,
      ownerCheckoutNote:
          ownerCheckoutNote.trim().isEmpty ? null : ownerCheckoutNote.trim(),
    );
    await _persistBooking(_bookings[index]);
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
    if (_usesSupabase) {
      await _client
          .from('listings')
          .update(<String, dynamic>{'click_count': updated.clickCount}).eq(
              'id', crashpadId);
    }
    notifyListeners();
  }

  /// Retrieves reviews for the given crashpad.
  Future<List<Review>> fetchReviews(String crashpadId) async {
    if (_usesSupabase) {
      final rows = await _client
          .from('reviews')
          .select()
          .eq('crashpad_id', crashpadId)
          .order('created_at', ascending: false);
      final reviews = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(reviewFromRow)
          .toList();
      _reviewsByCrashpad[crashpadId] = reviews;
      return List.unmodifiable(reviews);
    }
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
    final guest = _currentUser;
    if (guest == null || !guest.isEmployee) {
      throw AuthException('Only authenticated guests can write reviews.');
    }
    if (!hasCompletedStayForReview(
      crashpadId: crashpadId,
      guestEmail: guest.email,
    )) {
      throw AuthException(
        'You can review this crashpad after completing a confirmed stay.',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final review = Review(
      employeeName: guest.displayName,
      comment: comment,
      rating: rating,
      createdAt: DateTime.now(),
    );
    _reviewsByCrashpad.putIfAbsent(crashpadId, () => []).add(review);
    if (_usesSupabase) {
      await _client.from('reviews').insert(<String, dynamic>{
        'id': _uuid.v4(),
        'crashpad_id': crashpadId,
        'employee_id': guest.id,
        'employee_name': guest.displayName,
        'comment': comment,
        'rating': rating,
      });
    }
    notifyListeners();
  }

  bool hasCompletedStayForReview({
    required String crashpadId,
    required String guestEmail,
  }) {
    return _bookings.any(
      (booking) =>
          booking.crashpadId == crashpadId &&
          booking.guestEmail.toLowerCase() == guestEmail.toLowerCase() &&
          booking.status == BookingStatus.completed &&
          booking.paymentSummary.status == PaymentStatus.paid,
    );
  }

  int availableCapacityForDates({
    required Crashpad crashpad,
    required DateTime checkInDate,
    required DateTime checkOutDate,
  }) {
    return _reservableCapacity(crashpad, checkInDate, checkOutDate);
  }

  void canEditListingWithoutConflicts(Crashpad updatedCrashpad) {
    final related = _bookings
        .where(
          (booking) =>
              booking.crashpadId == updatedCrashpad.id &&
              _reservesCapacity(booking.status),
        )
        .toList();
    for (final booking in related) {
      final overlappingGuests = _reservedGuestsForDates(
        crashpadId: updatedCrashpad.id,
        checkInDate: booking.checkInDate,
        checkOutDate: booking.checkOutDate,
      );
      final staticCapacity =
          _availabilityService.summarize(updatedCrashpad).availableToBook;
      if (staticCapacity < overlappingGuests) {
        throw StateError(
          'This edit would reduce capacity below existing live bookings.',
        );
      }
      final nights =
          booking.checkOutDate.difference(booking.checkInDate).inDays;
      if (nights < updatedCrashpad.minimumStayNights) {
        throw StateError(
          'This edit would make an existing booking shorter than the minimum stay.',
        );
      }
    }
  }

  Future<MessageThread> startMessageThread({
    required String crashpadId,
    required String text,
  }) async {
    final guest = _currentUser;
    if (guest == null || !guest.isEmployee) {
      throw AuthException('Only authenticated guests can message owners.');
    }
    final crashpad = findCrashpadById(crashpadId);
    if (crashpad == null) {
      throw StateError('Listing not found.');
    }
    final ownerEmail = crashpad.owner.contact;
    final owner = ownerEmail == null
        ? null
        : _usesSupabase
            ? await _fetchProfileByEmail(ownerEmail)
            : _users.cast<AppUser?>().firstWhere(
                  (user) =>
                      user?.email.toLowerCase() == ownerEmail.toLowerCase(),
                  orElse: () => null,
                );
    if (owner == null) {
      throw StateError('This listing owner cannot receive messages.');
    }
    if (text.trim().isEmpty) {
      throw ArgumentError('Add a message before sending.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final existingIndex = _messageThreads.indexWhere(
      (thread) => thread.crashpadId == crashpadId && thread.guestId == guest.id,
    );
    if (existingIndex != -1) {
      return sendMessage(
        threadId: _messageThreads[existingIndex].id,
        text: text,
      );
    }
    final now = DateTime.now();
    if (_usesSupabase) {
      final threadId = _uuid.v4();
      final messageId = _uuid.v4();
      await _client.from('message_threads').insert(<String, dynamic>{
        'id': threadId,
        'crashpad_id': crashpad.id,
        'crashpad_name': crashpad.name,
        'guest_id': guest.id,
        'owner_id': owner.id,
        'last_activity': now.toIso8601String(),
      });
      await _client.from('messages').insert(<String, dynamic>{
        'id': messageId,
        'thread_id': threadId,
        'sender_id': guest.id,
        'body': text.trim(),
        'created_at': now.toIso8601String(),
      });
      final thread = MessageThread(
        id: threadId,
        crashpadId: crashpad.id,
        crashpadName: crashpad.name,
        guestId: guest.id,
        ownerId: owner.id,
        lastActivity: now,
        messages: <ChatMessage>[
          ChatMessage(
            id: messageId,
            senderId: guest.id,
            text: text.trim(),
            createdAt: now,
          ),
        ],
      );
      _messageThreads.insert(0, thread);
      notifyListeners();
      return thread;
    }

    final thread = MessageThread(
      id: _uuid.v4(),
      crashpadId: crashpad.id,
      crashpadName: crashpad.name,
      guestId: guest.id,
      ownerId: owner.id,
      lastActivity: now,
      messages: <ChatMessage>[
        ChatMessage(
          id: _uuid.v4(),
          senderId: guest.id,
          text: text.trim(),
          createdAt: now,
        ),
      ],
    );
    _messageThreads.insert(0, thread);
    notifyListeners();
    return thread;
  }

  Future<MessageThread> sendMessage({
    required String threadId,
    required String text,
  }) async {
    final sender = _currentUser;
    if (sender == null) {
      throw AuthException('You must be logged in to send messages.');
    }
    if (text.trim().isEmpty) {
      throw ArgumentError('Add a message before sending.');
    }
    final index = _messageThreads.indexWhere((thread) => thread.id == threadId);
    if (index == -1) {
      throw StateError('Message thread not found.');
    }
    final thread = _messageThreads[index];
    if (!thread.includesUser(sender.id)) {
      throw AuthException('You can only reply to your message threads.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final now = DateTime.now();
    if (_usesSupabase) {
      await _client.from('messages').insert(<String, dynamic>{
        'id': _uuid.v4(),
        'thread_id': threadId,
        'sender_id': sender.id,
        'body': text.trim(),
        'created_at': now.toIso8601String(),
      });
      await _client.from('message_threads').update(<String, dynamic>{
        'last_activity': now.toIso8601String(),
      }).eq('id', threadId);
    }
    final updated = thread.copyWith(
      lastActivity: now,
      messages: <ChatMessage>[
        ...thread.messages,
        ChatMessage(
          id: _uuid.v4(),
          senderId: sender.id,
          text: text.trim(),
          createdAt: now,
        ),
      ],
    );
    _messageThreads[index] = updated;
    notifyListeners();
    return updated;
  }

  int _reservableCapacity(
    Crashpad crashpad,
    DateTime checkInDate,
    DateTime checkOutDate,
  ) {
    final overlappingGuests = _reservedGuestsForDates(
      crashpadId: crashpad.id,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
    );
    return (_availabilityService.summarize(crashpad).availableToBook -
            overlappingGuests)
        .clamp(0, 999)
        .toInt();
  }

  int _reservedGuestsForDates({
    required String crashpadId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
  }) {
    return _bookings
        .where(
          (booking) =>
              booking.crashpadId == crashpadId &&
              _reservesCapacity(booking.status) &&
              _datesOverlap(
                booking.checkInDate,
                booking.checkOutDate,
                checkInDate,
                checkOutDate,
              ),
        )
        .fold<int>(0, (total, booking) => total + booking.guestCount);
  }

  void _ensureGuestCancellationWindow(BookingRecord booking) {
    if (booking.status != BookingStatus.confirmed) return;
    final cutoff = booking.checkInDate.subtract(const Duration(hours: 24));
    if (!DateTime.now().isBefore(cutoff)) {
      throw StateError(
        'Confirmed bookings can only be cancelled at least 24 hours before check-in.',
      );
    }
  }

  bool _reservesCapacity(BookingStatus status) {
    return status == BookingStatus.pending ||
        status == BookingStatus.awaitingPayment ||
        status == BookingStatus.confirmed ||
        status == BookingStatus.active;
  }

  bool _datesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  int _bookingIndex(String bookingId) {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) {
      throw StateError('Booking request not found.');
    }
    return index;
  }

  AppUser _requireOwner() {
    final owner = _currentUser;
    if (owner == null || !owner.isOwner) {
      throw AuthException('Only the listing owner can manage this booking.');
    }
    return owner;
  }

  void _ensureOwnerCanManage(AppUser owner, BookingRecord booking) {
    if (!owner.isOwner ||
        booking.ownerEmail.toLowerCase() != owner.email.toLowerCase()) {
      throw AuthException('You can only manage bookings for your listings.');
    }
  }

  Future<void> _ownerTransition({
    required String bookingId,
    required BookingStatus from,
    required BookingStatus to,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final owner = _requireOwner();
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    _ensureOwnerCanManage(owner, booking);
    if (booking.status != from) {
      throw StateError('This booking cannot move to ${to.label}.');
    }
    _bookings[index] = booking.copyWith(status: to);
    await _persistBooking(_bookings[index]);
    notifyListeners();
  }

  Future<void> _ownerCancel(
    String bookingId, {
    required Set<BookingStatus> allowedStatuses,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final owner = _requireOwner();
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    _ensureOwnerCanManage(owner, booking);
    if (!allowedStatuses.contains(booking.status)) {
      throw StateError('This booking cannot be declined or cancelled.');
    }
    _bookings[index] = _cancelledBooking(booking);
    await _persistBooking(_bookings[index]);
    notifyListeners();
  }

  BookingRecord _cancelledBooking(BookingRecord booking) {
    return booking.copyWith(
      status: BookingStatus.cancelled,
      paymentSummary: _paymentService.markRefunded(booking.paymentSummary),
    );
  }

  void _validateCheckoutEvidence({
    required BookingRecord booking,
    required List<ChargeLineItem> checkoutCharges,
    required String ownerCheckoutNote,
  }) {
    if (checkoutCharges.isEmpty) return;

    final note = ownerCheckoutNote.trim();
    final hasGuestPhoto = booking.checkoutReport?.hasPhotos ?? false;
    for (final charge in checkoutCharges) {
      switch (charge.type) {
        case ChargeType.damage:
        case ChargeType.custom:
          if (!hasGuestPhoto && note.isEmpty) {
            throw StateError(
              'Damage and custom fees require checkout photo evidence or an owner note.',
            );
          }
          break;
        case ChargeType.cleaning:
        case ChargeType.lateCheckout:
        case ChargeType.checkout:
          if (note.isEmpty) {
            throw StateError(
              'Cleaning and late checkout fees require an owner note.',
            );
          }
          break;
        case ChargeType.booking:
        case ChargeType.additionalService:
          break;
      }
    }
  }

  List<ReviewWithCrashpad> reviewsByEmployeeName(String employeeName) {
    final normalizedName = employeeName.trim().toLowerCase();
    final records = <ReviewWithCrashpad>[];
    for (final entry in _reviewsByCrashpad.entries) {
      final crashpad = findCrashpadById(entry.key);
      if (crashpad == null) continue;
      for (final review in entry.value) {
        if (review.employeeName.toLowerCase() == normalizedName) {
          records.add(
            ReviewWithCrashpad(
              crashpadId: crashpad.id,
              crashpadName: crashpad.name,
              review: review,
            ),
          );
        }
      }
    }
    records.sort(
      (a, b) => b.review.createdAt.compareTo(a.review.createdAt),
    );
    return List.unmodifiable(records);
  }

  List<ReviewWithCrashpad> reviewsForOwner(String ownerEmail) {
    final ownedIds = _crashpads
        .where(
          (crashpad) =>
              crashpad.owner.contact?.toLowerCase() == ownerEmail.toLowerCase(),
        )
        .map((crashpad) => crashpad.id)
        .toSet();
    final records = <ReviewWithCrashpad>[];
    for (final entry in _reviewsByCrashpad.entries) {
      if (!ownedIds.contains(entry.key)) continue;
      final crashpad = findCrashpadById(entry.key);
      if (crashpad == null) continue;
      records.addAll(
        entry.value.map(
          (review) => ReviewWithCrashpad(
            crashpadId: crashpad.id,
            crashpadName: crashpad.name,
            review: review,
          ),
        ),
      );
    }
    records.sort(
      (a, b) => b.review.createdAt.compareTo(a.review.createdAt),
    );
    return List.unmodifiable(records);
  }

  /// Marks the active user as subscribed to premium features.
  Future<void> subscribeCurrentUser() async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to subscribe.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _users.indexWhere((user) => user.id == current.id);
    final updated = current.copyWith(isSubscribed: true);
    if (index != -1) {
      _users[index] = updated;
    }
    if (identical(_currentUser, current)) {
      _currentUser = updated;
    }
    if (_usesSupabase) {
      await _client.from('profiles').update(
          <String, dynamic>{'is_subscribed': true}).eq('id', current.id);
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
    if (_usesSupabase) {
      await _client.from('profiles').update(<String, dynamic>{
        'avatar_base64': base64Image,
      }).eq('id', current.id);
    }
    notifyListeners();
  }

  Future<AppUser> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    required String countryOfBirth,
    required DateTime dateOfBirth,
    String? company,
    String? badgeNumber,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to update your profile.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final updated = current.copyWith(
      firstName: firstName,
      lastName: lastName,
      countryOfBirth: countryOfBirth,
      dateOfBirth: dateOfBirth,
      company: company,
      badgeNumber: badgeNumber,
    );
    final index = _users.indexWhere((user) => user.id == current.id);
    if (index != -1) {
      _users[index] = updated;
    }
    _currentUser = updated;
    if (_usesSupabase) {
      await _client
          .from('profiles')
          .update(profileToRow(updated)
            ..remove('id')
            ..remove('email'))
          .eq('id', current.id);
    }
    for (var i = 0; i < _crashpads.length; i += 1) {
      final crashpad = _crashpads[i];
      if (crashpad.owner.contact?.toLowerCase() ==
          updated.email.toLowerCase()) {
        _crashpads[i] = crashpad.copyWith(
          owner: Owner(name: updated.displayName, contact: updated.email),
        );
      }
    }
    notifyListeners();
    return updated;
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

  Future<Uri> createStripeConnectOnboardingLink() async {
    final owner = _requireOwner();
    final response = await _client.functions.invoke(
      AppConfig.stripeConnectFunction,
      body: <String, dynamic>{
        'returnUrl': '${AppConfig.productionOrigin}/account',
        'refreshUrl': '${AppConfig.productionOrigin}/account',
        'displayName': owner.displayName,
        'email': owner.email,
      },
    );
    final data = _functionData(response.data);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Stripe did not return an onboarding URL.');
    }
    return Uri.parse(url);
  }

  Future<Uri> createBookingPaymentCheckout(BookingRecord booking) async {
    final guest = _currentUser;
    if (guest == null || !guest.isEmployee) {
      throw AuthException('Only the booking guest can pay for this stay.');
    }
    if (booking.status != BookingStatus.awaitingPayment) {
      throw StateError('This booking is not ready for payment.');
    }
    final response = await _client.functions.invoke(
      AppConfig.stripeBookingCheckoutFunction,
      body: <String, dynamic>{
        'bookingId': booking.id,
        'successUrl': '${AppConfig.productionOrigin}/account',
        'cancelUrl': '${AppConfig.productionOrigin}/account',
      },
    );
    final data = _functionData(response.data);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Stripe did not return a checkout URL.');
    }
    return Uri.parse(url);
  }

  Future<Uri> createCheckoutChargePaymentCheckout(BookingRecord booking) async {
    final guest = _currentUser;
    if (guest == null || !guest.isEmployee) {
      throw AuthException('Only the booking guest can pay checkout charges.');
    }
    if (booking.status != BookingStatus.active) {
      throw StateError(
          'Checkout charges are only payable during active stays.');
    }
    if (booking.paymentSummary.checkoutChargesTotal <= 0) {
      throw StateError('No checkout charges are due.');
    }
    final response = await _client.functions.invoke(
      AppConfig.stripeCheckoutChargeFunction,
      body: <String, dynamic>{
        'bookingId': booking.id,
        'successUrl': '${AppConfig.productionOrigin}/account',
        'cancelUrl': '${AppConfig.productionOrigin}/account',
      },
    );
    final data = _functionData(response.data);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Stripe did not return a checkout URL.');
    }
    return Uri.parse(url);
  }

  Future<Uri> createSubscriptionCheckout() async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to subscribe.');
    }
    final response = await _client.functions.invoke(
      AppConfig.stripeSubscriptionCheckoutFunction,
      body: <String, dynamic>{
        'successUrl': '${AppConfig.productionOrigin}/account',
        'cancelUrl': '${AppConfig.productionOrigin}/subscribe',
      },
    );
    final data = _functionData(response.data);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Stripe did not return a subscription URL.');
    }
    return Uri.parse(url);
  }

  Future<Uri> createBillingPortalSession() async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to manage billing.');
    }
    final response = await _client.functions.invoke(
      AppConfig.stripeBillingPortalFunction,
      body: <String, dynamic>{
        'returnUrl': '${AppConfig.productionOrigin}/account',
      },
    );
    final data = _functionData(response.data);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Stripe did not return a billing portal URL.');
    }
    return Uri.parse(url);
  }

  Future<StripePayoutStatus> fetchStripePayoutStatus() async {
    final owner = _requireOwner();
    if (!_usesSupabase) return const StripePayoutStatus.notStarted();
    final row = await _client
        .from('stripe_accounts')
        .select()
        .eq('owner_id', owner.id)
        .maybeSingle();
    if (row == null) return const StripePayoutStatus.notStarted();
    return StripePayoutStatus.fromRow(row);
  }

  Future<SubscriptionStatus> fetchSubscriptionStatus() async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to view billing.');
    }
    if (!_usesSupabase) {
      return SubscriptionStatus(
        status: current.isSubscribed ? 'active' : 'none',
        isActive: current.isSubscribed,
      );
    }
    final row = await _client
        .from('subscription_records')
        .select()
        .eq('user_id', current.id)
        .maybeSingle();
    if (row == null) {
      return SubscriptionStatus(
        status: current.isSubscribed ? 'active' : 'none',
        isActive: current.isSubscribed,
      );
    }
    return SubscriptionStatus.fromRow(row, current.isSubscribed);
  }

  Future<void> confirmBookingPayment(String bookingId) async {
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    if (booking.status != BookingStatus.awaitingPayment) {
      throw StateError('This booking is not awaiting payment.');
    }
    final updated = booking.copyWith(
      status: BookingStatus.confirmed,
      paymentSummary: _paymentService.markPaid(
        booking.paymentSummary,
      ),
    );
    _bookings[index] = updated;
    await _persistBooking(updated);
    notifyListeners();
  }

  Future<void> confirmCheckoutChargePayment(String bookingId) async {
    final index = _bookingIndex(bookingId);
    final booking = _bookings[index];
    if (booking.status != BookingStatus.active) {
      throw StateError('This booking is not active.');
    }
    if (booking.paymentSummary.checkoutChargesTotal <= 0) {
      throw StateError('No checkout charges are due.');
    }
    if (booking.checkoutChargePaymentStatus != PaymentStatus.awaitingPayment) {
      throw StateError('Checkout charges are not awaiting payment.');
    }
    final updated = booking.copyWith(
      status: BookingStatus.completed,
      checkoutChargePaymentStatus: PaymentStatus.paid,
    );
    _bookings[index] = updated;
    await _persistBooking(updated);
    notifyListeners();
  }

  Map<String, dynamic> _functionData(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return const <String, dynamic>{};
  }

  Future<AppUser> _fetchProfile(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) throw AuthException('Account profile not found');
    final user = appUserFromProfile(row);
    final index = _users.indexWhere((candidate) => candidate.id == user.id);
    if (index == -1) {
      _users.add(user);
    } else {
      _users[index] = user;
    }
    return user;
  }

  Future<AppUser?> _fetchProfileByEmail(String email) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('email', email)
        .maybeSingle();
    return row == null ? null : appUserFromProfile(row);
  }

  Future<void> _refreshCrashpads() async {
    if (!_usesSupabase) return;
    final rows = await _client
        .from('listings')
        .select()
        .order('created_at', ascending: false);
    _crashpads
      ..clear()
      ..addAll(
        (rows as List).cast<Map<String, dynamic>>().map(crashpadFromRow),
      );
  }

  Future<void> _refreshBookings() async {
    if (!_usesSupabase || _currentUser == null) return;
    final rows = await _client
        .from('bookings')
        .select()
        .order('created_at', ascending: false);
    _bookings
      ..clear()
      ..addAll(
        (rows as List).cast<Map<String, dynamic>>().map(bookingFromRow),
      );
  }

  Future<void> _refreshMessageThreads() async {
    if (!_usesSupabase || _currentUser == null) return;
    final threadRows = await _client
        .from('message_threads')
        .select()
        .order('last_activity', ascending: false);
    final threads = <MessageThread>[];
    for (final thread in (threadRows as List).cast<Map<String, dynamic>>()) {
      final messageRows = await _client
          .from('messages')
          .select()
          .eq('thread_id', thread['id'] as String)
          .order('created_at');
      threads.add(
        messageThreadFromRows(
          thread: thread,
          messages: (messageRows as List).cast<Map<String, dynamic>>(),
        ),
      );
    }
    _messageThreads
      ..clear()
      ..addAll(threads);
  }

  Future<void> _persistBooking(BookingRecord booking) async {
    if (!_usesSupabase) return;
    await _client
        .from('bookings')
        .update(
          bookingToRow(booking)..remove('id'),
        )
        .eq('id', booking.id);
  }

  void _seedData(AppRepositorySeed seed) {
    _users
      ..clear()
      ..addAll(seed.users);

    _currentUser = null;

    _crashpads
      ..clear()
      ..addAll(seed.crashpads);

    _reviewsByCrashpad
      ..clear()
      ..addAll(seed.reviewsByCrashpad);

    _bookings.clear();
    _messageThreads.clear();
  }
}

class AppRepositorySeed {
  const AppRepositorySeed({
    required this.users,
    required this.crashpads,
    this.reviewsByCrashpad = const <String, List<Review>>{},
  });

  final List<AppUser> users;
  final List<Crashpad> crashpads;
  final Map<String, List<Review>> reviewsByCrashpad;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => jsonEncode({'message': message});
}

class ListingDeletionImpact {
  const ListingDeletionImpact({
    required this.selectedListingCount,
    required this.pendingCount,
    required this.confirmedCount,
    required this.activeCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  final int selectedListingCount;
  final int pendingCount;
  final int confirmedCount;
  final int activeCount;
  final int completedCount;
  final int cancelledCount;

  int get liveBookingCount => pendingCount + confirmedCount + activeCount;

  int get historyBookingCount => completedCount + cancelledCount;

  bool get canDelete => liveBookingCount == 0;
}

class StripePayoutStatus {
  const StripePayoutStatus({
    required this.status,
    required this.chargesEnabled,
    required this.payoutsEnabled,
    this.onboardingCompletedAt,
  });

  const StripePayoutStatus.notStarted()
      : status = 'not_started',
        chargesEnabled = false,
        payoutsEnabled = false,
        onboardingCompletedAt = null;

  factory StripePayoutStatus.fromRow(Map<String, dynamic> row) {
    return StripePayoutStatus(
      status: row['status']?.toString() ?? 'not_started',
      chargesEnabled: row['charges_enabled'] == true,
      payoutsEnabled: row['payouts_enabled'] == true,
      onboardingCompletedAt: DateTime.tryParse(
        row['onboarding_completed_at']?.toString() ?? '',
      ),
    );
  }

  final String status;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final DateTime? onboardingCompletedAt;

  bool get isReady => chargesEnabled && payoutsEnabled;

  String get label {
    if (isReady) return 'Ready for payouts';
    switch (status) {
      case 'onboarding':
        return 'Onboarding incomplete';
      case 'restricted':
        return 'Payouts restricted';
      case 'enabled':
        return 'Ready for payouts';
      default:
        return 'Not connected';
    }
  }

  String get description {
    if (isReady) {
      return 'Stripe can route guest payments and owner payouts for approved stays.';
    }
    switch (status) {
      case 'onboarding':
        return 'Finish Stripe onboarding before guests can complete payment for your listings.';
      case 'restricted':
        return 'Stripe needs more information before charges or payouts are enabled.';
      default:
        return 'Connect Stripe to receive payouts after guest bookings are paid.';
    }
  }
}

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.status,
    required this.isActive,
    this.currentPeriodEnd,
  });

  factory SubscriptionStatus.fromRow(
    Map<String, dynamic> row,
    bool profileIsSubscribed,
  ) {
    final status = row['status']?.toString() ?? 'none';
    return SubscriptionStatus(
      status: status,
      isActive:
          profileIsSubscribed || status == 'active' || status == 'trialing',
      currentPeriodEnd: DateTime.tryParse(
        row['current_period_end']?.toString() ?? '',
      ),
    );
  }

  final String status;
  final bool isActive;
  final DateTime? currentPeriodEnd;

  String get label {
    if (isActive) {
      return status == 'trialing' ? 'Trial active' : 'Premium active';
    }
    switch (status) {
      case 'past_due':
        return 'Payment needs attention';
      case 'canceled':
        return 'Subscription canceled';
      case 'incomplete':
        return 'Checkout not completed';
      default:
        return 'Premium inactive';
    }
  }

  String get description {
    if (isActive) {
      return 'Premium access is active from Stripe subscription status.';
    }
    if (status == 'past_due') {
      return 'Open billing to update payment details or resolve the invoice.';
    }
    return 'Start Stripe Checkout to activate premium access.';
  }
}
