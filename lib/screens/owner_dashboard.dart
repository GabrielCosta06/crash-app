import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';
import '../widgets/interaction_feedback.dart';

/// Rich analytics view giving owners quick access to their inventory.
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late Future<List<Crashpad>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _loadListings();
  }

  Future<List<Crashpad>> _loadListings() async {
    final repository = context.read<AppRepository>();
    final owner = repository.currentUser;
    if (owner == null || !owner.isOwner) return [];
    return repository.fetchOwnerCrashpads(owner.email);
  }

  Future<void> _refresh() async {
    final future = _loadListings();
    setState(() => _listingsFuture = future);
    await future;
  }

  Future<void> _showActiveListings() async {
    try {
      final listings = await _loadListings();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Active listings'),
          content: listings.isEmpty
              ? const Text('No listings yet. Create one to get started.')
              : SizedBox(
                  width: double.maxFinite,
                  height: 280,
                  child: ListView.builder(
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return ListTile(
                        title: Text(listing.name),
                        subtitle: Text(listing.location),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load listings: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final user = repository.currentUser;

    if (user == null || user.userType != AppUserType.owner) {
      return const _OwnerOnlyView();
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Owner command center'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: FutureBuilder<List<Crashpad>>(
        future: _listingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'We couldn\'t load your dashboard.',
              onRetry: _refresh,
            );
          }
          final listings = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // Extra bottom padding for FAB
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OwnerHeader(owner: user, listings: listings),
                const SizedBox(height: 24),
                _MetricsOverview(listings: listings),
                const SizedBox(height: 24),
                _PerformanceChart(listings: listings),
                const SizedBox(height: 24),
                _QuickActions(onShowListings: _showActiveListings),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/create_listing'),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Add Listing'),
        backgroundColor: AppPalette.aurora,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.owner, required this.listings});

  final AppUser owner;
  final List<Crashpad> listings;

  @override
  Widget build(BuildContext context) {
    final totalBookings =
        listings.fold<int>(0, (sum, listing) => sum + listing.clickCount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppPalette.deepSpace.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppPalette.aurora.withValues(alpha: 0.2),
            child: Text(
              owner.initials,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owner.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${listings.length} active crashpads | $totalBookings total interactions',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.softSlate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsOverview extends StatelessWidget {
  const _MetricsOverview({required this.listings});

  final List<Crashpad> listings;

  @override
  Widget build(BuildContext context) {
    final totalRevenue =
        listings.fold<double>(0, (sum, listing) => sum + listing.price);
    final highestClicks = listings.isEmpty
        ? 0
        : listings.map((listing) => listing.clickCount).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _MetricTile(
          label: 'Active listings',
          value: listings.length.toString(),
          icon: Icons.other_houses_outlined,
        ),
        const SizedBox(width: 16),
        _MetricTile(
          label: 'Avg nightly rate',
          value:
              listings.isEmpty ? '\$0' : '\$${(totalRevenue / listings.length).round()}',
          icon: Icons.attach_money,
        ),
        const SizedBox(width: 16),
        _MetricTile(
          label: 'Peak engagement',
          value: '$highestClicks taps',
          icon: Icons.timeline_outlined,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppPalette.deepSpace.withValues(alpha: 0.8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppPalette.neonPulse),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.softSlate),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceChart extends StatelessWidget {
  const _PerformanceChart({required this.listings});

  final List<Crashpad> listings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardColor = isLight ? AppPalette.lightSurface : AppPalette.deepSpace.withValues(alpha: 0.8);
  final borderColor = isLight ? AppPalette.lightPrimary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05);
    final textColor = isLight ? AppPalette.lightText : Colors.white;
    if (listings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cardColor,
        ),
        child: Center(
          child: Text('Add a crashpad to start seeing performance analytics.', style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
        ),
      );
    }

    final maxY = listings
        .map((listing) => listing.clickCount.toDouble())
        .fold<double>(0, (prev, clicks) => clicks > prev ? clicks : prev);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cardColor,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement radar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                barGroups: listings
                    .asMap()
                    .entries
                    .map(
                      (entry) => BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.clickCount.toDouble(),
                            color: AppPalette.neonPulse,
                            width: 18,
                            borderRadius: BorderRadius.circular(8),
                          )
                        ],
                      ),
                    )
                    .toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= listings.length) {
                          return const SizedBox.shrink();
                        }
                        final name = listings[index].name;
                        final displayName =
                            name.length > 8 ? name.substring(0, 8) : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            displayName,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                maxY: maxY < 5 ? 5 : maxY * 1.2,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onShowListings});

  final VoidCallback onShowListings;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ActionButtonData(
        icon: Icons.inventory_2_outlined,
        label: 'My active listings',
        onTap: onShowListings,
      ),
      _ActionButtonData(
        icon: Icons.delete_sweep_outlined,
        label: 'Delete listings',
        onTap: () => Navigator.pushNamed(context, '/delete_listings'),
      ),
      _ActionButtonData(
        icon: Icons.add_box_outlined,
        label: 'Create new listing',
        onTap: () => Navigator.pushNamed(context, '/create_listing'),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: buttons
          .map(
            (button) => SizedBox(
              width: 220,
              child: TapScale(
                child: ElevatedButton.icon(
                  onPressed: button.onTap,
                  icon: Icon(button.icon),
                  label: Text(button.label),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionButtonData {
  const _ActionButtonData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _OwnerOnlyView extends StatelessWidget {
  const _OwnerOnlyView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Owner command center'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch_outlined,
                  size: 60, color: AppPalette.neonPulse),
              const SizedBox(height: 16),
              Text(
                'Switch to an owner profile to access this dashboard.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Owners get real-time analytics, performance insights, and quick actions to manage listings.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppPalette.softSlate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}


