/// Public airport location used by the discovery map.
class Airport {
  const Airport({
    required this.code,
    required this.name,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
  });

  final String code;
  final String name;
  final String city;
  final String state;
  final double latitude;
  final double longitude;

  String get displayLocation => '$city, $state';
}
