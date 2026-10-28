import { test } from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { createCommerceHandler } from "../trainer-commerce/handler.ts";
import {
  cancelsAtPaidPeriodEnd,
  paidPeriod,
  PlatformCheckout,
} from "../_shared/trainer_commerce/platform_checkout.ts";
import {
  type StripeCheckoutBinding,
  StripeSandboxCheckout,
} from "../_shared/trainer_commerce/stripe_sandbox.ts";
const now = 1793218402;
const order = "9d50b521-de26-48b0-8da7-d1fd3e85a661";
const owner = "9d50b521-de26-48b0-8da7-d1fd3e85a662";
const httpConfig = {
  url: "https://sxbxfjqgoddzhtcyhalw.supabase.co",
  anonKey: "Fixture",
  serviceKey: "Fixture",
  stripeKey: "rk_test_Fixture",
  webhookSecret: "whsec_Fixture",
  portalId: "bpc_Fixture",
  enabled: true,
};
const context = {
  provider: "stripe",
  environment: { mode: "sandbox" as const, namespace: "entrenaop-dev" },
  circuit: "platform_access" as const,
  accountId: "acct_Fixture",
  sellerId: "acct_Fixture",
  buyerId: owner,
  contractId: order,
};
const binding: StripeCheckoutBinding = {
  command: {
    id: order,
    context,
    actorId: owner,
    expectedRevision: 0,
    offer: {
      id: "offer",
      version: 1,
      circuit: "platform_access",
      sellerId: "acct_Fixture",
      price: { minorUnits: 100, currency: "EUR" },
      capacity: 5,
      termsVersion: "sandbox-v1",
    },
  },
  priceId: "price_Fixture",
  customerId: "cus_Fixture",
  interval: "month",
  preparedAtSeconds: now,
  applicationFeePercent: null,
};

