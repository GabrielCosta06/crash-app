import '../config/app_config.dart';

enum ChargeType {
  booking,
  additionalService,
  checkout,
  cleaning,
  damage,
  lateCheckout,
  custom,
}

enum PaymentStatus {
  draft,
  authorized,
  paid,
  failed,
  refunded,
}

class ChargeLineItem {
  const ChargeLineItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.type,
  });

  final String id;
  final String label;
  final double amount;
  final ChargeType type;

  ChargeLineItem copyWith({
    String? id,
    String? label,
    double? amount,
    ChargeType? type,
  }) {
    return ChargeLineItem(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      type: type ?? this.type,
    );
  }
}

class PaymentSummary {
  const PaymentSummary({
    required this.bookingSubtotal,
    required this.additionalServices,
    required this.checkoutCharges,
    this.platformFeeRate = AppConfig.platformFeeRate,
    this.status = PaymentStatus.draft,
  });

  final double bookingSubtotal;
  final List<ChargeLineItem> additionalServices;
  final List<ChargeLineItem> checkoutCharges;
  final double platformFeeRate;
  final PaymentStatus status;

  double get additionalServicesTotal =>
      _sum(additionalServices.map((item) => item.amount));

  double get checkoutChargesTotal =>
      _sum(checkoutCharges.map((item) => item.amount));

  double get totalChargedToGuest => _roundCurrency(
        bookingSubtotal + additionalServicesTotal + checkoutChargesTotal,
      );

  double get platformFee =>
      _roundCurrency(totalChargedToGuest * platformFeeRate);

  double get ownerPayout => _roundCurrency(totalChargedToGuest - platformFee);

  List<ChargeLineItem> get allLineItems => <ChargeLineItem>[
        ChargeLineItem(
          id: 'booking-subtotal',
          label: 'Booking subtotal',
          amount: bookingSubtotal,
          type: ChargeType.booking,
        ),
        ...additionalServices,
        ...checkoutCharges,
      ];

  PaymentSummary copyWith({
    double? bookingSubtotal,
    List<ChargeLineItem>? additionalServices,
    List<ChargeLineItem>? checkoutCharges,
    double? platformFeeRate,
    PaymentStatus? status,
  }) {
    return PaymentSummary(
      bookingSubtotal: bookingSubtotal ?? this.bookingSubtotal,
      additionalServices: additionalServices ?? this.additionalServices,
      checkoutCharges: checkoutCharges ?? this.checkoutCharges,
      platformFeeRate: platformFeeRate ?? this.platformFeeRate,
      status: status ?? this.status,
    );
  }

  static double _sum(Iterable<double> amounts) {
    return _roundCurrency(
      amounts.fold<double>(0, (total, amount) => total + amount),
    );
  }

  static double _roundCurrency(double value) =>
      (value * 100).roundToDouble() / 100;
}
