import { test } from "node:test";
import assert from "node:assert/strict";
import {
  prorationTotal,
  paidUpgrade,
  SubscriptionChanges,
} from "../_shared/trainer_commerce/subscription_changes.ts";
import {
  StripeSandboxCheckout,
  type StripeCheckoutBinding,
} from "../_shared/trainer_commerce/stripe_sandbox.ts";

const now = 1793600000,
  end = now + 15 * 86400;
const original = {
  id: "offer-old",
  price_id: "price_Old",
  amount: 1200,
  currency: "EUR",
  interval: "month",
  capacity: 5,
};
const target = {
  id: "offer-new",
  price_id: "price_New",
  amount: 2400,
  currency: "EUR",
  interval: "month",
  capacity: 10,
};
function change(state = "quoted", kind = "immediate"): Record<string, unknown> {
  return {
    id: "change-a",
    from_offer: original,
    offer: target,
    kind,
    state,
    amount: 600,
    item_id: "si_Fixture",
    proration_at: now,
    effective_at: new Date(end * 1000).toISOString(),
    quoted_at: new Date(now * 1000).toISOString(),
  };
}
function subscription(price = "price_New"): Record<string, unknown> {
  return {
    id: "sub_Fixture",
    livemode: false,
    customer: "cus_Fixture",
    status: "active",
    collection_method: "charge_automatically",
    pending_update: null,
    schedule: null,
    latest_invoice: "in_Change",
    cancel_at_period_end: false,
    items: {
      has_more: false,
      data: [
        {
          id: "si_Fixture",
          quantity: 1,
          current_period_start: now - 15 * 86400,
          current_period_end: end,
          price: { id: price },
        },
      ],
    },
  };
}
function invoice(paid = true): Record<string, any> {
  const line = (price: string, amount: number) => ({
    amount,
    currency: "eur",
    quantity: 1,
    discount_amounts: [],
    taxes: [],
    period: { start: now, end },
    parent: {
      subscription_item_details: {
        subscription: "sub_Fixture",
        subscription_item: "si_Fixture",
        proration: true,
      },
    },
    pricing: { price_details: { price } },
  });
  return {
    id: "in_Change",
    livemode: false,
    customer: "cus_Fixture",
    currency: "eur",
    billing_reason: "subscription_update",
    parent: { subscription_details: { subscription: "sub_Fixture" } },
    starting_balance: 0,
    ending_balance: 0,
    total: 600,
    amount_due: 600,
    status: paid ? "paid" : "open",
    amount_paid: paid ? 600 : 0,
    amount_remaining: paid ? 0 : 600,
    amount_paid_off_stripe: 0,
    hosted_invoice_url: "https://invoice.stripe.com/i/test_fixture",
    lines: {
      has_more: false,
      data: [line("price_Old", -600), line("price_New", 1200)],
    },
    payments: {
      has_more: false,
      data: paid
        ? [
            {
              invoice: "in_Change",
              status: "paid",
              currency: "eur",
              amount_paid: 600,
              payment: {
                type: "payment_intent",
                payment_intent: {
                  id: "pi_Fixture",
                  livemode: false,
                  status: "succeeded",
                  customer: "cus_Fixture",
                  currency: "eur",
                  amount_received: 600,
                },
              },
            },
          ]
        : [],
    },
  };
}
const binding: StripeCheckoutBinding = {
  command: {
    id: "9d50b521-de26-48b0-8da7-d1fd3e85a661",
    actorId: "owner",
    expectedRevision: 0,
    context: {
      provider: "stripe",
      environment: { mode: "sandbox", namespace: "entrenaop-dev" },
      circuit: "platform_access",
      accountId: "acct_Fixture",
      sellerId: "acct_Fixture",
      buyerId: "owner",
      contractId: "contract",
    },
    offer: {
      id: "offer-old",
      version: 1,
      circuit: "platform_access",
      sellerId: "acct_Fixture",
      price: { minorUnits: 1200, currency: "EUR" },
      capacity: 5,
      termsVersion: "sandbox-v1",
    },
  },
  priceId: "price_Old",
  customerId: "cus_Fixture",
  interval: "month",
  preparedAtSeconds: now,
  applicationFeePercent: null,
};
function harness(
  c: Record<string, unknown>,
  responses: (path: string, fields: URLSearchParams) => unknown,
) {
  const calls: { path: string; fields: URLSearchParams; key: string | null }[] =
      [],
    writes: { action: string; data: Record<string, unknown> }[] = [];
  const stripe = new StripeSandboxCheckout(
    {
      secretKey: "rk_test_Fixture",
      platformAccountId: "acct_Fixture",
      namespace: "entrenaop-dev",
      returnUrl: "https://trainer.entrenaop.es/#/subscription",
    },
    async (url, init) => {
      const path = String(url).replace("https://api.stripe.com/v1/", "");
      const fields = new URLSearchParams(String(init?.body ?? ""));
      calls.push({
        path,
        fields,
        key: new Headers(init?.headers).get("Idempotency-Key"),
      });
      return new Response(JSON.stringify(responses(path, fields)), {
        status: 200,
      });
    },
    () => now,
  );
  const rpc = async (action: string, data: Record<string, unknown>) => {
    writes.push({ action, data });
    return {
      ...c,
      ...data,
      state: action === "change_quote" ? "quoted" : c.state,
    };
  };
  const manager = new SubscriptionChanges(
    stripe,
    rpc,
    {
      change: c,
      subscription_id: "sub_Fixture",
      paid_until: new Date(end * 1000).toISOString(),
    },
    binding,
    { id: "order", lease: "lease" },
    () => now,
  );
  return { manager, calls, writes };
}

