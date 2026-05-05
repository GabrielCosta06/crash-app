import 'dart:convert';

import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/message_thread.dart';
import '../models/payment.dart';
import '../models/review.dart';

AppUser appUserFromProfile(Map<String, dynamic> row) {
  return AppUser(
    id: row['id'] as String,
    email: row['email']?.toString() ?? '',
    password: '',
    firstName: row['first_name']?.toString() ?? '',
    lastName: row['last_name']?.toString() ?? '',
    countryOfBirth: row['country_of_birth']?.toString() ?? '',
    dateOfBirth: DateTime.tryParse(row['date_of_birth']?.toString() ?? '') ??
        DateTime(1990),
    userType: (row['user_type']?.toString() ?? '') == AppUserType.owner.name
        ? AppUserType.owner
        : AppUserType.employee,
    company: row['company']?.toString(),
    badgeNumber: row['badge_number']?.toString(),
    avatarBase64: row['avatar_base64']?.toString(),
    isSubscribed: row['is_subscribed'] == true,
  );
}

Map<String, dynamic> profileToRow(AppUser user) => <String, dynamic>{
      'id': user.id,
      'email': user.email,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'country_of_birth': user.countryOfBirth,
      'date_of_birth': user.dateOfBirth.toIso8601String(),
      'user_type': user.userType.name,
      'company': user.company,
      'badge_number': user.badgeNumber,
      'avatar_base64': user.avatarBase64,
      'is_subscribed': user.isSubscribed,
    };

Crashpad crashpadFromRow(Map<String, dynamic> row) {
  return Crashpad(
    id: row['id'] as String,
    name: row['name']?.toString() ?? 'Unnamed Crashpad',
    description: row['description']?.toString() ?? '',
    location: row['location']?.toString() ?? '',
    nearestAirport: row['nearest_airport']?.toString() ?? '',
    owner: Owner(
      name: row['owner_name']?.toString() ?? 'Unknown Owner',
      contact: row['owner_email']?.toString(),
    ),
    imageUrls: _stringList(row['image_urls']),
    dateAdded: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
    bedType: row['bed_type']?.toString() ?? CrashpadBedModel.hot.label,
    price: _double(row['price']),
    clickCount: _int(row['click_count']),
    rooms: _rooms(row['rooms']),
    amenities: _stringList(row['amenities']),
    houseRules: _stringList(row['house_rules']),
    services: _services(row['services']),
    checkoutCharges: _checkoutCharges(row['checkout_charges']),
    minimumStayNights: _int(row['minimum_stay_nights'], fallback: 1),
    distanceToAirportMiles: _nullableDouble(row['distance_to_airport_miles']),
    latitude: _nullableDouble(row['latitude']),
    longitude: _nullableDouble(row['longitude']),
  );
}

Map<String, dynamic> crashpadToRow(Crashpad crashpad, String ownerId) {
  return <String, dynamic>{
    'id': crashpad.id,
    'owner_id': ownerId,
    'name': crashpad.name,
    'description': crashpad.description,
    'location': crashpad.location,
    'nearest_airport': crashpad.nearestAirport,
    'owner_name': crashpad.owner.name,
    'owner_email': crashpad.owner.contact,
    'image_urls': crashpad.imageUrls,
    'bed_type': crashpad.bedType,
    'price': crashpad.price,
    'click_count': crashpad.clickCount,
    'rooms': crashpad.rooms.map(_roomToJson).toList(),
    'amenities': crashpad.amenities,
    'house_rules': crashpad.houseRules,
    'services': crashpad.services.map(_serviceToJson).toList(),
    'checkout_charges':
        crashpad.checkoutCharges.map(_checkoutChargeToJson).toList(),
    'minimum_stay_nights': crashpad.minimumStayNights,
    'distance_to_airport_miles': crashpad.distanceToAirportMiles,
    'latitude': crashpad.latitude,
    'longitude': crashpad.longitude,
  };
}

