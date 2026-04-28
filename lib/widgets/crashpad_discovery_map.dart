import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../data/airport_data.dart';
import '../models/airport.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

const double _airportSelectionZoom = 7;
const LatLng _usDefaultCenter = LatLng(39.5, -98.35);
const double _usDefaultZoom = 3.35;
final LatLngBounds _usAndTerritoryCenterBounds = LatLngBounds.unsafe(
  north: 72,
  south: -15,
  east: 180,
  west: -180,
);

class CrashpadDiscoveryMap extends StatefulWidget {
  const CrashpadDiscoveryMap({
    super.key,
    required this.crashpads,
    required this.onOpenCrashpad,
    required this.onShowAll,
    required this.availableCapacityForCrashpad,
    required this.ratingForCrashpad,
    this.resetToken = 0,
    this.availabilityDates,
  });

  final List<Crashpad> crashpads;
  final ValueChanged<Crashpad> onOpenCrashpad;
  final VoidCallback onShowAll;
  final int Function(Crashpad crashpad) availableCapacityForCrashpad;
  final double Function(Crashpad crashpad) ratingForCrashpad;
  final int resetToken;
  final DateTimeRange? availabilityDates;

  @override
  State<CrashpadDiscoveryMap> createState() => _CrashpadDiscoveryMapState();
}

class _CrashpadDiscoveryMapState extends State<CrashpadDiscoveryMap> {
  late final Future<void> _mapReadyFuture;
  String? _selectedCrashpadId;
  String? _selectedAirportCode;

  @override
  void initState() {
    super.initState();
    _mapReadyFuture = Future<void>.delayed(const Duration(milliseconds: 220));
  }

