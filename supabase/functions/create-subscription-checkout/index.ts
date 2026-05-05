import { corsHeaders, jsonResponse, readJson } from "../_shared/cors.ts";
import { requireUser, supabaseAdmin } from "../_shared/supabase.ts";
import { formBody, stripeRequest } from "../_shared/stripe.ts";

type StripeCustomer = { id: string };
type CheckoutSession = { id: string; url: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  try {
    const { user } = await requireUser(req);
    const admin = supabaseAdmin();
    const priceId = Deno.env.get("STRIPE_PREMIUM_PRICE_ID") ?? "";
    if (!priceId) return jsonResponse({ error: "STRIPE_PREMIUM_PRICE_ID is not configured" }, 500);

    const body = await readJson(req);
    const successUrl = String(body.successUrl ?? Deno.env.get("CRASH_APP_ORIGIN") ?? "");
    const cancelUrl = String(body.cancelUrl ?? successUrl);

    const { data: profile } = await admin
      .from("profiles")
      .select("id,email,first_name,last_name")
      .eq("id", user.id)
      .single();
    if (!profile) return jsonResponse({ error: "Profile not found" }, 404);

    const { data: existing } = await admin
      .from("subscription_records")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();

    let customerId = existing?.stripe_customer_id as string | undefined;
    if (!customerId) {
      const customer = await stripeRequest<StripeCustomer>("/v1/customers", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        idempotencyKey: `premium-customer-${user.id}`,
        body: formBody({
          email: profile.email,
          name: `${profile.first_name} ${profile.last_name}`.trim(),
          "metadata[user_id]": user.id,
        }),
      });
      customerId = customer.id;
      await admin.from("subscription_records").upsert({
        user_id: user.id,
        stripe_customer_id: customerId,
        status: "incomplete",
      });
    }

    const session = await stripeRequest<CheckoutSession>("/v1/checkout/sessions", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      idempotencyKey: `premium-subscription-checkout-${user.id}`,
      body: formBody({
        mode: "subscription",
        success_url: successUrl,
        cancel_url: cancelUrl,
        customer: customerId,
        client_reference_id: user.id,
        "metadata[user_id]": user.id,
        "metadata[purpose]": "premium_subscription",
        "subscription_data[metadata][user_id]": user.id,
        "line_items[0][quantity]": 1,
        "line_items[0][price]": priceId,
      }),
    });

    return jsonResponse({ url: session.url, sessionId: session.id });
  } catch (error) {
    if (error instanceof Response) return error;
    return jsonResponse({ error: String(error) }, 500);
  }
});
