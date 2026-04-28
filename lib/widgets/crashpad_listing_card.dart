import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/crashpad.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';
import 'interaction_feedback.dart';

class CrashpadListingCard extends StatelessWidget {
  const CrashpadListingCard({
    super.key,
    required this.crashpad,
    required this.onTap,
    this.compact = false,
  });

  final Crashpad crashpad;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final checkIn = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 1));
    final checkOut = checkIn.add(Duration(days: crashpad.minimumStayNights));
    final dateAwareCapacity =
        context.watch<AppRepository>().availableCapacityForDates(
              crashpad: crashpad,
              checkInDate: checkIn,
              checkOutDate: checkOut,
            );
    final imageHeight = compact ? 132.0 : 190.0;
    final isUrgent = dateAwareCapacity <= 1;

    return Semantics(
      button: true,
      label:
          '${crashpad.name}, ${_cityLine(crashpad.location)}, ${crashpad.bedModel.label}, \$${crashpad.price.toStringAsFixed(0)} per night, $dateAwareCapacity spaces open.',
      child: TapScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isUrgent
                  ? const Border(
                      left: BorderSide(color: AppPalette.warning, width: 3),
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: CrashSurface(
              padding: EdgeInsets.zero,
              radius: AppRadius.lg,
              color: AppPalette.panel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                    child: Stack(
                      children: <Widget>[
                        CrashpadImage(
                          imageUrls: crashpad.imageUrls,
                          height: imageHeight,
                          width: double.infinity,
                          heroTag: compact ? null : 'crashpad-${crashpad.id}',
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  AppPalette.ink.withValues(alpha: 0),
                                  AppPalette.ink.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.md,
                          top: AppSpacing.md,
                          child: StatusBadge(
                            label: crashpad.bedModel.shortLabel,
                            icon: Icons.bed_outlined,
                            color: crashpad.bedModel == CrashpadBedModel.cold
                                ? AppPalette.success
                                : AppPalette.blueSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                crashpad.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '\$${crashpad.price.toStringAsFixed(0)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppPalette.blueSoft),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _cityLine(crashpad.location),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppPalette.textMuted,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MiniFact(
                              icon: Icons.local_airport_outlined,
                              label: crashpad.nearestAirport,
                            ),
                            _MiniFact(
                              icon: Icons.king_bed_outlined,
                              label: '$dateAwareCapacity open',
                              color: isUrgent ? AppPalette.warning : null,
                            ),
                            if (crashpad.distanceToAirportMiles != null)
                              _MiniFact(
                                icon: Icons.route_outlined,
                                label:
                                    '${crashpad.distanceToAirportMiles!.toStringAsFixed(1)} mi',
                              ),
                            const _MiniFact(
                              icon: Icons.verified_user_outlined,
                              label: 'Verified',
                              color: AppPalette.success,
                              verified: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${crashpad.houseRules.length} house rules',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'View details',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AppPalette.blueSoft),
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

  String _cityLine(String location) {
    final parts = location.split(',');
    if (parts.length >= 3) {
      return '${parts[1].trim()}, ${parts[2].trim()}';
    }
    return location;
  }
}

class CrashpadImage extends StatelessWidget {
  const CrashpadImage({
    super.key,
    required this.imageUrls,
    required this.height,
    required this.width,
    this.heroTag,
  });

  final List<String> imageUrls;
  final double height;
  final double width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (heroTag == null) return image;
    return Hero(tag: heroTag!, child: image);
  }

  Widget _buildImage() {
    if (imageUrls.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: AppPalette.panelElevated,
        child: const Icon(
          Icons.apartment_outlined,
          color: AppPalette.textSubtle,
        ),
      );
    }

    final url = imageUrls.first;
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(icon: Icons.broken_image),
      );
    }

    try {
      return Image.memory(
        base64Decode(url),
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (_) {
      return _placeholder(icon: Icons.image_not_supported_outlined);
    }
  }

  Widget _placeholder({IconData icon = Icons.apartment_outlined}) {
    return Container(
      width: width,
      height: height,
      color: AppPalette.panelElevated,
      child: Center(child: Icon(icon, color: AppPalette.textSubtle)),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({
    required this.icon,
    required this.label,
    this.color,
    this.verified = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppPalette.textMuted;
    return Semantics(
      label: verified ? 'Verified listing' : label,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: verified ? AppSpacing.sm : 9,
          vertical: verified ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: verified
              ? AppPalette.success.withValues(alpha: 0.15)
              : color?.withValues(alpha: 0.1) ?? AppPalette.panelElevated,
          borderRadius: BorderRadius.circular(verified ? 6 : AppRadius.sm),
          border: Border.all(
            color: color?.withValues(alpha: 0.2) ?? AppPalette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontSize: verified ? 11 : null,
                    fontWeight: verified ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