  @override
  void didUpdateWidget(covariant CrashpadDiscoveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedCrashpadId != null &&
        !widget.crashpads
            .any((crashpad) => crashpad.id == _selectedCrashpadId)) {
      _selectedCrashpadId = null;
    }
    if (_selectedAirportCode != null &&
        !AirportData.usAirports
            .any((airport) => airport.code == _selectedAirportCode)) {
      _selectedAirportCode = null;
    }
  }

  void _selectCrashpad(Crashpad crashpad) {
    setState(() {
      _selectedCrashpadId = crashpad.id;
      _selectedAirportCode = null;
    });
  }

  void _selectAirport(Airport airport) {
    setState(() {
      _selectedAirportCode = airport.code;
      _selectedCrashpadId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _mapReadyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _MapLoadingState();
        }
        if (snapshot.hasError) {
          return _MapErrorState(message: snapshot.error.toString());
        }
        return _MapContent(
          crashpads: widget.crashpads,
          selectedCrashpadId: _selectedCrashpadId,
          selectedAirportCode: _selectedAirportCode,
          availabilityDates: widget.availabilityDates,
          resetToken: widget.resetToken,
          availableCapacityForCrashpad: widget.availableCapacityForCrashpad,
          ratingForCrashpad: widget.ratingForCrashpad,
          onSelectCrashpad: _selectCrashpad,
          onSelectAirport: _selectAirport,
          onOpenCrashpad: widget.onOpenCrashpad,
          onShowAll: widget.onShowAll,
        );
      },
    );
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.crashpads,
    required this.selectedCrashpadId,
    required this.selectedAirportCode,
    required this.availabilityDates,
    required this.resetToken,
    required this.availableCapacityForCrashpad,
    required this.ratingForCrashpad,
    required this.onSelectCrashpad,
    required this.onSelectAirport,
    required this.onOpenCrashpad,
    required this.onShowAll,
  });

  final List<Crashpad> crashpads;
  final String? selectedCrashpadId;
  final String? selectedAirportCode;
  final DateTimeRange? availabilityDates;
  final int resetToken;
  final int Function(Crashpad crashpad) availableCapacityForCrashpad;
  final double Function(Crashpad crashpad) ratingForCrashpad;
  final ValueChanged<Crashpad> onSelectCrashpad;
  final ValueChanged<Airport> onSelectAirport;
  final ValueChanged<Crashpad> onOpenCrashpad;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final crashpadPoints = crashpads
        .map((crashpad) => _CrashpadMapPoint.fromCrashpad(crashpad))
        .whereType<_CrashpadMapPoint>()
        .toList();
    final selectedCrashpad = selectedCrashpadId == null
        ? null
        : crashpads.cast<Crashpad?>().firstWhere(
              (crashpad) => crashpad?.id == selectedCrashpadId,
              orElse: () => null,
            );
    final selectedAirport = selectedAirportCode == null
        ? null
        : AirportData.usAirports.cast<Airport?>().firstWhere(
              (airport) => airport?.code == selectedAirportCode,
              orElse: () => null,
            );

    return CrashSurface(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
          final map = _MapCanvas(
            crashpadPoints: crashpadPoints,
            airports: AirportData.usAirports,
            resetToken: resetToken,
            borderRadius: isWide
                ? const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(AppRadius.xl),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
            selectedCrashpadId: selectedCrashpadId,
            selectedAirportCode: selectedAirportCode,
            onSelectCrashpad: onSelectCrashpad,
            onSelectAirport: onSelectAirport,
          );
          final details = _MapDetailsPanel(
            crashpadCount: crashpadPoints.length,
            airportCount: AirportData.usAirports.length,
            selectedCrashpad: selectedCrashpad,
            selectedAirport: selectedAirport,
            availabilityDates: availabilityDates,
            availableCapacityForCrashpad: availableCapacityForCrashpad,
            ratingForCrashpad: ratingForCrashpad,
            onOpenCrashpad: onOpenCrashpad,
            onShowAll: onShowAll,
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 380, child: map),
                const Divider(height: 1),
                details,
              ],
            );
          }

          return SizedBox(
            height: 500,
            child: Row(
              children: <Widget>[
                Expanded(flex: 7, child: map),
                const VerticalDivider(width: 1),
                SizedBox(width: 340, child: details),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.crashpadPoints,
    required this.airports,
    required this.resetToken,
    required this.borderRadius,
    required this.selectedCrashpadId,
    required this.selectedAirportCode,
    required this.onSelectCrashpad,
    required this.onSelectAirport,
  });

  final List<_CrashpadMapPoint> crashpadPoints;
  final List<Airport> airports;
  final int resetToken;
  final BorderRadius borderRadius;
  final String? selectedCrashpadId;
  final String? selectedAirportCode;
  final ValueChanged<Crashpad> onSelectCrashpad;
  final ValueChanged<Airport> onSelectAirport;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  final MapController _mapController = MapController();
  double _zoom = _usDefaultZoom;
  bool _hasTileError = false;
  late int _lastResetToken = widget.resetToken;

  bool get _airportsSelectable => _zoom >= _airportSelectionZoom;

  @override
  void didUpdateWidget(covariant _MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != _lastResetToken) {
      _lastResetToken = widget.resetToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitVisibleCrashpads();
      });
    }
  }

  void _fitVisibleCrashpads() {
    final points =
        widget.crashpadPoints.map((point) => point.position).toList();
    if (points.isEmpty) {
      _mapController.move(_usDefaultCenter, _usDefaultZoom);
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 10);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(72),
        minZoom: _usDefaultZoom,
        maxZoom: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Crashpad? crashpadForMarker(Marker marker) {
      final key = marker.key;
      if (key is ValueKey<String>) {
        final markerId = key.value;
        for (final point in widget.crashpadPoints) {
          if (point.crashpad.id == markerId) return point.crashpad;
        }
      }
      return null;
    }

    final crashpadMarkers = widget.crashpadPoints
        .map(
          (point) => Marker(
            key: ValueKey<String>(point.crashpad.id),
            point: point.position,
            width: 64,
            height: 64,
            child: _CrashpadMarker(
              crashpad: point.crashpad,
              selected: widget.selectedCrashpadId == point.crashpad.id,
            ),
          ),
        )
        .toList();

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _usDefaultCenter,
              initialZoom: _usDefaultZoom,
              minZoom: 2.4,
              maxZoom: 16,
              backgroundColor: AppPalette.panel,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: _usAndTerritoryCenterBounds,
              ),
              onPositionChanged: (camera, _) {
                if ((camera.zoom - _zoom).abs() < 0.15) return;
                setState(() => _zoom = camera.zoom);
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.crashapp.web',
                tileDisplay: const TileDisplay.instantaneous(),
                errorTileCallback: (_, __, ___) {
                  if (!_hasTileError && mounted) {
                    setState(() => _hasTileError = true);
                  }
                },
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: crashpadMarkers,
                  maxClusterRadius: 48,
                  size: const Size(50, 50),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(56),
                  maxZoom: 16,
                  disableClusteringAtZoom: 12,
                  onMarkerTap: (marker) {
                    final crashpad = crashpadForMarker(marker);
                    if (crashpad != null) widget.onSelectCrashpad(crashpad);
                  },
                  zoomToBoundsOnClick: true,
                  spiderfyCluster: true,
                  showPolygon: false,
                  builder: (context, markers) => _CrashpadClusterMarker(
                    count: markers.length,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !_airportsSelectable,
                child: MarkerLayer(
                  markers: <Marker>[
                    for (final airport in widget.airports)
                      Marker(
                        point: LatLng(airport.latitude, airport.longitude),
                        width: 48,
                        height: 32,
                        child: _AirportMarker(
                          airport: airport,
                          selectable: _airportsSelectable,
                          selected: widget.selectedAirportCode == airport.code,
                          onTap: () => widget.onSelectAirport(airport),
                        ),
                      ),
                  ],
                ),
              ),
              RichAttributionWidget(
                attributions: const <SourceAttribution>[
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
                showFlutterMapAttribution: false,
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            child: _MapModeBadge(airportsSelectable: _airportsSelectable),
          ),
          if (_hasTileError)
            const Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _TileErrorBanner(),
            ),
        ],
      ),
    );
  }
}

