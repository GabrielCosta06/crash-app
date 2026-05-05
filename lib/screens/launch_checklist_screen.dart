import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

class LaunchChecklistScreen extends StatelessWidget {
  const LaunchChecklistScreen({super.key});

  static const List<_LaunchItem> _items = <_LaunchItem>[
    _LaunchItem(
      title: 'Owner account created',
      detail: 'Sign up as an owner and verify the profile data is complete.',
      icon: Icons.person_add_alt_outlined,
    ),
    _LaunchItem(
      title: 'First listing published',
      detail:
          'Create a crashpad with rooms, bed model, rules, services, fees, and map coordinates.',
      icon: Icons.add_home_work_outlined,
    ),
    _LaunchItem(
      title: 'Stripe payouts connected',
      detail:
          'Open Stripe onboarding and confirm the owner account reaches Ready for payouts.',
      icon: Icons.account_balance_outlined,
    ),
    _LaunchItem(
      title: 'Guest booking requested',
      detail:
          'Sign up as a guest, choose dates, submit a booking request, and confirm it appears for the owner.',
      icon: Icons.flight_takeoff_outlined,
    ),
    _LaunchItem(
      title: 'Booking payment confirmed',
      detail:
          'Approve the request, complete Stripe Checkout in test mode, and verify webhook confirmation.',
      icon: Icons.credit_card_outlined,
    ),
    _LaunchItem(
      title: 'Premium subscription checked',
      detail:
          'Start Stripe Billing Checkout and verify premium access changes after the webhook.',
      icon: Icons.workspace_premium_outlined,
    ),
    _LaunchItem(
      title: 'Checkout fee flow tested',
      detail:
          'Check in the guest, assess a fee, pay it through Stripe Checkout, and confirm completion.',
      icon: Icons.receipt_long_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AnimatedBackButton(),
        title: const Text('Launch checklist'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeading(
                  title: 'First-user QA',
                  subtitle:
                      'Run this full story before inviting owners or crew into the marketplace.',
                ),
                const SizedBox(height: AppSpacing.xl),
                CrashSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: _items.asMap().entries.map((entry) {
                      final isLast = entry.key == _items.length - 1;
                      return Column(
                        children: <Widget>[
                          _LaunchChecklistRow(item: entry.value),
                          if (!isLast) const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                CrashSurface(
                  borderColor: AppPalette.blueSoft.withValues(alpha: 0.32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline,
                          color: AppPalette.blueSoft),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Use Stripe test-mode cards and refresh account status after redirects. Webhooks are the source of truth for payment, subscription, and payout readiness.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppPalette.textMuted),
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

class _LaunchChecklistRow extends StatelessWidget {
  const _LaunchChecklistRow({required this.item});

  final _LaunchItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(item.icon, color: AppPalette.blueSoft),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchItem {
  const _LaunchItem({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}
