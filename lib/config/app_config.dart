/// Central product configuration for Crash App.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Crash App';
  static const String productionOrigin = String.fromEnvironment(
    'CRASH_APP_ORIGIN',
    defaultValue: 'https://crash-pad-cold-dawn-1241.fly.dev',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get missingSupabaseKeys => <String>[
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      ];

  static const String stripeConnectFunction = 'create-stripe-connect-account';
  static const String stripeBookingCheckoutFunction = 'create-booking-checkout';
  static const String stripeCheckoutChargeFunction =
      'create-checkout-charge-session';

  /// Crash App currently monetizes through a transaction fee.
  ///
  /// Keep this centralized so Stripe integration can reuse the same business
  /// rule without duplicating a magic number across UI widgets.
  static const double platformFeeRate = 0.02;

  static const String platformFeeLabel = '(-) Crash App fee';
  static const int defaultGuestCount = 1;
}
