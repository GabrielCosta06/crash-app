import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../models/review.dart';

/// In-memory data source used to simulate authentication, listings,
/// reviews and theming state for the demo experience.
class AppRepository extends ChangeNotifier {
  AppRepository() {
    _seedData();
  }

  final Uuid _uuid = const Uuid();
  final List<AppUser> _users = [];
  final List<Crashpad> _crashpads = [];
  final Map<String, List<Review>> _reviewsByCrashpad = {};
  AppUser? _currentUser;
  bool _isDarkTheme = true; // Default to dark theme

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isDarkTheme => _isDarkTheme;

  List<Crashpad> get crashpads => List.unmodifiable(_crashpads);

  /// Toggles between light and dark themes.
  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  /// Forces the theme to the provided brightness.
  void setTheme(bool isDark) {
    _isDarkTheme = isDark;
    notifyListeners();
  }

  bool userExists(String email) =>
      _users.any((user) => user.email.toLowerCase() == email.toLowerCase());

  /// Authenticates a user with the provided credentials.
  Future<void> logIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final user = _users.firstWhere(
      (candidate) => candidate.email.toLowerCase() == email.toLowerCase(),
      orElse: () => throw AuthException('Account not found'),
    );

    if (user.password != password) {
      throw AuthException('Incorrect password');
    }
    _currentUser = user;
    notifyListeners();
  }

  /// Signs out the active user.
  Future<void> logOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
    notifyListeners();
  }

  /// Registers a new account and authenticates the user on success.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String countryOfBirth,
    required DateTime dateOfBirth,
    required AppUserType userType,
    String? company,
    String? badgeNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final alreadyExists = _users.any(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
    if (alreadyExists) {
      throw AuthException('An account with this email already exists');
    }

    final newUser = AppUser(
      id: _uuid.v4(),
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      countryOfBirth: countryOfBirth,
      dateOfBirth: dateOfBirth,
      userType: userType,
      company: company,
      badgeNumber: badgeNumber,
    );
    _users.add(newUser);
    _currentUser = newUser;
    notifyListeners();
  }

  /// Returns the list of available crashpads.
  Future<List<Crashpad>> fetchCrashpads() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_crashpads);
  }

  /// Fetches listings owned by the provided email.
  Future<List<Crashpad>> fetchOwnerCrashpads(String ownerEmail) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _crashpads
        .where((crashpad) =>
            crashpad.owner.contact?.toLowerCase() ==
            ownerEmail.toLowerCase())
        .toList();
  }

  /// Creates a new crashpad owned by the authenticated owner.
  Future<void> addCrashpad({
    required String name,
    required String description,
    required String location,
    required String nearestAirport,
    required String bedType,
    required double price,
    required List<String> imageUrls,
  }) async {
    final owner = _currentUser;
    if (owner == null || !owner.isOwner) {
      throw AuthException('Only authenticated owners can create listings.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final newCrashpad = Crashpad(
      id: _uuid.v4(),
      name: name,
      description: description,
      location: location,
      nearestAirport: nearestAirport,
      owner: Owner(name: owner.displayName, contact: owner.email),
      imageUrls: imageUrls,
      dateAdded: DateTime.now(),
      bedType: bedType,
      price: price,
      clickCount: 0,
    );
    _crashpads.insert(0, newCrashpad);
    notifyListeners();
  }

  /// Deletes multiple crashpads and their reviews.
  Future<void> deleteCrashpads(Set<String> crashpadIds) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _crashpads.removeWhere((crashpad) => crashpadIds.contains(crashpad.id));
    for (final id in crashpadIds) {
      _reviewsByCrashpad.remove(id);
    }
    notifyListeners();
  }

  /// Records a click on the provided crashpad identifier.
  Future<void> incrementClickCount(String crashpadId) async {
    final index =
        _crashpads.indexWhere((crashpad) => crashpad.id == crashpadId);
    if (index == -1) return;
    final updated = _crashpads[index]
        .copyWith(clickCount: _crashpads[index].clickCount + 1);
    _crashpads[index] = updated;
    notifyListeners();
  }

  /// Retrieves reviews for the given crashpad.
  Future<List<Review>> fetchReviews(String crashpadId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_reviewsByCrashpad[crashpadId] ?? []);
  }

  /// Persists a new review for the supplied crashpad.
  Future<void> addReview({
    required String crashpadId,
    required String employeeName,
    required String comment,
    required double rating,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final review = Review(
      employeeName: employeeName,
      comment: comment,
      rating: rating,
      createdAt: DateTime.now(),
    );
    _reviewsByCrashpad.putIfAbsent(crashpadId, () => []).add(review);
    notifyListeners();
  }

  /// Marks the active user as subscribed to premium features.
  Future<void> subscribeCurrentUser() async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('You must be logged in to subscribe.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _users.indexWhere((user) => user.id == current.id);
    if (index == -1) return;
    final updated = current.copyWith(isSubscribed: true);
    _users[index] = updated;
    if (identical(_currentUser, current)) {
      _currentUser = updated;
    }
    notifyListeners();
  }

  /// Updates the avatar for the authenticated user.
  Future<void> updateProfileAvatar(String base64Image) async {
    final current = _currentUser;
    if (current == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final updated = current.copyWith(avatarBase64: base64Image);
    final index = _users.indexWhere((user) => user.id == current.id);
    if (index != -1) {
      _users[index] = updated;
    }
    _currentUser = updated;
    notifyListeners();
  }

  double calculateAverageRating(String crashpadId) {
    final reviews = _reviewsByCrashpad[crashpadId];
    if (reviews == null || reviews.isEmpty) return 0.0;
    final total = reviews.fold<double>(
      0.0,
      (sum, review) => sum + review.rating,
    );
    return total / reviews.length;
  }

  void _seedData() {
    final owner = AppUser(
      id: _uuid.v4(),
      email: 'owner@crashpads.com',
      password: 'owner123',
      firstName: 'Gabriel',
      lastName: 'Costa',
      countryOfBirth: 'USA',
      dateOfBirth: DateTime(1988, 4, 12),
      userType: AppUserType.owner,
      isSubscribed: true,
    );

    final employee = AppUser(
      id: _uuid.v4(),
      email: 'crew@crashpads.com',
      password: 'flysafe',
      firstName: 'Rafael',
      lastName: 'Costa',
      countryOfBirth: 'Canada',
      dateOfBirth: DateTime(1992, 9, 3),
      userType: AppUserType.employee,
      company: 'SkyFusion Airways',
      badgeNumber: 'SF-8821',
    );

    _users
      ..clear()
      ..addAll([owner, employee]);

    _currentUser = null;

    final List<Map<String, dynamic>> mockCrashpadData = [
      {
        'name': 'Skyline Loft Haven',
        'description':
            'Immerse yourself in panoramic skyline vistas with smart mood lighting, ergonomic workspace, and soundproof rest pods designed for restorative layovers.',
        'location': '123 Aurora Ave, Seattle, WA, USA',
        'nearestAirport': 'SEA',
        'bedType': 'Hot Bed',
        'price': 139.0,
        'imageUrls': [
          'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=1200&q=80',
        ],
        'clickCount': 48,
      },
      {
        'name': 'Runway Retreat Capsule',
        'description':
            'Minimalist capsule suite with adaptive ambient lighting, integrated aromatherapy, and AI-assisted sleep tracking to sync with your next departure.',
        'location': '88 Velocity Blvd, Austin, TX, USA',
        'nearestAirport': 'AUS',
        'bedType': 'Cold Bed',
        'price': 98.5,
        'imageUrls': [
          'https://images.unsplash.com/photo-1493666438817-866a91353ca9?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1200&q=80',
        ],
        'clickCount': 27,
      },
      {
        'name': 'Altitude Zen Hub',
        'description':
            'Futuristic residence with chromed surfaces, biophilic walls, and biometric entry. Recharge in the meditation sphere or connect in the holo-collab lounge.',
        'location': '701 Quantum Pkwy, San Francisco, CA, USA',
        'nearestAirport': 'SFO',
        'bedType': 'Both',
        'price': 169.0,
        'imageUrls': [
          'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80',
        ],
        'clickCount': 65,
      },
    ];

    _crashpads
      ..clear()
      ..addAll(
        mockCrashpadData.map(
          (data) => Crashpad(
            id: _uuid.v4(),
            name: data['name'] as String,
            description: data['description'] as String,
            location: data['location'] as String,
            nearestAirport: data['nearestAirport'] as String,
            owner: Owner(name: owner.displayName, contact: owner.email),
            imageUrls:
                (data['imageUrls'] as List<dynamic>).cast<String>().toList(),
            dateAdded: DateTime.now()
                .subtract(Duration(days: Random().nextInt(30))),
            bedType: data['bedType'] as String,
            price: data['price'] as double,
            clickCount: data['clickCount'] as int,
          ),
        ),
      );

    _reviewsByCrashpad.clear();
    for (final crashpad in _crashpads) {
      _reviewsByCrashpad[crashpad.id] = [
        Review(
          employeeName: 'Alexandra Pierce',
          comment:
              'Loved the biometric entry and silent rest pods. Perfect reset between transatlantic rotations.',
          rating: 4.8,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Review(
          employeeName: 'Marcus Chen',
          comment:
              'Smart lighting + meditation sphere = instant calm. High-speed mesh network kept ops seamless.',
          rating: 4.6,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => jsonEncode({'message': message});
}
