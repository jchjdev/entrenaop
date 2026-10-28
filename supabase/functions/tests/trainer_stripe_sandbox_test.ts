import { test } from "node:test";
import assert from "node:assert/strict";
import {
  stripeApiVersion,
  StripeSandboxCheckout,
  verifyStripeSandboxSignal,
} from "../_shared/trainer_commerce/stripe_sandbox.ts";
import type {
  StripeCheckoutBinding,
  StripeSandboxConfig,
} from "../_shared/trainer_commerce/stripe_sandbox.ts";
import type { Actor, Circuit } from "../_shared/trainer_commerce/model.ts";

// Solo fixtures: no son precios, comisiones ni productos publicados.
const now = 1_800_000_000;
const config: StripeSandboxConfig = {
  secretKey: "sk_test_fixture",
  platformAccountId: "acct_platform",
  namespace: "entrenaop-dev",
  returnUrl: "https://trainer.entrenaop.es/#/subscription",
};
const actor: Actor = { userId: "buyer", mfa: true };
function fixture(circuit: Circuit = "platform_access") {
  const binding: StripeCheckoutBinding = {
    command: {
      id: "10000000-0000-4000-8000-000000000001",
      actorId: "buyer",
      expectedRevision: 0,
      context: {
        provider: "stripe",
        environment: { mode: "sandbox", namespace: "entrenaop-dev" },
        circuit,
        accountId: circuit === "platform_access"
          ? "acct_platform"
          : "acct_coach",
        sellerId: circuit === "platform_access" ? "platform" : "coach",
        buyerId: "buyer",
        contractId: "contract",
      },
      offer: {
        id: "offer",
        version: 1,
        circuit,
        sellerId: circuit === "platform_access" ? "platform" : "coach",
        price: { minorUnits: 1000, currency: "EUR" },
        capacity: circuit === "platform_access" ? 5 : null,
        termsVersion: "fixture-v1",
      },
    },
    priceId: "price_fixture",
    customerId: "cus_fixture",
    interval: "month",
    preparedAtSeconds: now,
    applicationFeePercent: circuit === "platform_access" ? null : 0,
  };
  const metadata = {
    eop_namespace: "entrenaop-dev",
    eop_circuit: circuit,
    eop_buyer: "buyer",
    eop_seller: binding.command.context.sellerId,
    eop_contract: "contract",
    eop_order: binding.command.id,
    eop_offer: "offer",
    eop_offer_version: "1",
  };
  const merchant = {
    id: binding.command.context.accountId,
    charges_enabled: true,
    payouts_enabled: true,
  };
  const price = {
    id: "price_fixture",
    active: true,
    livemode: false,
    unit_amount: 1000,
    currency: "eur",
    recurring: { interval: "month", interval_count: 1, usage_type: "licensed" },
  };
  const customer = {
    id: "cus_fixture",
    livemode: false,
    metadata: { eop_buyer: "buyer", eop_namespace: "entrenaop-dev" },
  };
  const checkout = {
    id: "cs_test_fixture",
    object: "checkout.session",
    livemode: false,
    mode: "subscription",
    metadata,
    client_reference_id: binding.command.id,
    customer: "cus_fixture",
    currency: "eur",
    status: "open",
    payment_status: "unpaid",
    subscription: null,
    url: "https://checkout.stripe.com/c/pay/cs_test_fixture",
  };
  const requests: { url: string; init: RequestInit }[] = [];
  let failPost = false;
  let responseOverride: Response | null = null;
  const fetcher: typeof fetch = async (input, init = {}) => {
    const url = String(input);
    requests.push({ url, init });
    if (responseOverride) return responseOverride.clone();
    if (failPost && init.method === "POST") throw new Error("timeout");
    const result = url.endsWith("/account")
      ? merchant
      : url.includes("/prices/")
      ? price
      : url.includes("/customers/")
      ? customer
      : checkout;
    return new Response(JSON.stringify(result), { status: 200 });
  };
  return {
    binding,
    merchant,
    price,
    customer,
    checkout,
    requests,
    client: new StripeSandboxCheckout(config, fetcher, () => now),
    failPost: () => {
      failPost = true;
    },
    response: (value: Response) => {
      responseOverride = value;
    },
  };
}

