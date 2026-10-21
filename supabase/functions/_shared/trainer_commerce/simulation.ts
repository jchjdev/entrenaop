import {
  assertActor,
  assertOffer,
  assertSimulation,
  assertSnapshot,
  assertSources,
  canonical,
  CommerceError,
  contextKey,
  integer,
  requireThat,
  text,
} from "./model.ts";
import type {
  Actor,
  Binding,
  CheckoutReference,
  Command,
  CommandRecord,
  Context,
  Decision,
  Lease,
  PaidEvidence,
  ProviderSnapshot,
  SimulationPolicy,
  Sources,
  VerifiedSignal,
} from "./model.ts";
import type {
  CommercialProviderPort,
  CommercialStorePort,
  VerifyEventPort,
} from "./ports.ts";
import { evaluateCommerce, paidEvidence } from "./policy.ts";

type Entry = {
  value: Binding;
  revision: number;
  signalSequence: number;
  processedSequence: number;
  generation: number;
  lease: Lease | null;
  snapshot: ProviderSnapshot | null;
  decision: Decision | null;
  history: ProviderSnapshot[];
  evidence: Map<string, PaidEvidence>;
};

// Almacén de prueba en memoria: sus pasos síncronos no acreditan transacciones SQL.
export class MemoryCommercialStore implements CommercialStorePort {
  private entries = new Map<string, Entry>();
  private commands = new Map<string, CommandRecord>();
  private contractCommands = new Map<string, string>();
  private events = new Set<string>();

  register(binding: Binding): void {
    assertSimulation(binding.context);
    assertOffer(binding.offer, binding.context);
    assertSources(binding.sources);
    requireThat(text(binding.subscriptionId), "invalid_binding");
    const key = contextKey(binding.context);
    requireThat(!this.entries.has(key), "binding_exists");
    this.entries.set(key, {
      value: structuredClone(binding),
      revision: 0,
      signalSequence: 0,
      processedSequence: 0,
      generation: 0,
      lease: null,
      snapshot: null,
      decision: null,
      history: [],
      evidence: new Map(),
    });
  }

  private entry(context: Context): Entry {
    assertSimulation(context);
    const entry = this.entries.get(contextKey(context));
    requireThat(entry, "unknown_binding");
    return entry;
  }

  binding(context: Context): { value: Binding; revision: number } {
    const entry = this.entry(context);
    return { value: structuredClone(entry.value), revision: entry.revision };
  }

  recordCommand(command: Command): CommandRecord {
    assertSimulation(command.context);
    assertOffer(command.offer, command.context);
    requireThat(
      text(command.id) && text(command.actorId) &&
        integer(command.expectedRevision),
      "invalid_command",
    );
    const previous = this.commands.get(command.id);
    if (previous) {
      requireThat(
        canonical(previous.command) === canonical(command),
        "idempotency_conflict",
      );
      return structuredClone(previous);
    }
    const entry = this.entry(command.context);
    requireThat(
      canonical(command.offer) === canonical(entry.value.offer),
      "offer_mismatch",
    );
    requireThat(
      command.expectedRevision === entry.revision,
      "revision_conflict",
    );
    if (command.context.circuit === "coach_service") {
      requireThat(
        entry.value.sources.relation === "active" &&
          entry.value.sources.merchant === "ready",
        "service_not_chargeable",
      );
    }
    const key = contextKey(command.context);
    requireThat(!this.contractCommands.has(key), "contract_checkout_exists");
    const record: CommandRecord = {
      command: structuredClone(command),
      state: "prepared",
      checkout: null,
    };
    this.commands.set(command.id, record);
    this.contractCommands.set(key, command.id);
    return structuredClone(record);
  }

  command(id: string): CommandRecord {
    const record = this.commands.get(id);
    requireThat(record, "unknown_command");
    return structuredClone(record);
  }

  claimCommand(id: string): boolean {
    const record = this.commands.get(id);
    requireThat(record, "unknown_command");
    if (record.state !== "prepared") return false;
    record.state = "submitting";
    return true;
  }

  completeCommand(id: string, reference: CheckoutReference): void {
    const record = this.commands.get(id);
    requireThat(record, "unknown_command");
    requireThat(
      reference.commandId === id && text(reference.id) &&
        contextKey(reference.context) === contextKey(record.command.context),
      "checkout_scope_mismatch",
    );
    requireThat(
      record.checkout === null ||
        canonical(record.checkout) === canonical(reference),
      "checkout_conflict",
    );
    record.checkout = structuredClone(reference);
    record.state = "completed";
  }

