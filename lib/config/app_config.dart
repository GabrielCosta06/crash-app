/// Central product configuration for Crash App.
class AppConfig {
  const AppConfig._();

  /// Crash App currently monetizes through a transaction fee.
  ///
  /// Keep this centralized so Stripe integration can reuse the same business
  /// rule without duplicating a magic number across UI widgets.
  static const double platformFeeRate = 0.02;

  static const String platformFeeLabel = '(-) Crash App fee';
  static const int defaultGuestCount = 1;
}
