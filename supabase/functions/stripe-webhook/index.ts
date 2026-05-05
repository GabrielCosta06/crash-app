import { jsonResponse } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const payload = await req.text();
  const signature = req.headers.get("stripe-signature") ?? "";
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
  if (!webhookSecret) return jsonResponse({ error: "Webhook secret missing" }, 500);
  const verified = await verifyStripeSignature(payload, signature, webhookSecret);
  if (!verified) return jsonResponse({ error: "Invalid signature" }, 400);

  const event = JSON.parse(payload) as Record<string, unknown>;
  const admin = supabaseAdmin();

  try {
    if (event.type === "checkout.session.completed") {
      const session = (event.data as Record<string, unknown>).object as Record<string, unknown>;
      const purpose = String(
        (session.metadata as Record<string, unknown> | undefined)?.purpose ?? "",
      );
      const bookingId = String(
        (session.metadata as Record<string, unknown> | undefined)?.booking_id ?? "",
      );
      const paymentIntentId = session.payment_intent
        ? String(session.payment_intent)
        : null;
      if (purpose === "booking" && bookingId) {
        const { data: booking } = await admin
          .from("bookings")
          .select("payment_summary")
          .eq("id", bookingId)
          .single();
        const summary = {
          ...(booking?.payment_summary as Record<string, unknown> | undefined ?? {}),
          status: "paid",
        };
        await admin
          .from("bookings")
          .update({ status: "confirmed", payment_summary: summary })
          .eq("id", bookingId)
          .eq("status", "awaitingPayment");
        await admin
          .from("payment_records")
          .update({
            status: "paid",
            stripe_payment_intent_id: paymentIntentId,
          })
          .eq("stripe_checkout_session_id", String(session.id));
      }

      if (purpose === "checkout_charge" && bookingId) {
        await admin
          .from("bookings")
          .update({
            status: "completed",
            checkout_charge_payment_status: "paid",
          })
          .eq("id", bookingId)
          .eq("status", "active");
        await admin
          .from("payment_records")
          .update({
            status: "paid",
            stripe_payment_intent_id: paymentIntentId,
          })
          .eq("stripe_checkout_session_id", String(session.id));
      }

      if (purpose === "premium_subscription") {
        const userId = String(
          (session.metadata as Record<string, unknown> | undefined)?.user_id ??
            session.client_reference_id ?? "",
        );
        const customerId = String(session.customer ?? "");
        const subscriptionId = session.subscription
          ? String(session.subscription)
          : null;
        if (userId && customerId) {
          await admin.from("subscription_records").upsert({
            user_id: userId,
            stripe_customer_id: customerId,
            stripe_subscription_id: subscriptionId,
            status: "active",
          });
          await admin
            .from("profiles")
            .update({ is_subscribed: true })
            .eq("id", userId);
        }
      }
    }

    if (
      event.type === "customer.subscription.created" ||
      event.type === "customer.subscription.updated" ||
      event.type === "customer.subscription.deleted"
    ) {
      const subscription = (event.data as Record<string, unknown>).object as Record<string, unknown>;
      const customerId = String(subscription.customer ?? "");
      const subscriptionId = String(subscription.id ?? "");
      const status = String(subscription.status ?? "incomplete");
      const currentPeriodEnd = Number(subscription.current_period_end ?? 0);
      const active = status === "active" || status === "trialing";
      const { data: record } = await admin
        .from("subscription_records")
        .select("user_id")
        .eq("stripe_customer_id", customerId)
        .maybeSingle();
      const userId = String(
        record?.user_id ??
          (subscription.metadata as Record<string, unknown> | undefined)?.user_id ??
          "",
      );
      if (userId && customerId) {
        await admin.from("subscription_records").upsert({
          user_id: userId,
          stripe_customer_id: customerId,
          stripe_subscription_id: subscriptionId,
          status,
          current_period_end: currentPeriodEnd > 0
            ? new Date(currentPeriodEnd * 1000).toISOString()
            : null,
        });
        await admin
          .from("profiles")
          .update({ is_subscribed: active })
          .eq("id", userId);
      }
    }

    if (event.type === "account.updated" || event.type === "v2.core.account.updated") {
      const account = (event.data as Record<string, unknown>).object as Record<string, unknown>;
      const accountId = String(account.id ?? "");
      const chargesEnabled = Boolean(account.charges_enabled);
      const payoutsEnabled = Boolean(account.payouts_enabled);
      await admin
        .from("stripe_accounts")
        .update({
          charges_enabled: chargesEnabled,
          payouts_enabled: payoutsEnabled,
          status: chargesEnabled && payoutsEnabled ? "enabled" : "restricted",
          onboarding_completed_at:
            chargesEnabled && payoutsEnabled ? new Date().toISOString() : null,
        })
        .eq("stripe_account_id", accountId);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
});

async function verifyStripeSignature(
  payload: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  const parts = Object.fromEntries(
    signature.split(",").map((part) => {
      const [key, value] = part.split("=");
      return [key, value];
    }),
  );
  const timestamp = parts.t;
  const expected = parts.v1;
  if (!timestamp || !expected) return false;
  const signedPayload = `${timestamp}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatureBytes = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedPayload),
  );
  return timingSafeEqual(hex(signatureBytes), expected);
}

function hex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let result = 0;
  for (let i = 0; i < left.length; i += 1) {
    result |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return result === 0;
}
