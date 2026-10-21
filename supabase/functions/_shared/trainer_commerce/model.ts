// Contratos puros: ninguna observación del proveedor concede derechos reales.
export type Circuit = "platform_access" | "coach_service";
export type Context = {
  provider: string;
  environment: { mode: "simulation" | "sandbox" | "live"; namespace: string };
  circuit: Circuit;
  accountId: string;
  sellerId: string;
  buyerId: string;
  contractId: string;
};
export type Money = { minorUnits: number; currency: string };
export type Offer = {
  id: string;
  version: number;
  circuit: Circuit;
  sellerId: string;
  price: Money;
  capacity: number | null;
  termsVersion: string;
};
export type Command = {
  id: string;
  context: Context;
  actorId: string;
  expectedRevision: number;
  offer: Offer;
};
// Esta evidencia se inyecta desde Auth; el núcleo no autentica una sesión.
export type Actor = { userId: string; mfa: boolean };
export type InvoiceFact = {
  invoiceId: string;
  lineId: string;
  paymentId: string | null;
  source: "provider" | "manual" | "credit" | "free";
  status: "open" | "paid" | "void" | "uncollectible";
  due: Money;
  paidMinorUnits: number;
  start: number;
  end: number;
};
export type Adjustment = {
  id: string;
  invoiceId: string;
  kind: "refund" | "dispute";
  status: "pending" | "succeeded" | "resolved";
  money: Money;
};
export type ProviderSnapshot = {
  context: Context;
  subscriptionId: string;
  offerId: string;
  offerVersion: number;
  currency: string;
  status: string;
  complete: boolean;
  invoices: InvoiceFact[];
  adjustments: Adjustment[];
};
export type Sources = {
  activeClients: number;
  manualGrant: { capacity: number; validUntil: number } | null;
  relation: "active" | "ended";
  merchant: "ready" | "disconnected" | "unknown";
};
export type Binding = {
  context: Context;
  offer: Offer;
  subscriptionId: string;
  sources: Sources;
};
export type SimulationPolicy = { version: string; scope: "simulation_only" };
export type PaidEvidence = {
  invoiceId: string;
  lineId: string;
  paymentId: string;
  money: Money;
  start: number;
  end: number;
};
export type Decision = {
  kind: "policy_required" | "proposed_change" | "conflict" | "unchanged";
  reason: string;
  policyVersion: string | null;
  paidEvidence: PaidEvidence[];
  proposedCapacity: number | null;
};
export type VerifiedSignal = {
  id: string;
  context: Context;
  subscriptionId: string;
};
export type Lease = {
  context: Context;
  generation: number;
  until: number;
  expectedRevision: number;
  signalSequence: number;
};
export type CheckoutReference = {
  id: string;
  commandId: string;
  context: Context;
};
export type CommandRecord = {
  command: Command;
  state: "prepared" | "submitting" | "uncertain" | "completed";
  checkout: CheckoutReference | null;
};