class _CrashpadMarker extends StatelessWidget {
  const _CrashpadMarker({
    required this.crashpad,
    required this.selected,
  });

  final Crashpad crashpad;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final marker = AnimatedScale(
      scale: selected ? 1.16 : 1,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: AppPalette.ink.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppPalette.warning : AppPalette.blueSoft,
              width: selected ? 3 : 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.blue.withValues(alpha: 0.42),
                blurRadius: selected ? 18 : 10,
              ),
            ],
          ),
          child: Icon(
            Icons.home_work_outlined,
            color: selected ? AppPalette.warning : AppPalette.blueSoft,
            size: 24,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Crashpad ${crashpad.name} near ${crashpad.nearestAirport}',
      child: Tooltip(message: crashpad.name, child: Center(child: marker)),
    );
  }
}

class _CrashpadClusterMarker extends StatelessWidget {
  const _CrashpadClusterMarker({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count crashpads in this area',
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.blue,
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.text, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppPalette.blue.withValues(alpha: 0.38),
              blurRadius: 18,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _AirportMarker extends StatelessWidget {
  const _AirportMarker({
    required this.airport,
    required this.selectable,
    required this.selected,
    required this.onTap,
  });

  final Airport airport;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = selected
        ? 0.86
        : selectable
            ? 0.62
            : 0.34;
    final marker = AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppPalette.panel.withValues(
            alpha: selected
                ? 0.86
                : selectable
                    ? 0.58
                    : 0.42,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: (selected ? AppPalette.warning : AppPalette.cyan)
                .withValues(alpha: selected ? 0.82 : 0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.flight_takeoff_outlined,
              size: 11,
              color: AppPalette.cyan,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                airport.code,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppPalette.text.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: selectable
          ? 'Airport ${airport.code}, ${airport.name}'
          : 'Airport ${airport.code}. Zoom in to select airport markers.',
      child: Tooltip(
        message: selectable
            ? '${airport.code} - ${airport.name}'
            : 'Zoom in to select ${airport.code}',
        child: IgnorePointer(
          ignoring: !selectable,
          // Airport markers stay above crashpads visually, but do not take
          // pointer events until the map is zoomed in enough for intent.
          child: MouseRegion(
            cursor: selectable
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(onTap: onTap, child: marker),
          ),
        ),
      ),
    );
  }
}

class _MapModeBadge extends StatelessWidget {
  const _MapModeBadge({required this.airportsSelectable});

  final bool airportsSelectable;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: airportsSelectable ? 'Airport select on' : 'Crashpad select',
      icon: airportsSelectable
          ? Icons.flight_takeoff_outlined
          : Icons.home_work_outlined,
      color: airportsSelectable ? AppPalette.cyan : AppPalette.blueSoft,
    );
  }
}

class _TileErrorBanner extends StatelessWidget {
  const _TileErrorBanner();

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      color: AppPalette.panelElevated.withValues(alpha: 0.94),
      child: Text(
        'Some map tiles could not load. Markers and listing details are still available.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppPalette.warning),
      ),
    );
  }
}