  uncertainCommand(id: string): void {
    const record = this.commands.get(id);
    requireThat(record, "unknown_command");
    if (record.state !== "completed") record.state = "uncertain";
  }

  acceptVerifiedEvent(signal: VerifiedSignal): "new" | "duplicate" {
    requireThat(text(signal.id), "invalid_event");
    const entry = this.entry(signal.context);
    requireThat(
      signal.subscriptionId === entry.value.subscriptionId,
      "event_object_mismatch",
    );
    const key = canonical([contextKey(signal.context), signal.id]);
    if (this.events.has(key)) return "duplicate";
    this.events.add(key);
    entry.signalSequence++;
    return "new";
  }

  claimReconciliation(
    context: Context,
    now: number,
    ttl: number,
  ): Lease | null {
    requireThat(
      integer(now) && integer(ttl, 1) && integer(now + ttl),
      "invalid_clock",
    );
    const entry = this.entry(context);
    if (entry.lease !== null && entry.lease.until > now) return null;
    entry.generation++;
    entry.lease = {
      context: structuredClone(context),
      generation: entry.generation,
      until: now + ttl,
      expectedRevision: entry.revision,
      signalSequence: entry.signalSequence,
    };
    return structuredClone(entry.lease);
  }

  commitFactsAndDecision(
    lease: Lease,
    snapshot: ProviderSnapshot,
    policy: SimulationPolicy | null,
    now: number,
  ): Decision {
    const entry = this.entry(lease.context);
    requireThat(
      integer(now) && entry.lease !== null &&
        canonical(entry.lease) === canonical(lease) &&
        now < lease.until,
      "stale_lease",
    );
    requireThat(entry.revision === lease.expectedRevision, "revision_conflict");
    requireThat(
      entry.signalSequence === lease.signalSequence,
      "reconciliation_changed",
    );
    assertSnapshot(snapshot, entry.value);
    const decision = evaluateCommerce(snapshot, entry.value, policy, now);
    const evidence = paidEvidence(snapshot);
    for (const fact of evidence) {
      const key = canonical([fact.invoiceId, fact.lineId, fact.paymentId]);
      const previous = entry.evidence.get(key);
      // Los ajustes son hechos separados; no reescriben un pago ya registrado.
      requireThat(
        !previous || canonical(previous) === canonical(fact),
        "economic_fact_conflict",
      );
    }
    for (const fact of evidence) {
      entry.evidence.set(
        canonical([fact.invoiceId, fact.lineId, fact.paymentId]),
        structuredClone(fact),
      );
    }
    if (canonical(entry.snapshot) !== canonical(snapshot)) {
      entry.history.push(structuredClone(snapshot));
    }
    entry.snapshot = structuredClone(snapshot);
    entry.decision = structuredClone(decision);
    entry.processedSequence = lease.signalSequence;
    entry.revision++;
    entry.lease = null;
    return structuredClone(decision);
  }

  releaseReconciliation(lease: Lease): void {
    const entry = this.entry(lease.context);
    if (entry.lease !== null && canonical(entry.lease) === canonical(lease)) {
      entry.lease = null;
    }
  }

  updateSources(
    context: Context,
    expectedRevision: number,
    sources: Sources,
  ): void {
    assertSources(sources);
    const entry = this.entry(context);
    requireThat(expectedRevision === entry.revision, "revision_conflict");
    entry.value.sources = structuredClone(sources);
    entry.revision++;
    entry.signalSequence++;
  }

  view(context: Context) {
    const entry = this.entry(context);
    return structuredClone({
      binding: entry.value,
      revision: entry.revision,
      snapshot: entry.snapshot,
      decision: entry.decision,
      history: entry.history,
      paidLedger: [...entry.evidence.values()],
      pending: entry.signalSequence > entry.processedSequence,
    });
  }
}

// Proveedor sintético: IDs locales sin URL, red, SDK, dinero ni claves.
export class FakeCommercialProvider implements CommercialProviderPort {
  private checkouts = new Map<
    string,
    { command: Command; reference: CheckoutReference }
  >();
  private snapshots = new Map<string, ProviderSnapshot>();
  created = 0;
  available = true;
  loseNextCreateResponse = false;
  beforeReadReturns: (() => Promise<void> | void) | null = null;

  setCanonical(snapshot: ProviderSnapshot): void {
    assertSimulation(snapshot.context);
    this.snapshots.set(contextKey(snapshot.context), structuredClone(snapshot));
  }

