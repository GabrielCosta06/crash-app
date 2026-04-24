class ListingContentService {
  const ListingContentService();

  static const List<String> amenityPresets = <String>[
    'Wi-Fi',
    'Laundry',
    'Shared kitchen',
    'Secure entry',
    'Blackout curtains',
    'Individual storage',
    'Parking',
    'Airport shuttle nearby',
    'Quiet workspace',
    'Weekly cleaning',
    'Fresh linens',
    'Crew-only property',
  ];

  static const List<String> houseRulePresets = <String>[
    'Quiet hours after 10 PM',
    'Clean shared spaces after use',
    'Crew members only',
    'No outside overnight guests',
    'Label stored bedding',
    'Respect assigned cold beds',
    'Hot-bed guests rotate based on arrival',
    'Report damage before checkout',
    'No smoking indoors',
    'Kitchen closes for cleaning at 9 PM',
  ];

  String normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? validateCustomAmenity(String value) {
    return _validateCustomItem(value, label: 'Amenity');
  }

  String? validateCustomRule(String value) {
    return _validateCustomItem(value, label: 'House rule');
  }

  List<String> normalizeSelection(Iterable<String> values) {
    final normalized = <String>[];
    for (final value in values) {
      final item = normalize(value);
      if (item.isNotEmpty &&
          !normalized.any(
            (existing) => existing.toLowerCase() == item.toLowerCase(),
          )) {
        normalized.add(item);
      }
    }
    return normalized;
  }

  String? _validateCustomItem(String value, {required String label}) {
    final normalized = normalize(value);
    if (normalized.length < 3) return '$label is too short';
    if (normalized.length > 56) return '$label must be 56 characters or less';
    if (!RegExp(r'[A-Za-z]').hasMatch(normalized)) {
      return '$label must include readable text';
    }
    if (RegExp(r'https?:\/\/|www\.|@').hasMatch(normalized.toLowerCase())) {
      return 'Do not add links, emails, or contact info here';
    }
    if (RegExp(r'(\+?\d[\d\s().-]{7,}\d)').hasMatch(normalized)) {
      return 'Do not add phone numbers here';
    }
    if (RegExp(r'[<>={}\[\]\\|]').hasMatch(normalized)) {
      return 'Remove special formatting characters';
    }
    return null;
  }
}
