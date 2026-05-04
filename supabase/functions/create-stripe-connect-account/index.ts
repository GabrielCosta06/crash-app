import { corsHeaders, jsonResponse, readJson } from "../_shared/cors.ts";
import { requireUser, supabaseAdmin } from "../_shared/supabase.ts";
import { stripeRequest } from "../_shared/stripe.ts";

type StripeAccount = { id: string };
type StripeAccountLink = { url: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  try {
    const { user } = await requireUser(req);
    const admin = supabaseAdmin();
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id,email,first_name,last_name,user_type")
      .eq("id", user.id)
      .single();
    if (profileError || !profile || profile.user_type !== "owner") {
      return jsonResponse({ error: "Only owners can connect payouts" }, 403);
    }

    const body = await readJson(req);
    const returnUrl = String(body.returnUrl ?? Deno.env.get("CRASH_APP_ORIGIN") ?? "");
    const refreshUrl = String(body.refreshUrl ?? returnUrl);

    const { data: existing } = await admin
      .from("stripe_accounts")
      .select("stripe_account_id")
      .eq("owner_id", user.id)
      .maybeSingle();

    let accountId = existing?.stripe_account_id as string | undefined;
    if (!accountId) {
      const account = await stripeRequest<StripeAccount>("/v2/core/accounts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        idempotencyKey: `owner-account-${user.id}`,
        body: JSON.stringify({
          contact_email: profile.email,
          display_name: `${profile.first_name} ${profile.last_name}`.trim(),
          identity: { country: "US" },
          configuration: {
            merchant: {
              capabilities: {
                card_payments: { requested: true },
                transfers: { requested: true },
              },
            },
            recipient: { capabilities: { transfers: { requested: true } } },
          },
          dashboard: { type: "express" },
          defaults: {
            responsibilities: {
              losses_collector: "stripe",
              fees_collector: "application",
            },
          },
        }),
      });
      accountId = account.id;
      await admin.from("stripe_accounts").upsert({
        owner_id: user.id,
        stripe_account_id: accountId,
        status: "onboarding",
      });
    }

    const link = await stripeRequest<StripeAccountLink>("/v2/core/account_links", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      idempotencyKey: `owner-onboarding-${user.id}-${Date.now()}`,
      body: JSON.stringify({
        account: accountId,
        use_case: {
          type: "account_onboarding",
          account_onboarding: {
            return_url: returnUrl,
            refresh_url: refreshUrl,
          },
        },
      }),
    });

    return jsonResponse({ url: link.url, accountId });
  } catch (error) {
    if (error instanceof Response) return error;
    return jsonResponse({ error: String(error) }, 500);
  }
});
