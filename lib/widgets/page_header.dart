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
  Size get preferredSize => const Size.fromHeight(140);

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
    final accentBackground = (isLight ? AppPalette.aurora : AppPalette.neonPulse)
        .withValues(alpha: 0.16);

    return Material(
      color: Colors.transparent,
      elevation: isLight ? 2 : 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxHeight < 138;
              final bool tight = constraints.maxHeight < 120;

              final EdgeInsets padding = EdgeInsets.fromLTRB(
                20,
                tight ? 8 : (compact ? 10 : 14),
                20,
                tight ? 10 : (compact ? 12 : 18),
              );
              final double iconPadding = tight ? 8 : (compact ? 10 : 12);
              final double iconSize = tight ? 24 : 28;
              final double primaryGap = tight ? 6 : 10;
              final double secondaryGap = tight ? 4 : 6;

              final TextStyle? titleStyle = (tight
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
              );
              final TextStyle? subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: subTextColor,
                fontSize: tight
                    ? (theme.textTheme.bodyMedium?.fontSize ?? 14) * 0.94
                    : null,
              );

              return Padding(
                padding: padding,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.all(iconPadding),
                          decoration: BoxDecoration(
                            color: accentBackground,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(icon, size: iconSize, color: AppPalette.neonPulse),
                        ),
                        SizedBox(height: primaryGap),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: titleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: secondaryGap),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: subtitleStyle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (actions.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconTheme.merge(
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
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
