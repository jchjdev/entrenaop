import { requireThat } from "./model.ts";
import {
  type StripeCheckoutBinding,
  StripeSandboxCheckout,
} from "./stripe_sandbox.ts";

type Json = Record<string, unknown>;
type Rpc = (action: string, data: Json) => Promise<unknown>;
type Period = { invoiceId: string; end: string } | null;
type FullPeriod = (
  subscription: Json,
  invoice: Json,
  binding: StripeCheckoutBinding,
  now: number,
) => Period;
const object = (value: unknown): Json => {
  requireThat(
    !!value && typeof value === "object" && !Array.isArray(value),
    "invalid_change_data",
  );
  return value as Json;
};
const identifier = (value: unknown, prefix: string): string => {
  requireThat(
    typeof value === "string" &&
      new RegExp(`^${prefix}_[A-Za-z0-9]+$`).test(value),
    "invalid_change_id",
  );
  return value;
};

export function subscriptionItem(subscription: Json, customer: string): Json {
  const items = object(subscription.items);
  requireThat(
    subscription.livemode === false &&
      subscription.customer === customer &&
      items.has_more === false &&
      Array.isArray(items.data) &&
      items.data.length === 1,
    "change_subscription_mismatch",
  );
  const item = object(items.data[0]);
  requireThat(
    item.quantity === 1 &&
      Number.isSafeInteger(item.current_period_end) &&
      Number.isSafeInteger(item.current_period_start),
    "change_item_mismatch",
  );
  identifier(item.id, "si");
  return item;
}

// El crédito debe corresponder exactamente al plan pagado y el débito al nuevo.
// No admitimos saldos externos, descuentos, impuestos u otros cargos en el piloto.
export function prorationTotal(
  invoice: Json,
  subscription: Json,
  change: Json,
  customer: string,
): number {
  const from = object(change.from_offer),
    target = object(change.offer);
  const lines = object(invoice.lines);
  requireThat(
    invoice.livemode === false &&
      invoice.customer === customer &&
      invoice.currency === String(target.currency).toLowerCase() &&
      object(object(invoice.parent).subscription_details).subscription ===
        subscription.id &&
      invoice.starting_balance === 0 &&
      invoice.ending_balance === 0 &&
      lines.has_more === false &&
      Array.isArray(lines.data) &&
      lines.data.length === 2,
    "change_invoice_mismatch",
  );
  let credit = 0,
    debit = 0,
    total = 0;
  for (const value of lines.data) {
    const line = object(value),
      parent = object(object(line.parent).subscription_item_details);
    const period = object(line.period),
      price = object(object(line.pricing).price_details).price;
    requireThat(
      parent.proration === true &&
        parent.subscription === subscription.id &&
        parent.subscription_item === change.item_id &&
        line.quantity === 1 &&
        line.currency === invoice.currency &&
        Number.isSafeInteger(line.amount) &&
        period.start === change.proration_at &&
        Number(period.end) * 1000 === Date.parse(String(change.effective_at)) &&
        Array.isArray(line.discount_amounts) &&
        line.discount_amounts.length === 0 &&
        Array.isArray(line.taxes) &&
        line.taxes.length === 0,
      "change_proration_mismatch",
    );
    if (price === from.price_id && Number(line.amount) <= 0) credit++;
    else if (price === target.price_id && Number(line.amount) >= 0) debit++;
    else requireThat(false, "change_price_mismatch");
    total += Number(line.amount);
  }
  requireThat(
    credit === 1 &&
      debit === 1 &&
      total >= 0 &&
      invoice.total === total &&
      invoice.amount_due === total &&
      total <= Number(target.amount),
    "change_total_mismatch",
  );
  return total;
}

