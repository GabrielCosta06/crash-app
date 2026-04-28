import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/crashpad_listing_card.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({super.key, this.initialSearchQuery, this.initialBedType});

  final String? initialSearchQuery;
  final String? initialBedType;

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _bedTypes = const <String>[
    'All',
    'Hot Bed',
    'Cold Bed',
    'Both',
  ];
  final List<String> _sortOptions = const <String>[
    'Newest',
    'Price: Low to High',
    'Price: High to Low',
    'Airport',
  ];

  String _selectedBedType = 'All';
  String _selectedSort = 'Newest';
  late final AnimationController _listAnimationController;
  bool _showInitialSkeleton = true;
  int _lastResultCount = 0;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _searchController.text = widget.initialSearchQuery ?? '';
    if (widget.initialBedType != null &&
        _bedTypes.contains(widget.initialBedType)) {
      _selectedBedType = widget.initialBedType!;
    }
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() => _showInitialSkeleton = false);
      _restartListAnimation(_lastResultCount);
    });
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _restartListAnimation(int itemCount) {
    final duration = 280 + (itemCount <= 1 ? 0 : (itemCount - 1) * 55);
    _listAnimationController.duration = Duration(milliseconds: duration);
    _listAnimationController
      ..reset()
      ..forward();
  }

  List<Crashpad> _results(List<Crashpad> crashpads) {
    final query = _searchController.text.trim().toLowerCase();
    final results = crashpads.where((crashpad) {
      final matchesBed =
          _selectedBedType == 'All' || crashpad.bedType == _selectedBedType;
      final matchesQuery =
          query.isEmpty ||
          <String>[
            crashpad.name,
            crashpad.location,
            crashpad.nearestAirport,
            crashpad.description,
            ...crashpad.amenities,
          ].join(' ').toLowerCase().contains(query);
      return matchesBed && matchesQuery;
    }).toList();

    switch (_selectedSort) {
      case 'Price: Low to High':
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Airport':
        results.sort((a, b) => a.nearestAirport.compareTo(b.nearestAirport));
        break;
      default:
        results.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final results = _results(repository.crashpads);
    if (results.length != _lastResultCount) {
      _lastResultCount = results.length;
      if (!_showInitialSkeleton) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _restartListAnimation(results.length);
        });
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeading(
                  title: 'Find a crashpad',
                  subtitle:
                      'Search by airport, city, amenity, price, and bed model.',
                  trailing: Tooltip(
                    message: 'Map search is not available in the mock build.',
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Map unavailable'),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CrashSurface(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide =
                          constraints.maxWidth >= AppBreakpoints.tablet;
                      final search = TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Search listings',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      );
                      final sort = DropdownButtonFormField<String>(
                        initialValue: _selectedSort,
                        decoration: const InputDecoration(
                          labelText: 'Sort',
                          prefixIcon: Icon(Icons.sort_rounded),
                        ),
                        items: _sortOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(option),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedSort = value);
                          }
                        },
                      );

                      if (!isWide) {
                        return Column(
                          children: <Widget>[
                            search,
                            const SizedBox(height: AppSpacing.lg),
                            sort,
                            const SizedBox(height: AppSpacing.lg),
                            _BedChoiceRow(
                              bedTypes: _bedTypes,
                              selected: _selectedBedType,
                              onSelected: (value) =>
                                  setState(() => _selectedBedType = value),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(flex: 3, child: search),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: sort),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _BedChoiceRow(
                            bedTypes: _bedTypes,
                            selected: _selectedBedType,
                            onSelected: (value) =>
                                setState(() => _selectedBedType = value),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_showInitialSkeleton)
                  const _ResultSkeletonLayout()
                else if (results.isEmpty)
                  const EmptyStatePanel(
                    icon: Icons.search_off_outlined,
                    title: 'No listings found',
                    message:
                        'Adjust the search, sort, or bed model filters and try again.',
                  )
                else
                  _ResultLayout(
                    results: results,
                    animationController: _listAnimationController,
                    onOpen: (crashpad) => Navigator.pushNamed(
                      context,
                      '/owner-details',
                      arguments: crashpad,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BedChoiceRow extends StatelessWidget {
  const _BedChoiceRow({
    required this.bedTypes,
    required this.selected,
    required this.onSelected,
  });

  final List<String> bedTypes;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: bedTypes.map((bedType) {
        return ChoiceChip(
          label: Text(bedType),
          selected: selected == bedType,
          onSelected: (_) => onSelected(bedType),
        );
      }).toList(),
    );
  }
}

class _ResultLayout extends StatelessWidget {
  const _ResultLayout({
    required this.results,
    required this.animationController,
    required this.onOpen,
  });

  final List<Crashpad> results;
  final AnimationController animationController;
  final ValueChanged<Crashpad> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.desktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _DesktopResultTable(
                  results: results,
                  animationController: animationController,
                  onOpen: onOpen,
                ),
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                flex: 2,
                child: CrashpadListingCard(
                  crashpad: results.first,
                  onTap: () => onOpen(results.first),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final crashpad = results[index];
            return _StaggeredEntry(
              index: index,
              controller: animationController,
              child: CrashpadListingCard(
                crashpad: crashpad,
                compact: constraints.maxWidth < AppBreakpoints.tablet,
                onTap: () => onOpen(crashpad),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
          itemCount: results.length,
        );
      },
    );
  }
}

class _DesktopResultTable extends StatelessWidget {
  const _DesktopResultTable({
    required this.results,
    required this.animationController,
    required this.onOpen,
  });

  final List<Crashpad> results;
  final AnimationController animationController;
  final ValueChanged<Crashpad> onOpen;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: results.asMap().entries.map((entry) {
          final index = entry.key;
          final crashpad = entry.value;
          final isLast = crashpad == results.last;
          return _StaggeredEntry(
            index: index,
            controller: animationController,
            child: InkWell(
              onTap: () => onOpen(crashpad),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: CrashpadImage(
                            imageUrls: crashpad.imageUrls,
                            height: 74,
                            width: 96,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                crashpad.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${crashpad.nearestAirport} - ${crashpad.location}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        StatusBadge(label: crashpad.bedModel.shortLabel),
                        const SizedBox(width: AppSpacing.lg),
                        Text(
                          '\$${crashpad.price.toStringAsFixed(0)}/night',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppPalette.blueSoft),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = controller.duration?.inMilliseconds ?? 280;
    final start = (index * 55 / total).clamp(0.0, 0.9);
    final end = ((index * 55 + 280) / total).clamp(start, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _ResultSkeletonLayout extends StatelessWidget {
  const _ResultSkeletonLayout();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.desktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Expanded(flex: 3, child: ListingCardSkeleton(compact: true)),
              SizedBox(width: AppSpacing.xxl),
              Expanded(flex: 2, child: ListingCardSkeleton()),
            ],
          );
        }
        return Column(
          children: const <Widget>[
            ListingCardSkeleton(compact: true),
            SizedBox(height: AppSpacing.lg),
            ListingCardSkeleton(compact: true),
            SizedBox(height: AppSpacing.lg),
            ListingCardSkeleton(compact: true),
          ],
        );
      },
    );
  }
}
