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
  final GlobalKey<FormState> _paymentFormKey = GlobalKey<FormState>();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  BookingRecord? _booking;
  int _stepIndex = 0;

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _goToPayment() {
    setState(() {
      _error = null;
      _stepIndex = 1;
    });
  }

  Future<void> _requestBooking() async {
    if (!_paymentFormKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || !user.isEmployee) {
      setState(
        () => _error = 'Sign in as a crew guest before requesting this stay.',
      );
      return;
    }
    if (!widget.arguments.draft.checkOutDate.isAfter(
      widget.arguments.draft.checkInDate,
    )) {
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
      setState(() {
        _booking = booking;
        _stepIndex = 2;
      });
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

  void _handleBack() {
    if (_isSubmitting) return;
    if (_booking == null && _stepIndex == 1) {
      setState(() {
        _error = null;
        _stepIndex = 0;
      });
      return;
    }
    Navigator.pop(context, _booking);
  }

  void _finish() => Navigator.pop(context, _booking);

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return PopScope<Object?>(
      canPop: !_isSubmitting && (booking != null || _stepIndex == 0),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isSubmitting && booking == null && _stepIndex == 1) {
          setState(() {
            _error = null;
            _stepIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AnimatedBackButton(onPressed: _handleBack),
          title: Text(
            booking != null
                ? 'Request sent'
                : _stepIndex == 0
                    ? 'Review booking'
                    : 'Mock payment',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ResponsivePage(
              maxWidth: 1080,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: booking == null
                    ? _stepIndex == 0
                        ? _RequestReview(
                            key: const ValueKey<String>('review'),
                            crashpad: widget.arguments.crashpad,
                            draft: widget.arguments.draft,
                            summary: widget.arguments.summary,
                            onContinue: _goToPayment,
                          )
                        : _PaymentStep(
                            key: const ValueKey<String>('payment'),
                            formKey: _paymentFormKey,
                            cardNameController: _cardNameController,
                            cardNumberController: _cardNumberController,
                            expiryController: _expiryController,
                            cvcController: _cvcController,
                            postalCodeController: _postalCodeController,
                            summary: widget.arguments.summary,
                            error: _error,
                            isSubmitting: _isSubmitting,
                            onBack: _handleBack,
                            onSubmit: _requestBooking,
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
    required this.onContinue,
  });

  final Crashpad crashpad;
  final BookingDraft draft;
  final PaymentSummary summary;
  final VoidCallback onContinue;

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
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                onPressed: onContinue,
                icon: Icons.credit_card_outlined,
                child: const Text('Continue to mock payment'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mock checkout only. Your payment is authorized now and captured only after owner checkout completion.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
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
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppPalette.textMuted),
          ),
          const Divider(height: 34),
          _FactRow(
            icon: Icons.bed_outlined,
            label: 'Bed model',
            value: crashpad.bedModel.label,
          ),
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

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    super.key,
    required this.formKey,
    required this.cardNameController,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvcController,
    required this.postalCodeController,
    required this.summary,
    required this.error,
    required this.isSubmitting,
    required this.onBack,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController cardNameController;
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvcController;
  final TextEditingController postalCodeController;
  final PaymentSummary summary;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
        final form = CrashSurface(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          radius: AppRadius.xxl,
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const StatusBadge(
                  label: 'Mock payment authorization',
                  icon: Icons.lock_outline,
                  color: AppPalette.blueSoft,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Demo card details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use any card-like values. This does not process a real payment or store card data.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: cardNameController,
                  enabled: !isSubmitting,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name on card',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 2) return 'Enter the cardholder name';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: cardNumberController,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Demo card number',
                    hintText: '4242 4242 4242 4242',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  validator: _validateCardNumber,
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final compact =
                        innerConstraints.maxWidth < AppBreakpoints.tablet;
                    final expiry = TextFormField(
                      controller: expiryController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Expiry',
                        hintText: 'MM/YY',
                      ),
                      validator: _validateExpiry,
                    );
                    final cvc = TextFormField(
                      controller: cvcController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'CVC',
                        hintText: '123',
                      ),
                      validator: _validateCvc,
                    );
                    if (compact) {
                      return Column(
                        children: <Widget>[
                          expiry,
                          const SizedBox(height: AppSpacing.lg),
                          cvc,
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: expiry),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: cvc),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: postalCodeController,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!isSubmitting) onSubmit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Billing ZIP / postal code',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 3) return 'Enter a billing postal code';
                    return null;
                  },
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _ErrorPanel(message: error!),
                ],
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    AppSecondaryButton(
                      onPressed: isSubmitting ? null : onBack,
                      icon: Icons.arrow_back_outlined,
                      child: const Text('Back to review'),
                    ),
                    AppPrimaryButton(
                      onPressed: isSubmitting ? null : onSubmit,
                      icon: isSubmitting ? null : Icons.send_outlined,
                      child: isSubmitting
                          ? Semantics(
                              label: 'Submitting booking request',
                              child: const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Text('Authorize mock payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        final summaryCard = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PaymentSummaryCard(summary: summary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Authorization only. The owner captures the final mock payment after checkout is complete.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.textMuted,
                  ),
            ),
          ],
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              form,
              const SizedBox(height: AppSpacing.xxl),
              summaryCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 6, child: form),
            const SizedBox(width: AppSpacing.xxxl),
            Expanded(flex: 4, child: summaryCard),
          ],
        );
      },
    );
  }
}

class _PendingConfirmation extends StatelessWidget {
  const _PendingConfirmation({
    super.key,
    required this.booking,
    required this.onDone,
  });

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
            'The owner will approve or decline this request. Your payment authorization is held until checkout, and you can cancel it from your booking history while it is pending.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          BookingRecordCard(
            booking: booking,
            perspective: BookingPerspective.guest,
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              onPressed: onDone,
              icon: Icons.arrow_back_outlined,
              child: const Text('Back to listing'),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
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

String? _validateCardNumber(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 12 || digits.length > 19) {
    return 'Enter a card-like demo number';
  }
  return null;
}

String? _validateExpiry(String? value) {
  final text = (value ?? '').trim();
  final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
  if (match == null) return 'Use MM/YY';
  final month = int.tryParse(match.group(1) ?? '');
  if (month == null || month < 1 || month > 12) {
    return 'Use a valid month';
  }
  return null;
}

String? _validateCvc(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 3 || digits.length > 4) {
    return 'Use 3 or 4 digits';
  }
  return null;
}
