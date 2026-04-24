import 'package:crash_pad/data/app_repository.dart';
import 'package:crash_pad/models/crashpad.dart';
import 'package:crash_pad/models/payment.dart';
import 'package:crash_pad/services/availability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner-created crashpad stores real room capacity and fees', () async {
    final repository = AppRepository();

    await repository.logIn('owner@crashpads.com', 'owner123');
    await repository.addCrashpad(
      name: 'Owner Test Crashpad',
      description: 'A full test listing with real operational values.',
      location: '100 Test Way, Denver, CO, USA',
      nearestAirport: 'DEN',
      bedType: CrashpadBedModel.flexible.label,
      price: 120,
      imageUrls: const <String>[],
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
}
