import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../models/review.dart';
import '../services/availability_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/crashpad_listing_card.dart';
import '../widgets/interaction_feedback.dart';

class OwnerDetailsScreen extends StatefulWidget {
  const OwnerDetailsScreen({super.key, required this.crashpad});

  final Crashpad crashpad;

  @override
  State<OwnerDetailsScreen> createState() => _OwnerDetailsScreenState();
}

class _OwnerDetailsScreenState extends State<OwnerDetailsScreen> {
  late Crashpad _crashpad;
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _crashpad = widget.crashpad;
    _reviewsFuture = _fetchReviews();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackClick());
  }

  Future<void> _trackClick() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user != null &&
        user.email.toLowerCase() == _crashpad.owner.contact?.toLowerCase()) {
      return;
    }
    await repository.incrementClickCount(_crashpad.id);
  }

  Future<List<Review>> _fetchReviews() {
    return context.read<AppRepository>().fetchReviews(_crashpad.id);
  }

  Future<void> _addReview() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || user.userType != AppUserType.employee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only verified crew can write reviews.')),
      );
      return;
    }

    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => const _ReviewDialog(),
    );
    if (result == null) return;

    await repository.addReview(
      crashpadId: _crashpad.id,
      employeeName: user.displayName,
      comment: result.comment,
      rating: result.rating,
    );
    if (!mounted) return;
    setState(() => _reviewsFuture = _fetchReviews());
    await showActionFeedback(
      context: context,
      icon: Icons.reviews_outlined,
      title: 'Review added',
      message: 'Your crew insight is now visible.',
      color: AppPalette.cyan,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final isEmployee = repository.currentUser?.userType == AppUserType.employee;
    final averageRating = repository.calculateAverageRating(_crashpad.id);
    final availability = const AvailabilityService().summarize(_crashpad);

    return Scaffold(
      appBar: AppBar(
        leading: const AnimatedBackButton(),
        title: const Text('Crashpad details'),
        actions: <Widget>[
          if (isEmployee)
            IconButton(
              onPressed: _addReview,
              icon: const Icon(Icons.rate_review_outlined),
              tooltip: 'Add review',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 1240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.desktop;
                    final gallery = _ListingHero(
                      crashpad: _crashpad,
                      averageRating: averageRating,
                      availability: availability,
                    );
                    final booking = _BookingPanel(crashpad: _crashpad);

                    if (!isWide) {
                      return Column(
                        children: <Widget>[
                          gallery,
                          const SizedBox(height: AppSpacing.xxl),
                          booking,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 7, child: gallery),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(flex: 4, child: booking),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxxl),
                _DetailsGrid(crashpad: _crashpad),
                const SizedBox(height: AppSpacing.xxxl),
                _RoomsSection(crashpad: _crashpad),
                const SizedBox(height: AppSpacing.xxxl),
                _ReviewsSection(reviewsFuture: _reviewsFuture),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListingHero extends StatelessWidget {
  const _ListingHero({
    required this.crashpad,
    required this.averageRating,
    required this.availability,
  });

  final Crashpad crashpad;
  final double averageRating;
  final AvailabilitySummary availability;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: Stack(
            children: <Widget>[
              CrashpadImage(
                imageUrls: crashpad.imageUrls,
                height:
                    MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet
                        ? 430
                        : 280,
                width: double.infinity,
                heroTag: 'crashpad-${crashpad.id}',
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.74),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        StatusBadge(
                          label: crashpad.bedModel.label,
                          icon: Icons.bed_outlined,
                          color: crashpad.bedModel == CrashpadBedModel.cold
                              ? AppPalette.success
                              : AppPalette.blueSoft,
                        ),
                        StatusBadge(
                          label:
                              '${availability.availableToBook} spaces available',
                          icon: Icons.event_available_outlined,
                          color: availability.hasAvailability
                              ? AppPalette.success
                              : AppPalette.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      crashpad.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppPalette.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${crashpad.location} | Nearest airport: ${crashpad.nearestAirport}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.text.withValues(alpha: 0.86)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _FactPill(
              icon: Icons.star_rounded,
              label: averageRating == 0
                  ? 'New listing'
                  : '${averageRating.toStringAsFixed(1)} crew rating',
            ),
            _FactPill(
              icon: Icons.king_bed_outlined,
              label: '${availability.totalPhysicalBeds} physical beds',
            ),
            _FactPill(
              icon: Icons.groups_2_outlined,
              label: '${crashpad.totalActiveGuests} active guests',
            ),
            if (crashpad.distanceToAirportMiles != null)
              _FactPill(
                icon: Icons.route_outlined,
                label:
                    '${crashpad.distanceToAirportMiles!.toStringAsFixed(1)} miles to ${crashpad.nearestAirport}',
              ),
          ],
        ),
      ],
    );
  }
}

class _BookingPanel extends StatefulWidget {
  const _BookingPanel({required this.crashpad});

  final Crashpad crashpad;

  @override
  State<_BookingPanel> createState() => _BookingPanelState();
}

class _BookingPanelState extends State<_BookingPanel> {
  final PaymentService _paymentService = const PaymentService();
  final Set<String> _selectedServices = <String>{};
  int _nights = AppConfig.defaultBookingNights;
  int _guestCount = AppConfig.defaultGuestCount;

  PaymentSummary get _summary {
    return _paymentService.buildSummary(_draft);
  }

  BookingDraft get _draft {
    final repository = context.read<AppRepository>();
    final guest = repository.currentUser;
    final selected = widget.crashpad.services
        .where((service) => _selectedServices.contains(service.id))
        .map((service) => service.toLineItem())
        .toList();

    return BookingDraft(
      crashpadId: widget.crashpad.id,
      guestId: guest?.id ?? 'guest',
      nightlyRate: widget.crashpad.price,
      nights: _nights,
      guestCount: _guestCount,
      additionalServices: selected,
    );
  }

  Future<void> _showMockPayment() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || !user.isEmployee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in as crew to book this stay.')),
      );
      return;
    }
    final authorized = _paymentService.authorizeMockPayment(_summary);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mock payment ready'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: PaymentSummaryCard(summary: authorized),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await repository.createBooking(
                crashpad: widget.crashpad,
                draft: _draft,
                paymentSummary: _paymentService.captureMockPayment(authorized),
              );
              if (!mounted) return;
              await showActionFeedback(
                context: context,
                icon: Icons.check_circle_outline,
                title: 'Booking confirmed',
                message: 'The owner can now manage this stay.',
                color: AppPalette.success,
              );
            },
            child: const Text('Confirm mock payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availability = const AvailabilityService().summarize(widget.crashpad);

    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Book this stay', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            widget.crashpad.bedModel.guestExplanation,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: _StepperField(
                  label: 'Nights',
                  value: _nights,
                  min: widget.crashpad.minimumStayNights,
                  max: 30,
                  onChanged: (value) => setState(() => _nights = value),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _StepperField(
                  label: 'Guests',
                  value: _guestCount,
                  min: 1,
                  max: availability.availableToBook.clamp(1, 8).toInt(),
                  onChanged: (value) => setState(() => _guestCount = value),
                ),
              ),
            ],
          ),
          if (widget.crashpad.services.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Additional services',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...widget.crashpad.services.map((service) {
              final selected = _selectedServices.contains(service.id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(service.name),
                subtitle: Text(
                  '${service.description}  |  \$${service.price.toStringAsFixed(2)}',
                ),
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _selectedServices.add(service.id);
                    } else {
                      _selectedServices.remove(service.id);
                    }
                  });
                },
              );
            }),
          ],
          const SizedBox(height: AppSpacing.xl),
          PaymentSummaryCard(summary: _summary),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: availability.hasAvailability ? _showMockPayment : null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Continue to mock payment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
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
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.crashpad});

  final Crashpad crashpad;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
        final children = <Widget>[
          _DescriptionBlock(crashpad: crashpad),
          _RulesAndFeesBlock(crashpad: crashpad),
        ];

        if (!isWide) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: children.first),
            const SizedBox(width: AppSpacing.xxl),
            Expanded(child: children.last),
          ],
        );
      },
    );
  }
}

