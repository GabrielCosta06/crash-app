import { corsHeaders, jsonResponse, readJson } from "../_shared/cors.ts";
import { requireUser, supabaseAdmin } from "../_shared/supabase.ts";
import { formBody, stripeRequest } from "../_shared/stripe.ts";

type BillingPortalSession = { url: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  try {
    const { user } = await requireUser(req);
    const admin = supabaseAdmin();
    const body = await readJson(req);
    const returnUrl = String(body.returnUrl ?? Deno.env.get("CRASH_APP_ORIGIN") ?? "");

    const { data: subscription } = await admin
      .from("subscription_records")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();
    if (!subscription?.stripe_customer_id) {
      return jsonResponse({ error: "No Stripe customer is linked to this account" }, 404);
    }

    const session = await stripeRequest<BillingPortalSession>(
      "/v1/billing_portal/sessions",
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: formBody({
          customer: subscription.stripe_customer_id,
          return_url: returnUrl,
        }),
      },
    );

    return jsonResponse({ url: session.url });
  } catch (error) {
    if (error instanceof Response) return error;
    return jsonResponse({ error: String(error) }, 500);
  }
});