test("calcula solo la diferencia del periodo restante, no otra mensualidad", () => {
  assert.equal(
    prorationTotal(invoice(), subscription(), change(), "cus_Fixture"),
    600,
  );
  assert.deepEqual(
    paidUpgrade(invoice(), subscription(), change(), "cus_Fixture"),
    { invoiceId: "in_Change", end: new Date(end * 1000).toISOString() },
  );
  assert.equal(
    paidUpgrade(
      invoice(false),
      subscription("price_Old"),
      change(),
      "cus_Fixture",
    ),
    null,
  );
});

test("no acredita otra cuenta, otra moneda, líneas truncadas o crédito inventado", () => {
  const mutations = [
    (i: any) => (i.customer = "cus_Other"),
    (i: any) => (i.currency = "usd"),
    (i: any) => (i.lines.has_more = true),
    (i: any) => (i.lines.data[0].amount = -700),
    (i: any) => (i.lines.data[1].pricing.price_details.price = "price_Other"),
    (i: any) =>
      (i.lines.data[1].parent.subscription_item_details.subscription_item =
        "si_Other"),
    (i: any) => i.lines.data[1].period.end++,
    (i: any) => (i.starting_balance = -1),
    (i: any) => (i.lines.data[1].taxes = [{ amount: 20 }]),
    (i: any) => (i.lines.data[1].discount_amounts = [{ amount: 10 }]),
  ];
  for (const mutate of mutations) {
    const i = invoice();
    mutate(i);
    assert.throws(() =>
      prorationTotal(i, subscription(), change(), "cus_Fixture"),
    );
  }
});

test("exige factura pagada, PaymentIntent propio y la diferencia previamente aceptada", () => {
  for (const mutate of [
    (i: any) => (i.amount_paid_off_stripe = 600),
    (i: any) =>
      (i.payments.data[0].payment.payment_intent.status = "processing"),
    (i: any) =>
      (i.payments.data[0].payment.payment_intent.customer = "cus_Other"),
    (i: any) =>
      (i.payments.data[0].payment.payment_intent.amount_received = 599),
  ]) {
    const i = invoice();
    mutate(i);
    assert.throws(() =>
      paidUpgrade(i, subscription(), change(), "cus_Fixture"),
    );
  }
  assert.throws(() =>
    paidUpgrade(
      invoice(),
      subscription(),
      { ...change(), amount: 601 },
      "cus_Fixture",
    ),
  );
});

test("preview no cobra y fija fecha, precio e importe antes de confirmar", async () => {
  const h = harness(change("prepared"), (path) =>
    path.startsWith("prices/")
      ? {
          id: "price_New",
          livemode: false,
          active: true,
          unit_amount: 2400,
          currency: "eur",
          recurring: { interval: "month" },
        }
      : invoice(),
  );
  await h.manager.quote(subscription("price_Old"), "change-a");
  assert.equal(h.calls.length, 2);
  assert.equal(h.calls[1].path, "invoices/create_preview");
  assert.equal(
    h.calls[1].fields.get("subscription_details[proration_date]"),
    String(now),
  );
  assert.equal(h.writes[0].action, "change_quote");
  assert.equal(h.writes[0].data.amount, 600);
});

test("ampliación pendiente usa idempotencia y no activa plazas sin pago", async () => {
  const pending = subscription("price_Old");
  pending.pending_update = { expires_at: now + 3600 };
  const h = harness(change(), (path) =>
    path.startsWith("subscriptions/") ? pending : invoice(false),
  );
  const result = await h.manager.confirm(
    subscription("price_Old"),
    "change-a",
    () => null,
  );
  assert.equal(result.confirmed, false);
  assert.equal(result.payment_url, "https://invoice.stripe.com/i/test_fixture");
  const update = h.calls.find((c) => c.path === "subscriptions/sub_Fixture")!;
  assert.equal(update.fields.get("payment_behavior"), "pending_if_incomplete");
  assert.equal(update.fields.get("proration_behavior"), "always_invoice");
  assert.equal(update.key, "entrenaop-dev:change:change-a:update");
  assert.equal(
    h.writes.some((w) => w.action === "change_apply"),
    false,
  );
});

test("la confirmación de pago aplica la cobertura sin extender el periodo original", async () => {
  const h = harness(change(), (path) =>
    path.startsWith("subscriptions/") ? subscription() : invoice(),
  );
  const result = await h.manager.confirm(
    subscription("price_Old"),
    "change-a",
    () => null,
  );
  assert.equal(result.confirmed, true);
  assert.equal(
    h.writes.find((w) => w.action === "change_apply")!.data.paid_until,
    new Date(end * 1000).toISOString(),
  );
});

