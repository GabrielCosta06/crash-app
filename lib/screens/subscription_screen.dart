import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/interaction_feedback.dart';

/// Premium upsell surface allowing crew members to subscribe.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProcessing = false;

  Future<void> _handleSubscribe() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to manage subscriptions.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await repository.subscribeCurrentUser();
      if (!mounted) return;
      await showActionFeedback(
        context: context,
        icon: Icons.workspace_premium_outlined,
        title: 'Subscription activated',
        message: 'Crew Pro access unlocked.',
        color: AppPalette.neonPulse,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AnimatedBackButton(),
        title: const Text('Premium access'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppPalette.deepSpace.withValues(alpha: 0.9),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    size: 56,
                    color: AppPalette.neonPulse,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Crew Pro Membership',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Access encrypted owner profiles, real-time availability, crew verified reviews, and immersive analytics dashboards. Only \$15/month.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.softSlate,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _BenefitList(),
                  const SizedBox(height: 24),
                  _isProcessing
                      ? const CircularProgressIndicator()
                      : TapScale(
                          enabled: !_isProcessing,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleSubscribe,
                              child: const Text('Activate Pro access'),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Maybe later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays subscription perks with matching iconography.
class _BenefitList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      'Owner insights & direct contact unlock',
      'Priority listing alerts tailored to your routes',
      'Curated lounge of partner amenities and perks',
      'Advanced filters, heatmaps, and trip planning tools',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: AppPalette.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
