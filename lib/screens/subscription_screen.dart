import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isSubscribing = false;

  Future<void> _subscribe() async {
    setState(() => _isSubscribing = true);
    try {
      await context.read<AppRepository>().subscribeCurrentUser();
      if (!mounted) return;
      await showActionFeedback(
        context: context,
        icon: Icons.workspace_premium_outlined,
        title: 'Premium active',
        message: 'Your mock subscription is active for this session.',
        color: AppPalette.success,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not activate subscription: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppRepository>().currentUser;
    final isSubscribed = user?.isSubscribed ?? false;
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
        title: const Text('Subscription'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeading(
                  title: 'Premium subscription',
                  subtitle:
                      'Activate a demo premium subscription without leaving the in-memory mock environment.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                CrashSurface(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isSubscribed
                            ? Icons.verified_outlined
                            : Icons.workspace_premium_outlined,
                        color: isSubscribed
                            ? AppPalette.success
                            : AppPalette.warning,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              isSubscribed
                                  ? 'Premium active'
                                  : 'Premium inactive',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSubscribed
                                  ? 'Your account is marked subscribed for this session.'
                                  : 'Run a mock payment to activate premium status on your account.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const PaymentSummaryCard(summary: summary),
                const SizedBox(height: AppSpacing.xxl),
                CrashSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Mock billing rule',
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
                        onPressed:
                            isSubscribed || _isSubscribing ? null : _subscribe,
                        icon: _isSubscribing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_outline),
                        label: Text(
                          isSubscribed
                              ? 'Subscription active'
                              : _isSubscribing
                                  ? 'Activating...'
                                  : 'Activate mock subscription',
                        ),
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
