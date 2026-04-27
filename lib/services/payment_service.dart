import '../models/booking.dart';
import '../models/payment.dart';

class PaymentService {
  const PaymentService();

  PaymentSummary buildSummary(BookingDraft draft) {
    return PaymentSummary(
      bookingSubtotal: draft.bookingSubtotal,
      additionalServices: draft.additionalServices,
      checkoutCharges: draft.checkoutCharges,
    );
  }

  PaymentSummary authorizeMockPayment(PaymentSummary summary) {
    return summary.copyWith(status: PaymentStatus.authorized);
  }

  PaymentSummary captureMockPayment(PaymentSummary summary) {
    if (summary.status == PaymentStatus.failed ||
        summary.status == PaymentStatus.refunded) {
      throw StateError('Only active payment authorizations can be captured.');
    }
    return summary.copyWith(status: PaymentStatus.paid);
  }

  PaymentSummary refundMockPayment(PaymentSummary summary) {
    if (summary.status == PaymentStatus.paid ||
        summary.status == PaymentStatus.authorized) {
      return summary.copyWith(status: PaymentStatus.refunded);
    }
    if (summary.status == PaymentStatus.draft) {
      return summary.copyWith(status: PaymentStatus.refunded);
    }
    throw StateError('This payment can no longer be refunded.');
  }

  PaymentSummary assessCheckoutCharges(
    PaymentSummary summary,
    List<ChargeLineItem> checkoutCharges,
  ) {
    if (summary.status == PaymentStatus.paid ||
        summary.status == PaymentStatus.refunded ||
        summary.status == PaymentStatus.failed) {
      throw StateError('Checkout charges can only be changed before capture.');
    }
    return summary.copyWith(
        checkoutCharges: List.unmodifiable(checkoutCharges));
  }
}
