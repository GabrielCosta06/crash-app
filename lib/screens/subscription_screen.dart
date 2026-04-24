import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const summary = PaymentSummary(
      bookingSubtotal: 1000,
      additionalServices: <ChargeLineItem>[
        ChargeLineItem(
          id: 'demo-service',
          label: 'Additional services',
          amount: 50,
          type: ChargeType.additionalService,
        ),
      ],
      checkoutCharges: <ChargeLineItem>[
        ChargeLineItem(
          id: 'demo-checkout',
          label: 'Checkout charges',
          amount: 25,
          type: ChargeType.checkout,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: const AnimatedBackButton(),
        title: const Text('Mock payment architecture'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeading(
                  title: 'Stripe-ready payment placeholder',
                  subtitle:
                      'Crash App now models guest charge, platform fee, and owner payout without hardcoding fee math in widgets.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                const PaymentSummaryCard(summary: summary),
                const SizedBox(height: AppSpacing.xxl),
                CrashSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Current rule',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Crash App fee is centralized at ${(AppConfig.platformFeeRate * 100).toStringAsFixed(0)}%. Stripe can later replace the mock capture while preserving this summary model.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppPalette.textMuted),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => showActionFeedback(
                          context: context,
                          icon: Icons.check_circle_outline,
                          title: 'Mock payment captured',
                          message: 'No real card was charged.',
                          color: AppPalette.success,
                        ),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Run mock capture'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
