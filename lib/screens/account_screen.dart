import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/booking_components.dart';
import '../widgets/interaction_feedback.dart';
import '../widgets/page_header.dart';

/// Profile surface for account details, stay history, and reviews.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isSavingProfile = false;
  bool _isRefreshingStatus = false;
  String? _accountError;

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<AppRepository>();

    setState(() => _isUploading = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      await repository.updateProfileAvatar(base64Encode(bytes));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _accountError = 'Could not update photo: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _editProfile(AppUser user) async {
    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (context) => _ProfileEditDialog(user: user),
    );
    if (draft == null) return;
    if (!mounted) return;

    final repository = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSavingProfile = true);
    try {
      await repository.updateCurrentUserProfile(
        firstName: draft.firstName,
        lastName: draft.lastName,
        countryOfBirth: draft.countryOfBirth,
        dateOfBirth: draft.dateOfBirth,
        company: draft.company,
        badgeNumber: draft.badgeNumber,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile information saved.')),
      );
      await showActionFeedback(
        context: context,
        icon: Icons.person_outline,
        title: 'Profile updated',
        message: 'Your account details are current.',
        color: AppPalette.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _accountError = 'Could not update profile: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _signOut() async {
    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    await repository.logOut();
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshingStatus = true);
    try {
      await context.read<AppRepository>().refreshAccountState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status refreshed.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _accountError = 'Could not refresh status: $error');
    } finally {
      if (mounted) setState(() => _isRefreshingStatus = false);
    }
  }

  Future<void> _cancelBooking(BookingRecord booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          'This will move ${booking.crashpadName} to Cancelled and notify the owner.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await context.read<AppRepository>().cancelBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _accountError =
            'Could not cancel this booking. ${error.toString()}',
      );
    }
  }

  Future<void> _submitCheckoutReport(BookingRecord booking) async {
    final report = await showDialog<_CheckoutReportDraft>(
      context: context,
      builder: (context) => _CheckoutReportDialog(booking: booking),
    );
    if (report == null) return;
    if (!mounted) return;

    try {
      await context.read<AppRepository>().submitCheckoutReport(
            bookingId: booking.id,
            notes: report.notes,
            photos: report.photos,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout report submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _accountError = 'Could not submit report: $error',
      );
    }
  }

  Future<void> _payForBooking(BookingRecord booking) async {
    try {
      final checkoutUrl =
          await context.read<AppRepository>().createBookingPaymentCheckout(
                booking,
              );
      if (!mounted) return;
      final launched = await launchUrl(
        checkoutUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() => _accountError = 'Could not open Stripe Checkout.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _accountError = 'Could not start payment. $error');
    }
  }

  Future<void> _payCheckoutCharges(BookingRecord booking) async {
    try {
      final checkoutUrl = await context
          .read<AppRepository>()
          .createCheckoutChargePaymentCheckout(booking);
      if (!mounted) return;
      final launched = await launchUrl(
        checkoutUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() => _accountError = 'Could not open Stripe Checkout.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _accountError = 'Could not start checkout charge payment. $error',
      );
    }
  }

  Future<void> _openStripeOnboarding() async {
    try {
      final url = await context
          .read<AppRepository>()
          .createStripeConnectOnboardingLink();
      if (!mounted) return;
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() => _accountError = 'Could not open Stripe onboarding.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(
          () => _accountError = 'Could not start Stripe onboarding. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final user = repository.currentUser;

    if (user == null) {
      return const _SignedOutView();
    }

    final bookings = user.isEmployee
        ? repository.bookings
            .where(
              (booking) =>
                  booking.guestEmail.toLowerCase() == user.email.toLowerCase(),
            )
            .toList()
        : repository.bookings
            .where(
              (booking) =>
                  booking.ownerEmail.toLowerCase() == user.email.toLowerCase(),
            )
            .toList();
    final reviews = user.isEmployee
        ? repository.reviewsByEmployeeName(user.displayName)
        : repository.reviewsForOwner(user.email);

    return Scaffold(
      appBar: PageHeader(
        title: 'Profile',
        subtitle: 'Personal info, booking history, and reviews.',
        icon: Icons.person_outline,
        actions: <Widget>[
          IconButton(
            onPressed: _isSavingProfile ? null : () => _editProfile(user),
            icon: _isSavingProfile
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsivePage(
          maxWidth: 1180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ProfileHero(
                user: user,
                isUploading: _isUploading,
                isSavingProfile: _isSavingProfile,
                onPickAvatar: _pickAvatar,
                onEditProfile: () => _editProfile(user),
              ),
              if (user.isOwner) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FutureBuilder<StripePayoutStatus>(
                  future: repository.fetchStripePayoutStatus(),
                  builder: (context, snapshot) {
                    return _PayoutReadinessCard(
                      status: snapshot.data ??
                          const StripePayoutStatus.notStarted(),
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      onOpenStripe: _openStripeOnboarding,
                      onRefresh: _refreshStatus,
                      isRefreshing: _isRefreshingStatus,
                    );
                  },
                ),
              ],
              if (_accountError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _AccountErrorPanel(
                  message: _accountError!,
                  onDismiss: () => setState(() => _accountError = null),
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
                  final personal = _PersonalInfoSection(user: user);
                  final status = _AccountStatusSection(user: user);

                  if (!isWide) {
                    return Column(
                      children: <Widget>[
                        personal,
                        const SizedBox(height: AppSpacing.xxl),
                        status,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 6, child: personal),
                      const SizedBox(width: AppSpacing.xxl),
                      Expanded(flex: 5, child: status),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _PaymentProcessingPanel(
                bookings: bookings,
                user: user,
                onRefresh: _refreshStatus,
                isRefreshing: _isRefreshingStatus,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _BookingHistorySection(
                bookings: bookings,
                user: user,
                onCancelBooking: _cancelBooking,
                onSubmitCheckoutReport: _submitCheckoutReport,
                onPayForBooking: _payForBooking,
                onPayCheckoutCharges: _payCheckoutCharges,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _ReviewHistorySection(reviews: reviews, user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountErrorPanel extends StatelessWidget {
  const _AccountErrorPanel({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      borderColor: AppPalette.danger.withValues(alpha: 0.36),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppPalette.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Account update failed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_outlined),
            tooltip: 'Dismiss account error',
          ),
        ],
      ),
    );
  }
}

class _PayoutReadinessCard extends StatelessWidget {
  const _PayoutReadinessCard({
    required this.status,
    required this.isLoading,
    required this.onOpenStripe,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final StripePayoutStatus status;
  final bool isLoading;
  final VoidCallback onOpenStripe;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final color = status.isReady ? AppPalette.success : AppPalette.warning;
    return CrashSurface(
      borderColor: color.withValues(alpha: 0.34),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            status.isReady
                ? Icons.verified_outlined
                : Icons.account_balance_outlined,
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
                      isLoading ? 'Checking payout status...' : status.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!isLoading)
                      StatusBadge(
                        label: status.isReady ? 'Ready' : 'Action needed',
                        icon: status.isReady
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: color,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isLoading
                      ? 'Reading the latest Stripe account readiness from Supabase.'
                      : status.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: isRefreshing ? null : onRefresh,
                icon: isRefreshing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
                label: const Text('Refresh'),
              ),
              ElevatedButton.icon(
                onPressed: onOpenStripe,
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(status.isReady ? 'Open Stripe' : 'Set up payouts'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentProcessingPanel extends StatelessWidget {
  const _PaymentProcessingPanel({
    required this.bookings,
    required this.user,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final List<BookingRecord> bookings;
  final AppUser user;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final awaitingBookingPayments = bookings
        .where((booking) => booking.status == BookingStatus.awaitingPayment)
        .toList();
    final checkoutFeesDue = bookings
        .where(
          (booking) =>
              booking.status == BookingStatus.active &&
              booking.checkoutChargePaymentStatus ==
                  PaymentStatus.awaitingPayment &&
              booking.paymentSummary.checkoutChargesTotal > 0,
        )
        .toList();

    if (awaitingBookingPayments.isEmpty && checkoutFeesDue.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = awaitingBookingPayments.length + checkoutFeesDue.length;
    return CrashSurface(
      borderColor: AppPalette.warning.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.sync_outlined, color: AppPalette.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  user.isEmployee
                      ? '$count payment step${count == 1 ? '' : 's'} waiting'
                      : '$count guest payment step${count == 1 ? '' : 's'} waiting',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stripe redirects can return before the webhook updates the booking. Refresh after completing Checkout if the status has not changed yet.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          if (checkoutFeesDue.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Checkout fees due',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...checkoutFeesDue.map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: StatusBadge(
                  label:
                      '${booking.crashpadName}: \$${booking.paymentSummary.checkoutChargesTotal.toStringAsFixed(0)}',
                  icon: Icons.receipt_long_outlined,
                  color: AppPalette.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.isUploading,
    required this.isSavingProfile,
    required this.onPickAvatar,
    required this.onEditProfile,
  });

  final AppUser user;
  final bool isUploading;
  final bool isSavingProfile;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final avatarBytes =
        user.avatarBase64 != null ? base64Decode(user.avatarBase64!) : null;

    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      radius: AppRadius.xxl,
      color: AppPalette.panel.withValues(alpha: 0.78),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
          final avatar = Stack(
            alignment: Alignment.bottomRight,
            children: <Widget>[
              CircleAvatar(
                radius: isWide ? 52 : 44,
                backgroundColor: AppPalette.blue.withValues(alpha: 0.2),
                backgroundImage:
                    avatarBytes != null ? MemoryImage(avatarBytes) : null,
                child: avatarBytes == null
                    ? Text(
                        user.initials,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppPalette.text,
                                ),
                      )
                    : null,
              ),
              TapScale(
                enabled: !isUploading,
                child: IconButton.filled(
                  onPressed: isUploading ? null : onPickAvatar,
                  icon: isUploading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined, size: 18),
                  tooltip: 'Update photo',
                ),
              ),
            ],
          );

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              StatusBadge(
                label: user.isOwner ? 'Owner account' : 'Guest account',
                icon: user.isOwner
                    ? Icons.apartment_outlined
                    : Icons.flight_takeoff_outlined,
                color: user.isOwner ? AppPalette.blueSoft : AppPalette.success,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                user.email,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: isSavingProfile ? null : onEditProfile,
                    icon: isSavingProfile
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: Text(
                      isSavingProfile ? 'Saving...' : 'Edit personal info',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isUploading ? null : onPickAvatar,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Change photo'),
                  ),
                ],
              ),
            ],
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                const SizedBox(height: AppSpacing.xxl),
                summary,
              ],
            );
          }

          return Row(
            children: <Widget>[
              avatar,
              const SizedBox(width: AppSpacing.xxxl),
              Expanded(child: summary),
            ],
          );
        },
      ),
    );
  }
}

class _PersonalInfoSection extends StatelessWidget {
  const _PersonalInfoSection({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final rows = <_ProfileInfoRow>[
      _ProfileInfoRow(
        icon: Icons.badge_outlined,
        label: 'Full name',
        value: user.displayName,
      ),
      _ProfileInfoRow(
        icon: Icons.cake_outlined,
        label: 'Date of birth',
        value: _formatDate(user.dateOfBirth),
      ),
      _ProfileInfoRow(
        icon: Icons.public,
        label: 'Country of birth',
        value: user.countryOfBirth,
      ),
      if (user.isEmployee)
        _ProfileInfoRow(
          icon: Icons.flight_takeoff_outlined,
          label: 'Airline',
          value: _valueOrEmpty(user.company),
        ),
      if (user.isEmployee)
        _ProfileInfoRow(
          icon: Icons.confirmation_number_outlined,
          label: 'Badge',
          value: _valueOrEmpty(user.badgeNumber),
        ),
    ];

    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Personal info',
            subtitle: 'The details used across bookings and reviews.',
          ),
          const SizedBox(height: AppSpacing.lg),
          ...rows,
        ],
      ),
    );
  }
}

class _AccountStatusSection extends StatelessWidget {
  const _AccountStatusSection({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Account status',
            subtitle: 'Role, authentication, and payment readiness.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileInfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: user.isOwner
                ? 'Owner: management tools enabled'
                : 'Guest: booking and review tools enabled',
          ),
          const _ProfileInfoRow(
            icon: Icons.lock_outline,
            label: 'Authentication',
            value: 'Supabase Auth is connected for this account.',
          ),
          const _ProfileInfoRow(
            icon: Icons.payments_outlined,
            label: 'Payments',
            value:
                'Stripe Checkout routes guest payments to owners and keeps the Crash App fee.',
          ),
        ],
      ),
    );
  }
}

class _BookingHistorySection extends StatelessWidget {
  const _BookingHistorySection({
    required this.bookings,
    required this.user,
    required this.onCancelBooking,
    required this.onSubmitCheckoutReport,
    required this.onPayForBooking,
    required this.onPayCheckoutCharges,
  });

  final List<BookingRecord> bookings;
  final AppUser user;
  final Future<void> Function(BookingRecord booking) onCancelBooking;
  final Future<void> Function(BookingRecord booking) onSubmitCheckoutReport;
  final Future<void> Function(BookingRecord booking) onPayForBooking;
  final Future<void> Function(BookingRecord booking) onPayCheckoutCharges;

  @override
  Widget build(BuildContext context) {
    final pending = bookings
        .where(
          (booking) =>
              booking.status == BookingStatus.pending ||
              booking.status == BookingStatus.awaitingPayment,
        )
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
        SectionHeading(
          title: user.isOwner ? 'Managed bookings' : 'Your bookings',
          subtitle: user.isOwner
              ? 'Guest stays attached to your managed listings.'
              : 'Requests, confirmed stays, and cancellations from your perspective.',
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
                    _BookingHistoryList(
                      bookings: pending,
                      user: user,
                      emptyTitle: 'No pending bookings',
                      emptyMessage: user.isOwner
                          ? 'New booking requests appear in the owner dashboard.'
                          : 'Request a crashpad and it will appear here while the owner reviews it.',
                      onCancelBooking: onCancelBooking,
                      onSubmitCheckoutReport: onSubmitCheckoutReport,
                      onPayForBooking: onPayForBooking,
                      onPayCheckoutCharges: onPayCheckoutCharges,
                    ),
                    _BookingHistoryList(
                      bookings: active,
                      user: user,
                      emptyTitle: 'No active bookings',
                      emptyMessage: user.isOwner
                          ? 'Approved stays appear here until checkout.'
                          : 'Owner-approved stays appear here.',
                      onCancelBooking: onCancelBooking,
                      onSubmitCheckoutReport: onSubmitCheckoutReport,
                      onPayForBooking: onPayForBooking,
                      onPayCheckoutCharges: onPayCheckoutCharges,
                    ),
                    _BookingHistoryList(
                      bookings: past,
                      user: user,
                      emptyTitle: 'No past bookings',
                      emptyMessage:
                          'Completed stays will be saved here for your records.',
                      onCancelBooking: onCancelBooking,
                      onSubmitCheckoutReport: onSubmitCheckoutReport,
                      onPayForBooking: onPayForBooking,
                      onPayCheckoutCharges: onPayCheckoutCharges,
                    ),
                    _BookingHistoryList(
                      bookings: cancelled,
                      user: user,
                      emptyTitle: 'No cancelled bookings',
                      emptyMessage:
                          'Cancelled or declined bookings stay separate from active trips.',
                      onCancelBooking: onCancelBooking,
                      onSubmitCheckoutReport: onSubmitCheckoutReport,
                      onPayForBooking: onPayForBooking,
                      onPayCheckoutCharges: onPayCheckoutCharges,
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

class _BookingHistoryList extends StatelessWidget {
  const _BookingHistoryList({
    required this.bookings,
    required this.user,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onCancelBooking,
    required this.onSubmitCheckoutReport,
    required this.onPayForBooking,
    required this.onPayCheckoutCharges,
  });

  final List<BookingRecord> bookings;
  final AppUser user;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function(BookingRecord booking) onCancelBooking;
  final Future<void> Function(BookingRecord booking) onSubmitCheckoutReport;
  final Future<void> Function(BookingRecord booking) onPayForBooking;
  final Future<void> Function(BookingRecord booking) onPayCheckoutCharges;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return BookingEmptyState(title: emptyTitle, message: emptyMessage);
    }

    return ListView.separated(
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final canCancel = user.isEmployee &&
            (booking.status == BookingStatus.pending ||
                booking.status == BookingStatus.awaitingPayment ||
                booking.status == BookingStatus.confirmed);
        final canSubmitCheckout = user.isEmployee &&
            (booking.status == BookingStatus.confirmed ||
                booking.status == BookingStatus.active);
        final canPay =
            user.isEmployee && booking.status == BookingStatus.awaitingPayment;
        final canPayCheckoutCharges = user.isEmployee &&
            booking.status == BookingStatus.active &&
            booking.checkoutChargePaymentStatus ==
                PaymentStatus.awaitingPayment &&
            booking.paymentSummary.checkoutChargesTotal > 0;
        return BookingRecordCard(
          booking: booking,
          perspective: user.isOwner
              ? BookingPerspective.owner
              : BookingPerspective.guest,
          primaryAction: canPay
              ? ElevatedButton.icon(
                  onPressed: () => onPayForBooking(booking),
                  icon: const Icon(Icons.credit_card_outlined),
                  label: const Text('Pay with Stripe'),
                )
              : canPayCheckoutCharges
                  ? ElevatedButton.icon(
                      onPressed: () => onPayCheckoutCharges(booking),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Pay checkout fees'),
                    )
                  : canSubmitCheckout
                      ? ElevatedButton.icon(
                          onPressed: () => onSubmitCheckoutReport(booking),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            booking.checkoutReport == null
                                ? 'Submit checkout report'
                                : 'Update checkout report',
                          ),
                        )
                      : canCancel
                          ? OutlinedButton.icon(
                              onPressed: () => onCancelBooking(booking),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel Booking'),
                            )
                          : null,
          secondaryAction: canSubmitCheckout && canCancel
              ? OutlinedButton.icon(
                  onPressed: () => onCancelBooking(booking),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Booking'),
                )
              : null,
        );
      },
    );
  }
}

class _CheckoutReportDraft {
  const _CheckoutReportDraft({
    required this.notes,
    required this.photos,
  });

  final String notes;
  final List<CheckoutPhoto> photos;
}

class _CheckoutReportDialog extends StatefulWidget {
  const _CheckoutReportDialog({required this.booking});

  final BookingRecord booking;

  @override
  State<_CheckoutReportDialog> createState() => _CheckoutReportDialogState();
}

class _CheckoutReportDialogState extends State<_CheckoutReportDialog> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  final List<CheckoutPhoto> _photos = <CheckoutPhoto>[];
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.booking.checkoutReport;
    if (existing != null) {
      _notesController.text = existing.notes;
      _photos.addAll(existing.photos);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => _isPicking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photos.add(
          CheckoutPhoto(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            fileName: file.name,
            base64Data: base64Encode(bytes),
            capturedAt: DateTime.now(),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _submit() {
    if (_notesController.text.trim().isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a note or photo before submitting.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _CheckoutReportDraft(
        notes: _notesController.text.trim(),
        photos: List.unmodifiable(_photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Checkout report'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.booking.crashpadName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Checkout notes',
                  hintText: 'Describe the room condition before you leave.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  ..._photos.map(
                    (photo) => _CheckoutPhotoThumb(
                      photo: photo,
                      onRemove: () => setState(() => _photos.remove(photo)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isPicking ? null : _pickPhoto,
                    icon: _isPicking
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_isPicking ? 'Adding...' : 'Add photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit report'),
        ),
      ],
    );
  }
}

class _CheckoutPhotoThumb extends StatelessWidget {
  const _CheckoutPhotoThumb({
    required this.photo,
    required this.onRemove,
  });

  final CheckoutPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(photo.base64Data);
    return SizedBox(
      width: 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.memory(
              bytes,
              height: 84,
              width: 118,
              fit: BoxFit.cover,
            ),
          ),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _ReviewHistorySection extends StatelessWidget {
  const _ReviewHistorySection({required this.reviews, required this.user});

  final List<ReviewWithCrashpad> reviews;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeading(
          title: 'Reviews',
          subtitle: user.isOwner
              ? 'Guest feedback across your listings.'
              : 'Reviews you have submitted after completed stays.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (reviews.isEmpty)
          EmptyStatePanel(
            icon: Icons.reviews_outlined,
            title: user.isOwner ? 'No listing reviews yet' : 'No reviews yet',
            message: user.isOwner
                ? 'Reviews for your crashpads will appear here.'
                : 'Complete a confirmed stay, then share a review from the listing page.',
          )
        else
          CrashSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: reviews.asMap().entries.map((entry) {
                final isLast = entry.key == reviews.length - 1;
                return Column(
                  children: <Widget>[
                    _ReviewHistoryTile(record: entry.value),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ReviewHistoryTile extends StatelessWidget {
  const _ReviewHistoryTile({required this.record});

  final ReviewWithCrashpad record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  record.crashpadName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.star_rounded, color: AppPalette.warning),
              const SizedBox(width: 4),
              Text(record.review.rating.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(record.review.comment),
          const SizedBox(height: 8),
          Text(
            '${record.review.employeeName} | ${_formatDate(record.review.createdAt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppPalette.blueSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(
        title: 'Profile',
        subtitle: 'Sign in to manage your Crashpad account.',
        icon: Icons.person_outline,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: EmptyStatePanel(
            icon: Icons.person_off_outlined,
            title: 'You are signed out',
            message: 'Sign in to view personal info, bookings, and reviews.',
          ),
        ),
      ),
    );
  }
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.user});

  final AppUser user;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _countryController;
  late final TextEditingController _companyController;
  late final TextEditingController _badgeController;
  late DateTime _dateOfBirth;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _countryController = TextEditingController(text: user.countryOfBirth);
    _companyController = TextEditingController(text: user.company ?? '');
    _badgeController = TextEditingController(text: user.badgeNumber ?? '');
    _dateOfBirth = user.dateOfBirth;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _companyController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() => _dateOfBirth = selected);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ProfileDraft(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        countryOfBirth: _countryController.text.trim(),
        dateOfBirth: _dateOfBirth,
        company: _companyController.text.trim(),
        badgeNumber: _badgeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AlertDialog(
      title: const Text('Edit profile'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.tablet;
                    final firstName = TextFormField(
                      controller: _firstNameController,
                      decoration:
                          const InputDecoration(labelText: 'First name'),
                      validator: _requiredValidator,
                    );
                    final lastName = TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: _requiredValidator,
                    );

                    if (!isWide) {
                      return Column(
                        children: <Widget>[
                          firstName,
                          const SizedBox(height: AppSpacing.lg),
                          lastName,
                        ],
                      );
                    }

                    return Row(
                      children: <Widget>[
                        Expanded(child: firstName),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: lastName),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _countryController,
                  decoration:
                      const InputDecoration(labelText: 'Country of birth'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Text(_formatDate(_dateOfBirth)),
                  ),
                ),
                if (user.isEmployee) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(labelText: 'Airline'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _badgeController,
                    decoration: const InputDecoration(labelText: 'Badge ID'),
                    validator: _requiredValidator,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.countryOfBirth,
    required this.dateOfBirth,
    required this.company,
    required this.badgeNumber,
  });

  final String firstName;
  final String lastName;
  final String countryOfBirth;
  final DateTime dateOfBirth;
  final String company;
  final String badgeNumber;
}

String _formatDate(DateTime date) {
  return DateFormat('MMM d, yyyy').format(date);
}

String _valueOrEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return 'Not provided';
  return value;
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}