export function paidUpgrade(
  invoice: Json,
  subscription: Json,
  change: Json,
  customer: string,
): Period {
  const total = prorationTotal(invoice, subscription, change, customer);
  requireThat(
    total === change.amount &&
      invoice.id === subscription.latest_invoice &&
      invoice.billing_reason === "subscription_update",
    "change_quote_mismatch",
  );
  if (invoice.status !== "paid") return null;
  const item = subscriptionItem(subscription, customer);
  requireThat(
    object(item.price).id === object(change.offer).price_id &&
      invoice.amount_paid === total &&
      invoice.amount_remaining === 0 &&
      invoice.amount_paid_off_stripe === 0,
    "change_payment_mismatch",
  );
  const payments = object(invoice.payments);
  requireThat(
    payments.has_more === false && Array.isArray(payments.data),
    "change_payments_incomplete",
  );
  if (total === 0) {
    // Redondeo a cero: solo sobre un periodo previo ya pagado, sin saldo externo.
    requireThat(payments.data.length === 0, "change_zero_payment_mismatch");
  } else {
    requireThat(payments.data.length === 1, "change_payments_incomplete");
    const payment = object(payments.data[0]),
      source = object(payment.payment);
    const intent = object(source.payment_intent);
    requireThat(
      payment.invoice === invoice.id &&
        payment.status === "paid" &&
        payment.currency === invoice.currency &&
        payment.amount_paid === total &&
        source.type === "payment_intent" &&
        intent.livemode === false &&
        intent.status === "succeeded" &&
        intent.customer === customer &&
        intent.currency === invoice.currency &&
        intent.amount_received === total,
      "change_payment_source_mismatch",
    );
    identifier(intent.id, "pi");
  }
  return {
    invoiceId: identifier(invoice.id, "in"),
    end: String(change.effective_at),
  };
}

export class SubscriptionChanges {
  private change: Json | null;
  private stripe: StripeSandboxCheckout;
  private rpc: Rpc;
  private order: Json;
  private binding: StripeCheckoutBinding;
  private token: Json;
  private now: () => number;
  constructor(
    stripe: StripeSandboxCheckout,
    rpc: Rpc,
    order: Json,
    binding: StripeCheckoutBinding,
    token: Json,
    now: () => number,
  ) {
    this.stripe = stripe;
    this.rpc = rpc;
    this.order = order;
    this.binding = binding;
    this.token = token;
    this.now = now;
    this.change = order.change ? object(order.change) : null;
  }

  private call(action: string, data: Json = {}): Promise<unknown> {
    return this.rpc(action, {
      ...this.token,
      change_id: this.change?.id,
      ...data,
    });
  }
  private request(
    path: string,
    fields?: URLSearchParams,
    suffix?: string,
  ): Promise<Json> {
    return this.stripe.request(
      this.binding.command.context,
      path,
      fields,
      suffix ? `entrenaop-dev:change:${this.change?.id}:${suffix}` : undefined,
    );
  }
  private async invoice(id: unknown): Promise<Json> {
    return await this.request(
      `invoices/${identifier(id, "in")}?expand[]=payments.data.payment.payment_intent&expand[]=amount_paid_off_stripe`,
    );
  }
  private async subscription(): Promise<Json> {
    return await this.request(
      `subscriptions/${identifier(this.order.subscription_id, "sub")}`,
    );
  }
  private validateCurrent(subscription: Json): Json {
    const item = subscriptionItem(subscription, this.binding.customerId);
    requireThat(
      subscription.id === this.order.subscription_id &&
        subscription.status === "active" &&
        subscription.collection_method === "charge_automatically" &&
        !subscription.cancel_at_period_end &&
        !subscription.cancel_at &&
        !subscription.pause_collection &&
        !subscription.pending_update &&
        object(item.price).id === this.binding.priceId &&
        Date.parse(String(this.order.paid_until)) ===
          Number(item.current_period_end) * 1000,
      "change_subscription_not_ready",
    );
    return item;
  }
  private paymentUrl(invoice: Json): string | null {
    if (typeof invoice.hosted_invoice_url !== "string") return null;
    const url = new URL(invoice.hosted_invoice_url);
    requireThat(
      url.protocol === "https:" &&
        url.hostname === "invoice.stripe.com" &&
        !url.username &&
        !url.password &&
        !url.port,
      "invalid_change_payment_url",
    );
    return url.toString();
  }

