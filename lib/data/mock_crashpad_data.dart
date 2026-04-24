import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../models/review.dart';

class MockCrashpadSeed {
  const MockCrashpadSeed._();

  /// Demo-only credentials preserved from the original app so current login
  /// screens still work. TODO: replace with Supabase Auth users before launch.
  static List<AppUser> users(Uuid uuid) {
    return <AppUser>[
      AppUser(
        id: uuid.v4(),
        email: 'owner@crashpads.com',
        password: 'owner123',
        firstName: 'Gabriel',
        lastName: 'Costa',
        countryOfBirth: 'USA',
        dateOfBirth: DateTime(1988, 4, 12),
        userType: AppUserType.owner,
        isSubscribed: true,
      ),
      AppUser(
        id: uuid.v4(),
        email: 'crew@crashpads.com',
        password: 'flysafe',
        firstName: 'Rafael',
        lastName: 'Costa',
        countryOfBirth: 'Canada',
        dateOfBirth: DateTime(1992, 9, 3),
        userType: AppUserType.employee,
        company: 'SkyFusion Airways',
        badgeNumber: 'SF-8821',
        isSubscribed: true,
      ),
    ];
  }

  static List<Crashpad> crashpads(Uuid uuid, Owner owner) {
    return <Crashpad>[
      Crashpad(
        id: uuid.v4(),
        name: 'Skyline Loft Haven',
        description:
            'A polished crew apartment with quiet sleeping rooms, blackout shades, a stocked kitchen, secure entry, and direct rail access to the airport.',
        location: '123 Aurora Ave, Seattle, WA, USA',
        nearestAirport: 'SEA',
        owner: owner,
        imageUrls: const <String>[
          'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=1200&q=80',
        ],
        dateAdded: DateTime.now().subtract(const Duration(days: 8)),
        bedType: CrashpadBedModel.hot.label,
        price: 139,
        clickCount: 48,
        rooms: <CrashpadRoom>[
          CrashpadRoom(
            id: 'sea-bunk-a',
            name: 'Bunk Room A',
            bedModel: CrashpadBedModel.hot,
            beds: _beds('SEA-A', 6, assigned: 0),
            activeGuests: 8,
            hotCapacity: 11,
            storageNote: 'Assigned bins for bedding and personal items.',
          ),
          CrashpadRoom(
            id: 'sea-quiet',
            name: 'Quiet Room',
            bedModel: CrashpadBedModel.hot,
            beds: _beds('SEA-Q', 4, assigned: 0),
            activeGuests: 4,
            hotCapacity: 6,
            storageNote: 'Quiet hours enforced between 10 PM and 8 AM.',
          ),
        ],
        amenities: const <String>[
          'Blackout curtains',
          'Fast Wi-Fi',
          'Washer and dryer',
          'Airport rail access',
          'Secure smart lock',
          'Crew-only kitchen',
        ],
        houseRules: const <String>[
          'Crew members only',
          'Quiet hours after 10 PM',
          'Label stored bedding',
          'Clean shared spaces after use',
        ],
        services: const <CrashpadService>[
          CrashpadService(
            id: 'sea-linen',
            name: 'Fresh linen reset',
            description:
                'Fresh sheets, towel, and pillowcase ready on arrival.',
            price: 18,
          ),
          CrashpadService(
            id: 'sea-locker',
            name: 'Monthly storage locker',
            description:
                'Reserved locker for bedding and small personal items.',
            price: 32,
          ),
        ],
        checkoutCharges: const <CrashpadCheckoutCharge>[
          CrashpadCheckoutCharge(
            id: 'sea-cleaning',
            name: 'Cleaning fee',
            description: 'Applied when checkout cleaning is not completed.',
            amount: 35,
            type: ChargeType.cleaning,
          ),
          CrashpadCheckoutCharge(
            id: 'sea-late',
            name: 'Late checkout fee',
            description: 'Applied when checkout happens after the agreed time.',
            amount: 25,
            type: ChargeType.lateCheckout,
          ),
        ],
        minimumStayNights: 3,
        distanceToAirportMiles: 4.2,
      ),
      Crashpad(
        id: uuid.v4(),
        name: 'Runway Retreat Capsule',
        description:
            'A dedicated cold-bed property with assigned beds, individual storage, calm lighting, and a predictable rest routine for commuter crew.',
        location: '88 Velocity Blvd, Austin, TX, USA',
        nearestAirport: 'AUS',
        owner: owner,
        imageUrls: const <String>[
          'https://images.unsplash.com/photo-1493666438817-866a91353ca9?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1200&q=80',
        ],
        dateAdded: DateTime.now().subtract(const Duration(days: 15)),
        bedType: CrashpadBedModel.cold.label,
        price: 98.5,
        clickCount: 27,
        rooms: <CrashpadRoom>[
          CrashpadRoom(
            id: 'aus-north',
            name: 'North Room',
            bedModel: CrashpadBedModel.cold,
            beds: _beds('AUS-N', 4, assigned: 3),
            activeGuests: 3,
            hotCapacity: 4,
          ),
          CrashpadRoom(
            id: 'aus-south',
            name: 'South Room',
            bedModel: CrashpadBedModel.cold,
            beds: _beds('AUS-S', 4, assigned: 2),
            activeGuests: 2,
            hotCapacity: 4,
          ),
        ],
        amenities: const <String>[
          'Assigned bed',
          'Individual storage',
          'Parking',
          'Quiet workspace',
          'Weekly cleaning',
        ],
        houseRules: const <String>[
          'No bed sharing',
          'Guests keep assigned storage only',
          'Kitchen closes for cleaning at 9 PM',
        ],
        services: const <CrashpadService>[
          CrashpadService(
            id: 'aus-airport',
            name: 'Airport drop-off',
            description: 'Owner-arranged airport ride when available.',
            price: 22,
          ),
        ],
        checkoutCharges: const <CrashpadCheckoutCharge>[
          CrashpadCheckoutCharge(
            id: 'aus-damage',
            name: 'Damage fee',
            description: 'Custom charge for verified damage after checkout.',
            amount: 75,
            type: ChargeType.damage,
          ),
        ],
        minimumStayNights: 2,
        distanceToAirportMiles: 7.8,
      ),
      Crashpad(
        id: uuid.v4(),
        name: 'Altitude Zen Hub',
        description:
            'A mixed-model crashpad with private cold beds, rotating hot-bed rooms, a meditation corner, and a larger common area for long-haul crews.',
        location: '701 Quantum Pkwy, San Francisco, CA, USA',
        nearestAirport: 'SFO',
        owner: owner,
        imageUrls: const <String>[
          'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80',
        ],
        dateAdded: DateTime.now().subtract(const Duration(days: 3)),
        bedType: CrashpadBedModel.flexible.label,
        price: 169,
        clickCount: 65,
        rooms: <CrashpadRoom>[
          CrashpadRoom(
            id: 'sfo-cold-suite',
            name: 'Cold Suite',
            bedModel: CrashpadBedModel.cold,
            beds: _beds('SFO-C', 3, assigned: 2),
            activeGuests: 2,
            hotCapacity: 3,
          ),
          CrashpadRoom(
            id: 'sfo-hot-loft',
            name: 'Hot Loft',
            bedModel: CrashpadBedModel.hot,
            beds: _beds('SFO-H', 8, assigned: 0),
            activeGuests: 10,
            hotCapacity: 14,
            storageNote: 'Bedding cubbies are first come, first served.',
          ),
        ],
        amenities: const <String>[
          'Mixed bed options',
          'Meditation nook',
          'Premium kitchen',
          'Laundry',
          'Owner-managed checkout',
          'SFO shuttle nearby',
        ],
        houseRules: const <String>[
          'Respect assigned cold beds',
          'Hot-bed guests rotate based on arrival',
          'Report damage before checkout',
          'No outside overnight guests',
        ],
        services: const <CrashpadService>[
          CrashpadService(
            id: 'sfo-meal',
            name: 'Meal prep kit',
            description: 'Three simple meals stocked before arrival.',
            price: 45,
          ),
          CrashpadService(
            id: 'sfo-clean-linen',
            name: 'Linen and towel refresh',
            description: 'Fresh linens plus towel refresh during the stay.',
            price: 28,
          ),
        ],
        checkoutCharges: const <CrashpadCheckoutCharge>[
          CrashpadCheckoutCharge(
            id: 'sfo-cleaning',
            name: 'Cleaning fee',
            description: 'Applied for missed checkout cleaning.',
            amount: 40,
            type: ChargeType.cleaning,
          ),
          CrashpadCheckoutCharge(
            id: 'sfo-custom',
            name: 'Custom owner charge',
            description: 'Owner-reviewed charge for unusual checkout items.',
            amount: 50,
            type: ChargeType.custom,
          ),
        ],
        minimumStayNights: 4,
        distanceToAirportMiles: 3.6,
      ),
    ];
  }

  static Map<String, List<Review>> reviewsByCrashpad(
    List<Crashpad> crashpads,
  ) {
    return <String, List<Review>>{
      for (final crashpad in crashpads)
        crashpad.id: <Review>[
          Review(
            employeeName: 'Alexandra Pierce',
            comment:
                'Clear house rules, easy airport access, and the bed setup matched what the listing promised.',
            rating: 4.8,
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          Review(
            employeeName: 'Marcus Chen',
            comment:
                'Clean common areas and transparent checkout expectations. I would book here again.',
            rating: 4.6,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
    };
  }

  static List<CrashpadBed> _beds(
    String prefix,
    int count, {
    required int assigned,
  }) {
    return List<CrashpadBed>.generate(count, (index) {
      final bedNumber = index + 1;
      final isAssigned = bedNumber <= assigned;
      return CrashpadBed(
        id: '$prefix-$bedNumber',
        label: 'Bed $bedNumber',
        isAssigned: isAssigned,
        isAvailable: true,
      );
    });
  }
}
