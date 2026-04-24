import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/crashpad.dart';
import '../services/availability_service.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

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
    final availability = const AvailabilityService().summarize(crashpad);
    final imageHeight = compact ? 132.0 : 190.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: CrashSurface(
        padding: EdgeInsets.zero,
        radius: AppRadius.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              child: Stack(
                children: <Widget>[
                  CrashpadImage(
                    imageUrls: crashpad.imageUrls,
                    height: imageHeight,
                    width: double.infinity,
                    heroTag: compact ? null : 'crashpad-${crashpad.id}',
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppPalette.blueSoft,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _cityLine(crashpad.location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppPalette.textMuted),
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
                        label: '${availability.availableToBook} open',
                      ),
                      if (crashpad.distanceToAirportMiles != null)
                        _MiniFact(
                          icon: Icons.route_outlined,
                          label:
                              '${crashpad.distanceToAirportMiles!.toStringAsFixed(1)} mi',
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
        child:
            const Icon(Icons.apartment_outlined, color: AppPalette.textSubtle),
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
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.panelElevated,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppPalette.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}
