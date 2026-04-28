import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/airport_data.dart';
import '../data/app_repository.dart';
import '../models/crashpad.dart';
import '../services/availability_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/crashpad_discovery_map.dart';
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
  String _selectedAirport = 'All';
  RangeValues? _priceRange;
  DateTimeRange? _availabilityDates;
  int _mapResetToken = 0;
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

  List<Crashpad> _results(AppRepository repository) {
    final query = _searchController.text.trim().toLowerCase();
    final priceRange = _effectivePriceRange(repository.crashpads);
    final availabilityDates = _availabilityDates;
    final crashpads = repository.crashpads;
    final results = crashpads.where((crashpad) {
      final matchesBed =
          _selectedBedType == 'All' || crashpad.bedType == _selectedBedType;
      final matchesAirport = _selectedAirport == 'All' ||
          crashpad.nearestAirport.toUpperCase() == _selectedAirport;
      final matchesPrice = crashpad.price >= priceRange.start &&
          crashpad.price <= priceRange.end;
      final matchesAvailability = availabilityDates == null ||
          repository.availableCapacityForDates(
                crashpad: crashpad,
                checkInDate: availabilityDates.start,
                checkOutDate: availabilityDates.end,
              ) >
              0;
      final matchesQuery = query.isEmpty ||
          <String>[
            crashpad.name,
            crashpad.location,
            crashpad.nearestAirport,
            crashpad.description,
            ...crashpad.amenities,
          ].join(' ').toLowerCase().contains(query);
      return matchesBed &&
          matchesAirport &&
          matchesPrice &&
          matchesAvailability &&
          matchesQuery;
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

  RangeValues _effectivePriceRange(List<Crashpad> crashpads) {
    final bounds = _priceBounds(crashpads);
    final current = _priceRange;
    if (current == null) return bounds;
    return RangeValues(
      current.start.clamp(bounds.start, bounds.end).toDouble(),
      current.end.clamp(bounds.start, bounds.end).toDouble(),
    );
  }

  RangeValues _priceBounds(List<Crashpad> crashpads) {
    if (crashpads.isEmpty) return const RangeValues(0, 500);
    final prices = crashpads.map((crashpad) => crashpad.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b).floorToDouble();
    final maxPrice = prices.reduce((a, b) => a > b ? a : b).ceilToDouble();
    if (minPrice == maxPrice) return RangeValues(0, maxPrice + 50);
    return RangeValues(minPrice, maxPrice);
  }

  int _availableCapacityFor(AppRepository repository, Crashpad crashpad) {
    final dates = _availabilityDates;
    if (dates != null) {
      return repository.availableCapacityForDates(
        crashpad: crashpad,
        checkInDate: dates.start,
        checkOutDate: dates.end,
      );
    }
    return const AvailabilityService().summarize(crashpad).availableToBook;
  }

  void _showAllCrashpads() {
    _searchController.clear();
    setState(() {
      _selectedAirport = 'All';
      _selectedBedType = 'All';
      _selectedSort = 'Newest';
      _priceRange = null;
      _availabilityDates = null;
      _mapResetToken += 1;
    });
  }

  Future<void> _pickAvailabilityDates() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _availabilityDates ??
          DateTimeRange(
            start: now.add(const Duration(days: 1)),
            end: now.add(const Duration(days: 4)),
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _availabilityDates = selected);
  }

  String _dateRangeLabel() {
    final dates = _availabilityDates;
    if (dates == null) return 'Availability dates';
    String format(DateTime date) => '${date.month}/${date.day}';
    return '${format(dates.start)} - ${format(dates.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final results = _results(repository);
    final priceBounds = _priceBounds(repository.crashpads);
    final effectivePriceRange = _effectivePriceRange(repository.crashpads);
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
                  trailing: const StatusBadge(
                    label: 'Crash App Map',
                    icon: Icons.map_outlined,
                    color: AppPalette.cyan,
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
                      final airport = DropdownButtonFormField<String>(
                        initialValue: _selectedAirport,
                        decoration: const InputDecoration(
                          labelText: 'Airport',
                          prefixIcon: Icon(Icons.flight_takeoff_outlined),
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'All',
                            child: Text('All airports'),
                          ),
                          ...AirportData.usAirports.map(
                            (airport) => DropdownMenuItem<String>(
                              value: airport.code,
                              child: Text('${airport.code} - ${airport.city}'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedAirport = value);
                        },
                      );
                      final dates = OutlinedButton.icon(
                        onPressed: _pickAvailabilityDates,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(_dateRangeLabel()),
                      );
                      final showAll = OutlinedButton.icon(
                        onPressed: _showAllCrashpads,
                        icon: const Icon(Icons.travel_explore_outlined),
                        label: const Text('Show all crashpads'),
                      );
                      final price = _PriceRangeControl(
                        range: effectivePriceRange,
                        bounds: priceBounds,
                        onChanged: (value) =>
                            setState(() => _priceRange = value),
                      );

                      if (!isWide) {
                        return Column(
                          children: <Widget>[
                            search,
                            const SizedBox(height: AppSpacing.lg),
                            airport,
                            const SizedBox(height: AppSpacing.lg),
                            sort,
                            const SizedBox(height: AppSpacing.lg),
                            _BedChoiceRow(
                              bedTypes: _bedTypes,
                              selected: _selectedBedType,
                              onSelected: (value) =>
                                  setState(() => _selectedBedType = value),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            price,
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: <Widget>[
                                Expanded(child: dates),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: showAll),
                              ],
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
                              Expanded(flex: 2, child: airport),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: sort),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 2,
                                child: _BedChoiceRow(
                                  bedTypes: _bedTypes,
                                  selected: _selectedBedType,
                                  onSelected: (value) => setState(
                                    () => _selectedBedType = value,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(flex: 2, child: price),
                              const SizedBox(width: AppSpacing.lg),
                              dates,
                              const SizedBox(width: AppSpacing.md),
                              showAll,
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeading(
                  title: 'Crash App Map',
                  subtitle:
                      'Compare crashpad locations against U.S. airport context.',
                ),
                const SizedBox(height: AppSpacing.lg),
                CrashpadDiscoveryMap(
                  crashpads: results,
                  resetToken: _mapResetToken,
                  availabilityDates: _availabilityDates,
                  availableCapacityForCrashpad: (crashpad) =>
                      _availableCapacityFor(repository, crashpad),
                  ratingForCrashpad: (crashpad) =>
                      repository.calculateAverageRating(crashpad.id),
                  onShowAll: _showAllCrashpads,
                  onOpenCrashpad: (crashpad) => Navigator.pushNamed(
                    context,
                    '/owner-details',
                    arguments: crashpad,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_showInitialSkeleton)
                  const _ResultSkeletonLayout()
                else if (results.isEmpty)
                  EmptyStatePanel(
                    icon: Icons.search_off_outlined,
                    title: 'No listings found',
                    message:
                        'Clear the search or choose a different bed model to broaden the results.',
                    action: AppSecondaryButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _selectedAirport = 'All';
                          _selectedBedType = 'All';
                          _selectedSort = 'Newest';
                          _priceRange = null;
                          _availabilityDates = null;
                          _mapResetToken += 1;
                        });
                      },
                      icon: Icons.refresh_outlined,
                      child: const Text('Clear filters'),
                    ),
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

class _PriceRangeControl extends StatelessWidget {
  const _PriceRangeControl({
    required this.range,
    required this.bounds,
    required this.onChanged,
  });

  final RangeValues range;
  final RangeValues bounds;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = (bounds.end - bounds.start).round().clamp(1, 500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.attach_money_outlined,
              color: AppPalette.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '\$${range.start.round()} - \$${range.end.round()}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: range,
          min: bounds.start,
          max: bounds.end,
          divisions: divisions,
          labels: RangeLabels(
            '\$${range.start.round()}',
            '\$${range.end.round()}',
          ),
          onChanged: onChanged,
        ),
      ],
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
                                '${crashpad.nearestAirport} - ${crashpad.location}${crashpad.distanceToAirportMiles == null ? '' : ' - ${crashpad.distanceToAirportMiles!.toStringAsFixed(1)} mi'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
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
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }
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
