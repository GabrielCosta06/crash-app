import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

/// Lets owners prune outdated crashpad listings in bulk.
class DeleteListingsScreen extends StatefulWidget {
  const DeleteListingsScreen({super.key});

  @override
  State<DeleteListingsScreen> createState() => _DeleteListingsScreenState();
}

class _DeleteListingsScreenState extends State<DeleteListingsScreen> {
  List<Crashpad> _listings = const [];
  final Set<String> _selectedIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || user.userType != AppUserType.owner) {
      setState(() {
        _listings = const [];
        _isLoading = false;
      });
      return;
    }
    final listings = await repository.fetchOwnerCrashpads(user.email);
    if (!mounted) return;
    setState(() {
      _listings = listings;
      _isLoading = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<AppRepository>();

    if (_selectedIds.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select at least one listing to delete.')),
      );
      return;
    }

    final impact = repository.bookingImpactForListingDeletion(_selectedIds);
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              impact.canDelete
                  ? 'Delete listings'
                  : 'Resolve bookings before deleting',
            ),
            content: _DeletionImpactSummary(impact: impact),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(impact.canDelete ? 'Cancel' : 'Close'),
              ),
              if (impact.canDelete)
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.danger.withValues(alpha: 0.15),
                    foregroundColor: AppPalette.danger,
                    side: const BorderSide(color: AppPalette.danger),
                  ),
                  child: const Text('Delete'),
                ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await repository.deleteCrashpads(_selectedIds);
      messenger.showSnackBar(
        const SnackBar(content: Text('Listings removed.')),
      );
      await _loadListings();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete listings: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AnimatedBackButton(),
        title: const Text('Manage listings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final listing = _listings[index];
                      final isSelected = _selectedIds.contains(listing.id);
                      return _ListingTile(
                        listing: listing,
                        selected: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked) {
                              _selectedIds.add(listing.id);
                            } else {
                              _selectedIds.remove(listing.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TapScale(
                          enabled: _selectedIds.isNotEmpty,
                          child: OutlinedButton(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : () => setState(() => _selectedIds.clear()),
                            child: const Text('Clear selection'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TapScale(
                          enabled: _selectedIds.isNotEmpty,
                          child: ElevatedButton(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : _deleteSelected,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.danger,
                            ),
                            child: Text('Delete ${_selectedIds.length}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DeletionImpactSummary extends StatelessWidget {
  const _DeletionImpactSummary({required this.impact});

  final ListingDeletionImpact impact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Selected listings: ${impact.selectedListingCount}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          impact.canDelete
              ? 'These listings have no pending, confirmed, or active bookings. Completed and cancelled booking history will remain visible.'
              : 'Listings with live bookings cannot be deleted. Resolve pending, confirmed, and active stays first.',
        ),
        const SizedBox(height: 16),
        _ImpactRow(label: 'Pending', value: impact.pendingCount),
        _ImpactRow(label: 'Confirmed', value: impact.confirmedCount),
        _ImpactRow(label: 'Active', value: impact.activeCount),
        _ImpactRow(label: 'Completed history', value: impact.completedCount),
        _ImpactRow(label: 'Cancelled history', value: impact.cancelledCount),
      ],
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          StatusBadge(
            label: '$value',
            color: value == 0 ? AppPalette.success : AppPalette.warning,
          ),
        ],
      ),
    );
  }
}

/// Single row used inside the bulk delete list.
class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.listing,
    required this.selected,
    required this.onChanged,
  });

  final Crashpad listing;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppPalette.deepSpace.withValues(alpha: 0.85),
        border: Border.all(
          color: selected
              ? AppPalette.neonPulse.withValues(alpha: 0.5)
              : AppPalette.border,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.location,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.softSlate),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bed type: ${listing.bedType} | \$${listing.price.toStringAsFixed(0)}/night',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyStatePanel(
        icon: Icons.layers_clear_outlined,
        title: 'No crashpads yet',
        message: 'Create a listing and your command center will appear here.',
      ),
    );
  }
}
