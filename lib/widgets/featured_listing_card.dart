import 'package:flutter/material.dart';
import 'package:crash_pad/models/crashpad.dart';
import 'package:crash_pad/screens/owner_details_screen.dart';
import 'package:crash_pad/theme/app_theme.dart';

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryText =
        isDark ? AppPalette.softSlate : Colors.grey[600]!;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OwnerDetailsScreen(crashpad: listing),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(right: 16.0),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6)
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "\$${listing.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cityState,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Nearest: ${listing.nearestAirport}",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Bed type: ${listing.bedType}",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondaryText),
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
