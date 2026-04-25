import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';
import '../widgets/page_header.dart';

final NumberFormat _money = NumberFormat.currency(symbol: r'$');

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
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update photo: $error')),
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
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update profile: $error')),
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
              _BookingHistorySection(bookings: bookings, user: user),
              const SizedBox(height: AppSpacing.xxxl),
              _ReviewHistorySection(reviews: reviews, user: user),
            ],
          ),
        ),
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
            subtitle: 'Access, subscription, and platform readiness.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileInfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: user.isOwner
                ? 'Owner: management tools enabled'
                : 'Guest: booking and review tools enabled',
          ),
          _ProfileInfoRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription',
            value: user.isSubscribed ? 'Premium active' : 'Free demo account',
          ),
          const _ProfileInfoRow(
            icon: Icons.lock_outline,
            label: 'Authentication',
            value: 'Demo in-memory auth with a Supabase-ready repository.',
          ),
          const _ProfileInfoRow(
            icon: Icons.payments_outlined,
            label: 'Payments',
            value: 'Mock checkout captures payment before confirming stays.',
          ),
        ],
      ),
    );
  }
}

class _BookingHistorySection extends StatelessWidget {
  const _BookingHistorySection({required this.bookings, required this.user});

  final List<BookingRecord> bookings;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeading(
          title: 'Booking history',
          subtitle: user.isOwner
              ? 'Guest stays attached to your managed listings.'
              : 'Your confirmed stays and stay progress.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (bookings.isEmpty)
          EmptyStatePanel(
            icon: Icons.event_busy_outlined,
            title: user.isOwner ? 'No managed stays yet' : 'No bookings yet',
            message: user.isOwner
                ? 'Confirmed guest bookings will appear here after checkout.'
                : 'Book a crashpad and your confirmed stay will appear here.',
          )
        else
          CrashSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: bookings.asMap().entries.map((entry) {
                final isLast = entry.key == bookings.length - 1;
                return Column(
                  children: <Widget>[
                    _BookingHistoryTile(booking: entry.value, user: user),
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

class _BookingHistoryTile extends StatelessWidget {
  const _BookingHistoryTile({required this.booking, required this.user});

  final BookingRecord booking;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                booking.crashpadName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                user.isOwner
                    ? '${booking.guestName} | ${booking.nights} nights | ${booking.guestCount} guest(s)'
                    : '${booking.nights} nights | ${booking.guestCount} guest(s) | ${_formatDate(booking.createdAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          );
          final facts = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              StatusBadge(
                label: booking.status.label,
                icon: Icons.event_available_outlined,
                color: _statusColor(booking.status),
              ),
              StatusBadge(
                label:
                    'Paid ${_money.format(booking.paymentSummary.totalChargedToGuest)}',
                icon: Icons.payments_outlined,
                color: AppPalette.success,
              ),
            ],
          );

          if (constraints.maxWidth < AppBreakpoints.tablet) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                details,
                const SizedBox(height: AppSpacing.lg),
                facts,
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: details),
              const SizedBox(width: AppSpacing.lg),
              facts,
            ],
          );
        },
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

Color _statusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.confirmed:
      return AppPalette.blueSoft;
    case BookingStatus.active:
      return AppPalette.warning;
    case BookingStatus.completed:
      return AppPalette.success;
    case BookingStatus.cancelled:
      return AppPalette.danger;
    case BookingStatus.pending:
    case BookingStatus.draft:
      return AppPalette.textMuted;
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}
