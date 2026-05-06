import 'dart:io';

import 'package:crash_pad/config/app_config.dart';
import 'package:crash_pad/data/app_repository.dart';
import 'package:crash_pad/models/app_user.dart';
import 'package:crash_pad/models/booking.dart';
import 'package:crash_pad/models/crashpad.dart';
import 'package:crash_pad/models/payment.dart';
import 'package:crash_pad/services/availability_service.dart';
import 'package:crash_pad/services/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/crashpad_test_seed.dart';

void main() {
  test('production repository no longer imports runtime mock seed data', () {
    final repositorySource =
        File('lib/data/app_repository.dart').readAsStringSync();
    expect(repositorySource, isNot(contains('mock_crashpad_data')));
    expect(File('lib/data/mock_crashpad_data.dart').existsSync(), isFalse);
    expect(File('test/fixtures/crashpad_test_seed.dart').existsSync(), isTrue);
  });

  test('owner-created crashpad stores real room capacity and fees', () async {
    final repository = seededRepository();

    await repository.logIn('owner@crashpads.com', 'owner123');
    await repository.addCrashpad(
      name: 'Owner Test Crashpad',
      description: 'A full test listing with real operational values.',
      location: '100 Test Way, Denver, CO, USA',
      nearestAirport: 'DEN',
      bedType: CrashpadBedModel.flexible.label,
      price: 120,
      imageUrls: const <String>['ZmFrZS1saXN0aW5nLXBob3Rv'],
      rooms: const <CrashpadRoom>[
        CrashpadRoom(
          id: 'cold-room',
          name: 'Cold Room',
          bedModel: CrashpadBedModel.cold,
          beds: <CrashpadBed>[
            CrashpadBed(id: 'c1', label: 'Bed 1', isAssigned: true),
            CrashpadBed(id: 'c2', label: 'Bed 2'),
            CrashpadBed(id: 'c3', label: 'Bed 3'),
          ],
          activeGuests: 1,
          hotCapacity: 3,
        ),
        CrashpadRoom(
          id: 'hot-room',
          name: 'Hot Room',
          bedModel: CrashpadBedModel.hot,
          beds: <CrashpadBed>[
            CrashpadBed(id: 'h1', label: 'Bed 1'),
            CrashpadBed(id: 'h2', label: 'Bed 2'),
          ],
          activeGuests: 3,
          hotCapacity: 5,
        ),
      ],
      amenities: const <String>['Wi-Fi', 'Laundry'],
      houseRules: const <String>['Quiet hours'],
      services: const <CrashpadService>[
        CrashpadService(
          id: 'linen',
          name: 'Linen reset',
          description: 'Fresh linens before arrival.',
          price: 20,
        ),
      ],
      checkoutCharges: const <CrashpadCheckoutCharge>[
        CrashpadCheckoutCharge(
          id: 'cleaning',
          name: 'Cleaning fee',
          description: 'Missed checkout cleaning.',
          amount: 35,
          type: ChargeType.cleaning,
        ),
      ],
      minimumStayNights: 4,
      distanceToAirportMiles: 6.5,
    );

    final ownerListings = await repository.fetchOwnerCrashpads(
      repository.currentUser!.email,
    );
    final created = ownerListings.first;
    final availability = const AvailabilityService().summarize(created);

    expect(created.name, 'Owner Test Crashpad');
    expect(created.rooms.length, 2);
    expect(created.totalPhysicalBeds, 5);
    expect(created.totalActiveGuests, 4);
    expect(availability.availableColdBeds, 2);
    expect(availability.availableHotSlots, 2);
    expect(availability.availableToBook, 4);
    expect(created.services.single.price, 20);
    expect(created.checkoutCharges.single.amount, 35);
    expect(created.minimumStayNights, 4);
    expect(created.distanceToAirportMiles, 6.5);
  });

  test('owner-created crashpad requires a real listing photo', () async {
    final repository = seededRepository();

    await repository.logIn('owner@crashpads.com', 'owner123');
    await expectLater(
      repository.addCrashpad(
        name: 'No Photo Crashpad',
        description: 'Listing should not publish without owner photos.',
        location: '100 Test Way, Denver, CO, USA',
        nearestAirport: 'DEN',
        bedType: CrashpadBedModel.hot.label,
        price: 120,
        imageUrls: const <String>[],
        rooms: const <CrashpadRoom>[
          CrashpadRoom(
            id: 'hot-room',
            name: 'Hot Room',
            bedModel: CrashpadBedModel.hot,
            beds: <CrashpadBed>[CrashpadBed(id: 'h1', label: 'Bed 1')],
            activeGuests: 0,
            hotCapacity: 1,
          ),
        ],
        amenities: const <String>['Wi-Fi'],
        houseRules: const <String>['Quiet hours'],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('guest booking is visible to owner and can move through stay workflow',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();

    await repository.logIn('owner@crashpads.com', 'owner123');
    final owner = repository.currentUser!;
    final ownerListings = await repository.fetchOwnerCrashpads(owner.email);
    final crashpad = ownerListings.first;

    await repository.logOut();
    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 1, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(const Duration(days: 5)),
      guestCount: 1,
      additionalServices: const <ChargeLineItem>[
        ChargeLineItem(
          id: 'linen',
          label: 'Linen reset',
          amount: 20,
          type: ChargeType.additionalService,
        ),
      ],
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    expect(booking.status, BookingStatus.pending);
    expect(booking.paymentSummary.status, PaymentStatus.draft);
    expect(
      booking.paymentSummary.platformFeeRate,
      AppConfig.platformFeeRate,
    );
    expect(
      booking.paymentSummary.ownerPayout,
      closeTo(
        booking.paymentSummary.totalChargedToGuest -
            booking.paymentSummary.platformFee,
        0.01,
      ),
    );

    final guestBookings = await repository.fetchGuestBookings(guest.email);
    expect(guestBookings, hasLength(1));
    expect(guestBookings.single.id, booking.id);

    final ownerBookings = await repository.fetchOwnerBookings(owner.email);
    expect(ownerBookings, hasLength(1));
    expect(ownerBookings.single.guestEmail, guest.email);

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    expect(repository.bookings.single.status, BookingStatus.confirmed);

    await repository.checkInBooking(booking.id);
    expect(repository.bookings.single.status, BookingStatus.active);

    await repository.completeBooking(
      bookingId: booking.id,
      checkoutCharges: const <ChargeLineItem>[
        ChargeLineItem(
          id: 'cleaning',
          label: 'Cleaning fee',
          amount: 35,
          type: ChargeType.cleaning,
        ),
      ],
      ownerCheckoutNote: 'Cleaning fee assessed after checkout.',
    );
    expect(repository.bookings.single.status, BookingStatus.active);
    expect(repository.bookings.single.checkoutChargePaymentStatus,
        PaymentStatus.awaitingPayment);
    await repository.confirmCheckoutChargePayment(booking.id);
    expect(repository.bookings.single.status, BookingStatus.completed);
    expect(repository.bookings.single.checkoutChargePaymentStatus,
        PaymentStatus.paid);
    expect(
        repository.bookings.single.paymentSummary.status, PaymentStatus.paid);
    expect(repository.bookings.single.paymentSummary.checkoutChargesTotal, 35);
  });

  test('booking creation enforces minimum stay and reserved capacity',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 2, 1);

    final shortDraft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(const Duration(days: 1)),
      guestCount: 1,
    );
    await expectLater(
      repository.createBooking(
        crashpad: crashpad,
        draft: shortDraft,
        paymentSummary: paymentService.buildSummary(shortDraft),
      ),
      throwsA(isA<ArgumentError>()),
    );

    final overCapacityDraft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 99,
    );
    await expectLater(
      repository.createBooking(
        crashpad: crashpad,
        draft: overCapacityDraft,
        paymentSummary: paymentService.buildSummary(overCapacityDraft),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('pending overlapping bookings reserve capacity', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 3, 1);
    final checkOut = checkIn.add(Duration(days: crashpad.minimumStayNights));
    final firstDraft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkOut,
      guestCount: 4,
    );
    await repository.createBooking(
      crashpad: crashpad,
      draft: firstDraft,
      paymentSummary: paymentService.buildSummary(firstDraft),
    );

    final secondDraft = firstDraft.copyWith(guestCount: 2);
    await expectLater(
      repository.createBooking(
        crashpad: crashpad,
        draft: secondDraft,
        paymentSummary: paymentService.buildSummary(secondDraft),
      ),
      throwsA(isA<StateError>()),
    );

    final nonOverlappingDraft = firstDraft.copyWith(
      checkInDate: checkOut,
      checkOutDate: checkOut.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 2,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: nonOverlappingDraft,
      paymentSummary: paymentService.buildSummary(nonOverlappingDraft),
    );
    expect(booking.status, BookingStatus.pending);
  });

  test('date-aware availability reflects pending booking reservations',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;
    final staticAvailability =
        const AvailabilityService().summarize(crashpad).availableToBook;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2027, 2, 1);
    final checkOut = checkIn.add(Duration(days: crashpad.minimumStayNights));
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkOut,
      guestCount: 2,
    );
    await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    expect(
      repository.availableCapacityForDates(
        crashpad: crashpad,
        checkInDate: checkIn,
        checkOutDate: checkOut,
      ),
      staticAvailability - 2,
    );
    expect(
      repository.availableCapacityForDates(
        crashpad: crashpad,
        checkInDate: checkOut,
        checkOutDate: checkOut.add(Duration(days: crashpad.minimumStayNights)),
      ),
      staticAvailability,
    );
  });

  test('guest and owner permissions are enforced for booking workflow',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 4, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.signUp(
      email: 'other.owner@example.com',
      password: 'owner456',
      firstName: 'Other',
      lastName: 'Owner',
      countryOfBirth: 'USA',
      dateOfBirth: DateTime(1980, 1, 1),
      userType: AppUserType.owner,
    );
    await expectLater(
      repository.approveBooking(booking.id),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.signUp(
      email: 'other.crew@example.com',
      password: 'crew456',
      firstName: 'Other',
      lastName: 'Crew',
      countryOfBirth: 'USA',
      dateOfBirth: DateTime(1990, 1, 1),
      userType: AppUserType.employee,
      company: 'Test Air',
      badgeNumber: 'TA-1',
    );
    await expectLater(
      repository.cancelBooking(booking.id),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.logIn('crew@crashpads.com', 'flysafe');
    await repository.cancelBooking(booking.id);
    expect(repository.bookings.single.status, BookingStatus.cancelled);
    expect(repository.bookings.single.paymentSummary.status,
        PaymentStatus.refunded);
  });

  test('confirmed guest cancellation is blocked inside 24 hour cutoff',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime.now().add(const Duration(hours: 20));
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await repository.logOut();
    await repository.logIn('crew@crashpads.com', 'flysafe');

    await expectLater(
      repository.cancelBooking(booking.id),
      throwsA(isA<StateError>()),
    );
    expect(repository.bookings.single.status, BookingStatus.confirmed);
  });

  test('illegal transitions leave booking unchanged', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 5, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await expectLater(
      repository.completeBooking(bookingId: booking.id),
      throwsA(isA<StateError>()),
    );
    expect(repository.bookings.single.status, BookingStatus.pending);

    await repository.approveBooking(booking.id);
    await expectLater(
      repository.approveBooking(booking.id),
      throwsA(isA<StateError>()),
    );
    expect(repository.bookings.single.status, BookingStatus.awaitingPayment);
  });

  test('guest checkout report is limited to the booking guest and active flow',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 6, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await expectLater(
      repository.submitCheckoutReport(
        bookingId: booking.id,
        notes: 'Trying before owner approval.',
        photos: const <CheckoutPhoto>[],
      ),
      throwsA(isA<StateError>()),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await expectLater(
      repository.submitCheckoutReport(
        bookingId: booking.id,
        notes: 'Owner cannot submit guest checkout.',
        photos: const <CheckoutPhoto>[],
      ),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.signUp(
      email: 'checkout.other@example.com',
      password: 'crew456',
      firstName: 'Other',
      lastName: 'Crew',
      countryOfBirth: 'USA',
      dateOfBirth: DateTime(1991, 1, 1),
      userType: AppUserType.employee,
      company: 'Test Air',
      badgeNumber: 'CO-2',
    );
    await expectLater(
      repository.submitCheckoutReport(
        bookingId: booking.id,
        notes: 'Wrong guest.',
        photos: const <CheckoutPhoto>[],
      ),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.logIn('crew@crashpads.com', 'flysafe');
    await repository.submitCheckoutReport(
      bookingId: booking.id,
      notes: 'Room is clean and locker is empty.',
      photos: <CheckoutPhoto>[
        CheckoutPhoto(
          id: 'photo-1',
          fileName: 'checkout.jpg',
          base64Data: 'ZmFrZQ==',
          capturedAt: DateTime(2026, 6, 4),
        ),
      ],
    );

    expect(repository.bookings.single.checkoutReport?.notes,
        'Room is clean and locker is empty.');
    expect(repository.bookings.single.checkoutReport?.photos, hasLength(1));
  });

  test('checkout fees require owner notes or guest photo evidence', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 7, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await repository.checkInBooking(booking.id);

    await expectLater(
      repository.completeBooking(
        bookingId: booking.id,
        checkoutCharges: const <ChargeLineItem>[
          ChargeLineItem(
            id: 'cleaning',
            label: 'Cleaning fee',
            amount: 35,
            type: ChargeType.cleaning,
          ),
        ],
      ),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      repository.completeBooking(
        bookingId: booking.id,
        checkoutCharges: const <ChargeLineItem>[
          ChargeLineItem(
            id: 'damage',
            label: 'Damage fee',
            amount: 75,
            type: ChargeType.damage,
          ),
        ],
      ),
      throwsA(isA<StateError>()),
    );

    await repository.completeBooking(
      bookingId: booking.id,
      checkoutCharges: const <ChargeLineItem>[
        ChargeLineItem(
          id: 'cleaning',
          label: 'Cleaning fee',
          amount: 35,
          type: ChargeType.cleaning,
        ),
      ],
      ownerCheckoutNote: 'Trash was left in the room after checkout.',
    );

    expect(repository.bookings.single.status, BookingStatus.active);
    expect(repository.bookings.single.checkoutChargePaymentStatus,
        PaymentStatus.awaitingPayment);
    await repository.confirmCheckoutChargePayment(booking.id);
    expect(repository.bookings.single.status, BookingStatus.completed);
    expect(
        repository.bookings.single.paymentSummary.status, PaymentStatus.paid);
    expect(repository.bookings.single.ownerCheckoutNote,
        'Trash was left in the room after checkout.');
  });

  test('damage fees can use guest checkout photo evidence', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2026, 8, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await repository.checkInBooking(booking.id);
    await repository.logOut();
    await repository.logIn('crew@crashpads.com', 'flysafe');
    await repository.submitCheckoutReport(
      bookingId: booking.id,
      notes: 'Photo before leaving.',
      photos: <CheckoutPhoto>[
        CheckoutPhoto(
          id: 'photo-1',
          fileName: 'before-leaving.jpg',
          base64Data: 'ZmFrZQ==',
          capturedAt: DateTime(2026, 8, 4),
        ),
      ],
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await repository.completeBooking(
      bookingId: booking.id,
      checkoutCharges: const <ChargeLineItem>[
        ChargeLineItem(
          id: 'damage',
          label: 'Damage fee',
          amount: 75,
          type: ChargeType.damage,
        ),
      ],
    );

    expect(repository.bookings.single.status, BookingStatus.active);
    expect(repository.bookings.single.checkoutChargePaymentStatus,
        PaymentStatus.awaitingPayment);
    await repository.confirmCheckoutChargePayment(booking.id);
    expect(repository.bookings.single.status, BookingStatus.completed);
    expect(repository.bookings.single.paymentSummary.checkoutChargesTotal, 75);
  });

  test('owner can edit all listing details through repository update',
      () async {
    final repository = seededRepository();

    await repository.logIn('owner@crashpads.com', 'owner123');
    final owner = repository.currentUser!;
    final original = (await repository.fetchOwnerCrashpads(owner.email)).first;
    final updated = await repository.updateCrashpad(
      original.copyWith(
        name: 'Updated Management Loft',
        description: 'Updated listing details for every guest-facing field.',
        location: '99 Updated Way, Chicago, IL, USA',
        nearestAirport: 'ORD',
        bedType: CrashpadBedModel.flexible.label,
        price: 155,
        imageUrls: const <String>['image-a', 'image-b'],
        rooms: const <CrashpadRoom>[
          CrashpadRoom(
            id: 'updated-room',
            name: 'Updated Room',
            bedModel: CrashpadBedModel.hot,
            beds: <CrashpadBed>[
              CrashpadBed(id: 'u1', label: 'Bed 1'),
              CrashpadBed(id: 'u2', label: 'Bed 2'),
            ],
            activeGuests: 1,
            hotCapacity: 3,
            storageNote: 'Updated storage note.',
          ),
        ],
        amenities: const <String>['Wi-Fi', 'Parking'],
        houseRules: const <String>['Updated quiet hours'],
        services: const <CrashpadService>[
          CrashpadService(
            id: 'updated-service',
            name: 'Updated service',
            description: 'Updated service description.',
            price: 24,
          ),
        ],
        checkoutCharges: const <CrashpadCheckoutCharge>[
          CrashpadCheckoutCharge(
            id: 'updated-charge',
            name: 'Updated charge',
            description: 'Updated checkout charge.',
            amount: 44,
            type: ChargeType.custom,
          ),
        ],
        minimumStayNights: 6,
        distanceToAirportMiles: 2.7,
      ),
    );

    expect(updated.name, 'Updated Management Loft');
    expect(updated.location, '99 Updated Way, Chicago, IL, USA');
    expect(updated.nearestAirport, 'ORD');
    expect(updated.price, 155);
    expect(updated.imageUrls, const <String>['image-a', 'image-b']);
    expect(updated.rooms.single.storageNote, 'Updated storage note.');
    expect(updated.amenities, const <String>['Wi-Fi', 'Parking']);
    expect(updated.houseRules, const <String>['Updated quiet hours']);
    expect(updated.services.single.name, 'Updated service');
    expect(updated.checkoutCharges.single.amount, 44);
    expect(updated.minimumStayNights, 6);
    expect(updated.distanceToAirportMiles, 2.7);
  });

  test('listing edits and deletion respect live booking impact', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2027, 3, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    final impact = repository.bookingImpactForListingDeletion({crashpad.id});
    expect(impact.pendingCount, 1);
    expect(impact.canDelete, isFalse);
    await expectLater(
      repository.deleteCrashpads({crashpad.id}),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      repository.updateCrashpad(
        crashpad.copyWith(
          rooms: const <CrashpadRoom>[
            CrashpadRoom(
              id: 'full-room',
              name: 'Full room',
              bedModel: CrashpadBedModel.hot,
              beds: <CrashpadBed>[CrashpadBed(id: 'bed', label: 'Bed')],
              activeGuests: 1,
              hotCapacity: 1,
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    await repository.declineBooking(booking.id);
    expect(
      repository.bookingImpactForListingDeletion({crashpad.id}).canDelete,
      isTrue,
    );
    await repository.deleteCrashpads({crashpad.id});
    expect(repository.findCrashpadById(crashpad.id), isNull);
    expect(repository.bookings.single.status, BookingStatus.cancelled);
  });

  test('test-seeded messaging workflows update state', () async {
    final repository = seededRepository();
    final crashpad = repository.crashpads.first;

    await repository.signUp(
      email: 'message.crew@example.com',
      password: 'crew456',
      firstName: 'Message',
      lastName: 'Crew',
      countryOfBirth: 'USA',
      dateOfBirth: DateTime(1993, 1, 1),
      userType: AppUserType.employee,
      company: 'Test Air',
      badgeNumber: 'MSG-1',
    );

    final thread = await repository.startMessageThread(
      crashpadId: crashpad.id,
      text: 'Is early check-in available?',
    );
    expect(thread.messages.single.text, 'Is early check-in available?');
    expect(repository.currentUserMessageThreads.single.id, thread.id);

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    final reply = await repository.sendMessage(
      threadId: thread.id,
      text: 'Yes, message me your arrival time.',
    );
    expect(reply.messages, hasLength(2));
    expect(repository.currentUserMessageThreads.single.id, thread.id);
  });

  test('owner can manually assign confirmed or active booking', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2027, 4, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    final room = crashpad.rooms.firstWhere(
      (candidate) => candidate.bedModel != CrashpadBedModel.cold,
    );
    await repository.assignBookingBed(
      bookingId: booking.id,
      roomId: room.id,
      assignmentNote: 'Assign near the west locker.',
    );

    final assigned = repository.bookings.single;
    expect(assigned.assignedRoomId, room.id);
    expect(assigned.assignedRoomName, room.name);
    expect(assigned.assignmentNote, 'Assign near the west locker.');
  });

  test('manual assignment enforces owner permissions and room validation',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2027, 5, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await expectLater(
      repository.assignBookingBed(bookingId: booking.id, roomId: 'missing'),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.signUp(
      email: 'assignment.owner@example.com',
      password: 'owner456',
      firstName: 'Other',
      lastName: 'Owner',
      countryOfBirth: 'USA',
      dateOfBirth: DateTime(1980, 1, 1),
      userType: AppUserType.owner,
    );
    await expectLater(
      repository.assignBookingBed(bookingId: booking.id, roomId: 'missing'),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await expectLater(
      repository.assignBookingBed(bookingId: booking.id, roomId: 'missing'),
      throwsA(isA<StateError>()),
    );
  });

  test('cold-bed manual assignment requires an available bed', () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.firstWhere(
      (listing) => listing.rooms.any(
        (room) =>
            room.bedModel == CrashpadBedModel.cold &&
            room.beds.any((bed) => !bed.isAssigned && bed.isAvailable),
      ),
    );
    final coldRoom = crashpad.rooms.firstWhere(
      (room) =>
          room.bedModel == CrashpadBedModel.cold &&
          room.beds.any((bed) => !bed.isAssigned && bed.isAvailable),
    );
    final availableBed = coldRoom.beds.firstWhere(
      (bed) => !bed.isAssigned && bed.isAvailable,
    );

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;
    final checkIn = DateTime(2027, 6, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await expectLater(
      repository.assignBookingBed(bookingId: booking.id, roomId: coldRoom.id),
      throwsA(isA<StateError>()),
    );
    await repository.assignBookingBed(
      bookingId: booking.id,
      roomId: coldRoom.id,
      bedId: availableBed.id,
    );
    expect(repository.bookings.single.assignedBedId, availableBed.id);
  });

  test('guest can only review after completing a confirmed paid stay',
      () async {
    final repository = seededRepository();
    const paymentService = PaymentService();
    final crashpad = repository.crashpads.first;
    final initialReviewCount =
        (await repository.fetchReviews(crashpad.id)).length;

    await repository.logIn('crew@crashpads.com', 'flysafe');
    final guest = repository.currentUser!;

    await expectLater(
      repository.addReview(
        crashpadId: crashpad.id,
        employeeName: guest.displayName,
        comment: 'Trying to review before a completed stay.',
        rating: 4,
      ),
      throwsA(isA<AuthException>()),
    );

    final checkIn = DateTime(2026, 1, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(const Duration(days: 3)),
      guestCount: 1,
    );
    final booking = await repository.createBooking(
      crashpad: crashpad,
      draft: draft,
      paymentSummary: paymentService.buildSummary(draft),
    );

    await expectLater(
      repository.addReview(
        crashpadId: crashpad.id,
        employeeName: guest.displayName,
        comment: 'Trying to review before completion.',
        rating: 4,
      ),
      throwsA(isA<AuthException>()),
    );

    await repository.logOut();
    await repository.logIn('owner@crashpads.com', 'owner123');
    await _approveAndPay(repository, booking.id);
    await repository.checkInBooking(booking.id);
    await repository.completeBooking(bookingId: booking.id);
    await repository.logOut();
    await repository.logIn('crew@crashpads.com', 'flysafe');
    await repository.addReview(
      crashpadId: crashpad.id,
      employeeName: guest.displayName,
      comment: 'Completed stay matched the listing and checkout was clear.',
      rating: 4.5,
    );

    final reviews = await repository.fetchReviews(crashpad.id);
    expect(reviews, hasLength(initialReviewCount + 1));
    expect(reviews.last.employeeName, guest.displayName);
  });
}

AppRepository seededRepository() {
  return AppRepository.testSeeded(seed: MockCrashpadSeed.repositorySeed());
}

Future<void> _approveAndPay(AppRepository repository, String bookingId) async {
  await repository.approveBooking(bookingId);
  expect(repository.bookings.single.status, BookingStatus.awaitingPayment);
  await repository.confirmBookingPayment(bookingId);
}
