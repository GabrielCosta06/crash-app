export const stripeApiVersion = "2026-02-25.clover";

export async function stripeRequest<T>(
  path: string,
  init: RequestInit & { idempotencyKey?: string } = {},
): Promise<T> {
  const secretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secretKey) throw new Error("STRIPE_SECRET_KEY is not configured");

  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${secretKey}`);
  headers.set("Stripe-Version", stripeApiVersion);
  if (init.idempotencyKey) {
    headers.set("Idempotency-Key", init.idempotencyKey);
  }

  const response = await fetch(`https://api.stripe.com${path}`, {
    ...init,
    headers,
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      typeof body?.error?.message === "string"
        ? body.error.message
        : `Stripe request failed: ${response.status}`,
    );
  }
  return body as T;
}

export function formBody(params: Record<string, string | number | boolean>) {
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    body.set(key, String(value));
  }
  return body;
}

export function dollarsToCents(value: unknown): number {
  const amount = typeof value === "number" ? value : Number(value ?? 0);
  return Math.round(amount * 100);
}

export function platformFeeCents(amountCents: number, feeRate: number): number {
  return Math.round(amountCents * feeRate);
}
