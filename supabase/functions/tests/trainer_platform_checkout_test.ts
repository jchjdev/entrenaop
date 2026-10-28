import { test } from "node:test";
import assert from "node:assert/strict";
import {
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
