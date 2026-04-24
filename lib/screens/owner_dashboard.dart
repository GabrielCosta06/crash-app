import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../services/availability_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

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
    if (owner == null || !owner.isOwner) return <Crashpad>[];
    return repository.fetchOwnerCrashpads(owner.email);
  }

  Future<void> _refresh() async {
    final future = _loadListings();
    setState(() => _listingsFuture = future);
    await future;
  }

  Future<void> _openCreateListing() async {
    await Navigator.pushNamed(context, '/create_listing');
    if (mounted) await _refresh();
  }

  Future<void> _openDeleteListings() async {
    await Navigator.pushNamed(context, '/delete_listings');
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final user = repository.currentUser;

    if (user == null || user.userType != AppUserType.owner) {
      return const _OwnerOnlyView();
    }

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Crashpad>>(
          future: _listingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: EmptyStatePanel(
                  icon: Icons.error_outline,
                  title: 'Dashboard unavailable',
                  message: 'The owner dashboard could not be loaded.',
                  action: ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ),
              );
            }
            final listings = snapshot.data ?? <Crashpad>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ResponsivePage(
                  maxWidth: 1240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _OwnerHero(owner: user, listings: listings),
                      const SizedBox(height: AppSpacing.xxl),
                      _Metrics(listings: listings),
                      const SizedBox(height: AppSpacing.xxxl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide =
                              constraints.maxWidth >= AppBreakpoints.desktop;
                          final inventory = _InventoryPanel(
                            listings: listings,
                            onCreateListing: _openCreateListing,
                          );
                          final payouts = _PayoutPanel(listings: listings);
                          if (!isWide) {
                            return Column(
                              children: <Widget>[
                                inventory,
                                const SizedBox(height: AppSpacing.xxl),
                                payouts,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 7, child: inventory),
                              const SizedBox(width: AppSpacing.xxl),
                              Expanded(flex: 4, child: payouts),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      _WorkflowPanel(
                        listings: listings,
                        onCreateListing: _openCreateListing,
                        onDeleteListings: _openDeleteListings,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListing,
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text('Add crashpad'),
      ),
    );
  }
}

class _OwnerHero extends StatelessWidget {
  const _OwnerHero({
    required this.owner,
    required this.listings,
  });

  final AppUser owner;
  final List<Crashpad> listings;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      radius: AppRadius.xxl,
      color: AppPalette.panel.withValues(alpha: 0.78),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
          final headline = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const StatusBadge(
                label: 'Owner command center',
                icon: Icons.dashboard_customize_outlined,
                color: AppPalette.cyan,
              ),
              const SizedBox(height: 18),
              Text(
                'Manage beds, guests, charges, and payouts.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Built for multi-property crashpad operators: track capacity, preserve hot/cold bed rules, preview payouts, and keep checkout charges transparent.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          );
          final profile = CrashSurface(
            radius: AppRadius.lg,
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppPalette.blue.withValues(alpha: 0.22),
                  child: Text(
                    owner.initials,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(owner.displayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${listings.length} active properties',
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

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                headline,
                const SizedBox(height: AppSpacing.xxl),
                profile,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: headline),
              const SizedBox(width: AppSpacing.xxxl),
              Expanded(flex: 2, child: profile),
            ],
          );
        },
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.listings});

  final List<Crashpad> listings;

  @override
  Widget build(BuildContext context) {
    final availability = const AvailabilityService();
    final totalBeds = listings.fold<int>(
      0,
      (sum, listing) => sum + availability.summarize(listing).totalPhysicalBeds,
    );
    final openCapacity = listings.fold<int>(
      0,
      (sum, listing) => sum + availability.summarize(listing).availableToBook,
    );
    final activeGuests = listings.fold<int>(
      0,
      (sum, listing) => sum + listing.totalActiveGuests,
    );
    final estimatedPayout = _estimatedPayout(listings);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppBreakpoints.desktop
            ? 4
            : constraints.maxWidth >= AppBreakpoints.tablet
                ? 2
                : 1;
        final metrics = <MetricCard>[
          MetricCard(
            label: 'Physical beds',
            value: '$totalBeds',
            icon: Icons.king_bed_outlined,
          ),
          MetricCard(
            label: 'Open capacity',
            value: '$openCapacity',
            icon: Icons.event_available_outlined,
            accent: AppPalette.success,
          ),
          MetricCard(
            label: 'Active guests',
            value: '$activeGuests',
            icon: Icons.groups_2_outlined,
            accent: AppPalette.cyan,
          ),
          MetricCard(
            label: '${AppConfig.defaultBookingNights}-night payout projection',
            value: '\$${estimatedPayout.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
            accent: AppPalette.warning,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 2.7 : 1.55,
          ),
          itemBuilder: (context, index) => metrics[index],
        );
      },
    );
  }

  static double _estimatedPayout(List<Crashpad> listings) {
    final paymentService = const PaymentService();
    return listings.fold<double>(0, (sum, listing) {
      final summary = paymentService.buildSummary(
        BookingDraft(
          crashpadId: listing.id,
          guestId: 'mock-dashboard',
          nightlyRate: listing.price,
          nights: AppConfig.defaultBookingNights,
          guestCount: 1,
        ),
      );
      return sum + summary.ownerPayout;
    });
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.listings,
    required this.onCreateListing,
  });

  final List<Crashpad> listings;
  final VoidCallback onCreateListing;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return EmptyStatePanel(
        icon: Icons.add_home_work_outlined,
        title: 'Create your first crashpad',
        message:
            'Properties, rooms, beds, guests, and payout previews will appear here.',
        action: ElevatedButton.icon(
          onPressed: onCreateListing,
          icon: const Icon(Icons.add),
          label: const Text('Add crashpad'),
        ),
      );
    }

    return CrashSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: SectionHeading(
              title: 'Property inventory',
              subtitle:
                  'Desktop-friendly operational view of listings and bed capacity.',
            ),
          ),
          const Divider(height: 1),
          ...listings.map((listing) => _InventoryRow(listing: listing)),
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.listing});

  final Crashpad listing;

  @override
  Widget build(BuildContext context) {
    final summary = const AvailabilityService().summarize(listing);
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/owner-details',
        arguments: listing,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < AppBreakpoints.tablet;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(listing.name,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  '${listing.nearestAirport} | ${listing.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            );
            final facts = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                StatusBadge(label: listing.bedModel.shortLabel),
                StatusBadge(
                  label: '${summary.availableToBook} open',
                  icon: Icons.event_available_outlined,
                  color: AppPalette.success,
                ),
                StatusBadge(
                  label: '${listing.totalActiveGuests} active',
                  icon: Icons.groups_2_outlined,
                  color: AppPalette.blueSoft,
                ),
                StatusBadge(
                  label: '\$${listing.price.toStringAsFixed(0)}/night',
                  icon: Icons.payments_outlined,
                  color: AppPalette.warning,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  title,
                  const SizedBox(height: AppSpacing.lg),
                  facts,
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(flex: 3, child: title),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 4, child: facts),
                const Icon(Icons.chevron_right, color: AppPalette.textMuted),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PayoutPanel extends StatelessWidget {
  const _PayoutPanel({required this.listings});

  final List<Crashpad> listings;

  @override
  Widget build(BuildContext context) {
    final paymentService = const PaymentService();
    final primary = listings.isEmpty ? null : listings.first;
    final summary = primary == null
        ? null
        : paymentService.buildSummary(
            BookingDraft(
              crashpadId: primary.id,
              guestId: 'mock-owner-preview',
              nightlyRate: primary.price,
              nights: AppConfig.defaultBookingNights,
              guestCount: 1,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (summary != null)
          PaymentSummaryCard(summary: summary, showStatus: false)
        else
          const EmptyStatePanel(
            icon: Icons.payments_outlined,
            title: 'No payout preview yet',
            message:
                'Add a crashpad to preview guest charges and owner payout.',
          ),
        const SizedBox(height: AppSpacing.xxl),
        CrashSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Payout calculation',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(
                'Calculated from the current nightly rate, configured default stay length, and centralized ${(AppConfig.platformFeeRate * 100).toStringAsFixed(0)}% Crash App fee. Payment capture remains mocked until Stripe is connected.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkflowPanel extends StatelessWidget {
  const _WorkflowPanel({
    required this.listings,
    required this.onCreateListing,
    required this.onDeleteListings,
  });

  final List<Crashpad> listings;
  final VoidCallback onCreateListing;
  final VoidCallback onDeleteListings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(
          title: 'Operational workflows',
          subtitle:
              'Owner actions preserved as demo flows and ready for Supabase repositories.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _WorkflowAction(
              icon: Icons.add_home_work_outlined,
              title: 'Create property',
              description:
                  'Add a crashpad with bed model, location, rate, and gallery.',
              onTap: onCreateListing,
            ),
            _WorkflowAction(
              icon: Icons.cleaning_services_outlined,
              title: 'Checkout charges',
              description:
                  'Cleaning, damage, late checkout, and custom charges are modeled.',
              onTap: () {},
            ),
            _WorkflowAction(
              icon: Icons.assignment_ind_outlined,
              title: 'Manual assignment',
              description:
                  'Cold-bed assignment and hot-bed capacity logic are separated from UI.',
              onTap: () {},
            ),
            _WorkflowAction(
              icon: Icons.delete_sweep_outlined,
              title: 'Manage listings',
              description: 'Remove outdated listings from the owner inventory.',
              onTap: onDeleteListings,
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkflowAction extends StatelessWidget {
  const _WorkflowAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: CrashSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: AppPalette.blueSoft),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerOnlyView extends StatelessWidget {
  const _OwnerOnlyView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: EmptyStatePanel(
              icon: Icons.lock_outline,
              title: 'Owner profile required',
              message:
                  'Create or sign into an owner account to manage crashpads, beds, stays, charges, and payout previews.',
              action: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Sign in'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
