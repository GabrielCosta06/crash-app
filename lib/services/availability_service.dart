import '../models/crashpad.dart';

class AvailabilitySummary {
  const AvailabilitySummary({
    required this.totalPhysicalBeds,
    required this.availableColdBeds,
    required this.hotCapacity,
    required this.activeHotGuests,
  });

  final int totalPhysicalBeds;
  final int availableColdBeds;
  final int hotCapacity;
  final int activeHotGuests;

  int get availableHotSlots =>
      (hotCapacity - activeHotGuests).clamp(0, 999).toInt();

  int get availableToBook => availableColdBeds + availableHotSlots;

  bool get hasAvailability => availableToBook > 0;
}

class AvailabilityService {
  const AvailabilityService();

  AvailabilitySummary summarize(Crashpad crashpad) {
    var totalPhysicalBeds = 0;
    var availableColdBeds = 0;
    var hotCapacity = 0;
    var activeHotGuests = 0;

    for (final room in crashpad.rooms) {
      totalPhysicalBeds += room.physicalBeds;
      switch (room.bedModel) {
        case CrashpadBedModel.cold:
          availableColdBeds += room.availableColdBeds;
          break;
        case CrashpadBedModel.hot:
          hotCapacity += room.hotCapacity;
          activeHotGuests += room.activeGuests;
          break;
        case CrashpadBedModel.flexible:
          availableColdBeds += room.availableColdBeds;
          hotCapacity += room.hotCapacity;
          activeHotGuests += room.activeGuests;
          break;
      }
    }

    return AvailabilitySummary(
      totalPhysicalBeds: totalPhysicalBeds,
      availableColdBeds: availableColdBeds,
      hotCapacity: hotCapacity,
      activeHotGuests: activeHotGuests,
    );
  }

  bool canBook(Crashpad crashpad, {int guests = 1}) {
    return summarize(crashpad).availableToBook >= guests;
  }
}
