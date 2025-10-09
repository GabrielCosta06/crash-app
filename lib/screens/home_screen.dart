import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';

/// Landing page showcasing featured crashpads and quick filters.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onUpdateIndex});

  final ValueChanged<int>? onUpdateIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final List<String> _bedTypes = ['All', 'Hot Bed', 'Cold Bed', 'Both'];
  String _selectedBedType = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isInitialized = false;
  bool _isLoading = true;
  List<Crashpad> _crashpads = const [];
  late final AnimationController _listController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _listController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      );
      _loadCrashpads();
    }
  }

  Future<void> _loadCrashpads() async {
    setState(() => _isLoading = true);
    try {
      final repository = context.read<AppRepository>();
      final items = await repository.fetchCrashpads();
      if (!mounted) return;
      setState(() {
        _crashpads = items;
      });
      _kickListAnimation();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Crashpad> get _filteredCrashpads {
    final query = _searchQuery.trim().toLowerCase();
    return _crashpads.where((crashpad) {
      final matchesBed =
          _selectedBedType == 'All' || crashpad.bedType == _selectedBedType;
      if (!matchesBed) return false;
      if (query.isEmpty) return true;
      final fields = [
        crashpad.name,
        crashpad.location,
        crashpad.description,
        crashpad.nearestAirport,
      ];
      return fields.any((field) => field.toLowerCase().contains(query));
    }).toList();
  }

  void _onBedTypeSelected(String type) {
    setState(() => _selectedBedType = type);
    _kickListAnimation();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _kickListAnimation();
  }

  void _kickListAnimation() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ??
        MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (reduceMotion) {
      _listController.value = 1.0;
    } else {
      _listController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_isInitialized) {
      _listController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadCrashpads,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            pinned: true,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              background: const _HeroBanner(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 16),
                  _FilterChips(
                    bedTypes: _bedTypes,
                    current: _selectedBedType,
                    onSelected: _onBedTypeSelected,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: _LoadingList(),
            )
          else if (_filteredCrashpads.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final crashpad = _filteredCrashpads[index];
                    return AnimatedBuilder(
                      animation: _listController,
                      builder: (context, child) {
                        final t = Curves.easeOut.transform(_listController.value);
                        return Transform.translate(
                          offset: Offset(0, (1 - t) * 12),
                          child: child,
                        );
                      },
                      child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.92, end: 1.0),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) => Transform.scale(
                        scale: scale,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: 1.0,
                          child: child,
                        ),
                      ),
                        child: _CrashpadCard(
                          crashpad: crashpad,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/owner-details',
                            arguments: crashpad,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filteredCrashpads.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatefulWidget {
  const _HeroBanner();

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final user = repository.currentUser;
    final isLight = theme.brightness == Brightness.light;

    final textColor = isLight ? AppPalette.lightText : Colors.white;
    final subTextColor =
        isLight ? AppPalette.lightTextSecondary : AppPalette.softSlate;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_controller.value);
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.lerp(
            Alignment.centerRight,
            Alignment.bottomLeft,
            progress,
          )!,
          colors: isLight
              ? [
                  Color.lerp(AppPalette.lightPrimary.withValues(alpha: 0.12),
                      AppPalette.neonPulse.withValues(alpha: 0.10), progress)!,
                  Color.lerp(AppPalette.lightSurface, Colors.white, progress)!,
                ]
              : [
                  Color.lerp(const Color(0xFF1B223F),
                      const Color(0xFF12162D), progress)!,
                  Color.lerp(const Color(0xFF141A2C),
                      AppPalette.neonPulse.withValues(alpha: 0.14), progress)!,
                ],
        );
        final elevation = 6 + progress * 6;
        final badgeColor = Color.lerp(
          isLight
              ? AppPalette.lightSurface
              : Colors.white.withValues(alpha: 0.08),
          AppPalette.neonPulse.withValues(alpha: isLight ? 0.18 : 0.26),
          progress * 0.7,
        );
        final avatarScale = 1 + 0.025 * math.sin(progress * math.pi * 2);
        final taglineOpacity = 0.82 + (progress * 0.18);

        return Material(
          elevation: elevation,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, kToolbarHeight + 18, 24, 28),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 14),
                    child: child!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: avatarScale,
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: isLight
                                ? AppPalette.lightPrimary
                                    .withValues(alpha: 0.12 + progress * 0.12)
                                : AppPalette.neonPulse
                                    .withValues(alpha: 0.15 + progress * 0.10),
                            child: const Icon(Icons.bed_outlined,
                                color: AppPalette.neonPulse, size: 28),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Text(
                              user != null
                                  ? 'Welcome back, ${user.firstName}!'
                                  : 'Welcome to Crashpads',
                              key: ValueKey<bool>(user != null),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: badgeColor,
                          ),
                          child: Text(
                            'v2.0',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppPalette.neonPulse,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 480),
                      opacity: taglineOpacity,
                      curve: Curves.easeInOut,
                      child: Text(
                        'Find your next restful layover or list your crew housing for others.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: subTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Search by name or location',
        prefixIcon: Icon(Icons.search),
      ),
      style: theme.textTheme.bodyLarge,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.bedTypes,
    required this.current,
    required this.onSelected,
  });

  final List<String> bedTypes;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: bedTypes
            .map((bedType) {
              final selected = current == bedType;
              return AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                scale: selected ? 1.0 : 0.96,
                child: ChoiceChip(
                  label: Text(bedType),
                  selected: selected,
                  onSelected: (_) => onSelected(bedType),
                ),
              );
            })
          .toList(),
      ),
    );
  }
}

