import 'dart:convert';

import 'payment.dart';

enum CrashpadBedModel {
  hot,
  cold,
  flexible,
}

extension CrashpadBedModelLabel on CrashpadBedModel {
  String get label {
    switch (this) {
      case CrashpadBedModel.hot:
        return 'Hot Bed';
      case CrashpadBedModel.cold:
        return 'Cold Bed';
      case CrashpadBedModel.flexible:
        return 'Both';
    }
  }

  String get shortLabel {
    switch (this) {
      case CrashpadBedModel.hot:
        return 'Hot';
      case CrashpadBedModel.cold:
        return 'Cold';
      case CrashpadBedModel.flexible:
        return 'Mixed';
    }
  }

  String get guestExplanation {
    switch (this) {
      case CrashpadBedModel.hot:
        return 'Shared rotating beds. Availability is based on active guest capacity, so you may use different sleeping spaces during the stay.';
      case CrashpadBedModel.cold:
        return 'Dedicated assigned bed. The bed is reserved for you during the stay and is not shared with another guest.';
      case CrashpadBedModel.flexible:
        return 'This crashpad supports both dedicated cold beds and rotating hot-bed capacity depending on room selection.';
    }
  }
}

CrashpadBedModel crashpadBedModelFromLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('cold')) return CrashpadBedModel.cold;
  if (normalized.contains('both') || normalized.contains('flex')) {
    return CrashpadBedModel.flexible;
  }
  return CrashpadBedModel.hot;
}

class CrashpadBed {
  const CrashpadBed({
    required this.id,
    required this.label,
    this.isAssigned = false,
    this.isAvailable = true,
  });

  final String id;
  final String label;
  final bool isAssigned;
  final bool isAvailable;
}

class CrashpadRoom {
  const CrashpadRoom({
    required this.id,
    required this.name,
    required this.bedModel,
    required this.beds,
    required this.activeGuests,
    required this.hotCapacity,
    this.storageNote,
  });

  final String id;
  final String name;
  final CrashpadBedModel bedModel;
  final List<CrashpadBed> beds;
  final int activeGuests;
  final int hotCapacity;
  final String? storageNote;

  int get physicalBeds => beds.length;

  int get assignedBeds => beds.where((bed) => bed.isAssigned).length;

  int get availableColdBeds =>
      beds.where((bed) => bed.isAvailable && !bed.isAssigned).length;

  int get availableHotSlots =>
      (hotCapacity - activeGuests).clamp(0, 999).toInt();
}

class CrashpadService {
  const CrashpadService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final double price;

  ChargeLineItem toLineItem() {
    return ChargeLineItem(
      id: id,
      label: name,
      amount: price,
      type: ChargeType.additionalService,
    );
  }
}

class CrashpadCheckoutCharge {
  const CrashpadCheckoutCharge({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.type,
  });

  final String id;
  final String name;
  final String description;
  final double amount;
  final ChargeType type;

  ChargeLineItem toLineItem() {
    return ChargeLineItem(
      id: id,
      label: name,
      amount: amount,
      type: type,
    );
  }
}

/// Domain model describing a crashpad listing.
class Crashpad {
  Crashpad({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.nearestAirport,
    required this.owner,
    required this.imageUrls,
    required this.dateAdded,
    required this.bedType,
    required this.price,
    required this.clickCount,
    this.rooms = const <CrashpadRoom>[],
    this.amenities = const <String>[],
    this.houseRules = const <String>[],
    this.services = const <CrashpadService>[],
    this.checkoutCharges = const <CrashpadCheckoutCharge>[],
    this.minimumStayNights = 1,
    this.distanceToAirportMiles,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final Owner owner;
  final List<String> imageUrls;
  final DateTime dateAdded;

  /// Kept for backwards compatibility with the original string-based model.
  final String bedType;
  final double price;
  final String nearestAirport;
  final int clickCount;
  final List<CrashpadRoom> rooms;
  final List<String> amenities;
  final List<String> houseRules;
  final List<CrashpadService> services;
  final List<CrashpadCheckoutCharge> checkoutCharges;
  final int minimumStayNights;
  final double? distanceToAirportMiles;

  CrashpadBedModel get bedModel => crashpadBedModelFromLabel(bedType);

  int get totalPhysicalBeds =>
      rooms.fold<int>(0, (total, room) => total + room.physicalBeds);

  int get totalActiveGuests =>
      rooms.fold<int>(0, (total, room) => total + room.activeGuests);

  /// Creates a [Crashpad] model from a remote response.
  factory Crashpad.fromJson(Map<String, dynamic> json) {
    List<String> images = [];
    final imageData = json['image_urls'];
    if (imageData != null) {
      if (imageData is String) {
        try {
          images = List<String>.from(jsonDecode(imageData));
        } catch (_) {
          images = [];
        }
      } else if (imageData is List) {
        images = List<String>.from(imageData);
      }
    }

    return Crashpad(
      id: json['id'] as String,
      name: json['name']?.toString() ?? 'Unnamed Crashpad',
      description:
          json['description']?.toString() ?? 'No description available',
      location: json['location']?.toString() ?? 'Location not specified',
      nearestAirport: json['nearest_airport']?.toString() ?? 'Unknown airport',
      owner: Owner.fromJson({
        'name': json['owner_name'] ?? 'Unknown Owner',
        'contact': json['owner_contact'],
      }),
      imageUrls: images,
      dateAdded: DateTime.parse(
        json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      bedType: json['bed_type']?.toString() ?? 'Hot Bed',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      clickCount: (json['click_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'nearest_airport': nearestAirport,
        'owner_name': owner.name,
        'owner_contact': owner.contact,
        'image_urls': jsonEncode(imageUrls),
        'created_at': dateAdded.toIso8601String(),
        'bed_type': bedType,
        'price': price,
        'click_count': clickCount,
      };

  Crashpad copyWith({
    String? name,
    String? description,
    String? location,
    Owner? owner,
    List<String>? imageUrls,
    DateTime? dateAdded,
    String? bedType,
    double? price,
    String? nearestAirport,
    int? clickCount,
    List<CrashpadRoom>? rooms,
    List<String>? amenities,
    List<String>? houseRules,
    List<CrashpadService>? services,
    List<CrashpadCheckoutCharge>? checkoutCharges,
    int? minimumStayNights,
    double? distanceToAirportMiles,
  }) {
    return Crashpad(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      owner: owner ?? this.owner,
      imageUrls: imageUrls ?? this.imageUrls,
      dateAdded: dateAdded ?? this.dateAdded,
      bedType: bedType ?? this.bedType,
      price: price ?? this.price,
      nearestAirport: nearestAirport ?? this.nearestAirport,
      clickCount: clickCount ?? this.clickCount,
      rooms: rooms ?? this.rooms,
      amenities: amenities ?? this.amenities,
      houseRules: houseRules ?? this.houseRules,
      services: services ?? this.services,
      checkoutCharges: checkoutCharges ?? this.checkoutCharges,
      minimumStayNights: minimumStayNights ?? this.minimumStayNights,
      distanceToAirportMiles:
          distanceToAirportMiles ?? this.distanceToAirportMiles,
    );
  }
}

/// Represents the owner metadata for a crashpad.
class Owner {
  const Owner({required this.name, this.contact});

  final String name;
  final String? contact;

  factory Owner.fromJson(Map<String, dynamic> json) => Owner(
        name: json['name']?.toString() ?? 'Unknown Owner',
        contact: json['contact']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact': contact,
      };

  Owner copyWith({
    String? name,
    String? contact,
  }) =>
      Owner(
        name: name ?? this.name,
        contact: contact ?? this.contact,
      );
}