test("la baja del portal flexible se reconoce solo al final del periodo pagado", () => {
  const end = now + 30 * 86400;
  const paidUntil = new Date(end * 1000).toISOString();
  assert.equal(
    cancelsAtPaidPeriodEnd({ cancel_at_period_end: true }, paidUntil, now),
    true,
  );
  assert.equal(
    cancelsAtPaidPeriodEnd(
      { cancel_at_period_end: false, cancel_at: end },
      paidUntil,
      now,
    ),
    true,
  );
  assert.equal(
    cancelsAtPaidPeriodEnd({ cancel_at: end - 86400 }, paidUntil, now),
    false,
  );
  assert.equal(
    cancelsAtPaidPeriodEnd({ cancel_at: null }, paidUntil, now),
    false,
  );
  assert.equal(cancelsAtPaidPeriodEnd({ cancel_at: end }, null, now), false);
  assert.equal(
    cancelsAtPaidPeriodEnd({ cancel_at: end }, paidUntil, end + 1),
    false,
  );
});
function fixture() {
  const subscription = {
    id: "sub_Fixture",
    livemode: false,
    customer: "cus_Fixture",
    latest_invoice: "in_Fixture",
    items: {
      has_more: false,
      data: [{
        id: "si_Fixture",
        quantity: 1,
        price: { id: "price_Fixture", currency: "eur", unit_amount: 100 },
      }],
    },
  };
  const invoice = {
    id: "in_Fixture",
    livemode: false,
    customer: "cus_Fixture",
    currency: "eur",
    parent: { subscription_details: { subscription: "sub_Fixture" } },
    status: "paid",
    amount_due: 100,
    amount_paid: 100,
    amount_remaining: 0,
    amount_paid_off_stripe: 0,
    payments: {
      has_more: false,
      data: [{
        invoice: "in_Fixture",
        status: "paid",
        currency: "eur",
        amount_paid: 100,
        payment: {
          type: "payment_intent",
          payment_intent: {
            id: "pi_Fixture",
            livemode: false,
            status: "succeeded",
            customer: "cus_Fixture",
            currency: "eur",
            amount_received: 100,
          },
        },
      }],
    },
    starting_balance: 0,
    ending_balance: 0,
    lines: {
      has_more: false,
      data: [{
        amount: 100,
        quantity: 1,
        parent: {
          subscription_item_details: {
            subscription_item: "si_Fixture",
            proration: false,
          },
        },
        pricing: { price_details: { price: "price_Fixture" } },
        period: { start: now - 60, end: now + 30 * 86400 },
      }],
    },
  };
  return { subscription, invoice };
}
test("solo el recibo pagado de la suscripción, comprador y precio enlazados acredita el periodo", () => {
  const { subscription, invoice } = fixture();
  assert.equal(
    paidPeriod(subscription, invoice, binding, now)?.invoiceId,
    "in_Fixture",
  );
  for (
    const change of [
      { customer: "cus_Other" },
      { livemode: true },
      { id: "in_Other" },
      { amount_paid: 0 },
      { starting_balance: -100 },
      { amount_paid_off_stripe: 100 },
      { payments: { has_more: false, data: [] } },
      { payments: { has_more: true, data: [] } },
      {
        payments: {
          has_more: false,
          data: [{ payment: { type: "payment_record", payment_intent: {} } }],
        },
      },
    ]
  ) {
    assert.throws(() =>
      paidPeriod(subscription, { ...invoice, ...change }, binding, now)
    );
  }
  assert.equal(
    paidPeriod(
      subscription,
      { ...invoice, status: "open" },
      binding,
      now,
    ),
    null,
  );
});
test("rechaza líneas parciales, prorrateos, precios ajenos y fechas inventadas", () => {
  const { subscription, invoice } = fixture();
  const line = invoice.lines.data[0];
  const edits = [
    { quantity: 2 },
    { amount: 50 },
    { pricing: { price_details: { price: "price_Other" } } },
    {
      parent: {
        subscription_item_details: {
          subscription_item: "si_Fixture",
          proration: true,
        },
      },
    },
    { period: { start: now + 999, end: now + 86400 } },
    { period: { start: now, end: now + 400 * 86400 } },
  ];
  for (const change of edits) {
    assert.throws(() =>
      paidPeriod(
        subscription,
        {
          ...invoice,
          lines: { has_more: false, data: [{ ...line, ...change }] },
        },
        binding,
        now,
      )
    );
  }
  assert.throws(() =>
    paidPeriod(
      subscription,
      { ...invoice, lines: { has_more: true, data: [line] } },
      binding,
      now,
    )
  );
});
test("una cuenta ajena no usa ni libera recursos de Stripe y su lease se cierra", async () => {
  const calls: string[] = [];
  const stripe = new StripeSandboxCheckout({
    secretKey: "rk_test_Fixture",
    platformAccountId: "acct_Fixture",
    namespace: "entrenaop-dev",
    returnUrl: "https://trainer.entrenaop.es/#/subscription",
  }, async () => {
    throw new Error("No debe llamar a Stripe");
  });
  const rpc = async (action: string) => {
    calls.push(action);
    return action === "claim"
      ? { id: order, owner_id: owner, lease: "lease" }
      : {};
  };
  await assert.rejects(
    new PlatformCheckout(stripe, rpc, "acct_Fixture").run(order, {
      userId: "other",
      mfa: true,
    }, "checkout"),
  );
  assert.deepEqual(calls, ["claim", "release"]);
});
test("sin Customer guardado después de la ventana incierta cierra el pedido sin crear Checkout", async () => {
  let requests = 0;
  const stripe = new StripeSandboxCheckout({
    secretKey: "rk_test_Fixture",
    platformAccountId: "acct_Fixture",
    namespace: "entrenaop-dev",
    returnUrl: "https://trainer.entrenaop.es/#/subscription",
  }, async () => {
    requests++;
    throw Error();
  });
  const rpc = async (action: string) =>
    action === "claim"
      ? {
        id: order,
        owner_id: owner,
        lease: "lease",
        created_at: new Date((now - 21 * 3600) * 1000).toISOString(),
        offer: {
          id: "offer",
          version: 1,
          amount: 100,
          currency: "EUR",
          capacity: 5,
          price_id: "price_Fixture",
          interval: "month",
        },
      }
      : {};
  const result = await new PlatformCheckout(
    stripe,
    rpc,
    "acct_Fixture",
    () => now,
  ).run(order, {
    userId: owner,
    mfa: true,
  }, "checkout");
  assert.equal(result.state, "expired");
  assert.equal(requests, 0);
});

