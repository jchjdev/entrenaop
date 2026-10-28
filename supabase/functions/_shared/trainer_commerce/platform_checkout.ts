import { requireThat } from "./model.ts";
import type { Actor, Context } from "./model.ts";
import {
  type StripeCheckoutBinding,
  StripeSandboxCheckout,
} from "./stripe_sandbox.ts";

type Json = Record<string, unknown>;
export type CommerceRpc = (action: string, data: Json) => Promise<unknown>;
export function row(value: unknown): Json {
  requireThat(
    !!value && typeof value === "object" && !Array.isArray(value),
    "invalid_commerce_data",
  );
  return value as Json;
}
function id(value: unknown, prefix: string): string {
  requireThat(
    typeof value === "string" &&
      new RegExp(`^${prefix}_[A-Za-z0-9]+$`).test(value),
    "invalid_commerce_id",
  );
  return value;
}
export type PaidPeriod = { invoiceId: string; end: string } | null;

// Solo evidencia canónica del proveedor. El retorno del navegador y los campos
// del webhook no se utilizan para calcular un periodo pagado.
export function paidPeriod(
  subscription: Json,
  invoice: Json,
  binding: StripeCheckoutBinding,
  now: number,
): PaidPeriod {
  const items = row(subscription.items);
  requireThat(
    Array.isArray(items.data) && items.data.length === 1 &&
      items.has_more === false,
    "subscription_items_mismatch",
  );
  const item = row(items.data[0]);
  const price = row(item.price);
  requireThat(
    subscription.livemode === false &&
      subscription.customer === binding.customerId &&
      item.quantity === 1 && price.id === binding.priceId &&
      price.currency === binding.command.offer.price.currency.toLowerCase() &&
      price.unit_amount === binding.command.offer.price.minorUnits,
    "subscription_scope_mismatch",
  );
  requireThat(
    invoice.id === subscription.latest_invoice && invoice.livemode === false &&
      invoice.customer === binding.customerId &&
      invoice.currency === price.currency &&
      row(row(invoice.parent).subscription_details).subscription ===
        subscription.id,
    "invoice_scope_mismatch",
  );
  if (invoice.status !== "paid") return null;
  const amount = binding.command.offer.price.minorUnits;
  requireThat(
    invoice.amount_paid === amount && invoice.amount_due === amount &&
      invoice.amount_remaining === 0 && invoice.amount_paid_off_stripe === 0,
    "invoice_payment_mismatch",
  );
  // El ensayo no admite descuentos, saldo a favor ni periodos gratuitos. Antes
  // de vender se ampliará este contrato junto con su política de ajustes.
  requireThat(
    invoice.starting_balance === 0 && invoice.ending_balance === 0,
    "invoice_credit_unsupported",
  );
  // Endive no tiene invoice.paid ni paid_out_of_band. El enlace InvoicePayment
  // debe acreditar un PaymentIntent completado dentro de Stripe, no una marca
  // manual de factura pagada ni un saldo externo.
  const payments = row(invoice.payments);
  requireThat(
    payments.has_more === false && Array.isArray(payments.data) &&
      payments.data.length === 1,
    "invoice_payments_incomplete",
  );
  const payment = row(payments.data[0]);
  const source = row(payment.payment);
  const intent = row(source.payment_intent);
  requireThat(
    payment.invoice === invoice.id && payment.status === "paid" &&
      payment.currency === price.currency && payment.amount_paid === amount &&
      source.type === "payment_intent" && intent.livemode === false &&
      intent.status === "succeeded" && intent.customer === binding.customerId &&
      intent.currency === price.currency && intent.amount_received === amount,
    "invoice_payment_source_mismatch",
  );
  id(intent.id, "pi");
  const lines = row(invoice.lines);
  requireThat(
    Array.isArray(lines.data) && lines.data.length === 1 &&
      lines.has_more === false,
    "invoice_lines_mismatch",
  );
  const line = row(lines.data[0]);
  const lineParent = row(row(line.parent).subscription_item_details);
  const period = row(line.period);
  requireThat(
    row(row(line.pricing).price_details).price === binding.priceId &&
      line.quantity === 1 && line.amount === amount &&
      lineParent.subscription_item === item.id &&
      lineParent.proration === false &&
      Number.isSafeInteger(period.start) && Number.isSafeInteger(period.end) &&
      Number(period.start) <= now + 60 &&
      Number(period.end) > Number(period.start) &&
      Number(period.end) - Number(period.start) <= 367 * 86400 &&
      Number(period.end) <= now + 367 * 86400,
    "invoice_period_mismatch",
  );
  return {
    invoiceId: id(invoice.id, "in"),
    end: new Date(Number(period.end) * 1000).toISOString(),
  };
}