class _CrashpadCard extends StatefulWidget {
  const _CrashpadCard({
    required this.crashpad,
    required this.onTap,
  });

  final Crashpad crashpad;
  final VoidCallback onTap;

  @override
  State<_CrashpadCard> createState() => _CrashpadCardState();
}

class _CrashpadCardState extends State<_CrashpadCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final averageRating =
        repository.calculateAverageRating(widget.crashpad.id).clamp(0.0, 5.0);

    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardColor = isLight ? AppPalette.lightSurface : AppPalette.deepSpace.withValues(alpha: 0.8);
  final borderColor = isLight ? AppPalette.lightPrimary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04);
    final textColor = isLight ? AppPalette.lightText : Colors.white;
    final subTextColor = isLight ? AppPalette.lightTextSecondary : AppPalette.softSlate;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1.0,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.onTap,
            child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: _CrashpadImage(
                imageUrls: widget.crashpad.imageUrls,
                heroTag: 'crashpad-${widget.crashpad.id}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppPalette.neonPulse.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          widget.crashpad.bedType.toUpperCase(),
                          style: const TextStyle(
                            color: AppPalette.neonPulse,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppPalette.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.crashpad.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: subTextColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.crashpad.location,
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: subTextColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.local_airport_outlined, size: 18, color: subTextColor),
                      const SizedBox(width: 6),
                      Text(
                        'Nearest: ${widget.crashpad.nearestAirport}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: subTextColor),
                      ),
                      const Spacer(),
                      Text(
                        '\$${widget.crashpad.price.toStringAsFixed(0)}/night',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.neonPulse,
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
    ),
  ),
),
);
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _LoadingCard(),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatefulWidget {
  @override
  State<_LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<_LoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween(begin: 0.08, end: 0.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
  final base = isLight
    ? AppPalette.lightPrimary.withValues(alpha: 0.06)
    : Colors.white.withValues(alpha: 0.06);
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
    final overlay = isLight
      ? AppPalette.lightPrimary.withValues(alpha: _shimmer.value)
      : Colors.white.withValues(alpha: _shimmer.value);
        return Container(
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: overlay,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 16,
                  width: 160,
                  decoration: BoxDecoration(
                    color: overlay,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 14,
                  width: 220,
                  decoration: BoxDecoration(
                    color: overlay,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _CrashpadImage extends StatelessWidget {
  const _CrashpadImage({required this.imageUrls, this.heroTag});

  final List<String> imageUrls;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Container(
        height: 190,
        decoration: BoxDecoration(
          color: AppPalette.deepSpace.withValues(alpha: 0.6),
        ),
        child: const Center(
          child: Icon(
            Icons.bed_outlined,
            color: AppPalette.softSlate,
            size: 42,
          ),
        ),
      );
    }

    final imageUrl = imageUrls.first;
    Widget imageWidget;
    if (imageUrl.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 190,
          color: AppPalette.deepSpace.withValues(alpha: 0.6),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 190,
          color: AppPalette.deepSpace.withValues(alpha: 0.6),
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      );
    } else {
      try {
        final bytes = base64Decode(imageUrl);
        imageWidget = Image.memory(
          bytes,
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {
        imageWidget = Container(
          height: 190,
          color: AppPalette.deepSpace.withValues(alpha: 0.6),
          child: const Icon(Icons.image_not_supported_outlined),
        );
      }
    }
    if (heroTag != null) {
      return Hero(tag: heroTag!, child: imageWidget);
    }
    return imageWidget;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(
          'No crashpads match this filter yet.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Refresh shortly or adjust filters to discover more locations.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.softSlate,
              ),
        ),
      ],
    );
  }
}
