import 'dart:convert';

/// Domain model describing a crashpad listing.
class Crashpad {
  final String id;
  final String name;
  final String description;
  final String location;
  final Owner owner;
  final List<String> imageUrls;
  final DateTime dateAdded;
  final String bedType;
  final double price;
  final String nearestAirport;
  final int clickCount;

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
  });

  /// Creates a [Crashpad] model from a remote response.
  factory Crashpad.fromJson(Map<String, dynamic> json) {
    // Parse image URLs from JSON array string or list
    List<String> images = [];
    final imageData = json['image_urls'];
    if (imageData != null) {
      if (imageData is String) {
        try {
          images = List<String>.from(jsonDecode(imageData));
        } catch (e) {
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
          json['created_at'] ?? DateTime.now().toIso8601String()),
      bedType: json['bed_type']?.toString() ?? 'Unknown bed type',
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
    );
  }
}

/// Represents the owner metadata for a crashpad.
class Owner {
  final String name;
  final String? contact;

  Owner({required this.name, this.contact});

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
