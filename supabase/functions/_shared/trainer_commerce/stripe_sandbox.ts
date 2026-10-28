import { assertActor, assertOffer, integer, requireThat } from "./model.ts";
import type { Actor, Command, Context } from "./model.ts";

// Adaptador de infraestructura de pruebas. No concede acceso ni ejecuta el
// evaluador simulado como si fuera una política comercial aprobada.
export const stripeApiVersion = "2026-09-30.endive";
type Json = Record<string, unknown>;
type Fetcher = typeof fetch;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const account = /^acct_[A-Za-z0-9]+$/;
const resource = /^(price|cus)_[A-Za-z0-9]+$/;
function object(value: unknown): Json {
  requireThat(
    value !== null && typeof value === "object" && !Array.isArray(value),
    "stripe_invalid_response",
  );
  return value as Json;
}
export type StripeSandboxConfig = {
  secretKey: string;
  platformAccountId: string;
  namespace: string;
  returnUrl: string;
};
export type StripeCheckoutBinding = {
  command: Command;
  priceId: string;
  customerId: string;
  interval: "month" | "year";
  preparedAtSeconds: number;
  applicationFeePercent: number | null;
};
export type StripeCheckout = {
  id: string;
  url: string | null;
  status: "open" | "complete" | "expired";
  paymentStatus: "paid" | "unpaid" | "no_payment_required";
  subscriptionId: string | null;
};

export class StripeSandboxCheckout {
  private readonly config: StripeSandboxConfig;
  private readonly fetcher: Fetcher;
  private readonly now: () => number;
  constructor(
    config: StripeSandboxConfig,
    fetcher: Fetcher = fetch,
    now: () => number = () => Math.floor(Date.now() / 1000),
  ) {
    requireThat(
      /^(sk|rk)_test_[A-Za-z0-9]+$/.test(config.secretKey),
      "stripe_test_key_required",
    );
    requireThat(
      account.test(config.platformAccountId) &&
        config.namespace === "entrenaop-dev",
      "stripe_environment_mismatch",
    );
    // El cliente no decide el destino de retorno ni introduce una URL en la RPC.
    requireThat(
      config.returnUrl === "https://trainer.entrenaop.es/#/subscription",
      "stripe_invalid_return_url",
    );
    this.config = { ...config };
    this.fetcher = fetcher;
    this.now = now;
  }

  private scope(context: Context) {
    requireThat(
      context.provider === "stripe" && context.environment.mode === "sandbox" &&
        context.environment.namespace === this.config.namespace,
      "stripe_environment_mismatch",
    );
    requireThat(account.test(context.accountId), "stripe_invalid_account");
    requireThat(
      context.circuit === "platform_access"
        ? context.accountId === this.config.platformAccountId
        : context.accountId !== this.config.platformAccountId,
      "stripe_account_scope_mismatch",
    );
  }

