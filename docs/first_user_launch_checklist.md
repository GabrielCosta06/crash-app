# First-User Launch Checklist

Use this with Stripe test mode and the production Supabase project before
inviting the first owners or crew users.

1. Create an owner account and complete profile details.
2. Create the first crashpad listing with rooms, bed model, rules, services,
   checkout fees, and map coordinates.
3. Complete Stripe Connect onboarding and confirm the owner account is ready for
   payouts.
4. Create a guest account and request a stay from the live listing.
5. Approve the request as the owner, pay through Stripe Checkout as the guest,
   and confirm the webhook moves the booking to confirmed.
6. Check in the guest, assess a checkout fee, pay it through Stripe Checkout,
   and confirm the booking completes after the webhook.
7. Use the in-app Refresh status buttons after Stripe redirects if webhook
   updates are not visible immediately.
