import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';
import 'interaction_feedback.dart';

final NumberFormat _money = NumberFormat.currency(symbol: r'$');

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= AppBreakpoints.desktop ? 32.0 : 20.0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 96),
          child: child,
        ),
      ),
    );
  }
}

class CrashSurface extends StatelessWidget {
  const CrashSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.radius = AppRadius.xl,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppPalette.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppPalette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppPalette.ink.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.color = AppPalette.blue,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppPalette.blue,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: CrashSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: AppRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: accent),
            const SizedBox(height: AppSpacing.md),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 64, color: AppPalette.textSubtle),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppPalette.text,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 14),
        ),
        if (action != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          action!,
        ],
      ],
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final darkerBlue = Color.alphaBlend(
      AppPalette.blue.withValues(alpha: 0.85),
      AppPalette.midnight,
    );
    final content = DefaultTextStyle.merge(
      style: const TextStyle(
        color: AppPalette.text,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      child: IconTheme.merge(
        data: const IconThemeData(color: AppPalette.text, size: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );

    return TapScale(
      enabled: onPressed != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[AppPalette.blue, darkerBlue],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadius.md),
              overlayColor: WidgetStateProperty.all(
                AppPalette.text.withValues(alpha: 0.08),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon),
        label: child,
      ),
    );
  }
}

class AppDestructiveButton extends StatelessWidget {
  const AppDestructiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon),
        label: child,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppPalette.danger.withValues(alpha: 0.15),
          foregroundColor: AppPalette.danger,
          side: const BorderSide(color: AppPalette.danger),
        ),
      ),
    );
  }
}

class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final sweep = (_controller.value * 2) - 1;
            return LinearGradient(
              begin: Alignment(sweep - 1, 0),
              end: Alignment(sweep + 1, 0),
              colors: const <Color>[
                AppPalette.border,
                AppPalette.panelElevated,
                AppPalette.border,
              ],
              stops: const <double>[0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadius.md,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppPalette.panelElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: CrashSurface(
        padding: EdgeInsets.zero,
        radius: AppRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ShimmerBox(
              height: compact ? 132 : 190,
              width: double.infinity,
              radius: AppRadius.lg,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  ShimmerBox(height: AppSpacing.lg, width: 180),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBox(height: AppSpacing.md, width: 120),
                  SizedBox(height: AppSpacing.lg),
                  ShimmerBox(height: 30, width: double.infinity),
                  SizedBox(height: AppSpacing.lg),
                  ShimmerBox(height: AppSpacing.md, width: 140),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard({
    super.key,
    required this.summary,
    this.showStatus = true,
  });

  final PaymentSummary summary;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Payment summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (showStatus)
                StatusBadge(
                  label: _statusLabel(summary.status),
                  icon: Icons.payments_outlined,
                  color: summary.status == PaymentStatus.paid
                      ? AppPalette.success
                      : AppPalette.blueSoft,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _MoneyRow(label: 'Booking subtotal', value: summary.bookingSubtotal),
          if (summary.additionalServicesTotal > 0)
            _MoneyRow(
              label: 'Additional services',
              value: summary.additionalServicesTotal,
            ),
          if (summary.checkoutChargesTotal > 0)
            _MoneyRow(
              label: 'Checkout charges',
              value: summary.checkoutChargesTotal,
            ),
          const Divider(height: 28),
          _MoneyRow(
            label: 'Total charged to guest',
            value: summary.totalChargedToGuest,
            emphasized: true,
          ),
          _MoneyRow(
            label: AppConfig.platformFeeLabel,
            value: summary.platformFee,
            muted: true,
          ),
          _MoneyRow(
            label: 'Owner payout',
            value: summary.ownerPayout,
            emphasized: true,
            color: AppPalette.success,
          ),
        ],
      ),
    );
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.draft:
        return 'Quote';
      case PaymentStatus.authorized:
        return 'Authorized';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.muted = false,
    this.color,
  });

  final String label;
  final double value;
  final bool emphasized;
  final bool muted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textStyle = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    final rowColor = color ?? (muted ? AppPalette.textMuted : AppPalette.text);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: textStyle?.copyWith(
                color: rowColor,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _money.format(value),
            style: textStyle?.copyWith(
              color: rowColor,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