BookingRecord bookingFromRow(Map<String, dynamic> row) {
  return BookingRecord(
    id: row['id'] as String,
    crashpadId: row['crashpad_id'] as String,
    crashpadName: row['crashpad_name']?.toString() ?? '',
    ownerEmail: row['owner_email']?.toString() ?? '',
    guestId: row['guest_id']?.toString() ?? '',
    guestName: row['guest_name']?.toString() ?? '',
    guestEmail: row['guest_email']?.toString() ?? '',
    checkInDate: DateTime.parse(row['check_in_date'] as String),
    checkOutDate: DateTime.parse(row['check_out_date'] as String),
    guestCount: _int(row['guest_count'], fallback: 1),
    paymentSummary: paymentSummaryFromJson(
      _map(row['payment_summary']),
    ),
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
    status: bookingStatusFromName(row['status']?.toString()),
    checkoutReport: _checkoutReport(row['checkout_report']),
    ownerCheckoutNote: row['owner_checkout_note']?.toString(),
    checkoutChargePaymentStatus: paymentStatusFromName(
      row['checkout_charge_payment_status']?.toString(),
    ),
    assignedRoomId: row['assigned_room_id']?.toString(),
    assignedRoomName: row['assigned_room_name']?.toString(),
    assignedBedId: row['assigned_bed_id']?.toString(),
    assignedBedLabel: row['assigned_bed_label']?.toString(),
    assignmentNote: row['assignment_note']?.toString(),
  );
}

Map<String, dynamic> bookingToRow(BookingRecord booking) => <String, dynamic>{
      'id': booking.id,
      'crashpad_id': booking.crashpadId,
      'crashpad_name': booking.crashpadName,
      'owner_email': booking.ownerEmail,
      'guest_id': booking.guestId,
      'guest_name': booking.guestName,
      'guest_email': booking.guestEmail,
      'check_in_date': booking.checkInDate.toIso8601String(),
      'check_out_date': booking.checkOutDate.toIso8601String(),
      'guest_count': booking.guestCount,
      'payment_summary': paymentSummaryToJson(booking.paymentSummary),
      'created_at': booking.createdAt.toIso8601String(),
      'status': booking.status.name,
      'checkout_report': booking.checkoutReport == null
          ? null
          : _checkoutReportToJson(booking.checkoutReport!),
      'owner_checkout_note': booking.ownerCheckoutNote,
      'checkout_charge_payment_status':
          booking.checkoutChargePaymentStatus.name,
      'assigned_room_id': booking.assignedRoomId,
      'assigned_room_name': booking.assignedRoomName,
      'assigned_bed_id': booking.assignedBedId,
      'assigned_bed_label': booking.assignedBedLabel,
      'assignment_note': booking.assignmentNote,
    };

PaymentSummary paymentSummaryFromJson(Map<String, dynamic> json) {
  return PaymentSummary(
    bookingSubtotal: _double(json['bookingSubtotal']),
    additionalServices: _lineItems(json['additionalServices']),
    checkoutCharges: _lineItems(json['checkoutCharges']),
    platformFeeRate: _double(
      json['platformFeeRate'],
      fallback: 0.02,
    ),
    status: paymentStatusFromName(json['status']?.toString()),
  );
}

Map<String, dynamic> paymentSummaryToJson(PaymentSummary summary) {
  return <String, dynamic>{
    'bookingSubtotal': summary.bookingSubtotal,
    'additionalServices':
        summary.additionalServices.map(_lineItemToJson).toList(),
    'checkoutCharges': summary.checkoutCharges.map(_lineItemToJson).toList(),
    'platformFeeRate': summary.platformFeeRate,
    'status': summary.status.name,
  };
}

Review reviewFromRow(Map<String, dynamic> row) {
  return Review(
    employeeName: row['employee_name']?.toString() ?? '',
    comment: row['comment']?.toString() ?? '',
    rating: _double(row['rating']),
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

MessageThread messageThreadFromRows({
  required Map<String, dynamic> thread,
  required List<Map<String, dynamic>> messages,
}) {
  return MessageThread(
    id: thread['id'] as String,
    crashpadId: thread['crashpad_id'] as String,
    crashpadName: thread['crashpad_name']?.toString() ?? '',
    guestId: thread['guest_id']?.toString() ?? '',
    ownerId: thread['owner_id']?.toString() ?? '',
    lastActivity:
        DateTime.tryParse(thread['last_activity']?.toString() ?? '') ??
            DateTime.now(),
    messages: messages
        .map(
          (message) => ChatMessage(
            id: message['id'] as String,
            senderId: message['sender_id'] as String,
            text: message['body']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(message['created_at']?.toString() ?? '') ??
                    DateTime.now(),
          ),
        )
        .toList(),
  );
}

BookingStatus bookingStatusFromName(String? value) {
  return BookingStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => BookingStatus.pending,
  );
}

PaymentStatus paymentStatusFromName(String? value) {
  return PaymentStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => PaymentStatus.draft,
  );
}

List<String> _stringList(Object? value) {
  final decoded = _decoded(value);
  if (decoded is List) return decoded.map((item) => item.toString()).toList();
  return const <String>[];
}

