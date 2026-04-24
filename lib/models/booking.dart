import 'payment.dart';

enum BookingStatus {
  draft,
  pending,
  confirmed,
  active,
  completed,
  cancelled,
}

class BookingDraft {
  const BookingDraft({
    required this.crashpadId,
    required this.guestId,
    required this.nightlyRate,
    required this.nights,
    required this.guestCount,
    this.additionalServices = const <ChargeLineItem>[],
    this.checkoutCharges = const <ChargeLineItem>[],
    this.status = BookingStatus.draft,
  });

  final String crashpadId;
  final String guestId;
  final double nightlyRate;
  final int nights;
  final int guestCount;
  final List<ChargeLineItem> additionalServices;
  final List<ChargeLineItem> checkoutCharges;
  final BookingStatus status;

  double get bookingSubtotal => nightlyRate * nights * guestCount;

  BookingDraft copyWith({
    String? crashpadId,
    String? guestId,
    double? nightlyRate,
    int? nights,
    int? guestCount,
    List<ChargeLineItem>? additionalServices,
    List<ChargeLineItem>? checkoutCharges,
    BookingStatus? status,
  }) {
    return BookingDraft(
      crashpadId: crashpadId ?? this.crashpadId,
      guestId: guestId ?? this.guestId,
      nightlyRate: nightlyRate ?? this.nightlyRate,
      nights: nights ?? this.nights,
      guestCount: guestCount ?? this.guestCount,
      additionalServices: additionalServices ?? this.additionalServices,
      checkoutCharges: checkoutCharges ?? this.checkoutCharges,
      status: status ?? this.status,
    );
  }
}
