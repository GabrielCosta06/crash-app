import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../services/availability_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/booking_components.dart';
import '../widgets/interaction_feedback.dart';

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

  Future<void> _openLaunchChecklist() async {
    await Navigator.pushNamed(context, '/launch-checklist');
  }

  List<BookingRecord> _ownerBookingsForCurrentUser() {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null) return const <BookingRecord>[];
    return repository.bookings
        .where(
          (booking) =>
              booking.ownerEmail.toLowerCase() == user.email.toLowerCase(),
        )
        .toList();
  }

  Future<void> _openCheckoutCharges() async {
    final repository = context.read<AppRepository>();
    final activeBookings = _ownerBookingsForCurrentUser()
        .where((booking) => booking.status == BookingStatus.active)
        .toList();
    if (activeBookings.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No checked-in stays'),
          content: const Text(
            'Checkout charges can be assessed after a booking has been checked in.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final booking = await showDialog<BookingRecord>(
      context: context,
      builder: (context) => _BookingPickerDialog(
        title: 'Select stay for charges',
        bookings: activeBookings,
      ),
    );
    if (booking == null || !mounted) return;
    final listing = repository.findCrashpadById(booking.crashpadId);
    final draft = await showDialog<_CheckoutCompletionDraft>(
      context: context,
      builder: (context) => _CheckoutChargeDialog(
        booking: booking,
        availableCharges: listing?.checkoutCharges ?? const [],
        title: 'Assess checkout charges',
        intro:
            'Review checkout evidence for ${booking.guestName}, select any charges, then send them to the guest for Stripe Checkout payment.',
        actionLabel: 'Save charges',
      ),
    );
    if (draft == null) return;
    try {
      await repository.assessCheckoutCharges(
        bookingId: booking.id,
        charges: draft.charges,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checkout charges saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save checkout charges: $error')),
      );
    }
  }

  Future<void> _openManualAssignment() async {
    final repository = context.read<AppRepository>();
    final bookings = _ownerBookingsForCurrentUser()
        .where(
          (booking) =>
              booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.active,
        )
        .toList();
    final listings = (await _listingsFuture);
    if (!mounted) return;
    if (bookings.isEmpty || listings.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No stays to assign'),
          content: const Text(
            'Manual assignment is available for confirmed or checked-in stays.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final draft = await showDialog<_ManualAssignmentDraft>(
      context: context,
      builder: (context) =>
          _ManualAssignmentDialog(bookings: bookings, listings: listings),
    );
    if (draft == null) return;
    try {
      await repository.assignBookingBed(
        bookingId: draft.bookingId,
        roomId: draft.roomId,
        bedId: draft.bedId,
        assignmentNote: draft.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Manual assignment saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save assignment: $error')),
      );
    }
  }

  Future<void> _setBookingStatus(
    BookingRecord booking,
    BookingStatus status,
  ) async {
    var checkoutCharges = const <ChargeLineItem>[];
    var ownerCheckoutNote = '';
    if (status == BookingStatus.completed) {
      final listing = context.read<AppRepository>().findCrashpadById(
            booking.crashpadId,
          );
      final completion = await showDialog<_CheckoutCompletionDraft>(
        context: context,
        builder: (context) => _CheckoutChargeDialog(
          booking: booking,
          availableCharges: listing?.checkoutCharges ?? const [],
          title: 'Complete stay',
          intro:
              'Review checkout evidence for ${booking.guestName}. If you add charges, the guest must pay them in Stripe before the stay is completed.',
          actionLabel: 'Complete Stay',
        ),
      );
      if (completion == null) return;
      checkoutCharges = completion.charges;
      ownerCheckoutNote = completion.ownerNote;
    } else {
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
    }
    if (!mounted) return;
    setState(() => _updatingBookingId = booking.id);
    try {
      final repository = context.read<AppRepository>();
      switch (status) {
        case BookingStatus.awaitingPayment:
          throw StateError('Guest payment is required before confirmation.');
        case BookingStatus.confirmed:
          await repository.approveBooking(booking.id);
          break;
        case BookingStatus.cancelled:
          if (booking.status == BookingStatus.pending) {
            await repository.declineBooking(booking.id);
          } else {
            await repository.cancelBooking(booking.id);
          }
          break;
        case BookingStatus.active:
          await repository.checkInBooking(booking.id);
          break;
        case BookingStatus.completed:
          await repository.completeBooking(
            bookingId: booking.id,
            checkoutCharges: checkoutCharges,
            ownerCheckoutNote: ownerCheckoutNote,
          );
          break;
        case BookingStatus.pending:
        case BookingStatus.draft:
          throw StateError('Unsupported owner booking transition.');
      }
      if (!mounted) return;
      final resultLabel = status == BookingStatus.confirmed &&
              booking.status == BookingStatus.pending
          ? BookingStatus.awaitingPayment.label
          : status == BookingStatus.completed && checkoutCharges.isNotEmpty
              ? 'Awaiting checkout fee payment'
              : status.label;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stay moved to $resultLabel.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update stay: $error')));
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
      case BookingStatus.awaitingPayment:
        return 'Waiting for guest payment';
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
        return 'Approve ${booking.guestName} for ${booking.crashpadName}. The guest will receive a Stripe Checkout payment request before the stay is confirmed.';
      case BookingStatus.awaitingPayment:
        return 'The owner approved this request. The guest must complete payment before check-in.';
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
      case BookingStatus.awaitingPayment:
        return 'Waiting for Payment';
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
                      const SizedBox(height: AppSpacing.xl),
                      _Metrics(listings: listings, bookings: ownerBookings),
                      const SizedBox(height: AppSpacing.xxl),
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
                                const SizedBox(height: AppSpacing.xl),
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
                      const SizedBox(height: AppSpacing.xxl),
                      _WorkflowPanel(
                        listings: listings,
                        onCreateListing: _openCreateListing,
                        onDeleteListings: _openDeleteListings,
                        onCheckoutCharges: _openCheckoutCharges,
                        onManualAssignment: _openManualAssignment,
                        onLaunchChecklist: _openLaunchChecklist,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.sizeOf(context).width < 900 ? 88 : 0,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openCreateListing,
          icon: const Icon(Icons.add_home_work_outlined),
          label: const Text('Add crashpad'),
        ),
      ),
    );
  }
}

