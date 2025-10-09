import 'dart:convert';

enum AppUserType { owner, employee }

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.countryOfBirth,
    required this.dateOfBirth,
    required this.userType,
    this.company,
    this.badgeNumber,
    this.avatarBase64,
    this.isSubscribed = false,
  });

  final String id;
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String countryOfBirth;
  final DateTime dateOfBirth;
  final AppUserType userType;
  final String? company;
  final String? badgeNumber;
  final String? avatarBase64;
  bool isSubscribed;

  String get displayName => '$firstName $lastName';
  bool get isOwner => userType == AppUserType.owner;
  bool get isEmployee => userType == AppUserType.employee;

  String get initials =>
      ('${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}')
          .toUpperCase();

  AppUser copyWith({
    bool? isSubscribed,
    String? avatarBase64,
  }) {
    return AppUser(
      id: id,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      countryOfBirth: countryOfBirth,
      dateOfBirth: dateOfBirth,
      userType: userType,
      company: company,
      badgeNumber: badgeNumber,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'countryOfBirth': countryOfBirth,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'userType': userType.name,
        'company': company,
        'badgeNumber': badgeNumber,
        'avatarBase64': avatarBase64,
        'isSubscribed': isSubscribed,
      };

  String toJson() => jsonEncode(toMap());
}