test("reducción programa dos fases sin cobrar ahora ni activar el cupo futuro", async () => {
  const c = change("quoted", "renewal");
  c.amount = 0;
  const schedule = {
    id: "sub_sched_Fixture",
    livemode: false,
    customer: "cus_Fixture",
    subscription: "sub_Fixture",
    current_phase: { start_date: now - 15 * 86400, end_date: end },
  };
  const h = harness(c, (path, fields) => {
    if (path === "subscription_schedules" || !fields.has("end_behavior"))
      return schedule;
    return {
      ...schedule,
      end_behavior: "release",
      phases: [
        { start_date: now - 15 * 86400, end_date: end },
        { start_date: end, items: [{ price: "price_New", quantity: 1 }] },
      ],
    };
  });
  const result = await h.manager.confirm(
    subscription("price_Old"),
    "change-a",
    () => null,
  );
  assert.equal(result.state, "scheduled");
  const update = h.calls.find((x) => x.fields.has("phases[1][start_date]"))!;
  assert.equal(update.fields.get("phases[1][start_date]"), String(end));
  assert.equal(update.fields.get("proration_behavior"), "none");
  assert.equal(
    h.writes.some((w) => w.action === "change_apply"),
    false,
  );
});

test("no anula una operación incierta sin reconciliar el efecto en Stripe", async () => {
  const h = harness(change("processing"), () => ({
    ...invoice(),
    billing_reason: "subscription_create",
  }));
  await assert.rejects(
    () => h.manager.cancel(subscription("price_Old"), "change-a", () => null),
    /change_reconciliation_required/,
  );
  assert.equal(
    h.writes.some((w) => w.action === "change_cancel"),
    false,
  );
});

test("la renovación solo aplica el cupo nuevo cuando su factura está pagada", async () => {
  for (const paid of [false, true]) {
    const c = change("scheduled", "renewal");
    c.schedule_id = "sub_sched_Fixture";
    const h = harness(c, () => invoice(paid));
    const nextEnd = new Date((end + 30 * 86400) * 1000).toISOString();
    const result = await h.manager.reconcile(subscription(), () =>
      paid ? { invoiceId: "in_Change", end: nextEnd } : null,
    );
    assert.equal(!!result.applied, paid);
    assert.equal(
      h.writes.some((w) => w.action === "change_apply"),
      paid,
    );
    if (paid)
      assert.equal(
        h.writes.find((w) => w.action === "change_apply")!.data.paid_until,
        nextEnd,
      );
  }
});

test("recupera una anulación ya realizada en Stripe sin repetir la liberación", async () => {
  const c = change("scheduled", "renewal");
  c.schedule_id = "sub_sched_Fixture";
  const h = harness(c, (path) =>
    path.startsWith("subscriptions/")
      ? subscription("price_Old")
      : {
          id: "sub_sched_Fixture",
          livemode: false,
          customer: "cus_Fixture",
          status: "released",
          subscription: null,
          released_subscription: "sub_Fixture",
        },
  );
  assert.equal(
    (await h.manager.cancel(subscription("price_Old"), "change-a", () => null))
      .state,
    "canceled_change",
  );
  assert.equal(h.calls.length, 2);
  assert.deepEqual(
    h.writes.map((w) => w.action),
    ["change_cancel"],
  );
});

test("recupera fases confirmadas tras perder la respuesta sin volver a programarlas", async () => {
  const c = change("processing", "renewal");
  c.schedule_id = "sub_sched_Fixture";
  const h = harness(c, () => ({
    livemode: false,
    customer: "cus_Fixture",
    status: "active",
    subscription: "sub_Fixture",
    phases: [
      {},
      { start_date: end, items: [{ price: "price_New", quantity: 1 }] },
    ],
  }));
  await h.manager.reconcile(subscription("price_Old"), () => null);
  assert.deepEqual(
    h.writes.map((w) => w.action),
    ["change_scheduled"],
  );
  assert.equal(h.calls.length, 1);
});

test("si la renovación coincide con anular, conserva el nuevo periodo acreditado", async () => {
  const c = change("scheduled", "renewal");
  c.schedule_id = "sub_sched_Fixture";
  const h = harness(c, (path) =>
    path.startsWith("subscriptions/")
      ? subscription()
      : path.startsWith("invoices/")
        ? invoice()
        : {
            livemode: false,
            customer: "cus_Fixture",
            status: "released",
            subscription: null,
            released_subscription: "sub_Fixture",
          },
  );
  const nextEnd = new Date((end + 30 * 86400) * 1000).toISOString();
  const result = await h.manager.cancel(
    subscription("price_Old"),
    "change-a",
    () => ({ invoiceId: "in_Change", end: nextEnd }),
  );
  assert.equal(result.confirmed, true);
  assert.deepEqual(
    h.writes.map((w) => w.action),
    ["change_apply"],
  );
});