class _MapDetailsPanel extends StatelessWidget {
  const _MapDetailsPanel({
    required this.crashpadCount,
    required this.airportCount,
    required this.selectedCrashpad,
    required this.selectedAirport,
    required this.availabilityDates,
    required this.availableCapacityForCrashpad,
    required this.ratingForCrashpad,
    required this.onOpenCrashpad,
    required this.onShowAll,
  });

  final int crashpadCount;
  final int airportCount;
  final Crashpad? selectedCrashpad;
  final Airport? selectedAirport;
  final DateTimeRange? availabilityDates;
  final int Function(Crashpad crashpad) availableCapacityForCrashpad;
  final double Function(Crashpad crashpad) ratingForCrashpad;
  final ValueChanged<Crashpad> onOpenCrashpad;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final selectedCrashpad = this.selectedCrashpad;
    final selectedAirport = this.selectedAirport;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Crash App Map', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Crashpads are the primary markers. Airport labels stay visible for context and become selectable after zooming in.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatusBadge(
                label: '$crashpadCount crashpads',
                icon: Icons.home_work_outlined,
                color: AppPalette.blueSoft,
              ),
              StatusBadge(
                label: '$airportCount airports',
                icon: Icons.flight_takeoff_outlined,
                color: AppPalette.cyan,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppSecondaryButton(
              onPressed: onShowAll,
              icon: Icons.travel_explore_outlined,
              child: const Text('Show all crashpads'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: selectedCrashpad != null
                  ? _SelectedCrashpadDetails(
                      crashpad: selectedCrashpad,
                      availabilityDates: availabilityDates,
                      availableCapacity: availableCapacityForCrashpad(
                        selectedCrashpad,
                      ),
                      rating: ratingForCrashpad(selectedCrashpad),
                      onOpen: onOpenCrashpad,
                    )
                  : selectedAirport != null
                      ? _SelectedAirportDetails(airport: selectedAirport)
                      : crashpadCount == 0
                          ? _MapEmptyState(onShowAll: onShowAll)
                          : const _MapHint(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedAirportDetails extends StatelessWidget {
  const _SelectedAirportDetails({required this.airport});

  final Airport airport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StatusBadge(
          label: airport.code,
          icon: Icons.flight_takeoff_outlined,
          color: AppPalette.cyan,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(airport.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          airport.displayLocation,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppPalette.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Airport labels provide map context. Select a crashpad marker to compare availability and distance.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppPalette.textMuted),
        ),
      ],
    );
  }
}

class _SelectedCrashpadDetails extends StatelessWidget {
  const _SelectedCrashpadDetails({
    required this.crashpad,
    required this.availabilityDates,
    required this.availableCapacity,
    required this.rating,
    required this.onOpen,
  });

  final Crashpad crashpad;
  final DateTimeRange? availabilityDates;
  final int availableCapacity;
  final double rating;
  final ValueChanged<Crashpad> onOpen;

  @override
  Widget build(BuildContext context) {
    final airport = AirportData.findByCode(crashpad.nearestAirport);
    final distance = _distanceToAirport(crashpad, airport);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StatusBadge(label: crashpad.bedModel.shortLabel),
        const SizedBox(height: AppSpacing.md),
        Text(crashpad.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(
          icon: Icons.king_bed_outlined,
          label: _availabilityLabel(availableCapacity, availabilityDates),
        ),
        _DetailRow(
          icon: Icons.flight_takeoff_outlined,
          label: '${crashpad.nearestAirport} nearest airport',
        ),
        _DetailRow(
          icon: Icons.route_outlined,
          label: distance == null
              ? 'Airport distance not listed'
              : '${distance.toStringAsFixed(1)} miles from airport',
        ),
        if (rating > 0)
          _DetailRow(
            icon: Icons.star_outline,
            label: '${rating.toStringAsFixed(1)} guest rating',
          ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppPrimaryButton(
            onPressed: () => onOpen(crashpad),
            icon: Icons.open_in_new_outlined,
            child: const Text('View Listing'),
          ),
        ),
      ],
    );
  }

  static String _availabilityLabel(
    int availableCapacity,
    DateTimeRange? availabilityDates,
  ) {
    final suffix = availableCapacity == 1 ? 'space' : 'spaces';
    if (availabilityDates == null) {
      return '$availableCapacity available $suffix';
    }
    return '$availableCapacity available $suffix for selected dates';
  }

  static double? _distanceToAirport(Crashpad crashpad, Airport? airport) {
    if (airport != null && crashpad.hasMapCoordinates) {
      return const Distance().as(
        LengthUnit.Mile,
        LatLng(crashpad.latitude!, crashpad.longitude!),
        LatLng(airport.latitude, airport.longitude),
      );
    }
    return crashpad.distanceToAirportMiles;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppPalette.textMuted, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint();

  @override
  Widget build(BuildContext context) {
    return const EmptyStatePanel(
      icon: Icons.touch_app_outlined,
      title: 'Select a crashpad',
      message:
          'Tap a crashpad marker or cluster to evaluate airport distance and availability.',
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return EmptyStatePanel(
      icon: Icons.search_off_outlined,
      title: 'No matching crashpads',
      message: 'Clear filters to bring all current crashpads back into view.',
      action: AppSecondaryButton(
        onPressed: onShowAll,
        icon: Icons.refresh_outlined,
        child: const Text('Show all crashpads'),
      ),
    );
  }
}

class _MapLoadingState extends StatelessWidget {
  const _MapLoadingState();

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          ShimmerBox(height: 20, width: 160),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 360, width: double.infinity, radius: AppRadius.lg),
        ],
      ),
    );
  }
}

