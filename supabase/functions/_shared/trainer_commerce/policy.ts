import {
  assertOffer,
  assertSimulation,
  assertSnapshot,
  assertSources,
  integer,
  requireThat,
  text,
} from "./model.ts";
import type {
  Binding,
  Decision,
  PaidEvidence,
  ProviderSnapshot,
  SimulationPolicy,
} from "./model.ts";

export function paidEvidence(snapshot: ProviderSnapshot): PaidEvidence[] {
  return snapshot.invoices.filter((line) =>
    line.status === "paid" &&
    line.source === "provider" && line.paymentId !== null &&
    line.due.minorUnits > 0 && line.paidMinorUnits >= line.due.minorUnits
  ).map((line) => ({
    invoiceId: line.invoiceId,
    lineId: line.lineId,
    paymentId: line.paymentId!,
    money: { minorUnits: line.paidMinorUnits, currency: line.due.currency },
    start: line.start,
    end: line.end,
  }));
}

// Solo devuelve una propuesta de ensayo; no existe puerto de concesión de acceso.
export function evaluateCommerce(
  snapshot: ProviderSnapshot,
  binding: Binding,
  policy: SimulationPolicy | null,
  now: number,
): Decision {
  assertSimulation(binding.context);
  assertOffer(binding.offer, binding.context);
  assertSources(binding.sources);
  assertSnapshot(snapshot, binding);
  requireThat(integer(now), "invalid_clock");
  const evidence = paidEvidence(snapshot);
  const decide = (
    kind: Decision["kind"],
    reason: string,
    capacity: number | null = null,
  ): Decision => ({
    kind,
    reason,
    policyVersion: policy?.version ?? null,
    paidEvidence: evidence,
    proposedCapacity: capacity,
  });
  if (policy === null) {
    return decide("policy_required", "commercial_policy_not_approved");
  }
  requireThat(
    policy.scope === "simulation_only" && text(policy.version),
    "invalid_policy",
  );
  if (snapshot.adjustments.length > 0) {
    return decide("policy_required", "adjustment_requires_review");
  }
  if (snapshot.status !== "active") {
    return decide("policy_required", "subscription_state_requires_review");
  }
  if (
    snapshot.invoices.some((line) =>
      line.source !== "provider" || line.due.minorUnits === 0
    )
  ) {
    return decide("policy_required", "non_cash_coverage_requires_review");
  }
  if (
    snapshot.invoices.some((line) =>
      ["open", "uncollectible"].includes(line.status) && line.start <= now
    )
  ) {
    return decide("policy_required", "unsettled_invoice_requires_review");
  }
  if (
    snapshot.invoices.some((line) =>
      line.status === "paid" &&
      (line.paymentId === null || line.paidMinorUnits < line.due.minorUnits)
    )
  ) {
    return decide("policy_required", "incomplete_payment_evidence");
  }
  if (
    snapshot.invoices.some((line) =>
      line.status === "paid" &&
      (line.due.minorUnits !== binding.offer.price.minorUnits ||
        line.paidMinorUnits !== line.due.minorUnits)
    )
  ) {
    return decide("policy_required", "nonstandard_amount_requires_review");
  }
  if (!evidence.some((line) => line.start <= now && now < line.end)) {
    return decide("policy_required", "no_verified_current_payment");
  }
  if (binding.context.circuit === "coach_service") {
    return decide(
      "unchanged",
      binding.sources.relation !== "active" ||
        binding.sources.merchant !== "ready"
        ? "service_lifecycle_requires_review"
        : "service_payment_recorded_without_entitlements",
    );
  }
  if (binding.sources.manualGrant !== null) {
    return decide("policy_required", "manual_source_precedence_not_approved");
  }
  const capacity = binding.offer.capacity!;
  if (binding.sources.activeClients > capacity) {
    return decide("conflict", "capacity_below_active_clients");
  }
  return decide("proposed_change", "simulation_paid_capacity", capacity);
}
