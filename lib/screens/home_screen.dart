import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/crashpad.dart';
import '../services/availability_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/crashpad_listing_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onUpdateIndex, this.managementIndex});

  final ValueChanged<int>? onUpdateIndex;
  final int? managementIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _bedTypes = const <String>[
    'All',
    'Hot Bed',
    'Cold Bed',
    'Both'
  ];

  String _selectedBedType = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Crashpad> _filter(List<Crashpad> crashpads) {
    final query = _searchQuery.trim().toLowerCase();
    return crashpads.where((crashpad) {
      final matchesBed =
          _selectedBedType == 'All' || crashpad.bedType == _selectedBedType;
      if (!matchesBed) return false;
      if (query.isEmpty) return true;
      final haystack = <String>[
        crashpad.name,
        crashpad.location,
        crashpad.nearestAirport,
        crashpad.description,
        ...crashpad.amenities,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _openCrashpad(Crashpad crashpad) {
    Navigator.pushNamed(context, '/owner-details', arguments: crashpad);
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final crashpads = repository.crashpads;
    final filtered = _filter(crashpads);
    final availability = const AvailabilityService();
    final totalOpenBeds = crashpads.fold<int>(
      0,
      (sum, crashpad) => sum + availability.summarize(crashpad).availableToBook,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ResponsivePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroSearch(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onManagementTap: widget.managementIndex == null
                        ? null
                        : () => widget.onUpdateIndex?.call(
                              widget.managementIndex!,
                            ),
                    onFindTap: () => widget.onUpdateIndex?.call(1),
                    listingCount: crashpads.length,
                    openBeds: totalOpenBeds,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _BedFilters(
                    bedTypes: _bedTypes,
                    selected: _selectedBedType,
                    onSelected: (bedType) => setState(
                      () => _selectedBedType = bedType,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeading(
                    title: 'Available crashpads',
                    subtitle:
                        'Transparent bed model, availability, fees, and house rules before you book.',
                    trailing: TextButton.icon(
                      onPressed: () => widget.onUpdateIndex?.call(1),
                      icon: const Icon(Icons.tune_outlined),
                      label: const Text('Advanced search'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (filtered.isEmpty)
                    const EmptyStatePanel(
                      icon: Icons.travel_explore_outlined,
                      title: 'No crashpads match that search',
                      message:
                          'Try another airport, city, or bed model to discover more options.',
                    )
                  else
                    _ListingGrid(
                      crashpads: filtered,
                      onOpenCrashpad: _openCrashpad,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSearch extends StatelessWidget {
  const _HeroSearch({
    required this.controller,
    required this.onChanged,
    this.onManagementTap,
    required this.onFindTap,
    required this.listingCount,
    required this.openBeds,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onManagementTap;
  final VoidCallback onFindTap;
  final int listingCount;
  final int openBeds;

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
                label: 'Crew crashpad marketplace',
                icon: Icons.verified_outlined,
                color: AppPalette.cyan,
              ),
              const SizedBox(height: 18),
	              Text(
	                'Find verified crashpads near your airport.',
	                style: Theme.of(context).textTheme.displaySmall,
	              ),
	              const SizedBox(height: 14),
	              Text(
	                'Compare bed type, rules, amenities, and total cost. Built for airline crew rest between trips.',
	                style: Theme.of(context)
	                    .textTheme
	                    .bodyLarge
	                    ?.copyWith(color: AppPalette.textMuted),
	              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
	                decoration: const InputDecoration(
	                  labelText: 'Search city, airport, amenity',
	                  prefixIcon: Icon(Icons.search_rounded),
	                ),
		                onSubmitted: (_) => onManagementTap?.call(),
		              ),
		              const SizedBox(height: 16),
		              Wrap(
		                spacing: 12,
		                runSpacing: 12,
		                children: <Widget>[
		                  ElevatedButton.icon(
		                    onPressed: onFindTap,
	                    icon: const Icon(Icons.calendar_month_outlined),
	                    label: const Text('Start booking'),
	                  ),
	                  if (onManagementTap != null)
                    OutlinedButton.icon(
                      onPressed: onManagementTap,
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Management dashboard'),
                    ),
                ],
              ),
            ],
          );

          final stats = _HeroStats(
            listingCount: listingCount,
            openBeds: openBeds,
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                headline,
                const SizedBox(height: AppSpacing.xxl),
                stats,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: headline),
              const SizedBox(width: AppSpacing.xxxl),
              Expanded(flex: 2, child: stats),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.listingCount,
    required this.openBeds,
  });

  final int listingCount;
  final int openBeds;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: 'Live listings',
                value: '$listingCount',
                icon: Icons.apartment_outlined,
                accent: AppPalette.blueSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Open capacity',
                value: '$openBeds',
                icon: Icons.king_bed_outlined,
                accent: AppPalette.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CrashSurface(
          radius: AppRadius.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Hot vs cold bed clarity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Hot-bed capacity tracks active guests and shared sleeping spaces. Cold-bed availability tracks dedicated assigned beds.',
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

class _BedFilters extends StatelessWidget {
  const _BedFilters({
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
        final isSelected = selected == bedType;
        return ChoiceChip(
	          label: Row(
	            mainAxisSize: MainAxisSize.min,
	            children: [
	              Text(bedType),
	              if (bedType != 'All') ...[
	                const SizedBox(width: 4),
	                Tooltip(
	                  message: bedType == 'Hot Bed'
	                      ? 'Shared rotating sleeping space.'
	                      : bedType == 'Cold Bed'
	                          ? 'Dedicated assigned bed.'
	                          : 'Offers both hot and cold bed options.',
	                  child: const Icon(Icons.info_outline, size: 14),
	                ),
	              ],
	            ],
	          ),
	          selected: isSelected,
	          onSelected: (_) => onSelected(bedType),
	        );
	      }).toList(),
	    );
	  }
	}

class _ListingGrid extends StatelessWidget {
  const _ListingGrid({
    required this.crashpads,
    required this.onOpenCrashpad,
  });

  final List<Crashpad> crashpads;
  final ValueChanged<Crashpad> onOpenCrashpad;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= AppBreakpoints.desktop
            ? 3
            : width >= AppBreakpoints.tablet
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: crashpads.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: columns == 1 ? 1.18 : 0.86,
          ),
          itemBuilder: (context, index) {
            final crashpad = crashpads[index];
            return CrashpadListingCard(
              crashpad: crashpad,
              onTap: () => onOpenCrashpad(crashpad),
            );
          },
        );
      },
    );
  }
}
