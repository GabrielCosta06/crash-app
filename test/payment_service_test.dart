import 'package:crash_pad/config/app_config.dart';
import 'package:crash_pad/models/booking.dart';
import 'package:crash_pad/models/payment.dart';
import 'package:crash_pad/services/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentService', () {
    test('calculates guest charge, Crash App fee, and owner payout', () {
      const service = PaymentService();
      final checkIn = DateTime(2026, 1, 1);

      final summary = service.buildSummary(
        BookingDraft(
          crashpadId: 'listing-1',
          guestId: 'guest-1',
          nightlyRate: 1000,
          checkInDate: checkIn,
          checkOutDate: checkIn.add(const Duration(days: 1)),
          guestCount: 1,
          additionalServices: <ChargeLineItem>[
            ChargeLineItem(
              id: 'service-1',
              label: 'Additional services',
              amount: 50,
              type: ChargeType.additionalService,
            ),
          ],
          checkoutCharges: <ChargeLineItem>[
            ChargeLineItem(
              id: 'checkout-1',
              label: 'Checkout charges',
              amount: 25,
              type: ChargeType.checkout,
            ),
          ],
        ),
      );

      expect(summary.totalChargedToGuest, 1075);
      expect(summary.platformFeeRate, AppConfig.platformFeeRate);
      expect(summary.platformFee, 21.5);
      expect(summary.ownerPayout, 1053.5);
    });

    test('mock payment transitions are explicit', () {
      const service = PaymentService();
      const summary = PaymentSummary(
        bookingSubtotal: 100,
        additionalServices: <ChargeLineItem>[],
        checkoutCharges: <ChargeLineItem>[],
      );

      expect(service.authorizeMockPayment(summary).status,
          PaymentStatus.authorized);
      expect(service.captureMockPayment(summary).status, PaymentStatus.paid);
    });
  });
}
