import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuickLink extends StatelessWidget {
  final String title;
  const QuickLink({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent =
        isDark ? AppPalette.neonPulse : Colors.blue.shade900;
    return ListTile(
      onTap: () {
        // Implement your navigation or action here.
      },
      leading: Icon(Icons.link, color: accent),
      title: Text(
        title,
        style: TextStyle(
          color: accent,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: accent),
    );
  }
}