export class PlatformCheckout {
  private readonly stripe: StripeSandboxCheckout;
  private readonly rpc: CommerceRpc;
  private readonly account: string;
  private readonly now: () => number;
  private readonly portalId: string;
  constructor(
    stripe: StripeSandboxCheckout,
    rpc: CommerceRpc,
    account: string,
    now = () => Math.floor(Date.now() / 1000),
    portalId = "",
  ) {
    this.stripe = stripe;
    this.rpc = rpc;
    this.account = account;
    this.now = now;
    this.portalId = portalId;
  }

  private binding(order: Json): StripeCheckoutBinding {
    const offer = row(order.offer);
    const context: Context = {
      provider: "stripe",
      environment: { mode: "sandbox", namespace: "entrenaop-dev" },
      circuit: "platform_access",
      accountId: this.account,
      sellerId: this.account,
      buyerId: String(order.owner_id),
      contractId: String(order.id),
    };
    return {
      command: {
        id: String(order.id),
        context,
        actorId: String(order.owner_id),
        expectedRevision: 0,
        offer: {
          id: String(offer.id),
          version: Number(offer.version),
          circuit: "platform_access",
          sellerId: this.account,
          price: {
            minorUnits: Number(offer.amount),
            currency: String(offer.currency),
          },
          capacity: Number(offer.capacity),
          termsVersion: "sandbox-v1",
        },
      },
      customerId: String(order.customer_id),
      priceId: String(offer.price_id),
      interval: offer.interval as "month" | "year",
      applicationFeePercent: null,
      preparedAtSeconds: Math.floor(
        Date.parse(String(order.created_at)) / 1000,
      ),
    };
  }

