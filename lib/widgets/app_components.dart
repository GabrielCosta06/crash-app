import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';

final NumberFormat _money = NumberFormat.currency(symbol: r'$');

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
              EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                96,
              ),
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
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.textMuted),
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
    return CrashSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent),
          const SizedBox(height: 14),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
        ],
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
    return CrashSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: AppPalette.textSubtle),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            action!,
          ],
        ],
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
          _MoneyRow(
            label: 'Booking subtotal',
            value: summary.bookingSubtotal,
          ),
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