class _MapErrorState extends StatelessWidget {
  const _MapErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyStatePanel(
      icon: Icons.map_outlined,
      title: 'Crash App Map unavailable',
      message: 'Map data could not be prepared. $message',
    );
  }
}

class _CrashpadMapPoint {
  const _CrashpadMapPoint({
    required this.crashpad,
    required this.position,
  });

  final Crashpad crashpad;
  final LatLng position;

  static _CrashpadMapPoint? fromCrashpad(Crashpad crashpad) {
    if (crashpad.hasMapCoordinates) {
      return _CrashpadMapPoint(
        crashpad: crashpad,
        position: LatLng(crashpad.latitude!, crashpad.longitude!),
      );
    }
    final airport = AirportData.findByCode(crashpad.nearestAirport);
    if (airport == null) return null;
    final offset = _demoSafeOffset(crashpad.id);
    return _CrashpadMapPoint(
      crashpad: crashpad,
      position: LatLng(
        airport.latitude + offset.latitude,
        airport.longitude + offset.longitude,
      ),
    );
  }

  static _CoordinateOffset _demoSafeOffset(String seed) {
    final total =
        seed.codeUnits.fold<int>(0, (sum, codeUnit) => sum + codeUnit);
    final direction = total.isEven ? 1 : -1;
    final spread = 0.035 + (total % 7) * 0.008;
    final angle = (total % 360) * math.pi / 180;
    return _CoordinateOffset(
      latitude: math.sin(angle) * spread * direction,
      longitude: math.cos(angle) * spread,
    );
  }
}

class _CoordinateOffset {
  const _CoordinateOffset({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
