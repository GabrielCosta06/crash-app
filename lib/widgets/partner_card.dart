import 'package:flutter/material.dart';

class PartnerCard extends StatelessWidget {
  final String partnerLogoUrl;
  final String partnerName;
  const PartnerCard({
    super.key,
    required this.partnerLogoUrl,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        width: 100,
        height: 100,
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: partnerLogoUrl.isNotEmpty
              ? Image.network(
                  partnerLogoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        partnerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                )
              : Center(
                  child: Text(
                    partnerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A widget that returns a horizontal list of trusted partner logos.
class PartnersList extends StatelessWidget {
  const PartnersList({super.key});

  // List of trusted partners with logo URLs and names.
  static const List<Map<String, String>> partners = [
    {
      'partnerLogoUrl':
          'https://vpygfszjcyowdzgoxvss.supabase.co/storage/v1/object/public/general-images//united_logo.png',
      'partnerName': 'United Airlines',
    },
    {
      'partnerLogoUrl':
          'https://vpygfszjcyowdzgoxvss.supabase.co/storage/v1/object/public/general-images//american_logo.jpg',
      'partnerName': 'American Airlines',
    },
    {
      'partnerLogoUrl':
          'https://vpygfszjcyowdzgoxvss.supabase.co/storage/v1/object/public/general-images//swiss_logo.png',
      'partnerName': 'Swiss Airlines',
    },
    {
      'partnerLogoUrl':
          'https://vpygfszjcyowdzgoxvss.supabase.co/storage/v1/object/public/general-images//emirates_logo.png',
      'partnerName': 'Emirates Airlines',
    },
    {
      'partnerLogoUrl':
          'https://vpygfszjcyowdzgoxvss.supabase.co/storage/v1/object/public/general-images//delta_logo.png',
      'partnerName': 'Delta Airlines',
    },
    {
      'partnerLogoUrl':
          'https://vpygfszjcyowdzgoxvss.supabase.co/storage/v1/object/public/general-images//jetblue_logo.png',
      'partnerName': 'jetBlue Airways',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110, // accommodates the 100x100 PartnerCard with margins
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: partners
            .map(
              (partner) => PartnerCard(
                partnerLogoUrl: partner['partnerLogoUrl']!,
                partnerName: partner['partnerName']!,
              ),
            )
            .toList(),
      ),
    );
  }
}
