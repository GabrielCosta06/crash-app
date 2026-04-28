import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../models/review.dart';
import '../models/message_thread.dart';
import '../services/availability_service.dart';
import '../services/payment_service.dart';
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
  final List<MessageThread> _messageThreads = [];
  final AvailabilityService _availabilityService = const AvailabilityService();
  final PaymentService _paymentService = const PaymentService();
  AppUser? _currentUser;
  bool _isDarkTheme = true;

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
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final bookingPayment = paymentSummary.status == PaymentStatus.draft
        ? paymentSummary.copyWith(status: PaymentStatus.authorized)
        : paymentSummary;
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
    await _ownerTransition(
      bookingId: bookingId,
      from: BookingStatus.pending,
      to: BookingStatus.confirmed,
    );
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
    );
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
    final paid = _paymentService.captureMockPayment(assessed);
    _bookings[index] = booking.copyWith(
      status: BookingStatus.completed,
      paymentSummary: paid,
      ownerCheckoutNote:
          ownerCheckoutNote.trim().isEmpty ? null : ownerCheckoutNote.trim(),
    );
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
        : _users.cast<AppUser?>().firstWhere(
              (user) => user?.email.toLowerCase() == ownerEmail.toLowerCase(),
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
    notifyListeners();
  }

  BookingRecord _cancelledBooking(BookingRecord booking) {
    return booking.copyWith(
      status: BookingStatus.cancelled,
      paymentSummary: _paymentService.refundMockPayment(booking.paymentSummary),
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
    _messageThreads.clear();
  }
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
