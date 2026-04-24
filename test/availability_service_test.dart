import 'package:crash_pad/models/crashpad.dart';
import 'package:crash_pad/services/availability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvailabilityService', () {
    test('cold beds count only unassigned available beds', () {
      final crashpad = _crashpad(
        rooms: <CrashpadRoom>[
          CrashpadRoom(
            id: 'cold-room',
            name: 'Cold Room',
            bedModel: CrashpadBedModel.cold,
            beds: const <CrashpadBed>[
              CrashpadBed(id: 'bed-1', label: 'Bed 1', isAssigned: true),
              CrashpadBed(id: 'bed-2', label: 'Bed 2'),
              CrashpadBed(id: 'bed-3', label: 'Bed 3'),
            ],
            activeGuests: 1,
            hotCapacity: 3,
          ),
        ],
      );

      final summary = const AvailabilityService().summarize(crashpad);

      expect(summary.totalPhysicalBeds, 3);
      expect(summary.availableColdBeds, 2);
      expect(summary.availableHotSlots, 0);
      expect(summary.availableToBook, 2);
    });

    test('hot beds use active guest capacity instead of assigned beds', () {
      final crashpad = _crashpad(
        bedType: CrashpadBedModel.hot.label,
        rooms: <CrashpadRoom>[
          CrashpadRoom(
            id: 'hot-room',
            name: 'Hot Room',
            bedModel: CrashpadBedModel.hot,
            beds: const <CrashpadBed>[
              CrashpadBed(id: 'bed-1', label: 'Bed 1'),
              CrashpadBed(id: 'bed-2', label: 'Bed 2'),
              CrashpadBed(id: 'bed-3', label: 'Bed 3'),
              CrashpadBed(id: 'bed-4', label: 'Bed 4'),
            ],
            activeGuests: 5,
            hotCapacity: 7,
          ),
        ],
      );

      final summary = const AvailabilityService().summarize(crashpad);

      expect(summary.totalPhysicalBeds, 4);
      expect(summary.availableColdBeds, 0);
      expect(summary.availableHotSlots, 2);
      expect(summary.availableToBook, 2);
    });
  });
}

Crashpad _crashpad({
  required List<CrashpadRoom> rooms,
  String bedType = 'Cold Bed',
}) {
  return Crashpad(
    id: 'listing',
    name: 'Test Crashpad',
    description: 'Test listing',
    location: 'Test City',
    nearestAirport: 'TST',
    owner: const Owner(name: 'Owner', contact: 'owner@example.com'),
    imageUrls: const <String>[],
    dateAdded: DateTime(2026, 1),
    bedType: bedType,
    price: 100,
    clickCount: 0,
    rooms: rooms,
  );
}
