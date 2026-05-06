# Crash App

A Flutter-based marketplace for airline crew crashpads, featuring role-based access for guests and owners, secure booking workflows, and optimized UI for crew rest management.

## Project Overview

Crash App is designed to solve the unique housing needs of airline crew members. It allows owners to list properties with specific bed models (Hot Bed vs. Cold Bed) and enables crew members to find, book, and pay for stays near their assigned airports.

## Recent UI/UX Improvements

The following 15 improvements have been implemented to enhance the user experience and scannability:

1.  **Call-to-Action Booking Flow**: Added a prominent "Start booking" CTA on the home screen that guides users directly to the search/filter section.
2.  **Role-Based Initial Routing**: The app now intelligently routes users based on their role (Owner vs. Guest) upon login.
3.  **Sidebar Role Badges**: Added clear visual indicators in the navigation sidebar to show the current user's role.
4.  **Decision-First Listing Cards**: Improved scannability of listing cards by highlighting critical information like "Verified" status and urgent availability (e.g., "1 open" in red).
5.  **Hot/Cold Bed Tooltips**: Added informational tooltips to the bed type filters to clarify the difference between rotating "Hot Beds" and assigned "Cold Beds".
6.  **Information Hierarchy Rework**: Reordered the details page to prioritize trust signals and property descriptions over technical room breakdowns.
7.  **Trust & Verification Layer**: Added a dedicated "Trust and Verification" section on the details page, including owner response times and security features.
8.  **Owner-Approval Checkout**: Guests request a stay first; owners approve it; then Stripe Checkout opens from booking history.
9.  **Stripe Test-Mode Payments**: Booking payments, owner payouts, checkout charges, and Crash App platform fees are routed through Supabase Edge Functions backed by Stripe test-mode keys.
10. **Scannable Dashboard Metrics**: Improved the owner dashboard with better spacing and clearer metric cards for properties and earnings.
11. **Skeleton Loaders**: Implemented custom skeleton loaders for the owner dashboard to improve perceived performance during data fetching.
12. **Contextual Empty States**: Replaced generic "No data" messages with actionable empty states that guide users on how to proceed (e.g., "Add your first crashpad").
13. **Improved Onboarding Copy**: Updated the home and signup screens with clearer, benefit-driven copy tailored to airline crew needs.
14. **Visual Consistency**: Standardized padding, radius, and color usage across new components using the `AppPalette` and `AppSpacing` themes.
15. **Accessibility Hints**: Added tooltips and descriptive labels to icons to improve accessibility for screen readers and new users.

## Technical Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Theme**: Custom `AppTheme` with `AppPalette` for consistent branding.
- **Components**: Reusable widgets in `lib/widgets/app_components.dart`.

## Getting Started

1.  **Clone the repository**.
2.  **Install dependencies**: `flutter pub get`
3.  **Configure Supabase**: provide `SUPABASE_URL` and `SUPABASE_ANON_KEY` via dart defines.
4.  **Run the app**: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## First-User Data

Crash App no longer boots with production mock data. If Supabase configuration
is missing, startup fails closed with a configuration screen. Marketplace
content starts with user-created owner listings; seeded crashpads exist only in
test fixtures under `test/fixtures`.

Before inviting first users, run the in-app owner **Launch checklist** or follow
`docs/first_user_launch_checklist.md` with Stripe test-mode keys.
