import 'payment.dart';

enum BookingStatus {
  draft,
  pending,
  confirmed,
  active,
  completed,
  cancelled,
}

extension BookingStatusLabel on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.draft:
        return 'Draft';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.active:
        return 'Checked in';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class BookingDraft {
  BookingDraft({
    required this.crashpadId,
    required this.guestId,
    required this.nightlyRate,
    required this.checkInDate,
    required this.checkOutDate,
    required this.guestCount,
    this.additionalServices = const <ChargeLineItem>[],
    this.checkoutCharges = const <ChargeLineItem>[],
    this.status = BookingStatus.draft,
  }) {
    if (!checkOutDate.isAfter(checkInDate)) {
      throw ArgumentError.value(
        checkOutDate,
        'checkOutDate',
        'Booking check-out date must be after check-in date.',
      );
    }
  }

  final String crashpadId;
  final String guestId;
  final double nightlyRate;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int guestCount;
  final List<ChargeLineItem> additionalServices;
  final List<ChargeLineItem> checkoutCharges;
  final BookingStatus status;

  int get nights => checkOutDate.difference(checkInDate).inDays;

  double get bookingSubtotal => nightlyRate * nights * guestCount;

  BookingDraft copyWith({
    String? crashpadId,
    String? guestId,
    double? nightlyRate,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? guestCount,
    List<ChargeLineItem>? additionalServices,
    List<ChargeLineItem>? checkoutCharges,
    BookingStatus? status,
  }) {
    return BookingDraft(
      crashpadId: crashpadId ?? this.crashpadId,
      guestId: guestId ?? this.guestId,
      nightlyRate: nightlyRate ?? this.nightlyRate,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      guestCount: guestCount ?? this.guestCount,
      additionalServices: additionalServices ?? this.additionalServices,
      checkoutCharges: checkoutCharges ?? this.checkoutCharges,
      status: status ?? this.status,
    );
  }
}

class BookingRecord {
  BookingRecord({
    required this.id,
    required this.crashpadId,
    required this.crashpadName,
    required this.ownerEmail,
    required this.guestId,
    required this.guestName,
    required this.guestEmail,
    required this.checkInDate,
    required this.checkOutDate,
    required this.guestCount,
    required this.paymentSummary,
    required this.createdAt,
    this.status = BookingStatus.confirmed,
  }) {
    if (!checkOutDate.isAfter(checkInDate)) {
      throw ArgumentError.value(
        checkOutDate,
        'checkOutDate',
        'Booking check-out date must be after check-in date.',
      );
    }
  }

  final String id;
  final String crashpadId;
  final String crashpadName;
  final String ownerEmail;
  final String guestId;
  final String guestName;
  final String guestEmail;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int guestCount;
  final PaymentSummary paymentSummary;
  final DateTime createdAt;
  final BookingStatus status;

  int get nights => checkOutDate.difference(checkInDate).inDays;

  BookingRecord copyWith({
    BookingStatus? status,
    PaymentSummary? paymentSummary,
  }) {
    return BookingRecord(
      id: id,
      crashpadId: crashpadId,
      crashpadName: crashpadName,
      ownerEmail: ownerEmail,
      guestId: guestId,
      guestName: guestName,
      guestEmail: guestEmail,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      guestCount: guestCount,
      paymentSummary: paymentSummary ?? this.paymentSummary,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}