class _DescriptionBlock extends StatelessWidget {
  const _DescriptionBlock({required this.crashpad});

  final Crashpad crashpad;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What guests get',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(crashpad.description),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: crashpad.amenities
                .map(
                  (amenity) => StatusBadge(
                    label: amenity,
                    icon: Icons.check_circle_outline,
                    color: AppPalette.blueSoft,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RulesAndFeesBlock extends StatelessWidget {
  const _RulesAndFeesBlock({required this.crashpad});

  final Crashpad crashpad;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Rules and checkout charges',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...crashpad.houseRules.map(
            (rule) => _BulletLine(icon: Icons.rule_outlined, text: rule),
          ),
          if (crashpad.checkoutCharges.isNotEmpty) ...<Widget>[
            const Divider(height: 30),
            ...crashpad.checkoutCharges.map(
              (charge) => _BulletLine(
                icon: Icons.receipt_long_outlined,
                text:
                    '${charge.name}: \$${charge.amount.toStringAsFixed(2)} - ${charge.description}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({required this.crashpad});

  final Crashpad crashpad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(
          title: 'Rooms and bed logic',
          subtitle:
              'Owners can support assigned cold beds, rotating hot beds, or both.',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= AppBreakpoints.desktop
                ? 3
                : constraints.maxWidth >= AppBreakpoints.tablet
                    ? 2
                    : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: crashpad.rooms.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: columns == 1 ? 1.55 : 1.2,
              ),
              itemBuilder: (context, index) => _RoomCard(
                room: crashpad.rooms[index],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final CrashpadRoom room;

  @override
  Widget build(BuildContext context) {
    final isHot = room.bedModel == CrashpadBedModel.hot;
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(room.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              StatusBadge(label: room.bedModel.shortLabel),
            ],
          ),
          const SizedBox(height: 12),
          _BulletLine(
            icon: Icons.king_bed_outlined,
            text: '${room.physicalBeds} physical beds',
          ),
          _BulletLine(
            icon:
                isHot ? Icons.groups_2_outlined : Icons.assignment_ind_outlined,
            text: isHot
                ? '${room.availableHotSlots} hot-bed slots open'
                : '${room.availableColdBeds} assigned beds open',
          ),
          _BulletLine(
            icon: Icons.person_pin_circle_outlined,
            text: '${room.activeGuests} active guests',
          ),
          if (room.storageNote != null)
            _BulletLine(
                icon: Icons.inventory_2_outlined, text: room.storageNote!),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviewsFuture});

  final Future<List<Review>> reviewsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: reviewsFuture,
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? <Review>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeading(
              title: 'Crew reviews',
              subtitle: 'Recent guest feedback from verified crew members.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (reviews.isEmpty)
              const EmptyStatePanel(
                icon: Icons.reviews_outlined,
                title: 'No reviews yet',
                message: 'Verified crew reviews will appear here.',
              )
            else
              Column(
                children: reviews
                    .map(
                      (review) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: _ReviewTile(review: review),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  review.employeeName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.star_rounded, color: AppPalette.warning),
              const SizedBox(width: 4),
              Text(review.rating.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment),
          const SizedBox(height: 8),
          Text(
            _formatDate(review.createdAt),
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

class _FactPill extends StatelessWidget {
  const _FactPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: label, icon: icon, color: AppPalette.textMuted);
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppPalette.blueSoft),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft({required this.comment, required this.rating});

  final String comment;
  final double rating;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  double _rating = 4.5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share your experience'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'What should other crew know?',
              ),
              validator: (value) => value == null || value.trim().length < 10
                  ? 'Be a bit more descriptive'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Slider(
                    value: _rating,
                    onChanged: (value) => setState(() => _rating = value),
                    divisions: 8,
                    min: 1,
                    max: 5,
                    label: _rating.toStringAsFixed(1),
                  ),
                ),
                Text(_rating.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _ReviewDraft(
                  comment: _commentController.text.trim(),
                  rating: _rating,
                ),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
