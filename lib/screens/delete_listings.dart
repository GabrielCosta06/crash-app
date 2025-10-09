import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';
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

    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete listings'),
            content: Text(
              'This will remove ${_selectedIds.length} listing(s) permanently. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await repository.deleteCrashpads(_selectedIds);
    messenger.showSnackBar(
      const SnackBar(content: Text('Listings removed.')),
    );
    await _loadListings();
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
                                onPressed:
                                    _selectedIds.isEmpty ? null : _deleteSelected,
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
              : Colors.white.withValues(alpha: 0.04),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.softSlate),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined,
              size: 52, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No crashpads yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a listing and your command center will appear here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.softSlate),
          ),
        ],
      ),
    );
  }
}