  async quote(subscription: Json, changeId: string): Promise<Json> {
    requireThat(
      this.change?.id === changeId &&
        ["prepared", "quoted"].includes(String(this.change.state)),
      "change_not_ready",
    );
    const item = this.validateCurrent(subscription);
    requireThat(!subscription.schedule, "change_schedule_exists");
    const target = object(this.change.offer);
    const price = await this.request(
      `prices/${identifier(target.price_id, "price")}`,
    );
    requireThat(
      price.livemode === false &&
        price.active === true &&
        price.unit_amount === target.amount &&
        price.currency === String(target.currency).toLowerCase() &&
        object(price.recurring).interval === target.interval,
      "change_target_mismatch",
    );
    const at = this.now(),
      end = new Date(Number(item.current_period_end) * 1000).toISOString();
    let amount = 0;
    if (this.change.kind === "immediate") {
      const preview = await this.request(
        "invoices/create_preview",
        new URLSearchParams({
          customer: this.binding.customerId,
          subscription: String(subscription.id),
          "subscription_details[items][0][id]": String(item.id),
          "subscription_details[items][0][price]": String(target.price_id),
          "subscription_details[items][0][quantity]": "1",
          "subscription_details[proration_behavior]": "always_invoice",
          "subscription_details[proration_date]": String(at),
        }),
      );
      amount = prorationTotal(
        preview,
        subscription,
        {
          ...this.change,
          item_id: item.id,
          proration_at: at,
          effective_at: end,
        },
        this.binding.customerId,
      );
    }
    this.change = object(
      await this.call("change_quote", {
        amount,
        item_id: item.id,
        proration_at: at,
        effective_at: end,
      }),
    );
    return { change: this.change, confirmed: false };
  }

  async confirm(
    subscription: Json,
    changeId: string,
    fullPeriod: FullPeriod,
  ): Promise<Json> {
    requireThat(this.change?.id === changeId, "change_not_ready");
    if (
      ["applied", "scheduled", "payment_pending"].includes(
        String(this.change.state),
      )
    ) {
      return await this.refreshResult(subscription, fullPeriod);
    }
    requireThat(
      ["quoted", "processing"].includes(String(this.change.state)),
      "change_not_ready",
    );
    if (this.change.state === "quoted") this.validateCurrent(subscription);
    requireThat(
      this.now() - Date.parse(String(this.change.quoted_at)) / 1000 < 20 * 3600,
      "change_reconciliation_required",
    );
    await this.call("change_start");
    this.change.state = "processing";
    if (this.change.kind === "immediate") {
      const updated = await this.request(
        `subscriptions/${identifier(subscription.id, "sub")}`,
        new URLSearchParams({
          "items[0][id]": String(this.change.item_id),
          "items[0][price]": String(object(this.change.offer).price_id),
          "items[0][quantity]": "1",
          payment_behavior: "pending_if_incomplete",
          proration_behavior: "always_invoice",
          proration_date: String(this.change.proration_at),
        }),
        "update",
      );
      await this.call("change_invoice", {
        invoice_id: identifier(updated.latest_invoice, "in"),
      });
      this.change.state = "payment_pending";
      this.change.invoice_id = updated.latest_invoice;
      return await this.refreshResult(updated, fullPeriod);
    }
    let scheduleId = this.change.schedule_id;
    if (!scheduleId) {
      const schedule = await this.request(
        "subscription_schedules",
        new URLSearchParams({
          from_subscription: identifier(subscription.id, "sub"),
        }),
        "schedule-create",
      );
      scheduleId = identifier(schedule.id, "sub_sched");
      await this.call("change_schedule_id", { schedule_id: scheduleId });
      this.change.schedule_id = scheduleId;
    }
    const schedule = await this.request(
      `subscription_schedules/${identifier(scheduleId, "sub_sched")}`,
    );
    requireThat(
      schedule.livemode === false &&
        schedule.customer === this.binding.customerId &&
        schedule.subscription === subscription.id,
      "change_schedule_mismatch",
    );
    const phase = object(schedule.current_phase);
    const end = Math.floor(Date.parse(String(this.change.effective_at)) / 1000);
    const fields = new URLSearchParams({
      end_behavior: "release",
      proration_behavior: "none",
      "phases[0][start_date]": String(phase.start_date),
      "phases[0][end_date]": String(end),
      "phases[0][items][0][price]": this.binding.priceId,
      "phases[0][items][0][quantity]": "1",
      "phases[0][proration_behavior]": "none",
      "phases[1][start_date]": String(end),
      "phases[1][duration][interval]": this.binding.interval,
      "phases[1][duration][interval_count]": "1",
      "phases[1][items][0][price]": String(object(this.change.offer).price_id),
      "phases[1][items][0][quantity]": "1",
      "phases[1][proration_behavior]": "none",
    });
    const updated = await this.request(
      `subscription_schedules/${scheduleId}`,
      fields,
      "schedule-update",
    );
    const phases = updated.phases;
    requireThat(
      Array.isArray(phases) &&
        phases.length === 2 &&
        object(phases[1]).start_date === end &&
        updated.end_behavior === "release",
      "change_schedule_mismatch",
    );
    const nextItems = object(phases[1]).items;
    requireThat(
      Array.isArray(nextItems) &&
        nextItems.length === 1 &&
        object(nextItems[0]).price === object(this.change.offer).price_id &&
        object(nextItems[0]).quantity === 1,
      "change_schedule_mismatch",
    );
    await this.call("change_scheduled");
    return { state: "scheduled", confirmed: false };
  }

