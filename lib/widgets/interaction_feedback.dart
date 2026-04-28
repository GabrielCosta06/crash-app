import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Provides a subtle scaling effect when the user presses on interactive widgets.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressScale = 0.97,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeInOut,
  });

  final Widget child;
  final bool enabled;
  final double pressScale;
  final Duration duration;
  final Curve curve;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) {
      return;
    }
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  void didUpdateWidget(covariant TapScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: widget.enabled && _pressed ? widget.pressScale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

/// Animated back button that plays a quick scale effect before navigating back.
class AnimatedBackButton extends StatelessWidget {
  const AnimatedBackButton({super.key, this.onPressed, this.pressScale = 0.97});

  final VoidCallback? onPressed;
  final double pressScale;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      pressScale: pressScale,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox.square(
          dimension: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.panelElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.border),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              iconSize: 18,
              padding: EdgeInsets.zero,
              color: AppPalette.text,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays a transient, animated dialog to highlight successful actions.
Future<void> showActionFeedback({
  required BuildContext context,
  required IconData icon,
  required String title,
  String? message,
  Color? color,
  Duration displayDuration = const Duration(milliseconds: 1300),
}) {
  final theme = Theme.of(context);
  final accentColor = color ?? theme.colorScheme.secondary;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'action-feedback',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ActionFeedbackDialog(
        icon: icon,
        title: title,
        message: message,
        color: accentColor,
        displayDuration: displayDuration,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(scale),
          child: child,
        ),
      );
    },
  );
}

class _ActionFeedbackDialog extends StatefulWidget {
  const _ActionFeedbackDialog({
    required this.icon,
    required this.title,
    required this.color,
    required this.displayDuration,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final Duration displayDuration;

  @override
  State<_ActionFeedbackDialog> createState() => _ActionFeedbackDialogState();
}

class _ActionFeedbackDialogState extends State<_ActionFeedbackDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.displayDuration, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.95 : 0.97,
    );

    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 32, color: widget.color),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 4,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                width: constraints.maxWidth,
                                color: widget.color.withValues(alpha: 0.12),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: widget.displayDuration,
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return Container(
                                    width: constraints.maxWidth * value,
                                    color: widget.color,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
