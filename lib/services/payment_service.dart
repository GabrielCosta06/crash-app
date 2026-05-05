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

  PaymentSummary markAuthorized(PaymentSummary summary) {
    return summary.copyWith(status: PaymentStatus.authorized);
  }

  PaymentSummary markAwaitingPayment(PaymentSummary summary) {
    return summary.copyWith(status: PaymentStatus.awaitingPayment);
  }

  PaymentSummary markPaid(PaymentSummary summary) {
    if (summary.status == PaymentStatus.failed ||
        summary.status == PaymentStatus.refunded) {
      throw StateError('Only active payment states can be marked paid.');
    }
    return summary.copyWith(status: PaymentStatus.paid);
  }

  PaymentSummary markRefunded(PaymentSummary summary) {
    if (summary.status == PaymentStatus.paid ||
        summary.status == PaymentStatus.awaitingPayment ||
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
    if (summary.status == PaymentStatus.refunded ||
        summary.status == PaymentStatus.failed) {
      throw StateError(
        'Checkout charges cannot be changed after failure or refund.',
      );
    }
    return summary.copyWith(
        checkoutCharges: List.unmodifiable(checkoutCharges));
  }
}