  async cancel(
    subscription: Json,
    changeId: string,
    fullPeriod: FullPeriod,
  ): Promise<Json> {
    requireThat(this.change?.id === changeId, "change_not_ready");
    const result = await this.reconcile(subscription, fullPeriod);
    if (result.applied || this.change.state === "applied")
      return { confirmed: true, state: "active" };
    if (this.change.state === "canceled")
      return { state: "canceled_change", confirmed: false };
    requireThat(
      this.change.state !== "processing" ||
        !!this.change.schedule_id ||
        !!this.change.invoice_id,
      "change_reconciliation_required",
    );
    if (this.change.schedule_id) {
      const schedule = await this.request(
        `subscription_schedules/${identifier(this.change.schedule_id, "sub_sched")}`,
      );
      requireThat(
        schedule.subscription === subscription.id &&
          schedule.customer === this.binding.customerId &&
          schedule.livemode === false,
        "change_schedule_mismatch",
      );
      const released = await this.request(
        `subscription_schedules/${schedule.id}/release`,
        new URLSearchParams({ preserve_cancel_date: "true" }),
        "release",
      );
      requireThat(
        released.status === "released",
        "change_schedule_not_released",
      );
      // La renovación puede coincidir con la anulación: conciliamos de nuevo
      // antes de dar por cancelado un cambio cuyo nuevo periodo ya se haya pagado.
      const current = await this.subscription();
      if (
        object(subscriptionItem(current, this.binding.customerId).price).id ===
        object(this.change.offer).price_id
      ) {
        return this.refreshResult(current, fullPeriod);
      }
      requireThat(
        object(subscriptionItem(current, this.binding.customerId).price).id ===
          this.binding.priceId,
        "change_schedule_mismatch",
      );
    } else if (this.change.invoice_id) {
      const invoice = await this.invoice(this.change.invoice_id);
      requireThat(invoice.status !== "paid", "change_already_paid");
      if (invoice.status !== "void") {
        const canceled = await this.request(
          `invoices/${identifier(invoice.id, "in")}/void`,
          new URLSearchParams(),
          "void",
        );
        requireThat(canceled.status === "void", "change_invoice_not_void");
      }
      const current = await this.subscription();
      requireThat(
        !current.pending_update &&
          object(subscriptionItem(current, this.binding.customerId).price)
            .id === this.binding.priceId,
        "change_cancel_not_confirmed",
      );
    }
    await this.call("change_cancel");
    return { state: "canceled_change", confirmed: false };
  }

  async refreshResult(
    subscription: Json,
    fullPeriod: FullPeriod,
  ): Promise<Json> {
    const result = await this.reconcile(subscription, fullPeriod);
    if (result.applied) return { state: "active", confirmed: true };
    if (this.change?.kind === "immediate" && this.change.invoice_id) {
      const invoice = await this.invoice(this.change.invoice_id);
      return {
        state: "payment_pending",
        confirmed: false,
        payment_url: this.paymentUrl(invoice),
      };
    }
    return { state: this.change?.state, confirmed: false };
  }