  async request(
    context: Context,
    path: string,
    fields?: URLSearchParams,
    idempotency?: string,
  ): Promise<Json> {
    this.scope(context);
    const headers: Record<string, string> = {
      Authorization: `Bearer ${this.config.secretKey}`,
      "Stripe-Version": stripeApiVersion,
    };
    if (context.circuit === "coach_service") {
      headers["Stripe-Account"] = context.accountId;
    }
    if (fields) headers["Content-Type"] = "application/x-www-form-urlencoded";
    if (idempotency) headers["Idempotency-Key"] = idempotency;
    const response = await this.fetcher(`https://api.stripe.com/v1/${path}`, {
      method: fields ? "POST" : "GET",
      headers,
      body: fields,
      redirect: "error",
      signal: AbortSignal.timeout(8000),
    });
    // No propagar errores del proveedor que puedan contener datos privados.
    requireThat(response.ok, "stripe_request_failed");
    const reader = response.body?.getReader();
    requireThat(reader, "stripe_invalid_response");
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) break;
        size += next.value.length;
        requireThat(size <= 262144, "stripe_response_too_large");
        chunks.push(next.value);
      }
    } finally {
      // Una cancelación del transporte no debe dejar una operación incierta
      // bloqueada indefinidamente esperando a otro consumidor de su stream.
      void reader.cancel().catch(() => {});
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    try {
      return object(
        JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)),
      );
    } catch {
      requireThat(false, "stripe_invalid_response");
    }
  }

  private validate(binding: StripeCheckoutBinding, actor: Actor) {
    assertOffer(binding.command.offer, binding.command.context);
    assertActor(actor, binding.command);
    this.scope(binding.command.context);
    requireThat(
      uuid.test(binding.command.id) &&
        integer(binding.command.expectedRevision),
      "stripe_invalid_operation",
    );
    requireThat(
      resource.test(binding.priceId) && binding.priceId.startsWith("price_") &&
        resource.test(binding.customerId) &&
        binding.customerId.startsWith("cus_"),
      "stripe_invalid_resource",
    );
    requireThat(
      ["month", "year"].includes(binding.interval) &&
        binding.command.offer.price.minorUnits > 0,
      "stripe_invalid_price",
    );
    requireThat(integer(binding.preparedAtSeconds), "stripe_invalid_operation");
    requireThat(
      binding.command.context.circuit === "platform_access"
        ? binding.applicationFeePercent === null
        : typeof binding.applicationFeePercent === "number" &&
          Number.isFinite(binding.applicationFeePercent) &&
          binding.applicationFeePercent >= 0 &&
          binding.applicationFeePercent <= 100,
      "stripe_fee_policy_required",
    );
  }

  private metadata(binding: StripeCheckoutBinding): Record<string, string> {
    const { context, offer, id } = binding.command;
    return {
      eop_namespace: context.environment.namespace,
      eop_circuit: context.circuit,
      eop_buyer: context.buyerId,
      eop_seller: context.sellerId,
      eop_contract: context.contractId,
      eop_order: id,
      eop_offer: offer.id,
      eop_offer_version: String(offer.version),
    };
  }

  async create(
    binding: StripeCheckoutBinding,
    actor: Actor,
  ): Promise<StripeCheckout> {
    this.validate(binding, actor);
    const { context, offer, id } = binding.command;
    // Stripe puede purgar las claves a partir de 24 h. Una operación incierta
    // antigua requiere conciliación, nunca repetir POST a ciegas tras esa ventana.
    requireThat(
      binding.preparedAtSeconds <= this.now() + 30 &&
        this.now() - binding.preparedAtSeconds < 20 * 3600,
      "stripe_checkout_reconciliation_required",
    );
    const merchant = await this.request(context, "account");
    requireThat(
      merchant.id === context.accountId,
      "stripe_account_scope_mismatch",
    );
    if (context.circuit === "coach_service") {
      requireThat(
        merchant.charges_enabled === true && merchant.payouts_enabled === true,
        "stripe_merchant_not_ready",
      );
    }
    const price = await this.request(context, `prices/${binding.priceId}`);
    const recurring = object(price.recurring);
    requireThat(
      price.id === binding.priceId && price.livemode === false &&
        price.active === true &&
        price.currency === offer.price.currency.toLowerCase() &&
        price.unit_amount === offer.price.minorUnits &&
        recurring.interval === binding.interval &&
        recurring.interval_count === 1 && recurring.usage_type === "licensed",
      "stripe_price_mismatch",
    );
    const customer = await this.request(
      context,
      `customers/${binding.customerId}`,
    );
    const customerMetadata = object(customer.metadata);
    requireThat(
      customer.id === binding.customerId && customer.deleted !== true &&
        customer.livemode === false &&
        customerMetadata.eop_buyer === context.buyerId &&
        customerMetadata.eop_namespace === context.environment.namespace,
      "stripe_customer_mismatch",
    );
    const fields = new URLSearchParams({
      mode: "subscription",
      customer: binding.customerId,
      "line_items[0][price]": binding.priceId,
      "line_items[0][quantity]": "1",
      client_reference_id: id,
      locale: "es",
      integration_identifier: `entrenaop_trainer_${
        id.replaceAll("-", "").slice(0, 8).split("").map((hex) =>
          String.fromCharCode(97 + parseInt(hex, 16))
        ).join("")
      }`,
      "subscription_data[billing_mode][type]": "flexible",
      success_url: `${this.config.returnUrl}?order=${id}&checkout=returned`,
      cancel_url: `${this.config.returnUrl}?order=${id}&checkout=canceled`,
    });
    for (const [key, value] of Object.entries(this.metadata(binding))) {
      fields.set(`metadata[${key}]`, value);
      fields.set(`subscription_data[metadata][${key}]`, value);
    }
    if (context.circuit === "coach_service") {
      fields.set(
        "subscription_data[application_fee_percent]",
        String(binding.applicationFeePercent),
      );
    }
    // El mismo pedido recupera la misma sesión incluso tras un timeout. No se
    // reintenta con otra clave ni se acepta una oferta alterada en el almacén.
    const key =
      `${context.environment.namespace}:${context.accountId}:${context.circuit}:${id}`;
    return this.checkout(
      await this.request(context, "checkout/sessions", fields, key),
      binding,
    );
  }

  async read(
    binding: StripeCheckoutBinding,
    actor: Actor,
    sessionId: string,
  ): Promise<StripeCheckout> {
    this.validate(binding, actor);
    requireThat(
      /^cs_test_[A-Za-z0-9]+$/.test(sessionId),
      "stripe_test_session_required",
    );
    return this.checkout(
      await this.request(
        binding.command.context,
        `checkout/sessions/${sessionId}`,
      ),
      binding,
    );
  }

  private checkout(
    value: Json,
    binding: StripeCheckoutBinding,
  ): StripeCheckout {
    requireThat(
      typeof value.id === "string" && /^cs_test_[A-Za-z0-9]+$/.test(value.id) &&
        value.object === "checkout.session" && value.livemode === false &&
        value.mode === "subscription",
      "stripe_checkout_mismatch",
    );
    const metadata = object(value.metadata);
    requireThat(
      Object.entries(this.metadata(binding)).every(([key, expected]) =>
        metadata[key] === expected
      ) && value.client_reference_id === binding.command.id &&
        value.customer === binding.customerId &&
        value.currency === binding.command.offer.price.currency.toLowerCase(),
      "stripe_checkout_scope_mismatch",
    );
    requireThat(
      ["open", "complete", "expired"].includes(String(value.status)) &&
        ["paid", "unpaid", "no_payment_required"].includes(
          String(value.payment_status),
        ),
      "stripe_checkout_state_unknown",
    );
    requireThat(
      value.subscription === null ||
        (typeof value.subscription === "string" &&
          /^sub_[A-Za-z0-9]+$/.test(value.subscription)),
      "stripe_invalid_subscription",
    );
    if (value.url !== null) {
      requireThat(typeof value.url === "string", "stripe_invalid_checkout_url");
      const uri = new URL(value.url);
      requireThat(
        uri.protocol === "https:" && uri.hostname === "checkout.stripe.com" &&
          !uri.username && !uri.password && !uri.port,
        "stripe_invalid_checkout_url",
      );
    }
    requireThat(
      value.status !== "open" || value.url !== null,
      "stripe_checkout_url_missing",
    );
    return {
      id: value.id,
      url: value.url as string | null,
      status: value.status as StripeCheckout["status"],
      paymentStatus: value.payment_status as StripeCheckout["paymentStatus"],
      subscriptionId: value.subscription as string | null,
    };
  }
}

