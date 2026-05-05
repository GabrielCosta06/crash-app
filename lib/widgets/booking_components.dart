import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

final NumberFormat _money = NumberFormat.currency(symbol: r'$');
final DateFormat _date = DateFormat('MMM d');

class BookingStatusStyle {
  const BookingStatusStyle({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

BookingStatusStyle bookingStatusStyle(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return const BookingStatusStyle(
        label: 'Pending owner approval',
        description: 'The owner needs to approve or decline this request.',
        icon: Icons.hourglass_top_outlined,
        color: AppPalette.warning,
      );
    case BookingStatus.awaitingPayment:
      return const BookingStatusStyle(
        label: 'Awaiting guest payment',
        description: 'The owner approved this stay. Guest payment is next.',
        icon: Icons.credit_card_outlined,
        color: AppPalette.blueSoft,
      );
    case BookingStatus.confirmed:
      return const BookingStatusStyle(
        label: 'Confirmed',
        description: 'The stay is approved and ready for arrival.',
        icon: Icons.verified_outlined,
        color: AppPalette.success,
      );
    case BookingStatus.cancelled:
      return const BookingStatusStyle(
        label: 'Cancelled',
        description: 'This request is closed and no longer active.',
        icon: Icons.cancel_outlined,
        color: AppPalette.danger,
      );
    case BookingStatus.active:
      return const BookingStatusStyle(
        label: 'Checked in',
        description: 'The guest is currently staying at this crashpad.',
        icon: Icons.login_outlined,
        color: AppPalette.blueSoft,
      );
    case BookingStatus.completed:
      return const BookingStatusStyle(
        label: 'Completed',
        description: 'The stay is complete.',
        icon: Icons.done_all_outlined,
        color: AppPalette.cyan,
      );
    case BookingStatus.draft:
      return const BookingStatusStyle(
        label: 'Draft',
        description: 'This request has not been submitted.',
        icon: Icons.edit_calendar_outlined,
        color: AppPalette.textMuted,
      );
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final style = bookingStatusStyle(status);
    return StatusBadge(
      label: style.label,
      icon: style.icon,
      color: style.color,
    );
  }
}

class BookingPriceSummaryCard extends StatelessWidget {
  const BookingPriceSummaryCard({
    super.key,
    required this.nightlyRate,
    required this.nights,
    required this.guestCount,
    required this.summary,
    this.title = 'Price summary',
    this.showStatus = false,
  });

  final double nightlyRate;
  final int nights;
  final int guestCount;
  final PaymentSummary summary;
  final String title;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final rateLabel =
        '${_money.format(nightlyRate)} x $nights night${nights == 1 ? '' : 's'}';
    final guestSuffix = guestCount > 1 ? ' x $guestCount guests' : '';
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (showStatus)
                StatusBadge(
                  label: _paymentStatusLabel(summary.status),
                  icon: Icons.payments_outlined,
                  color: summary.status == PaymentStatus.failed
                      ? AppPalette.danger
                      : AppPalette.blueSoft,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _MoneyRow(
              label: '$rateLabel$guestSuffix', value: summary.bookingSubtotal),
          if (summary.additionalServicesTotal > 0)
            _MoneyRow(
              label: 'Selected services',
              value: summary.additionalServicesTotal,
            ),
          if (summary.checkoutChargesTotal > 0)
            _MoneyRow(
              label: 'Checkout charges',
              value: summary.checkoutChargesTotal,
            ),
          const Divider(height: 28),
          _MoneyRow(
            label: 'Total',
            value: summary.totalChargedToGuest,
            emphasized: true,
          ),
        ],
      ),
    );
  }

  String _paymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.draft:
        return 'Estimate';
      case PaymentStatus.awaitingPayment:
        return 'Payment due';
      case PaymentStatus.authorized:
        return 'Pay later';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

class BookingRecordCard extends StatelessWidget {
  const BookingRecordCard({
    super.key,
    required this.booking,
    required this.perspective,
    this.primaryAction,
    this.secondaryAction,
  });

  final BookingRecord booking;
  final BookingPerspective perspective;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final style = bookingStatusStyle(booking.status);
    final person = perspective == BookingPerspective.owner
        ? booking.guestName
        : booking.ownerEmail;
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadius.lg,
      borderColor: style.color.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.crashpadName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      person,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppPalette.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              BookingStatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              StatusBadge(
                label:
                    '${_date.format(booking.checkInDate)} - ${_date.format(booking.checkOutDate)}',
                icon: Icons.date_range_outlined,
                color: AppPalette.blueSoft,
              ),
              StatusBadge(
                label:
                    '${booking.nights} night${booking.nights == 1 ? '' : 's'}',
                icon: Icons.nights_stay_outlined,
                color: AppPalette.cyan,
              ),
              StatusBadge(
                label:
                    _money.format(booking.paymentSummary.totalChargedToGuest),
                icon: Icons.payments_outlined,
                color: AppPalette.success,
              ),
              StatusBadge(
                label: _paymentStatusLabel(booking.paymentSummary.status),
                icon: Icons.account_balance_wallet_outlined,
                color: _paymentStatusColor(booking.paymentSummary.status),
              ),
              if (booking.paymentSummary.checkoutChargesTotal > 0)
                StatusBadge(
                  label:
                      '${_money.format(booking.paymentSummary.checkoutChargesTotal)} checkout ${_checkoutChargeStatusLabel(booking.checkoutChargePaymentStatus)}',
                  icon: Icons.receipt_long_outlined,
                  color:
                      booking.checkoutChargePaymentStatus == PaymentStatus.paid
                          ? AppPalette.success
                          : AppPalette.warning,
                ),
              if (booking.hasManualAssignment)
                StatusBadge(
                  label: booking.assignedBedLabel == null
                      ? 'Assigned: ${booking.assignedRoomName}'
                      : 'Assigned: ${booking.assignedRoomName} / ${booking.assignedBedLabel}',
                  icon: Icons.assignment_ind_outlined,
                  color: AppPalette.blueSoft,
                ),
              if (booking.checkoutReport != null)
                StatusBadge(
                  label:
                      'Checkout report ${booking.checkoutReport!.photos.length} photo${booking.checkoutReport!.photos.length == 1 ? '' : 's'}',
                  icon: Icons.photo_camera_outlined,
                  color: AppPalette.cyan,
                ),
            ],
          ),
          if (primaryAction != null || secondaryAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                if (primaryAction != null) primaryAction!,
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _paymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.draft:
        return 'Quote';
      case PaymentStatus.awaitingPayment:
        return 'Payment due';
      case PaymentStatus.authorized:
        return 'Authorized';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color _paymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppPalette.success;
      case PaymentStatus.failed:
      case PaymentStatus.refunded:
        return AppPalette.danger;
      case PaymentStatus.draft:
      case PaymentStatus.awaitingPayment:
      case PaymentStatus.authorized:
        return AppPalette.blueSoft;
    }
  }

  String _checkoutChargeStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.awaitingPayment:
        return 'due';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
      case PaymentStatus.draft:
      case PaymentStatus.authorized:
        return 'staged';
    }
  }
}

enum BookingPerspective { guest, owner }

class BookingEmptyState extends StatelessWidget {
  const BookingEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return EmptyStatePanel(
      icon: Icons.event_busy_outlined,
      title: title,
      message: message,
      action: action,
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                color: emphasized ? AppPalette.text : AppPalette.textMuted,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _money.format(value),
            style: style?.copyWith(
              color: emphasized ? AppPalette.text : AppPalette.text,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
