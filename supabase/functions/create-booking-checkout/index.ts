import { corsHeaders, jsonResponse, readJson } from "../_shared/cors.ts";
import { requireUser, supabaseAdmin } from "../_shared/supabase.ts";
import {
  dollarsToCents,
  formBody,
  platformFeeCents,
  stripeRequest,
} from "../_shared/stripe.ts";

type CheckoutSession = { id: string; url: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  try {
    const { user } = await requireUser(req);
    const admin = supabaseAdmin();
    const body = await readJson(req);
    const bookingId = String(body.bookingId ?? "");
    const successUrl = String(body.successUrl ?? Deno.env.get("CRASH_APP_ORIGIN") ?? "");
    const cancelUrl = String(body.cancelUrl ?? successUrl);
    if (!bookingId) return jsonResponse({ error: "bookingId is required" }, 400);

    const { data: booking, error: bookingError } = await admin
      .from("bookings")
      .select("*")
      .eq("id", bookingId)
      .single();
    if (bookingError || !booking) return jsonResponse({ error: "Booking not found" }, 404);
    if (booking.guest_id !== user.id) {
      return jsonResponse({ error: "Only the booking guest can pay" }, 403);
    }
    if (booking.status !== "awaitingPayment") {
      return jsonResponse({ error: "Booking is not awaiting payment" }, 409);
    }

    const { data: listing, error: listingError } = await admin
      .from("listings")
      .select("owner_id,owner_email")
      .eq("id", booking.crashpad_id)
      .single();
    if (listingError || !listing) return jsonResponse({ error: "Listing not found" }, 404);

    const { data: stripeAccount } = await admin
      .from("stripe_accounts")
      .select("stripe_account_id,charges_enabled,payouts_enabled")
      .eq("owner_id", listing.owner_id)
      .maybeSingle();
    if (!stripeAccount?.stripe_account_id) {
      return jsonResponse({ error: "Owner payouts are not connected" }, 409);
    }

    const summary = booking.payment_summary as Record<string, unknown>;
    const amountCents = dollarsToCents(totalChargedToGuest(summary));
    const feeRate = Number(summary.platformFeeRate ?? 0.02);
    const feeCents = platformFeeCents(amountCents, feeRate);
    const ownerPayoutCents = amountCents - feeCents;
    if (amountCents <= 0) return jsonResponse({ error: "Booking total is invalid" }, 400);

    const session = await stripeRequest<CheckoutSession>("/v1/checkout/sessions", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      idempotencyKey: `booking-checkout-${bookingId}`,
      body: formBody({
        mode: "payment",
        success_url: successUrl,
        cancel_url: cancelUrl,
        customer_email: booking.guest_email,
        "client_reference_id": bookingId,
        "metadata[booking_id]": bookingId,
        "metadata[purpose]": "booking",
        "line_items[0][quantity]": 1,
        "line_items[0][price_data][currency]": "usd",
        "line_items[0][price_data][unit_amount]": amountCents,
        "line_items[0][price_data][product_data][name]":
          `Crashpad stay: ${booking.crashpad_name}`,
        "payment_intent_data[application_fee_amount]": feeCents,
        "payment_intent_data[transfer_data][destination]":
          stripeAccount.stripe_account_id,
      }),
    });

    await admin.from("payment_records").upsert({
      booking_id: bookingId,
      payer_id: booking.guest_id,
      owner_id: listing.owner_id,
      stripe_checkout_session_id: session.id,
      amount_cents: amountCents,
      platform_fee_cents: feeCents,
      owner_payout_cents: ownerPayoutCents,
      status: "awaitingPayment",
      purpose: "booking",
    }, { onConflict: "stripe_checkout_session_id" });

    return jsonResponse({ url: session.url, sessionId: session.id });
  } catch (error) {
    if (error instanceof Response) return error;
    return jsonResponse({ error: String(error) }, 500);
  }
});

function totalChargedToGuest(summary: Record<string, unknown>): number {
  return Number(summary.bookingSubtotal ?? 0) +
    lineItemTotal(summary.additionalServices) +
    lineItemTotal(summary.checkoutCharges);
}

function lineItemTotal(value: unknown): number {
  if (!Array.isArray(value)) return 0;
  return value.reduce((total, item) => {
    if (!item || typeof item !== "object") return total;
    return total + Number((item as Record<string, unknown>).amount ?? 0);
  }, 0);
}