for (const circuit of ["platform_access", "coach_service"] as const) {
  test(`Checkout ${circuit} usa cuenta, precio, comprador e idempotencia fijados`, async () => {
    const f = fixture(circuit);
    const result = await f.client.create(f.binding, actor);
    assert.equal(result.id, "cs_test_fixture");
    assert.equal(result.paymentStatus, "unpaid");
    assert.equal(f.requests.length, 4);
    for (const request of f.requests) {
      const headers = new Headers(request.init.headers);
      assert.equal(headers.get("Stripe-Version"), stripeApiVersion);
      assert.equal(
        headers.get("Stripe-Account"),
        circuit === "coach_service" ? "acct_coach" : null,
      );
      assert.equal(request.init.redirect, "error");
      assert.equal(new URL(request.url).origin, "https://api.stripe.com");
    }
    const last = f.requests.at(-1)!;
    const fields = new URLSearchParams(String(last.init.body));
    assert.equal(fields.get("mode"), "subscription");
    assert.equal(fields.get("line_items[0][price]"), "price_fixture");
    assert.equal(fields.get("line_items[0][price_data][unit_amount]"), null);
    assert.equal(fields.get("customer"), "cus_fixture");
    assert.equal(fields.get("subscription_data[metadata][eop_buyer]"), "buyer");
    assert.equal(
      fields.get("subscription_data[application_fee_percent]"),
      circuit === "coach_service" ? "0" : null,
    );
    assert.equal(
      new Headers(last.init.headers).get("Idempotency-Key"),
      `entrenaop-dev:${f.binding.command.context.accountId}:${circuit}:${f.binding.command.id}`,
    );
    await f.client.create(f.binding, actor);
    assert.equal(
      new Headers(f.requests.at(-1)!.init.headers).get("Idempotency-Key"),
      new Headers(last.init.headers).get("Idempotency-Key"),
    );
  });
}

test("rechaza producción, clave live, retorno ajeno y cruce de cuentas antes de llamar", async () => {
  for (
    const change of [
      { secretKey: "sk_live_fixture" },
      { namespace: "production" },
      { returnUrl: "https://evil.invalid/" },
    ]
  ) assert.throws(() => new StripeSandboxCheckout({ ...config, ...change }));
  for (
    const change of [
      (f: ReturnType<typeof fixture>) => {
        f.binding.command.context.environment.mode = "live";
      },
      (f: ReturnType<typeof fixture>) => {
        f.binding.command.context.accountId = "acct_coach";
      },
      (f: ReturnType<typeof fixture>) => {
        f.binding.command.context.buyerId = "other";
      },
      (f: ReturnType<typeof fixture>) => {
        f.binding.customerId = "cus_bad/../../account";
      },
    ]
  ) {
    const f = fixture();
    change(f);
    await assert.rejects(f.client.create(f.binding, actor));
    assert.equal(f.requests.length, 0);
  }
  const f = fixture();
  await assert.rejects(f.client.create(f.binding, { ...actor, mfa: false }));
  assert.equal(f.requests.length, 0);
});

test("validación canónica rechaza comercio, comprador, moneda, importe o periodicidad distintos", async () => {
  for (
    const change of [
      (f: ReturnType<typeof fixture>) => {
        f.merchant.id = "acct_other";
      },
      (f: ReturnType<typeof fixture>) => {
        f.price.unit_amount = 1;
      },
      (f: ReturnType<typeof fixture>) => {
        f.price.currency = "usd";
      },
      (f: ReturnType<typeof fixture>) => {
        f.price.recurring.interval = "year";
      },
      (f: ReturnType<typeof fixture>) => {
        f.price.recurring.usage_type = "metered";
      },
      (f: ReturnType<typeof fixture>) => {
        f.price.active = false;
      },
      (f: ReturnType<typeof fixture>) => {
        f.price.livemode = true;
      },
      (f: ReturnType<typeof fixture>) => {
        f.customer.metadata.eop_buyer = "other";
      },
      (f: ReturnType<typeof fixture>) => {
        f.customer.livemode = true;
      },
    ]
  ) {
    const f = fixture();
    change(f);
    await assert.rejects(f.client.create(f.binding, actor));
    assert.ok(!f.requests.some((r) => r.init.method === "POST"));
  }
  const f = fixture("coach_service");
  f.merchant.payouts_enabled = false;
  await assert.rejects(f.client.create(f.binding, actor));
  assert.ok(!f.requests.some((r) => r.init.method === "POST"));
});

test("una comisión pendiente no se convierte en cero y una operación incierta antigua no se recobra", async () => {
  const f = fixture("coach_service");
  f.binding.applicationFeePercent = null;
  await assert.rejects(f.client.create(f.binding, actor));
  assert.equal(f.requests.length, 0);
  const old = fixture();
  old.binding.preparedAtSeconds -= 20 * 3600;
  await assert.rejects(old.client.create(old.binding, actor));
  assert.equal(old.requests.length, 0);
});

