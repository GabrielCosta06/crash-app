import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({
    super.key,
    this.initialSearchQuery,
    this.initialBedType,
  });

  final String? initialSearchQuery;
  final String? initialBedType;

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _sortOptions = const [
    'Newest',
    'Price: Low to High',
    'Price: High to Low',
    'Name',
  ];

  List<Crashpad> _crashpads = const [];
  List<Crashpad> _filteredCrashpads = const [];

  String _selectedSort = 'Newest';
  String? _selectedBedType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchQuery ?? '';
    _selectedBedType = widget.initialBedType;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _fetchCrashpads();
    }
  }

  Future<void> _fetchCrashpads() async {
    setState(() => _isLoading = true);
    try {
      final repository = context.read<AppRepository>();
      final items = await repository.fetchCrashpads();
      if (!mounted) return;
      setState(() {
        _crashpads = items;
        _applyFilters();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final bedType = _selectedBedType;

    var results = _crashpads.where((crashpad) {
      final matchesQuery = crashpad.name.toLowerCase().contains(query) ||
          crashpad.location.toLowerCase().contains(query);
      final matchesBed =
          bedType == null || bedType.isEmpty || crashpad.bedType == bedType;
      return matchesQuery && matchesBed;
    }).toList();

    switch (_selectedSort) {
      case 'Price: Low to High':
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Name':
        results.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        results.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }

    setState(() => _filteredCrashpads = results);
  }

  Future<void> _onRefresh() async {
    await _fetchCrashpads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final user = repository.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Crashpads'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            initialValue: _selectedSort,
            onSelected: (value) {
              setState(() => _selectedSort = value);
              _applyFilters();
            },
            itemBuilder: (context) => _sortOptions
                .map(
                  (option) => PopupMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by name or location',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('All beds', _selectedBedType == null,
                            () {
                          setState(() => _selectedBedType = null);
                          _applyFilters();
                        }),
                        const SizedBox(width: 8),
                        ...['Hot Bed', 'Cold Bed', 'Both'].map(
                          (bedType) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(
                              bedType,
                              _selectedBedType == bedType,
                              () {
                                setState(() => _selectedBedType = bedType);
                                _applyFilters();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filteredCrashpads.isEmpty
                        ? const _EmptyResults()
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredCrashpads.length,
                            itemBuilder: (context, index) {
                              final crashpad = _filteredCrashpads[index];
                              return _FindResultCard(
                                crashpad: crashpad,
                                onTap: () {
                                  final isSubscribed = user?.isSubscribed ?? false;
                                  if (user == null || !isSubscribed) {
                                    _promptSubscription(context);
                                  } else {
                                    Navigator.pushNamed(
                                      context,
                                      '/owner-details',
                                      arguments: crashpad,
                                    );
                                  }
                                },
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  void _promptSubscription(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock complete details'),
        content: const Text(
          'Subscribe for \$15/month to access owner contact info and advanced analytics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscribe');
            },
            child: const Text('Subscribe now'),
          ),
        ],
      ),
    );
  }
}

class _FindResultCard extends StatelessWidget {
  const _FindResultCard({
    required this.crashpad,
    required this.onTap,
  });

  final Crashpad crashpad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final averageRating =
        repository.calculateAverageRating(crashpad.id).clamp(0.0, 5.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppPalette.deepSpace.withValues(alpha: 0.8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            _ResultImage(imageUrls: crashpad.imageUrls),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          crashpad.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Icon(Icons.star, color: AppPalette.warning, size: 18),
                      const SizedBox(width: 4),
                      Text(averageRating.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          crashpad.location,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppPalette.softSlate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nearest airport: ${crashpad.nearestAirport}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppPalette.aurora.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          crashpad.bedType,
                          style: const TextStyle(color: AppPalette.neonPulse),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '\$${crashpad.price.toStringAsFixed(0)}/night',
                        style: const TextStyle(
                          color: AppPalette.neonPulse,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    const double size = 96;
    if (imageUrls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppPalette.deepSpace.withValues(alpha: 0.6),
        ),
        child: const Icon(Icons.image_outlined, color: AppPalette.softSlate),
      );
    }

    final firstUrl = imageUrls.first;
    if (firstUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CachedNetworkImage(
          imageUrl: firstUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: AppPalette.deepSpace.withValues(alpha: 0.6),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: size,
            height: size,
            color: AppPalette.deepSpace.withValues(alpha: 0.6),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    try {
      final bytes = base64Decode(firstUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppPalette.deepSpace.withValues(alpha: 0.6),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore, size: 48, color: Colors.white.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Text(
            'No crashpads found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search keywords or filters.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.softSlate,
                ),
          ),
        ],
      ),
    );
  }
}
