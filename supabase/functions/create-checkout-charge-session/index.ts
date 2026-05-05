import { corsHeaders, jsonResponse, readJson } from "../_shared/cors.ts";
import { requireUser, supabaseAdmin } from "../_shared/supabase.ts";
import { formBody, platformFeeCents, stripeRequest } from "../_shared/stripe.ts";

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

    const { data: booking } = await admin
      .from("bookings")
      .select("*")
      .eq("id", bookingId)
      .single();
    if (!booking) return jsonResponse({ error: "Booking not found" }, 404);
    if (booking.guest_id !== user.id) {
      return jsonResponse({ error: "Only the booking guest can pay checkout charges" }, 403);
    }
    if (booking.status !== "active") {
      return jsonResponse({ error: "Checkout charges are only payable during active stays" }, 409);
    }

    const summary = booking.payment_summary as Record<string, unknown>;
    const checkoutCharges = Array.isArray(summary.checkoutCharges)
      ? summary.checkoutCharges as Array<Record<string, unknown>>
      : [];
    const amountCents = Math.round(
      checkoutCharges.reduce((sum, item) => sum + Number(item.amount ?? 0), 0) * 100,
    );
    if (amountCents <= 0) return jsonResponse({ error: "No checkout charges are due" }, 400);

    const { data: listing } = await admin
      .from("listings")
      .select("owner_id")
      .eq("id", booking.crashpad_id)
      .single();
    const { data: stripeAccount } = await admin
      .from("stripe_accounts")
      .select("stripe_account_id")
      .eq("owner_id", listing.owner_id)
      .single();
    const feeCents = platformFeeCents(amountCents, Number(summary.platformFeeRate ?? 0.02));

    const session = await stripeRequest<CheckoutSession>("/v1/checkout/sessions", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      idempotencyKey: `checkout-charge-${bookingId}`,
      body: formBody({
        mode: "payment",
        success_url: successUrl,
        cancel_url: cancelUrl,
        customer_email: booking.guest_email,
        "client_reference_id": bookingId,
        "metadata[booking_id]": bookingId,
        "metadata[purpose]": "checkout_charge",
        "line_items[0][quantity]": 1,
        "line_items[0][price_data][currency]": "usd",
        "line_items[0][price_data][unit_amount]": amountCents,
        "line_items[0][price_data][product_data][name]":
          `Checkout charges: ${booking.crashpad_name}`,
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
      owner_payout_cents: amountCents - feeCents,
      status: "awaitingPayment",
      purpose: "checkout_charge",
    }, { onConflict: "stripe_checkout_session_id" });

    await admin
      .from("bookings")
      .update({ checkout_charge_payment_status: "awaitingPayment" })
      .eq("id", bookingId);

    return jsonResponse({ url: session.url, sessionId: session.id });
  } catch (error) {
    if (error instanceof Response) return error;
    return jsonResponse({ error: String(error) }, 500);
  }
});
