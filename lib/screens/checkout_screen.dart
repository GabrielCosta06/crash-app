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
import '../widgets/interaction_feedback.dart';

final NumberFormat _money = NumberFormat.currency(symbol: r'$');

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
  final GlobalKey<FormState> _cardFormKey = GlobalKey<FormState>();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();

  _CheckoutStep _step = _CheckoutStep.payment;
  _PaymentMethod _method = _PaymentMethod.savedCard;
  bool _isProcessing = false;
  String? _error;
  BookingRecord? _booking;

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    if (_method == _PaymentMethod.newCard &&
        !(_cardFormKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check the card details and try again.')),
      );
      return;
    }

    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || !user.isEmployee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sign in as a guest to complete payment.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final authorized = _paymentService.authorizeMockPayment(
        widget.arguments.summary,
      );
      final captured = _paymentService.captureMockPayment(authorized);
      final booking = await repository.createBooking(
        crashpad: widget.arguments.crashpad,
        draft: widget.arguments.draft,
        paymentSummary: captured,
      );
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _step = _CheckoutStep.confirmation;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment complete. Booking confirmed.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Payment could not be completed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!)),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _finish() {
    Navigator.pop(context, _booking);
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      appBar: AppBar(
        leading: AnimatedBackButton(
          onPressed: _isProcessing ? () {} : _finish,
        ),
        title: Text(
          _step == _CheckoutStep.confirmation
              ? 'Booking confirmed'
              : 'Checkout',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 1120,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _step == _CheckoutStep.confirmation && booking != null
                  ? _ConfirmationView(
                      key: const ValueKey<String>('confirmation'),
                      booking: booking,
                      crashpad: widget.arguments.crashpad,
                      onDone: _finish,
                    )
                  : _PaymentView(
                      key: const ValueKey<String>('payment'),
                      crashpad: widget.arguments.crashpad,
                      draft: widget.arguments.draft,
                      summary: widget.arguments.summary,
                      method: _method,
                      error: _error,
                      isProcessing: _isProcessing,
                      cardFormKey: _cardFormKey,
                      cardNameController: _cardNameController,
                      cardNumberController: _cardNumberController,
                      expiryController: _expiryController,
                      cvcController: _cvcController,
                      zipController: _zipController,
                      onMethodChanged: (method) =>
                          setState(() => _method = method),
                      onConfirm: _confirmPayment,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentView extends StatelessWidget {
  const _PaymentView({
    super.key,
    required this.crashpad,
    required this.draft,
    required this.summary,
    required this.method,
    required this.error,
    required this.isProcessing,
    required this.cardFormKey,
    required this.cardNameController,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvcController,
    required this.zipController,
    required this.onMethodChanged,
    required this.onConfirm,
  });

  final Crashpad crashpad;
  final BookingDraft draft;
  final PaymentSummary summary;
  final _PaymentMethod method;
  final String? error;
  final bool isProcessing;
  final GlobalKey<FormState> cardFormKey;
  final TextEditingController cardNameController;
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvcController;
  final TextEditingController zipController;
  final ValueChanged<_PaymentMethod> onMethodChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
        final summaryColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _CheckoutStepHeader(activeStep: 1),
            const SizedBox(height: AppSpacing.xxl),
            _StaySummaryCard(crashpad: crashpad, draft: draft),
            const SizedBox(height: AppSpacing.xxl),
            PaymentSummaryCard(summary: summary.copyWith(), showStatus: false),
            if (crashpad.checkoutCharges.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              _PotentialChargesCard(crashpad: crashpad),
            ],
          ],
        );
        final paymentColumn = _PaymentMethodCard(
          method: method,
          error: error,
          isProcessing: isProcessing,
          cardFormKey: cardFormKey,
          cardNameController: cardNameController,
          cardNumberController: cardNumberController,
          expiryController: expiryController,
          cvcController: cvcController,
          zipController: zipController,
          onMethodChanged: onMethodChanged,
          onConfirm: onConfirm,
          total: summary.totalChargedToGuest,
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              summaryColumn,
              const SizedBox(height: AppSpacing.xxl),
              paymentColumn,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 6, child: summaryColumn),
            const SizedBox(width: AppSpacing.xxxl),
            Expanded(flex: 5, child: paymentColumn),
          ],
        );
      },
    );
  }
}