  async run(
    orderId: string,
    actor: Actor | null,
    action: "checkout" | "refresh" | "portal",
  ): Promise<Json> {
    const order = row(await this.rpc("claim", { id: orderId }));
    const token = { id: orderId, lease: order.lease };
    try {
      if (actor) {
        requireThat(
          actor.mfa && actor.userId === order.owner_id,
          "identity_mismatch",
        );
      }
      let binding = this.binding(order);
      const providerActor = { userId: String(order.owner_id), mfa: true };
      if (
        !order.session_id && this.now() - binding.preparedAtSeconds >= 20 * 3600
      ) {
        if (order.customer_id) {
          // Una creación incierta antigua se busca canónicamente. No se vuelve
          // a usar una clave de idempotencia que Stripe ya podría haber purgado.
          const query = new URLSearchParams({
            customer: binding.customerId,
            limit: "100",
            "created[gte]": String(binding.preparedAtSeconds - 60),
          });
          const sessions = await this.stripe.request(
            binding.command.context,
            `checkout/sessions?${query}`,
          );
          requireThat(
            sessions.has_more === false && Array.isArray(sessions.data),
            "checkout_reconciliation_incomplete",
          );
          const matches = sessions.data.map(row).filter((s) =>
            s.client_reference_id === order.id
          );
          requireThat(matches.length <= 1, "checkout_reconciliation_ambiguous");
          if (matches.length === 1) {
            const recovered = await this.stripe.read(
              binding,
              providerActor,
              id(matches[0].id, "cs_test"),
            );
            await this.rpc("checkout", { ...token, session_id: recovered.id });
            order.session_id = recovered.id;
          }
        }
        if (!order.session_id) {
          // Sin Customer guardado, el flujo nunca pudo iniciar Checkout. Si la
          // búsqueda completa tampoco encuentra una sesión, se puede cerrar.
          await this.rpc("expired", token);
          return { state: "expired" };
        }
      }
      if (!order.customer_id) {
        requireThat(
          action === "checkout" &&
            binding.preparedAtSeconds > this.now() - 20 * 3600,
          "customer_reconciliation_required",
        );
        const customer = await this.stripe.request(
          binding.command.context,
          "customers",
          new URLSearchParams({
            "metadata[eop_buyer]": String(order.owner_id),
            "metadata[eop_namespace]": "entrenaop-dev",
          }),
          `entrenaop-dev:customer:${order.owner_id}`,
        );
        requireThat(
          customer.livemode === false,
          "customer_environment_mismatch",
        );
        order.customer_id = id(customer.id, "cus");
        await this.rpc("customer", {
          ...token,
          customer_id: order.customer_id,
        });
        binding = this.binding(order);
      }
      if (action === "portal") {
        requireThat(!!order.subscription_id, "subscription_missing");
        requireThat(
          /^bpc_[A-Za-z0-9]+$/.test(this.portalId),
          "portal_configuration_required",
        );
        const portal = await this.stripe.request(
          binding.command.context,
          "billing_portal/sessions",
          new URLSearchParams({
            customer: binding.customerId,
            return_url: "https://trainer.entrenaop.es/#/subscription",
            configuration: this.portalId,
          }),
        );
        const uri = new URL(String(portal.url));
        requireThat(
          uri.protocol === "https:" && uri.hostname === "billing.stripe.com" &&
            !uri.username && !uri.password && !uri.port,
          "invalid_portal_url",
        );
        return { url: uri.toString() };
      }
      if (!order.session_id) {
        requireThat(action === "checkout", "checkout_not_ready");
        const checkout = await this.stripe.create(binding, providerActor);
        await this.rpc("checkout", { ...token, session_id: checkout.id });
        order.session_id = checkout.id;
      }
      const checkout = await this.stripe.read(
        binding,
        providerActor,
        String(order.session_id),
      );
      if (checkout.status === "expired") {
        await this.rpc("expired", token);
        return { state: "expired" };
      }
      if (checkout.status === "open") {
        return {
          state: "open",
          ...(action === "checkout" ? { url: checkout.url } : {}),
        };
      }
      requireThat(checkout.subscriptionId, "subscription_missing");
      const subscription = await this.stripe.request(
        binding.command.context,
        `subscriptions/${checkout.subscriptionId}`,
      );
      requireThat(
        subscription.id === checkout.subscriptionId &&
          subscription.livemode === false &&
          subscription.customer === binding.customerId,
        "subscription_scope_mismatch",
      );
      requireThat(
        !order.subscription_id || order.subscription_id === subscription.id,
        "subscription_scope_mismatch",
      );
      let paid: PaidPeriod = null;
      if (subscription.latest_invoice) {
        const invoiceId = id(subscription.latest_invoice, "in");
        const invoice = await this.stripe.request(
          binding.command.context,
          `invoices/${invoiceId}?expand[]=payments.data.payment.payment_intent&expand[]=amount_paid_off_stripe`,
        );
        paid = paidPeriod(subscription, invoice, binding, this.now());
      }
      const states: Record<string, string> = {
        active: "active",
        past_due: "past_due",
        unpaid: "past_due",
        incomplete: "past_due",
        incomplete_expired: "canceled",
        canceled: "canceled",
        paused: "past_due",
      };
      let state = states[String(subscription.status)];
      requireThat(state, "subscription_state_unknown");
      const paidUntil = paid?.end ?? order.paid_until;
      const hasCurrentPayment = typeof paidUntil === "string" &&
        Date.parse(paidUntil) > this.now() * 1000;
      if (state === "active" && !hasCurrentPayment) state = "open";
      // Sin primer recibo válido no se habilita acceso. Después se conserva
      // exclusivamente el periodo ya acreditado, incluso con un impago nuevo.
      await this.rpc("apply", {
        ...token,
        subscription_id: subscription.id,
        state,
        cancel_at_period_end: subscription.cancel_at_period_end === true,
        invoice_id: paid?.invoiceId ?? null,
        paid_until: paid?.end ?? null,
      });
      return { state, confirmed: hasCurrentPayment };
    } finally {
      try {
        await this.rpc("release", token);
      } catch { /* La lease caduca; jamás se libera la de otro proceso. */ }
    }
  }
}
