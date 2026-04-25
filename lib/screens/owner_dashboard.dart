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
import '../widgets/booking_components.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late Future<List<Crashpad>> _listingsFuture;
  String? _updatingBookingId;

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

  Future<void> _setBookingStatus(
    BookingRecord booking,
    BookingStatus status,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_statusDialogTitle(status)),
        content: Text(_statusDialogMessage(status, booking)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep current status'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_statusDialogAction(status)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _updatingBookingId = booking.id);
    try {
      await context.read<AppRepository>().updateBookingStatus(
            bookingId: booking.id,
            status: status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stay moved to ${status.label}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update stay: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingBookingId = null);
      }
    }
  }

  String _statusDialogTitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Approve this request?';
      case BookingStatus.cancelled:
        return 'Cancel this booking?';
      case BookingStatus.active:
        return 'Mark guest checked in?';
      case BookingStatus.completed:
        return 'Complete this stay?';
      case BookingStatus.pending:
      case BookingStatus.draft:
        return 'Update booking status?';
    }
  }

  String _statusDialogMessage(BookingStatus status, BookingRecord booking) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Approve ${booking.guestName} for ${booking.crashpadName}. The guest will see the stay as confirmed.';
      case BookingStatus.cancelled:
        return 'This moves ${booking.crashpadName} to Cancelled and removes it from active booking lists.';
      case BookingStatus.active:
        return 'Use this after ${booking.guestName} has arrived for check-in.';
      case BookingStatus.completed:
        return 'Complete this stay after checkout is finished.';
      case BookingStatus.pending:
      case BookingStatus.draft:
        return 'This will update the booking status.';
    }
  }

  String _statusDialogAction(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Approve Request';
      case BookingStatus.cancelled:
        return 'Cancel Booking';
      case BookingStatus.active:
        return 'Check In';
      case BookingStatus.completed:
        return 'Complete Stay';
      case BookingStatus.pending:
      case BookingStatus.draft:
        return 'Update';
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
      body: SafeArea(
        child: FutureBuilder<List<Crashpad>>(
          future: _listingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _DashboardSkeleton();
            }
            if (snapshot.hasError) {
              return Center(
                child: EmptyStatePanel(
                  icon: Icons.error_outline,
                  title: 'Management unavailable',
                  message: 'The management dashboard could not be loaded.',
                  action: ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ),
              );
            }
            final listings = snapshot.data ?? <Crashpad>[];
            final ownerBookings = repository.bookings
                .where(
                  (booking) =>
                      booking.ownerEmail.toLowerCase() ==
                      user.email.toLowerCase(),
                )
                .toList();
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
                      _BookingWorkflowPanel(
                        bookings: ownerBookings,
                        onSetStatus: _setBookingStatus,
                        updatingBookingId: _updatingBookingId,
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
                label: 'Management command center',
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
            label: 'Minimum-stay payout projection',
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
      final checkIn = DateUtils.dateOnly(DateTime.now()).add(
        const Duration(days: 1),
      );
      final checkOut = checkIn.add(Duration(days: listing.minimumStayNights));
      final summary = paymentService.buildSummary(
        BookingDraft(
          crashpadId: listing.id,
          guestId: 'mock-dashboard',
          nightlyRate: listing.price,
          checkInDate: checkIn,
          checkOutDate: checkOut,
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
        : () {
            final checkIn = DateUtils.dateOnly(DateTime.now()).add(
              const Duration(days: 1),
            );
            final checkOut =
                checkIn.add(Duration(days: primary.minimumStayNights));
            return paymentService.buildSummary(
              BookingDraft(
                crashpadId: primary.id,
                guestId: 'mock-owner-preview',
                nightlyRate: primary.price,
                checkInDate: checkIn,
                checkOutDate: checkOut,
                guestCount: 1,
              ),
            );
          }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (summary != null)
          PaymentSummaryCard(summary: summary, showStatus: false)
        else
          EmptyStatePanel(
            icon: Icons.payments_outlined,
            title: 'No payout preview yet',
            message:
                'Set a nightly rate for your listing to preview your expected payout.',
            action: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add your first crashpad'),
            ),
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
                'Calculated from the current nightly rate, each listing minimum stay, and centralized ${(AppConfig.platformFeeRate * 100).toStringAsFixed(0)}% Crash App fee. Payment capture remains mocked until Stripe is connected.',
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

class _BookingWorkflowPanel extends StatelessWidget {
  const _BookingWorkflowPanel({
    required this.bookings,
    required this.onSetStatus,
    required this.updatingBookingId,
  });

  final List<BookingRecord> bookings;
  final String? updatingBookingId;
  final Future<void> Function(BookingRecord booking, BookingStatus status)
      onSetStatus;

  @override
  Widget build(BuildContext context) {
    final pending = bookings
        .where((booking) => booking.status == BookingStatus.pending)
        .toList();
    final active = bookings
        .where(
          (booking) =>
              booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.active,
        )
        .toList();
    final past = bookings
        .where((booking) => booking.status == BookingStatus.completed)
        .toList();
    final cancelled = bookings
        .where((booking) => booking.status == BookingStatus.cancelled)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(
          title: 'Booking requests',
          subtitle:
              'Approve incoming crew requests, manage active stays, and keep cancelled bookings out of the way.',
        ),
        const SizedBox(height: AppSpacing.lg),
        DefaultTabController(
          length: 4,
          child: Column(
            children: <Widget>[
              CrashSurface(
                padding: const EdgeInsets.all(AppSpacing.sm),
                radius: AppRadius.lg,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: <Widget>[
                    Tab(text: 'Pending (${pending.length})'),
                    Tab(text: 'Active (${active.length})'),
                    Tab(text: 'Past (${past.length})'),
                    Tab(text: 'Cancelled (${cancelled.length})'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 460,
                child: TabBarView(
                  children: <Widget>[
                    _OwnerBookingList(
                      bookings: pending,
                      emptyTitle: 'No pending requests',
                      emptyMessage:
                          'New crew booking requests will appear here for approval.',
                      updatingBookingId: updatingBookingId,
                      onSetStatus: onSetStatus,
                    ),
                    _OwnerBookingList(
                      bookings: active,
                      emptyTitle: 'No active stays',
                      emptyMessage:
                          'Approved and checked-in bookings stay here until checkout is complete.',
                      updatingBookingId: updatingBookingId,
                      onSetStatus: onSetStatus,
                    ),
                    _OwnerBookingList(
                      bookings: past,
                      emptyTitle: 'No past stays',
                      emptyMessage:
                          'Completed stays will collect here for payout and review history.',
                      updatingBookingId: updatingBookingId,
                      onSetStatus: onSetStatus,
                    ),
                    _OwnerBookingList(
                      bookings: cancelled,
                      emptyTitle: 'No cancelled bookings',
                      emptyMessage:
                          'Declined and cancelled bookings are separated from active work.',
                      updatingBookingId: updatingBookingId,
                      onSetStatus: onSetStatus,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerBookingList extends StatelessWidget {
  const _OwnerBookingList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.updatingBookingId,
    required this.onSetStatus,
  });

  final List<BookingRecord> bookings;
  final String emptyTitle;
  final String emptyMessage;
  final String? updatingBookingId;
  final Future<void> Function(BookingRecord booking, BookingStatus status)
      onSetStatus;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return BookingEmptyState(
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.separated(
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final isUpdating = updatingBookingId == booking.id;
        final actions = _actionsFor(booking, isUpdating);
        return BookingRecordCard(
          booking: booking,
          perspective: BookingPerspective.owner,
          primaryAction: actions.primary,
          secondaryAction: actions.secondary,
        );
      },
    );
  }

  _BookingCardActions _actionsFor(BookingRecord booking, bool isUpdating) {
    Widget button({
      required String label,
      required IconData icon,
      required BookingStatus status,
      bool outlined = false,
    }) {
      final onPressed = isUpdating ? null : () => onSetStatus(booking, status);
      if (outlined) {
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(isUpdating ? 'Updating...' : label),
        );
      }
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: isUpdating
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(isUpdating ? 'Updating...' : label),
      );
    }

    switch (booking.status) {
      case BookingStatus.pending:
        return _BookingCardActions(
          primary: button(
            label: 'Approve Request',
            icon: Icons.check_outlined,
            status: BookingStatus.confirmed,
          ),
          secondary: button(
            label: 'Decline',
            icon: Icons.close_outlined,
            status: BookingStatus.cancelled,
            outlined: true,
          ),
        );
      case BookingStatus.confirmed:
        return _BookingCardActions(
          primary: button(
            label: 'Check In',
            icon: Icons.login_outlined,
            status: BookingStatus.active,
          ),
          secondary: button(
            label: 'Cancel',
            icon: Icons.cancel_outlined,
            status: BookingStatus.cancelled,
            outlined: true,
          ),
        );
      case BookingStatus.active:
        return _BookingCardActions(
          primary: button(
            label: 'Complete Stay',
            icon: Icons.done_all_outlined,
            status: BookingStatus.completed,
          ),
        );
      case BookingStatus.draft:
      case BookingStatus.completed:
      case BookingStatus.cancelled:
        return const _BookingCardActions();
    }
  }
}

class _BookingCardActions {
  const _BookingCardActions({this.primary, this.secondary});

  final Widget? primary;
  final Widget? secondary;
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
              'Management actions preserved as demo flows and ready for Supabase repositories.',
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
              description:
                  'Remove outdated listings from the management inventory.',
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

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(height: 200, radius: AppRadius.xxl),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                    child: _SkeletonBox(height: 100, radius: AppRadius.lg)),
                const SizedBox(width: 12),
                Expanded(
                    child: _SkeletonBox(height: 100, radius: AppRadius.lg)),
                const SizedBox(width: 12),
                Expanded(
                    child: _SkeletonBox(height: 100, radius: AppRadius.lg)),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),
            _SkeletonBox(height: 300, radius: AppRadius.xl),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.radius});
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.panelElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
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
              title: 'Management access required',
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
