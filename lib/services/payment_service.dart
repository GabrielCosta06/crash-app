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
    return summary.copyWith(status: PaymentStatus.paid);
  }
}