class _CheckoutStepHeader extends StatelessWidget {
  const _CheckoutStepHeader({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final steps = <String>['Review', 'Payment', 'Confirmation'];
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final isActive = index == activeStep;
          final isDone = index < activeStep;
          return Expanded(
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive
                        ? AppPalette.blue
                        : AppPalette.panelElevated,
                    border: Border.all(color: AppPalette.borderStrong),
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : Icons.circle,
                    size: isDone ? 18 : 9,
                    color: AppPalette.text,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    entry.value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isActive || isDone
                              ? AppPalette.text
                              : AppPalette.textMuted,
                        ),
                  ),
                ),
                if (index != steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: isDone ? AppPalette.blue : AppPalette.border,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StaySummaryCard extends StatelessWidget {
  const _StaySummaryCard({required this.crashpad, required this.draft});

  final Crashpad crashpad;
  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const StatusBadge(
            label: 'Stay review',
            icon: Icons.event_available_outlined,
            color: AppPalette.cyan,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(crashpad.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${crashpad.location} | ${crashpad.nearestAirport}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const Divider(height: 30),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              StatusBadge(
                label: '${draft.nights} nights',
                icon: Icons.nights_stay_outlined,
              ),
              StatusBadge(
                label: '${draft.guestCount} guest(s)',
                icon: Icons.person_outline,
                color: AppPalette.success,
              ),
              StatusBadge(
                label: _money.format(draft.nightlyRate),
                icon: Icons.payments_outlined,
                color: AppPalette.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PotentialChargesCard extends StatelessWidget {
  const _PotentialChargesCard({required this.crashpad});

  final Crashpad crashpad;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Possible checkout charges',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'These are not charged today. They may apply after checkout if the owner verifies the condition.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...crashpad.checkoutCharges.map(
            (charge) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppPalette.blueSoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(charge.name)),
                  Text(_money.format(charge.amount)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.error,
    required this.isProcessing,
    required this.cardFormKey,
    required this.cardNameController,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvcController,
    required this.zipController,
    required this.onMethodChanged,
    required this.onConfirm,
    required this.total,
  });

  final _PaymentMethod method;
  final String? error;
  final bool isProcessing;
  final GlobalKey<FormState> cardFormKey;
  final TextEditingController cardNameController;
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvcController;
  final TextEditingController zipController;
  final ValueChanged<_PaymentMethod> onMethodChanged;
  final VoidCallback onConfirm;
  final double total;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Payment method', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'This demo authorizes and captures a mock payment, then creates a confirmed booking.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          _MethodTile(
            selected: method == _PaymentMethod.savedCard,
            icon: Icons.credit_card_outlined,
            title: 'Saved demo card',
            subtitle: 'Visa ending in 4242',
            onTap: () => onMethodChanged(_PaymentMethod.savedCard),
          ),
          const SizedBox(height: AppSpacing.md),
          _MethodTile(
            selected: method == _PaymentMethod.newCard,
            icon: Icons.add_card_outlined,
            title: 'Use a new card',
            subtitle: 'Enter card details for this booking',
            onTap: () => onMethodChanged(_PaymentMethod.newCard),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: method == _PaymentMethod.newCard
                ? Padding(
                    key: const ValueKey<String>('new-card-form'),
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _NewCardForm(
                      formKey: cardFormKey,
                      cardNameController: cardNameController,
                      cardNumberController: cardNumberController,
                      expiryController: expiryController,
                      cvcController: cvcController,
                      zipController: zipController,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _ErrorPanel(message: error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : onConfirm,
              icon: isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(
                isProcessing
                    ? 'Processing payment...'
                    : 'Pay ${_money.format(total)}',
              ),
            ),
          ),
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
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.blue.withValues(alpha: 0.14)
                : AppPalette.panelElevated.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppPalette.blue : AppPalette.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon,
                  color: selected ? AppPalette.blueSoft : AppPalette.textMuted),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppPalette.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppPalette.blueSoft : AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewCardForm extends StatelessWidget {
  const _NewCardForm({
    required this.formKey,
    required this.cardNameController,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvcController,
    required this.zipController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController cardNameController;
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvcController;
  final TextEditingController zipController;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: cardNameController,
            decoration: const InputDecoration(
              labelText: 'Name on card',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: cardNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: '4242 4242 4242 4242',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 12) return 'Enter a valid card number';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
              final expiry = TextFormField(
                controller: expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry',
                  hintText: 'MM/YY',
                ),
                validator: _requiredValidator,
              );
              final cvc = TextFormField(
                controller: cvcController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CVC'),
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 3) return 'Enter CVC';
                  return null;
                },
              );
              final zip = TextFormField(
                controller: zipController,
                decoration: const InputDecoration(labelText: 'ZIP'),
                validator: _requiredValidator,
              );

              if (!isWide) {
                return Column(
                  children: <Widget>[
                    expiry,
                    const SizedBox(height: AppSpacing.lg),
                    cvc,
                    const SizedBox(height: AppSpacing.lg),
                    zip,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: expiry),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: cvc),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: zip),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    super.key,
    required this.booking,
    required this.crashpad,
    required this.onDone,
  });

  final BookingRecord booking;
  final Crashpad crashpad;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _CheckoutStepHeader(activeStep: 2),
        const SizedBox(height: AppSpacing.xxl),
        CrashSurface(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          radius: AppRadius.xxl,
          color: AppPalette.panel.withValues(alpha: 0.82),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppPalette.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppPalette.success,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Your stay is confirmed.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Payment was captured and the owner can now manage check-in, stay completion, and payout details.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= AppBreakpoints.tablet ? 3 : 1;
                  final items = <Widget>[
                    _ConfirmationMetric(
                      label: 'Crashpad',
                      value: crashpad.name,
                      icon: Icons.apartment_outlined,
                    ),
                    _ConfirmationMetric(
                      label: 'Booking status',
                      value: booking.status.label,
                      icon: Icons.event_available_outlined,
                    ),
                    _ConfirmationMetric(
                      label: 'Total paid',
                      value: _money.format(
                        booking.paymentSummary.totalChargedToGuest,
                      ),
                      icon: Icons.payments_outlined,
                    ),
                  ];
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: columns == 1 ? 3.2 : 1.55,
                    ),
                    itemBuilder: (context, index) => items[index],
                  );
                },
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
        ),
      ],
    );
  }
}

class _ConfirmationMetric extends StatelessWidget {
  const _ConfirmationMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: AppPalette.blueSoft),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

enum _CheckoutStep { payment, confirmation }

enum _PaymentMethod { savedCard, newCard }

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}