test("timeout no provoca reintentos invisibles, y recuperar sesión valida titular y metadata", async () => {
  const f = fixture();
  f.failPost();
  await assert.rejects(f.client.create(f.binding, actor));
  assert.equal(f.requests.filter((r) => r.init.method === "POST").length, 1);
  const recovered = await f.client.read(f.binding, actor, "cs_test_fixture");
  assert.equal(recovered.status, "open");
  f.checkout.metadata.eop_buyer = "other";
  await assert.rejects(f.client.read(f.binding, actor, "cs_test_fixture"));
  const before = f.requests.length;
  await assert.rejects(f.client.read(f.binding, actor, "cs_live_other"));
  assert.equal(f.requests.length, before);
});

test("pago devuelto por Checkout no concede acceso y solo acepta destinos del proveedor", async () => {
  const f = fixture();
  Object.assign(f.checkout, {
    status: "complete",
    payment_status: "paid",
    subscription: "sub_fixture",
    url: null,
  });
  const result = await f.client.read(f.binding, actor, "cs_test_fixture");
  assert.equal(result.paymentStatus, "paid");
  assert.equal(result.subscriptionId, "sub_fixture");
  assert.equal(Object.hasOwn(result, "access"), false);
  for (
    const uri of [
      "https://evil.invalid/pay",
      "http://checkout.stripe.com/pay",
      "https://evil@checkout.stripe.com/pay",
    ]
  ) {
    const invalid = fixture();
    invalid.checkout.url = uri;
    await assert.rejects(
      invalid.client.read(invalid.binding, actor, "cs_test_fixture"),
    );
  }
});

test("acota respuestas del proveedor y no devuelve su error privado", async () => {
  const f = fixture();
  f.response(new Response("private-account-data", { status: 400 }));
  await assert.rejects(
    f.client.create(f.binding, actor),
    (error: Error) => !error.message.includes("private-account-data"),
  );
  const big = fixture();
  big.response(new Response("a".repeat(262145)));
  await assert.rejects(
    big.client.create(big.binding, actor),
    /stripe_response_too_large/,
  );
  const broken = fixture();
  broken.response(new Response("PRIVATE invalid json"));
  await assert.rejects(
    broken.client.create(broken.binding, actor),
    (error: Error) => !error.message.includes("PRIVATE"),
  );
});

const secret = "whsec_fixture";
const event = {
  id: "evt_fixture",
  type: "checkout.session.completed",
  api_version: stripeApiVersion,
  livemode: false,
  data: { object: { id: "cs_test_fixture" } },
};
async function signed(body: string, timestamp = now) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const proof = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      encoder.encode(`${timestamp}.${body}`),
    ),
  );
  return `t=${timestamp},v1=${
    Array.from(proof, (value) => value.toString(16).padStart(2, "0")).join("")
  }`;
}
async function verify(body: string, signature?: string) {
  return verifyStripeSandboxSignal({
    body,
    signature: signature ?? await signed(body),
    secret,
    platformAccountId: "acct_platform",
    nowSeconds: now,
  });
}
test("webhook HMAC conserva cuenta conectada y devuelve señal, no derechos", async () => {
  assert.deepEqual(await verify(JSON.stringify(event)), {
    eventId: "evt_fixture",
    type: "checkout.session.completed",
    accountId: "acct_platform",
    objectId: "cs_test_fixture",
  });
  const body = JSON.stringify({ ...event, account: "acct_coach" });
  assert.equal((await verify(body)).accountId, "acct_coach");
  const signature = await signed(body);
  assert.equal(
    (await verify(body, `v1=${"0".repeat(64)},${signature}`)).eventId,
    "evt_fixture",
  );
});
test("rechaza cuerpo alterado, replay antiguo, firma ajena, evento live y versión imprevista", async () => {
  const body = JSON.stringify(event);
  await assert.rejects(verify(`${body} `, await signed(body)));
  await assert.rejects(verify(body, await signed(body, now - 301)));
  await assert.rejects(verify(body, `t=${now},v1=${"0".repeat(64)}`));
  await assert.rejects(verify(body, `${await signed(body)},t=${now}`));
  await assert.rejects(verify(JSON.stringify({ ...event, livemode: true })));
  await assert.rejects(
    verify(JSON.stringify({ ...event, api_version: "other" })),
  );
});