  prepareCheckout(command: Command): Promise<CheckoutReference> {
    assertSimulation(command.context);
    requireThat(this.available, "provider_unavailable");
    const previous = this.checkouts.get(command.id);
    if (previous) {
      requireThat(
        canonical(previous.command) === canonical(command),
        "idempotency_conflict",
      );
      return Promise.resolve(structuredClone(previous.reference));
    }
    const reference = {
      id: `simulation_checkout_${++this.created}`,
      commandId: command.id,
      context: structuredClone(command.context),
    };
    this.checkouts.set(command.id, {
      command: structuredClone(command),
      reference,
    });
    if (this.loseNextCreateResponse) {
      this.loseNextCreateResponse = false;
      throw new CommerceError("simulated_response_lost");
    }
    return Promise.resolve(structuredClone(reference));
  }

  recoverCheckout(command: Command): Promise<CheckoutReference | null> {
    assertSimulation(command.context);
    requireThat(this.available, "provider_unavailable");
    const previous = this.checkouts.get(command.id);
    requireThat(
      !previous || canonical(previous.command) === canonical(command),
      "idempotency_conflict",
    );
    return Promise.resolve(
      previous ? structuredClone(previous.reference) : null,
    );
  }

  async readCanonical(context: Context): Promise<ProviderSnapshot> {
    assertSimulation(context);
    requireThat(this.available, "provider_unavailable");
    const current = this.snapshots.get(contextKey(context));
    requireThat(current, "provider_object_missing");
    const result = structuredClone(current);
    const hook = this.beforeReadReturns;
    this.beforeReadReturns = null;
    await hook?.();
    return result;
  }
}

// Lista de fixtures exactas. NO verifica firmas Stripe, tokens ni autenticación real.
export class FixtureEventVerifier implements VerifyEventPort {
  private fixtures = new Map<string, VerifiedSignal>();
  register(
    input: { body: string; proof: string },
    signal: VerifiedSignal,
  ): void {
    assertSimulation(signal.context);
    const key = canonical(input);
    requireThat(!this.fixtures.has(key), "fixture_exists");
    this.fixtures.set(key, structuredClone(signal));
  }
  verify(
    input: { body: string; proof: string },
  ): Promise<VerifiedSignal> {
    const signal = this.fixtures.get(canonical(input));
    requireThat(signal, "unverified_fixture_event");
    return Promise.resolve(structuredClone(signal));
  }
}

export class CommerceSimulation {
  private store: CommercialStorePort;
  private provider: CommercialProviderPort;
  private now: () => number;

  constructor(
    store: CommercialStorePort,
    provider: CommercialProviderPort,
    clock: () => number,
  ) {
    this.store = store;
    this.provider = provider;
    this.now = clock;
  }

  async submit(actor: Actor, command: Command): Promise<CheckoutReference> {
    assertSimulation(command.context);
    assertActor(actor, command);
    // Copia estable antes del primer await: el consumidor no puede cambiar la orden en vuelo.
    const stable = structuredClone(command);
    const record = this.store.recordCommand(stable);
    if (record.checkout) return record.checkout;
    if (!this.store.claimCommand(stable.id)) {
      const recovered = await this.provider.recoverCheckout(stable);
      requireThat(recovered, "command_uncertain");
      this.store.completeCommand(stable.id, recovered);
      return recovered;
    }
    try {
      const result = await this.provider.prepareCheckout(stable);
      this.store.completeCommand(stable.id, result);
      return result;
    } catch (error) {
      this.store.uncertainCommand(stable.id);
      throw error;
    }
  }

  async receive(
    input: { body: string; proof: string },
    verifier: VerifyEventPort,
  ): Promise<"new" | "duplicate"> {
    const signal = await verifier.verify(input);
    assertSimulation(signal.context);
    return this.store.acceptVerifiedEvent(signal);
  }

  async reconcile(
    context: Context,
    policy: SimulationPolicy | null = null,
    ttl = 1000,
  ): Promise<Decision | "busy"> {
    assertSimulation(context);
    const stable = structuredClone(context);
    const lease = this.store.claimReconciliation(stable, this.now(), ttl);
    if (!lease) return "busy";
    try {
      const snapshot = await this.provider.readCanonical(stable);
      return this.store.commitFactsAndDecision(
        lease,
        snapshot,
        policy,
        this.now(),
      );
    } catch (error) {
      this.store.releaseReconciliation(lease);
      throw error;
    }
  }
}