export class CommerceError extends Error {
  readonly code: string;
  constructor(code: string) {
    super(code);
    this.name = "CommerceError";
    this.code = code;
  }
}
export function requireThat(
  condition: unknown,
  code: string,
): asserts condition {
  if (!condition) throw new CommerceError(code);
}
export function integer(value: number, minimum = 0): boolean {
  return Number.isSafeInteger(value) && value >= minimum;
}
export function text(value: string): boolean {
  return typeof value === "string" && value.trim().length > 0;
}
// Serialización exacta para igualdad/idempotencia, no un hash criptográfico.
export function canonical(value: unknown): string {
  if (value === null || typeof value !== "object") {
    requireThat(
      value === null || typeof value === "string" ||
        typeof value === "boolean" ||
        (typeof value === "number" && Number.isFinite(value)),
      "non_json_value",
    );
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  requireThat(
    Object.getPrototypeOf(value) === Object.prototype ||
      Object.getPrototypeOf(value) === null,
    "non_json_value",
  );
  const row = value as Record<string, unknown>;
  return `{${
    Object.keys(row).sort().map((key) =>
      `${JSON.stringify(key)}:${canonical(row[key])}`
    ).join(",")
  }}`;
}
export function contextKey(context: Context): string {
  return canonical(context);
}
export function assertContext(context: Context): void {
  requireThat(
    [
      context.provider,
      context.environment.namespace,
      context.accountId,
      context.sellerId,
      context.buyerId,
      context.contractId,
    ].every(text) &&
      ["simulation", "sandbox", "live"].includes(context.environment.mode) &&
      ["platform_access", "coach_service"].includes(context.circuit),
    "invalid_context",
  );
}
export function assertSimulation(context: Context): void {
  assertContext(context);
  requireThat(
    context.environment.mode === "simulation" && context.provider === "fake",
    "simulation_only",
  );
}
export function assertMoney(money: Money): void {
  requireThat(
    integer(money.minorUnits) && /^[A-Z]{3}$/.test(money.currency),
    "invalid_money",
  );
}
export function assertOffer(offer: Offer, context: Context): void {
  assertContext(context);
  assertMoney(offer.price);
  requireThat(
    text(offer.id) && integer(offer.version, 1) && text(offer.termsVersion),
    "invalid_offer",
  );
  requireThat(
    offer.circuit === context.circuit && offer.sellerId === context.sellerId,
    "offer_scope_mismatch",
  );
  requireThat(
    context.circuit === "platform_access"
      ? integer(offer.capacity as number, 1)
      : offer.capacity === null,
    "invalid_capacity",
  );
}
export function assertSources(sources: Sources): void {
  requireThat(integer(sources.activeClients), "invalid_sources");
  requireThat(
    ["active", "ended"].includes(sources.relation) &&
      ["ready", "disconnected", "unknown"].includes(sources.merchant),
    "invalid_sources",
  );
  if (sources.manualGrant !== null) {
    requireThat(
      integer(sources.manualGrant.capacity, 1) &&
        integer(sources.manualGrant.validUntil),
      "invalid_sources",
    );
  }
}
export function assertActor(actor: Actor, command: Command): void {
  requireThat(actor.mfa === true, "mfa_required");
  requireThat(
    actor.userId === command.actorId &&
      actor.userId === command.context.buyerId,
    "identity_mismatch",
  );
}
export function assertSnapshot(
  snapshot: ProviderSnapshot,
  binding: Binding,
): void {
  requireThat(
    contextKey(snapshot.context) === contextKey(binding.context) &&
      snapshot.subscriptionId === binding.subscriptionId,
    "snapshot_scope_mismatch",
  );
  requireThat(
    snapshot.offerId === binding.offer.id &&
      snapshot.offerVersion === binding.offer.version,
    "snapshot_offer_mismatch",
  );
  requireThat(
    snapshot.currency === binding.offer.price.currency,
    "currency_mismatch",
  );
  requireThat(snapshot.complete === true, "incomplete_snapshot");
  requireThat(text(snapshot.status), "invalid_snapshot");
  const lines = new Set<string>();
  for (const invoice of snapshot.invoices) {
    assertMoney(invoice.due);
    requireThat(
      invoice.due.currency === snapshot.currency,
      "currency_mismatch",
    );
    requireThat(
      integer(invoice.paidMinorUnits) && integer(invoice.start) &&
        integer(invoice.end) && invoice.end > invoice.start &&
        ["open", "paid", "void", "uncollectible"].includes(invoice.status) &&
        ["provider", "manual", "credit", "free"].includes(invoice.source) &&
        text(invoice.invoiceId) && text(invoice.lineId) &&
        (invoice.paymentId === null || text(invoice.paymentId)),
      "invalid_invoice",
    );
    const key = canonical([invoice.invoiceId, invoice.lineId]);
    requireThat(!lines.has(key), "duplicate_invoice_line");
    lines.add(key);
  }
  const adjustments = new Set<string>();
  for (const adjustment of snapshot.adjustments) {
    assertMoney(adjustment.money);
    requireThat(
      adjustment.money.currency === snapshot.currency,
      "currency_mismatch",
    );
    requireThat(
      text(adjustment.id) && text(adjustment.invoiceId) &&
        ["refund", "dispute"].includes(adjustment.kind) &&
        ["pending", "succeeded", "resolved"].includes(adjustment.status),
      "invalid_adjustment",
    );
    requireThat(!adjustments.has(adjustment.id), "duplicate_adjustment");
    adjustments.add(adjustment.id);
  }
}
