import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gradient header used by secondary screens to mirror the home hero styling.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(132);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isLight
          ? <Color>[
              AppPalette.lightSurface,
              AppPalette.aurora.withValues(alpha: 0.12),
            ]
          : <Color>[
              AppPalette.deepSpace.withValues(alpha: 0.92),
              AppPalette.neonPulse.withValues(alpha: 0.12),
            ],
    );

    final textColor = isLight ? AppPalette.lightText : Colors.white;
    final subTextColor =
        isLight ? AppPalette.lightTextSecondary : AppPalette.softSlate;
    final accentBackground =
        (isLight ? AppPalette.aurora : AppPalette.neonPulse)
            .withValues(alpha: 0.16);

    return Material(
      color: Colors.transparent,
      elevation: isLight ? 2 : 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: isLight
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.aurora.withValues(alpha: 0.12),
                    offset: const Offset(0, 12),
                    blurRadius: 24,
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    offset: const Offset(0, 18),
                    blurRadius: 36,
                  ),
                ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 26, color: AppPalette.neonPulse),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  IconTheme.merge(
                    data: IconThemeData(color: textColor),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions
                          .map(
                            (Widget action) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: action,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