test("HTTP no consulta al proveedor sin sesión, desde otro origen o fuera del proyecto Dev", async () => {
  let calls = 0;
  const fetcher = async () => {
    calls++;
    throw Error("No debe consultar");
  };
  const make = (origin?: string) =>
    new Request(httpConfig.url + "/functions/v1/trainer-commerce", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(origin ? { Origin: origin } : {}),
      },
      body: JSON.stringify({ action: "checkout" }),
    });
  assert.equal(
    (await createCommerceHandler(httpConfig, fetcher)(make())).status,
    403,
  );
  assert.equal(
    (await createCommerceHandler(httpConfig, fetcher)(
      make("https://unrelated.invalid"),
    )).status,
    403,
  );
  assert.equal(
    (await createCommerceHandler({
      ...httpConfig,
      url: "https://other.supabase.co",
    }, fetcher)(make())).status,
    503,
  );
  assert.equal(calls, 0);
});

test("HTTP comprueba MFA real del usuario antes de preparar cualquier pedido", async () => {
  const calls: string[] = [];
  const fetcher: typeof fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    return Response.json(
      url.endsWith("/auth/v1/user")
        ? {
          id: owner,
          email_confirmed_at: "2026-10-28T12:00:00Z",
          is_anonymous: false,
        }
        : false,
    );
  };
  const response = await createCommerceHandler(httpConfig, fetcher)(
    new Request(httpConfig.url + "/functions/v1/trainer-commerce", {
      method: "POST",
      headers: { Authorization: "Bearer Fixture" },
      body: JSON.stringify({ action: "checkout", offer_id: order }),
    }),
  );
  assert.equal(response.status, 403);
  assert.equal((await response.json()).error, "mfa_required");
  assert.equal(calls.length, 2);
  assert.ok(calls[1].endsWith("/rpc/get_trainer_security_status"));
});

test("HTTP rechaza un webhook sin firma antes de escribir el ledger", async () => {
  let calls = 0;
  const handler = createCommerceHandler(httpConfig, async () => {
    calls++;
    throw Error();
  });
  const response = await handler(
    new Request(httpConfig.url + "/functions/v1/trainer-commerce/webhook", {
      method: "POST",
      body: "{}",
    }),
  );
  assert.equal(response.status, 503);
  assert.equal(calls, 0);
});

test("un webhook firmado ya completado no relee Stripe ni vuelve a conceder acceso", async () => {
  const calls: string[] = [];
  const fetcher: typeof fetch = async (input) => {
    calls.push(String(input));
    return Response.json({ done: true });
  };
  const timestamp = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({
    id: "evt_Fixture",
    type: "invoice.paid",
    api_version: "2026-09-30.endive",
    livemode: false,
    data: { object: { id: "in_Fixture" } },
  });
  const signature = createHmac("sha256", httpConfig.webhookSecret).update(
    `${timestamp}.${body}`,
  ).digest("hex");
  const response = await createCommerceHandler(httpConfig, fetcher)(
    new Request(httpConfig.url + "/functions/v1/trainer-commerce/webhook", {
      method: "POST",
      headers: { "Stripe-Signature": `t=${timestamp},v1=${signature}` },
      body,
    }),
  );
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.ok(calls[0].endsWith("/rpc/trainer_commerce_server"));
});
