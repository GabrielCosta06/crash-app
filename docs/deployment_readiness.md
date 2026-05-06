# Crash App Deployment Readiness

## Web Beta

Build with production dart-defines:

```bash
flutter build web --release \
  --dart-define=CRASH_APP_ORIGIN=https://crash-pad-cold-dawn-1241.fly.dev \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

Fly deploys the Flutter web build from `dockerfile`. GitHub Actions verifies
`flutter analyze`, `flutter test`, and `flutter build web` before `flyctl deploy`.

## Supabase

Apply `supabase/migrations/20260504120000_crash_app_mvp.sql`, then set Edge
Function secrets:

```bash
supabase secrets set \
  STRIPE_SECRET_KEY=sk_test_... \
  STRIPE_WEBHOOK_SECRET=whsec_... \
  CRASH_APP_ORIGIN=https://crash-pad-cold-dawn-1241.fly.dev
```

Deploy functions:

```bash
supabase functions deploy create-stripe-connect-account
supabase functions deploy create-booking-checkout
supabase functions deploy create-checkout-charge-session
supabase functions deploy stripe-webhook --no-verify-jwt
```

Configure Stripe webhooks to call:

```text
https://<project-ref>.functions.supabase.co/stripe-webhook
```

Listen for at least `checkout.session.completed`, `account.updated`, and the
Accounts v2 account update event emitted by your Stripe account. Crash App
monetizes through Stripe Connect application fees on booking and checkout-fee
payments, not a monthly subscription.

## Mobile Release

Android uses `com.crashapp.marketplace` and release signing environment
variables from `.env.example`. Build the store artifact with:

```bash
flutter build appbundle --release \
  --dart-define=CRASH_APP_ORIGIN=https://crash-pad-cold-dawn-1241.fly.dev \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

iOS uses `com.crashapp.marketplace`. Archive on macOS with the Apple Developer
team and provisioning profile selected in Xcode, passing the same dart-defines.