  async reconcile(
    subscription: Json,
    fullPeriod: FullPeriod,
  ): Promise<{ applied?: boolean; skipInvoice?: boolean; pending?: boolean }> {
    const change = this.change;
    if (
      !change ||
      !["processing", "payment_pending", "scheduled"].includes(
        String(change.state),
      )
    )
      return {};
    const item = subscriptionItem(subscription, this.binding.customerId);
    if (change.kind === "immediate") {
      if (!subscription.latest_invoice) return {};
      const invoice = await this.invoice(subscription.latest_invoice);
      if (invoice.billing_reason !== "subscription_update") return {};
      if (!change.invoice_id) {
        // Recupera una respuesta de actualización incierta sin volver a cobrar.
        prorationTotal(invoice, subscription, change, this.binding.customerId);
        await this.call("change_invoice", {
          invoice_id: identifier(invoice.id, "in"),
        });
        change.invoice_id = invoice.id;
      }
      requireThat(invoice.id === change.invoice_id, "change_invoice_mismatch");
      if (invoice.status === "void" || invoice.status === "uncollectible") {
        await this.call("change_cancel");
        return { skipInvoice: true };
      }
      const paid = paidUpgrade(
        invoice,
        subscription,
        change,
        this.binding.customerId,
      );
      if (!paid) return { skipInvoice: true, pending: true };
      await this.call("change_apply", {
        invoice_id: paid.invoiceId,
        paid_until: paid.end,
      });
      change.state = "applied";
      return { applied: true, skipInvoice: true };
    }
    if (object(item.price).id !== object(change.offer).price_id) {
      if (change.schedule_id) {
        const schedule = await this.request(
          `subscription_schedules/${identifier(change.schedule_id, "sub_sched")}`,
        );
        requireThat(
          schedule.livemode === false &&
            schedule.customer === this.binding.customerId &&
            (schedule.subscription === subscription.id ||
              schedule.released_subscription === subscription.id),
          "change_schedule_mismatch",
        );
        if (
          ["released", "canceled", "aborted"].includes(String(schedule.status))
        ) {
          const current = await this.subscription();
          const currentPrice = object(
            subscriptionItem(current, this.binding.customerId).price,
          ).id;
          if (currentPrice === object(change.offer).price_id)
            return this.reconcile(current, fullPeriod);
          requireThat(
            currentPrice === this.binding.priceId,
            "change_schedule_mismatch",
          );
          await this.call("change_cancel");
          change.state = "canceled";
        } else if (
          change.state === "processing" &&
          Array.isArray(schedule.phases) &&
          schedule.phases.length === 2
        ) {
          const next = object(schedule.phases[1]),
            items = next.items;
          requireThat(
            Number(next.start_date) * 1000 ===
              Date.parse(String(change.effective_at)) &&
              Array.isArray(items) &&
              items.length === 1 &&
              object(items[0]).price === object(change.offer).price_id &&
              object(items[0]).quantity === 1,
            "change_schedule_mismatch",
          );
          await this.call("change_scheduled");
          change.state = "scheduled";
        }
      }
      return {};
    }
    const invoice = await this.invoice(subscription.latest_invoice);
    const target = object(change.offer);
    const binding: StripeCheckoutBinding = {
      ...this.binding,
      priceId: String(target.price_id),
      command: {
        ...this.binding.command,
        offer: {
          ...this.binding.command.offer,
          price: {
            minorUnits: Number(target.amount),
            currency: String(target.currency),
          },
        },
      },
    };
    const paid = fullPeriod(subscription, invoice, binding, this.now());
    if (!paid) return { skipInvoice: true, pending: true };
    requireThat(
      Date.parse(paid.end) > Date.parse(String(change.effective_at)),
      "change_renewal_period_mismatch",
    );
    await this.call("change_apply", {
      invoice_id: paid.invoiceId,
      paid_until: paid.end,
    });
    change.state = "applied";
    return { applied: true };
  }
}