List<CrashpadRoom> _rooms(Object? value) {
  final decoded = _decoded(value);
  if (decoded is! List) return const <CrashpadRoom>[];
  return decoded.map((item) {
    final json = _map(item);
    return CrashpadRoom(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      bedModel: crashpadBedModelFromLabel(json['bedModel']?.toString() ?? ''),
      beds: (_decoded(json['beds']) as List? ?? const []).map((bed) {
        final bedJson = _map(bed);
        return CrashpadBed(
          id: bedJson['id']?.toString() ?? '',
          label: bedJson['label']?.toString() ?? '',
          isAssigned: bedJson['isAssigned'] == true,
          isAvailable: bedJson['isAvailable'] != false,
        );
      }).toList(),
      activeGuests: _int(json['activeGuests']),
      hotCapacity: _int(json['hotCapacity']),
      storageNote: json['storageNote']?.toString(),
    );
  }).toList();
}

List<CrashpadService> _services(Object? value) {
  final decoded = _decoded(value);
  if (decoded is! List) return const <CrashpadService>[];
  return decoded.map((item) {
    final json = _map(item);
    return CrashpadService(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _double(json['price']),
    );
  }).toList();
}

List<CrashpadCheckoutCharge> _checkoutCharges(Object? value) {
  final decoded = _decoded(value);
  if (decoded is! List) return const <CrashpadCheckoutCharge>[];
  return decoded.map((item) {
    final json = _map(item);
    return CrashpadCheckoutCharge(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: _double(json['amount']),
      type: ChargeType.values.firstWhere(
        (type) => type.name == json['type']?.toString(),
        orElse: () => ChargeType.custom,
      ),
    );
  }).toList();
}

List<ChargeLineItem> _lineItems(Object? value) {
  final decoded = _decoded(value);
  if (decoded is! List) return const <ChargeLineItem>[];
  return decoded.map((item) {
    final json = _map(item);
    return ChargeLineItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      amount: _double(json['amount']),
      type: ChargeType.values.firstWhere(
        (type) => type.name == json['type']?.toString(),
        orElse: () => ChargeType.custom,
      ),
    );
  }).toList();
}

CheckoutReport? _checkoutReport(Object? value) {
  if (value == null) return null;
  final json = _map(value);
  return CheckoutReport(
    notes: json['notes']?.toString() ?? '',
    photos: (_decoded(json['photos']) as List? ?? const []).map((item) {
      final photo = _map(item);
      return CheckoutPhoto(
        id: photo['id']?.toString() ?? '',
        fileName: photo['fileName']?.toString() ?? '',
        base64Data: photo['base64Data']?.toString() ?? '',
        capturedAt: DateTime.tryParse(photo['capturedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList(),
    submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

Map<String, dynamic> _roomToJson(CrashpadRoom room) => <String, dynamic>{
      'id': room.id,
      'name': room.name,
      'bedModel': room.bedModel.label,
      'beds': room.beds
          .map(
            (bed) => <String, dynamic>{
              'id': bed.id,
              'label': bed.label,
              'isAssigned': bed.isAssigned,
              'isAvailable': bed.isAvailable,
            },
          )
          .toList(),
      'activeGuests': room.activeGuests,
      'hotCapacity': room.hotCapacity,
      'storageNote': room.storageNote,
    };

Map<String, dynamic> _serviceToJson(CrashpadService service) =>
    <String, dynamic>{
      'id': service.id,
      'name': service.name,
      'description': service.description,
      'price': service.price,
    };

Map<String, dynamic> _checkoutChargeToJson(CrashpadCheckoutCharge charge) =>
    <String, dynamic>{
      'id': charge.id,
      'name': charge.name,
      'description': charge.description,
      'amount': charge.amount,
      'type': charge.type.name,
    };

Map<String, dynamic> _lineItemToJson(ChargeLineItem item) => <String, dynamic>{
      'id': item.id,
      'label': item.label,
      'amount': item.amount,
      'type': item.type.name,
    };

Map<String, dynamic> _checkoutReportToJson(CheckoutReport report) {
  return <String, dynamic>{
    'notes': report.notes,
    'submittedAt': report.submittedAt.toIso8601String(),
    'photos': report.photos
        .map(
          (photo) => <String, dynamic>{
            'id': photo.id,
            'fileName': photo.fileName,
            'base64Data': photo.base64Data,
            'capturedAt': photo.capturedAt.toIso8601String(),
          },
        )
        .toList(),
  };
}

Object? _decoded(Object? value) {
  if (value is String) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }
  return value;
}

Map<String, dynamic> _map(Object? value) {
  final decoded = _decoded(value);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