export type StripeSandboxSignal = {
  eventId: string;
  type: string;
  accountId: string;
  objectId: string;
};

// Verifica el cuerpo ORIGINAL. La señal solo solicita conciliación canónica;
// ni metadata ni `paid` en un webhook conceden Pro, cupos o vínculos.
export async function verifyStripeSandboxSignal(input: {
  body: string;
  signature: string;
  secret: string;
  platformAccountId: string;
  nowSeconds: number;
}): Promise<StripeSandboxSignal> {
  requireThat(
    input.body.length <= 262144 && input.signature.length <= 2048 &&
      /^whsec_[A-Za-z0-9]+$/.test(input.secret) &&
      account.test(input.platformAccountId),
    "stripe_invalid_webhook",
  );
  const components = input.signature.split(",").map((part) =>
    part.trim().split("=")
  );
  const timestamps = components.filter(([key]) => key === "t").map((
    [, value],
  ) => value);
  const proofs = components.filter(([key]) => key === "v1").map(([, value]) =>
    value
  );
  requireThat(
    timestamps.length === 1 && /^\d{1,12}$/.test(timestamps[0] ?? "") &&
      integer(input.nowSeconds) &&
      Math.abs(input.nowSeconds - Number(timestamps[0])) <= 300 &&
      proofs.length > 0 &&
      proofs.every((proof) => /^[a-f0-9]{64}$/.test(proof ?? "")),
    "stripe_invalid_signature",
  );
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(input.secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  let verified = false;
  for (const proof of proofs) {
    const bytes = Uint8Array.from(
      proof.match(/../g)!,
      (hex) => Number.parseInt(hex, 16),
    );
    verified = await crypto.subtle.verify(
      "HMAC",
      key,
      bytes,
      encoder.encode(`${timestamps[0]}.${input.body}`),
    ) || verified;
  }
  requireThat(verified, "stripe_invalid_signature");
  let event: Json;
  try {
    event = object(JSON.parse(input.body));
  } catch {
    requireThat(false, "stripe_invalid_webhook");
  }
  const item = object(object(event.data).object);
  requireThat(
    event.livemode === false && event.api_version === stripeApiVersion &&
      typeof event.id === "string" && /^evt_[A-Za-z0-9]+$/.test(event.id) &&
      typeof event.type === "string" && event.type.length <= 100 &&
      typeof item.id === "string" && item.id.length <= 256,
    "stripe_webhook_environment_mismatch",
  );
  const accountId = event.account ?? input.platformAccountId;
  requireThat(
    typeof accountId === "string" && account.test(accountId),
    "stripe_invalid_account",
  );
  return { eventId: event.id, type: event.type, accountId, objectId: item.id };
}
