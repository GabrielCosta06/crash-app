import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/booking_components.dart';
import '../widgets/interaction_feedback.dart';

final DateFormat _date = DateFormat('MMM d, yyyy');

class CheckoutArguments {
  const CheckoutArguments({
    required this.crashpad,
    required this.draft,
    required this.summary,
  });

  final Crashpad crashpad;
  final BookingDraft draft;
  final PaymentSummary summary;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.arguments});

  final CheckoutArguments arguments;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final PaymentService _paymentService = const PaymentService();
  bool _isSubmitting = false;
  String? _error;
  BookingRecord? _booking;

  Future<void> _requestBooking() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || !user.isEmployee) {
      setState(
        () => _error = 'Sign in as a crew guest before requesting this stay.',
      );
      return;
    }
    if (!widget.arguments.draft.checkOutDate
        .isAfter(widget.arguments.draft.checkInDate)) {
      setState(
        () => _error = 'Choose a check-out date after the check-in date.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final authorized = _paymentService.authorizeMockPayment(
        widget.arguments.summary,
      );
      final booking = await repository.createBooking(
        crashpad: widget.arguments.crashpad,
        draft: widget.arguments.draft,
        paymentSummary: authorized,
      );
      if (!mounted) return;
      setState(() => _booking = booking);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'We could not send this booking request. ${_friendlyError(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _finish() => Navigator.pop(context, _booking);

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      appBar: AppBar(
        leading: AnimatedBackButton(
          onPressed: _isSubmitting ? () {} : _finish,
        ),
        title: Text(booking == null ? 'Review booking' : 'Request sent'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 1080,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: booking == null
                  ? _RequestReview(
                      key: const ValueKey<String>('review'),
                      crashpad: widget.arguments.crashpad,
                      draft: widget.arguments.draft,
                      summary: widget.arguments.summary,
                      error: _error,
                      isSubmitting: _isSubmitting,
                      onRequest: _requestBooking,
                    )
                  : _PendingConfirmation(
                      key: const ValueKey<String>('pending'),
                      booking: booking,
                      onDone: _finish,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestReview extends StatelessWidget {
  const _RequestReview({
    super.key,
    required this.crashpad,
    required this.draft,
    required this.summary,
    required this.error,
    required this.isSubmitting,
    required this.onRequest,
  });

  final Crashpad crashpad;
  final BookingDraft draft;
  final PaymentSummary summary;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
        final stay = _StayReviewCard(crashpad: crashpad, draft: draft);
        final price = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BookingPriceSummaryCard(
              nightlyRate: draft.nightlyRate,
              nights: draft.nights,
              guestCount: draft.guestCount,
              summary: summary,
              title: 'Price before owner approval',
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _ErrorPanel(message: error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onRequest,
                icon: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  isSubmitting ? 'Sending request...' : 'Confirm & Pay Later',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mock checkout only. The owner approves the request before the stay is confirmed.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              stay,
              const SizedBox(height: AppSpacing.xxl),
              price,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 6, child: stay),
            const SizedBox(width: AppSpacing.xxxl),
            Expanded(flex: 5, child: price),
          ],
        );
      },
    );
  }
}

class _StayReviewCard extends StatelessWidget {
  const _StayReviewCard({required this.crashpad, required this.draft});

  final Crashpad crashpad;
  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const StatusBadge(
            label: 'Request review',
            icon: Icons.flight_takeoff_outlined,
            color: AppPalette.cyan,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(crashpad.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '${crashpad.location} • ${crashpad.nearestAirport}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const Divider(height: 34),
          _FactRow(
            icon: Icons.calendar_month_outlined,
            label: 'Dates',
            value:
                '${_date.format(draft.checkInDate)} - ${_date.format(draft.checkOutDate)}',
          ),
          _FactRow(
            icon: Icons.nights_stay_outlined,
            label: 'Stay length',
            value: '${draft.nights} night${draft.nights == 1 ? '' : 's'}',
          ),
          _FactRow(
            icon: Icons.person_outline,
            label: 'Guests',
            value: '${draft.guestCount}',
          ),
          if (draft.additionalServices.isNotEmpty)
            _FactRow(
              icon: Icons.room_service_outlined,
              label: 'Services',
              value: '${draft.additionalServices.length} selected',
            ),
        ],
      ),
    );
  }
}

class _PendingConfirmation extends StatelessWidget {
  const _PendingConfirmation(
      {super.key, required this.booking, required this.onDone});

  final BookingRecord booking;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final style = bookingStatusStyle(booking.status);
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      radius: AppRadius.xxl,
      borderColor: style.color.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(style.icon, color: style.color, size: 34),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Booking request pending.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The owner will approve or decline this request. You can cancel it from your booking history while it is pending.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          BookingRecordCard(
            booking: booking,
            perspective: BookingPerspective.guest,
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.arrow_back_outlined),
              label: const Text('Back to listing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppPalette.blueSoft),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.textMuted),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppPalette.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

String _friendlyError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  if (message.startsWith('Invalid argument')) {
    return 'Please review the selected dates and try again.';
  }
  return message;
}
