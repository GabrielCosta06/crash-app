import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

final DateFormat _date = DateFormat('MMM d, yyyy');

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  bool _isRefreshing = false;

  Future<void> _openSubscriptionFlow({required bool manage}) async {
    setState(() => _isLoading = true);
    try {
      final repository = context.read<AppRepository>();
      final url = manage
          ? await repository.createBillingPortalSession()
          : await repository.createSubscriptionCheckout();
      if (!mounted) return;
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Stripe billing.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start billing: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    try {
      await context.read<AppRepository>().refreshAccountState();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription status refreshed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh subscription: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppRepository>().currentUser;
    final isSubscribed = user?.isSubscribed ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: AnimatedBackButton(),
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
                      'Use Stripe test-mode Billing to activate or manage premium access.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                FutureBuilder<SubscriptionStatus>(
                  future:
                      context.read<AppRepository>().fetchSubscriptionStatus(),
                  builder: (context, snapshot) {
                    final status = snapshot.data ??
                        SubscriptionStatus(
                          status: isSubscribed ? 'active' : 'none',
                          isActive: isSubscribed,
                        );
                    return _SubscriptionStatusCard(
                      status: status,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      onRefresh: _refreshStatus,
                      isRefreshing: _isRefreshing,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
                CrashSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Stripe Billing',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Premium access is controlled by Stripe subscription status. Webhooks mark active and trialing subscriptions as premium.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppPalette.textMuted),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _openSubscriptionFlow(
                                  manage: isSubscribed,
                                ),
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.open_in_new_outlined),
                        label: Text(
                          _isLoading
                              ? 'Opening...'
                              : isSubscribed
                                  ? 'Manage billing'
                                  : 'Subscribe with Stripe',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Returned from Stripe? Use Refresh status if premium access has not updated yet.',
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
          ),
        ),
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({
    required this.status,
    required this.isLoading,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final SubscriptionStatus status;
  final bool isLoading;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final color = status.isActive ? AppPalette.success : AppPalette.warning;
    return CrashSurface(
      borderColor: color.withValues(alpha: 0.34),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            status.isActive
                ? Icons.verified_outlined
                : Icons.workspace_premium_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      isLoading ? 'Checking subscription...' : status.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!isLoading)
                      StatusBadge(
                        label: status.status,
                        icon: Icons.sync_outlined,
                        color: color,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isLoading
                      ? 'Reading the latest Stripe subscription state from Supabase.'
                      : status.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.textMuted),
                ),
                if (status.currentPeriodEnd != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Current period ends ${_date.format(status.currentPeriodEnd!)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppPalette.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            label: const Text('Refresh status'),
          ),
        ],
      ),
    );
  }
}
