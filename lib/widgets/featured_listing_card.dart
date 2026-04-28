import 'package:flutter/material.dart';
import 'package:crash_pad/models/crashpad.dart';
import 'package:crash_pad/screens/owner_details_screen.dart';
import 'package:crash_pad/theme/app_theme.dart';
import 'package:crash_pad/widgets/app_components.dart';
import 'package:crash_pad/widgets/interaction_feedback.dart';

class FeaturedListingCard extends StatelessWidget {
  final Crashpad listing;
  final double cardWidth;
  final double imageHeight;
  final Widget Function(dynamic imageUrls) buildListingImages;

  const FeaturedListingCard({
    super.key,
    required this.listing,
    required this.cardWidth,
    required this.imageHeight,
    required this.buildListingImages,
  });

  @override
  Widget build(BuildContext context) {
    List<String> parts = listing.location.split(",");
    String cityState = parts.length >= 3
        ? "${parts[1].trim()}, ${parts[2].trim()}"
        : listing.location;
    const secondaryText = AppPalette.textMuted;
    return TapScale(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            AppPageRoute<void>(
              builder: (context) => OwnerDetailsScreen(crashpad: listing),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Card(
          margin: const EdgeInsets.only(right: AppSpacing.lg),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section with overlay and price badge.
              Stack(
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: cardWidth,
                    child: buildListingImages(listing.imageUrls),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppPalette.ink.withValues(alpha: 0),
                            AppPalette.ink.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "\$${listing.price.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: AppPalette.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Details section.
              Padding(
                padding: const EdgeInsets.all(12.0),
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
                      cityState,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondaryText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Nearest: ${listing.nearestAirport}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondaryText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bed type: ${listing.bedType}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