class _CheckoutChargeDialog extends StatefulWidget {
  const _CheckoutChargeDialog({
    required this.booking,
    required this.availableCharges,
    required this.title,
    required this.intro,
    required this.actionLabel,
  });

  final BookingRecord booking;
  final List<CrashpadCheckoutCharge> availableCharges;
  final String title;
  final String intro;
  final String actionLabel;

  @override
  State<_CheckoutChargeDialog> createState() => _CheckoutChargeDialogState();
}

class _CheckoutCompletionDraft {
  const _CheckoutCompletionDraft({
    required this.charges,
    required this.ownerNote,
  });

  final List<ChargeLineItem> charges;
  final String ownerNote;
}

class _CheckoutChargeDialogState extends State<_CheckoutChargeDialog> {
  final Set<String> _selectedChargeIds = <String>{};
  final TextEditingController _ownerNoteController = TextEditingController();

  @override
  void dispose() {
    _ownerNoteController.dispose();
    super.dispose();
  }

  void _complete(List<ChargeLineItem> selectedCharges) {
    final ownerNote = _ownerNoteController.text.trim();
    final needsNote = selectedCharges.any(
      (charge) =>
          charge.type == ChargeType.cleaning ||
          charge.type == ChargeType.lateCheckout ||
          charge.type == ChargeType.checkout,
    );
    final needsDamageEvidence = selectedCharges.any(
      (charge) =>
          charge.type == ChargeType.damage || charge.type == ChargeType.custom,
    );
    final hasGuestPhoto = widget.booking.checkoutReport?.hasPhotos ?? false;

    if (needsNote && ownerNote.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an owner note for cleaning or late fees.'),
        ),
      );
      return;
    }
    if (needsDamageEvidence && ownerNote.isEmpty && !hasGuestPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Damage and custom fees require guest photos or an owner note.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _CheckoutCompletionDraft(charges: selectedCharges, ownerNote: ownerNote),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.booking.checkoutReport;
    final selectedCharges = widget.availableCharges
        .where((charge) => _selectedChargeIds.contains(charge.id))
        .map((charge) => charge.toLineItem())
        .toList();
    final preview = widget.booking.paymentSummary.copyWith(
      checkoutCharges: selectedCharges,
    );

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.intro),
              const SizedBox(height: AppSpacing.lg),
              _CheckoutEvidencePanel(report: report),
              const SizedBox(height: AppSpacing.lg),
              if (widget.availableCharges.isEmpty)
                Text(
                  'This listing has no configured checkout charges.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                )
              else
                ...widget.availableCharges.map((charge) {
                  final selected = _selectedChargeIds.contains(charge.id);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(charge.name),
                    subtitle: Text(
                      '${charge.description}  |  \$${charge.amount.toStringAsFixed(2)}',
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedChargeIds.add(charge.id);
                        } else {
                          _selectedChargeIds.remove(charge.id);
                        }
                      });
                    },
                  );
                }),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _ownerNoteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Owner checkout note',
                  hintText:
                      'Required when applying cleaning, late checkout, damage, or custom fees.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PaymentSummaryCard(summary: preview, showStatus: false),
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
          onPressed: () => _complete(selectedCharges),
          icon: const Icon(Icons.done_all_outlined),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _BookingPickerDialog extends StatelessWidget {
  const _BookingPickerDialog({required this.title, required this.bookings});

  final String title;
  final List<BookingRecord> bookings;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: Text(booking.crashpadName),
              subtitle: Text('${booking.guestName} - ${booking.status.label}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, booking),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ManualAssignmentDraft {
  const _ManualAssignmentDraft({
    required this.bookingId,
    required this.roomId,
    required this.bedId,
    required this.note,
  });

  final String bookingId;
  final String roomId;
  final String? bedId;
  final String note;
}

class _ManualAssignmentDialog extends StatefulWidget {
  const _ManualAssignmentDialog({
    required this.bookings,
    required this.listings,
  });

  final List<BookingRecord> bookings;
  final List<Crashpad> listings;

  @override
  State<_ManualAssignmentDialog> createState() =>
      _ManualAssignmentDialogState();
}

class _ManualAssignmentDialogState extends State<_ManualAssignmentDialog> {
  late BookingRecord _selectedBooking;
  String? _selectedRoomId;
  String? _selectedBedId;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBooking = widget.bookings.first;
    _selectedRoomId = _listingFor(_selectedBooking)?.rooms.firstOrNull?.id;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Crashpad? _listingFor(BookingRecord booking) {
    for (final listing in widget.listings) {
      if (listing.id == booking.crashpadId) return listing;
    }
    return null;
  }

  CrashpadRoom? _selectedRoom(Crashpad? listing) {
    if (listing == null || _selectedRoomId == null) return null;
    for (final room in listing.rooms) {
      if (room.id == _selectedRoomId) return room;
    }
    return null;
  }

  void _submit() {
    final roomId = _selectedRoomId;
    if (roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a room before saving.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _ManualAssignmentDraft(
        bookingId: _selectedBooking.id,
        roomId: roomId,
        bedId: _selectedBedId,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listingFor(_selectedBooking);
    final room = _selectedRoom(listing);
    final beds = room?.beds
            .where(
              (bed) =>
                  room.bedModel != CrashpadBedModel.cold ||
                  (!bed.isAssigned && bed.isAvailable),
            )
            .toList() ??
        const <CrashpadBed>[];
    final requiresBed = room?.bedModel == CrashpadBedModel.cold;

    return AlertDialog(
      title: const Text('Manual assignment'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _selectedBooking.id,
                decoration: const InputDecoration(
                  labelText: 'Booking',
                  prefixIcon: Icon(Icons.event_available_outlined),
                ),
                items: widget.bookings
                    .map(
                      (booking) => DropdownMenuItem<String>(
                        value: booking.id,
                        child: Text(
                          '${booking.guestName} - ${booking.crashpadName}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final booking = widget.bookings.firstWhere(
                    (candidate) => candidate.id == value,
                  );
                  final nextListing = _listingFor(booking);
                  setState(() {
                    _selectedBooking = booking;
                    _selectedRoomId = nextListing?.rooms.firstOrNull?.id;
                    _selectedBedId = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoomId,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: (listing?.rooms ?? const <CrashpadRoom>[])
                    .map(
                      (room) => DropdownMenuItem<String>(
                        value: room.id,
                        child: Text(
                          '${room.name} (${room.bedModel.shortLabel})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoomId = value;
                    _selectedBedId = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _selectedBedId,
                decoration: InputDecoration(
                  labelText: requiresBed ? 'Bed' : 'Bed (optional)',
                  prefixIcon: const Icon(Icons.bed_outlined),
                ),
                items: beds
                    .map(
                      (bed) => DropdownMenuItem<String>(
                        value: bed.id,
                        child: Text(bed.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedBedId = value),
                validator: (_) =>
                    requiresBed && _selectedBedId == null ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Assignment note',
                  hintText: 'Optional room, locker, or arrival context.',
                ),
              ),
              if (requiresBed && beds.isEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const Text('No available cold beds remain in this room.'),
              ],
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
          onPressed: requiresBed && _selectedBedId == null ? null : _submit,
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Save assignment'),
        ),
      ],
    );
  }
}

class _CheckoutEvidencePanel extends StatelessWidget {
  const _CheckoutEvidencePanel({required this.report});

  final CheckoutReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return CrashSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: AppRadius.lg,
        color: AppPalette.panelElevated.withValues(alpha: 0.42),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline, color: AppPalette.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'No guest checkout report has been submitted.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      color: AppPalette.panelElevated.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.fact_check_outlined, color: AppPalette.cyan),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Guest checkout report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label:
                    '${report!.photos.length} photo${report!.photos.length == 1 ? '' : 's'}',
                icon: Icons.photo_camera_outlined,
                color: AppPalette.cyan,
              ),
            ],
          ),
          if (report!.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(report!.notes),
          ],
          if (report!.photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: report!.photos.map((photo) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.memory(
                    base64Decode(photo.base64Data),
                    height: 96,
                    width: 128,
                    fit: BoxFit.cover,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerHero extends StatelessWidget {
  const _OwnerHero({required this.owner, required this.listings});

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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppPalette.textMuted),
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
                      Text(
                        owner.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listings.length} active properties',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppPalette.textMuted,
                            ),
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
  const _Metrics({required this.listings, required this.bookings});

  final List<Crashpad> listings;
  final List<BookingRecord> bookings;

  @override
  Widget build(BuildContext context) {
    final availability = const AvailabilityService();
    final totalBeds = listings.fold<int>(
      0,
      (sum, listing) => sum + availability.summarize(listing).totalPhysicalBeds,
    );
    final repository = context.watch<AppRepository>();
    final tomorrow = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 1));
    final openCapacity = listings.fold<int>(0, (sum, listing) {
      return sum +
          repository.availableCapacityForDates(
            crashpad: listing,
            checkInDate: tomorrow,
            checkOutDate: tomorrow.add(
              Duration(days: listing.minimumStayNights),
            ),
          );
    });
    final activeGuests = listings.fold<int>(
      0,
      (sum, listing) =>
          sum +
          bookings
              .where(
                (booking) =>
                    booking.crashpadId == listing.id &&
                    booking.status == BookingStatus.active,
              )
              .fold<int>(0, (total, booking) => total + booking.guestCount),
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
      final checkIn = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 1));
      final checkOut = checkIn.add(Duration(days: listing.minimumStayNights));
      final summary = paymentService.buildSummary(
        BookingDraft(
          crashpadId: listing.id,
          guestId: 'owner-dashboard-preview',
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
    return TapScale(
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, '/owner-details', arguments: listing),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < AppBreakpoints.tablet;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    listing.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${listing.nearestAirport} | ${listing.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
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
            final checkIn = DateUtils.dateOnly(
              DateTime.now(),
            ).add(const Duration(days: 1));
            final checkOut = checkIn.add(
              Duration(days: primary.minimumStayNights),
            );
            return paymentService.buildSummary(
              BookingDraft(
                crashpadId: primary.id,
                guestId: 'owner-payout-preview',
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
            action: AppPrimaryButton(
              onPressed: () {},
              icon: Icons.add,
              child: const Text('Add your first crashpad'),
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
        CrashSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Payout calculation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Calculated from the current nightly rate, each listing minimum stay, and centralized ${(AppConfig.platformFeeRate * 100).toStringAsFixed(0)}% Crash App fee. Stripe Checkout handles guest payments before payouts are finalized.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
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
      return BookingEmptyState(title: emptyTitle, message: emptyMessage);
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
      case BookingStatus.awaitingPayment:
        return const _BookingCardActions();
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
    required this.onCheckoutCharges,
    required this.onManualAssignment,
    required this.onLaunchChecklist,
  });

  final List<Crashpad> listings;
  final VoidCallback onCreateListing;
  final VoidCallback onDeleteListings;
  final VoidCallback onCheckoutCharges;
  final VoidCallback onManualAssignment;
  final VoidCallback onLaunchChecklist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(
          title: 'Operational workflows',
          subtitle:
              'Manage real listings, stays, assignments, and Stripe-backed charges.',
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
              onTap: onCheckoutCharges,
            ),
            _WorkflowAction(
              icon: Icons.assignment_ind_outlined,
              title: 'Manual assignment',
              description:
                  'Cold-bed assignment and hot-bed capacity logic are separated from UI.',
              onTap: onManualAssignment,
            ),
            _WorkflowAction(
              icon: Icons.delete_sweep_outlined,
              title: 'Manage listings',
              description:
                  'Remove outdated listings from the management inventory.',
              onTap: onDeleteListings,
            ),
            _WorkflowAction(
              icon: Icons.fact_check_outlined,
              title: 'Launch checklist',
              description:
                  'Walk through first-user QA for listings, Stripe payouts, booking payments, and checkout fees.',
              onTap: onLaunchChecklist,
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
      child: TapScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: CrashSurface(
            radius: AppRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: AppPalette.blueSoft),
                const SizedBox(height: 14),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
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
    return const SafeArea(
      child: SingleChildScrollView(
        child: ResponsivePage(
          maxWidth: 1240,
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ShimmerBox(height: 148, width: double.infinity),
                SizedBox(height: AppSpacing.xl),
                _DashboardMetricSkeletonGrid(),
                SizedBox(height: AppSpacing.xxl),
                ShimmerBox(height: 280, width: double.infinity),
                SizedBox(height: AppSpacing.xxl),
                ShimmerBox(height: 360, width: double.infinity),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricSkeletonGrid extends StatelessWidget {
  const _DashboardMetricSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppBreakpoints.desktop
            ? 4
            : constraints.maxWidth >= AppBreakpoints.tablet
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            childAspectRatio: columns == 1 ? 2.7 : 1.55,
          ),
          itemBuilder: (context, index) =>
              const ShimmerBox(height: 120, width: double.infinity),
        );
      },
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
