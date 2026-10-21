import { test } from "node:test";
import assert from "node:assert/strict";
import {
  canonical,
  CommerceError,
  CommerceSimulation,
  FakeCommercialProvider,
  FixtureEventVerifier,
  MemoryCommercialStore,
} from "../_shared/trainer_commerce/mod.ts";
import type {
  Actor,
  Binding,
  Command,
  Context,
  InvoiceFact,
  ProviderSnapshot,
  SimulationPolicy,
} from "../_shared/trainer_commerce/mod.ts";

// Importes y tiempos sintéticos: no son tarifas ni condiciones comerciales aprobadas.
const policy: SimulationPolicy = {
  version: "fixture-policy-v1",
  scope: "simulation_only",
};
function fixture(circuit: Context["circuit"] = "platform_access") {
  const context: Context = {
    provider: "fake",
    environment: { mode: "simulation", namespace: "fixture-A" },
    circuit,
    accountId: circuit === "platform_access"
      ? "platform-account"
      : "coach-account",
    sellerId: circuit === "platform_access" ? "platform" : "coach",
    buyerId: circuit === "platform_access" ? "coach" : "student",
    contractId: "contract-A",
  };
  const binding: Binding = {
    context,
    subscriptionId: "subscription-A",
    offer: {
      id: "offer-A",
      version: 1,
      circuit,
      sellerId: context.sellerId,
      price: { minorUnits: 1000, currency: "EUR" },
      capacity: circuit === "platform_access" ? 5 : null,
      termsVersion: "fixture-terms-v1",
    },
    sources: {
      activeClients: 3,
      manualGrant: null,
      relation: "active",
      merchant: "ready",
    },
  };
  const paid: InvoiceFact = {
    invoiceId: "invoice-A",
    lineId: "line-A",
    paymentId: "payment-A",
    source: "provider",
    status: "paid",
    due: { minorUnits: 1000, currency: "EUR" },
    paidMinorUnits: 1000,
    start: 0,
    end: 20_000,
  };
  const snapshot: ProviderSnapshot = {
    context,
    subscriptionId: binding.subscriptionId,
    offerId: binding.offer.id,
    offerVersion: 1,
    currency: "EUR",
    status: "active",
    complete: true,
    invoices: [paid],
    adjustments: [],
  };
  const store = new MemoryCommercialStore();
  store.register(binding);
  const provider = new FakeCommercialProvider();
  provider.setCanonical(snapshot);
  let now = 10_000;
  const engine = () => new CommerceSimulation(store, provider, () => now);
  const actor: Actor = { userId: context.buyerId, mfa: true };
  const command: Command = {
    id: "operation-A",
    context,
    actorId: actor.userId,
    expectedRevision: 0,
    offer: binding.offer,
  };
  const verifier = new FixtureEventVerifier();
  const signal = (id: string, hints: unknown = {}) => {
    const input = {
      body: JSON.stringify({ id, hints }),
      proof: `fixture-only-${id}`,
    };
    verifier.register(input, {
      id,
      context,
      subscriptionId: binding.subscriptionId,
    });
    return input;
  };
  return {
    context,
    binding,
    snapshot,
    paid,
    store,
    provider,
    engine,
    actor,
    command,
    verifier,
    signal,
    advance: (milliseconds: number) => {
      now += milliseconds;
    },
    now: () => now,
  };
}
function code(expected: string) {
  return (error: unknown) =>
    error instanceof CommerceError && error.code === expected;
}

test("01 · Checkout o retorno local no conceden acceso ni acreditan pago", async () => {
  const f = fixture();
  const checkout = await f.engine().submit(f.actor, f.command);
  assert.match(checkout.id, /^simulation_checkout_/);
  assert.equal(f.store.view(f.context).decision, null);
  assert.deepEqual(f.store.view(f.context).paidLedger, []);
  // Incluso la conciliación canónica sin una política solo registra hechos.
  const decision = await f.engine().reconcile(f.context);
  assert.ok(decision !== "busy");
  assert.equal(decision.kind, "policy_required");
  assert.equal(decision.proposedCapacity, null);
});

test("02 · respuesta perdida recupera la orden estable con otra instancia del coordinador", async () => {
  const f = fixture();
  f.provider.loseNextCreateResponse = true;
  await assert.rejects(
    f.engine().submit(f.actor, f.command),
    code("simulated_response_lost"),
  );
  assert.equal(f.store.command(f.command.id).state, "uncertain");
  const recovered = await f.engine().submit(f.actor, f.command);
  assert.equal(recovered.id, "simulation_checkout_1");
  assert.deepEqual(await f.engine().submit(f.actor, f.command), recovered);
  assert.equal(f.provider.created, 1);
});

test("03 · reutilizar operación con otro precio, moneda, capacidad o cuenta se rechaza", async () => {
  const f = fixture();
  await f.engine().submit(f.actor, f.command);
  for (
    const changed of [
      {
        ...f.command,
        offer: {
          ...f.command.offer,
          price: { minorUnits: 2000, currency: "EUR" },
        },
      },
      {
        ...f.command,
        offer: {
          ...f.command.offer,
          price: { minorUnits: 1000, currency: "USD" },
        },
      },
      { ...f.command, offer: { ...f.command.offer, capacity: 8 } },
      { ...f.command, context: { ...f.context, accountId: "other-account" } },
    ]
  ) {
    await assert.rejects(
      f.engine().submit(f.actor, changed),
      code("idempotency_conflict"),
    );
  }
  assert.equal(f.provider.created, 1);
});

test("04 · dos instancias y operaciones simultáneas no abren dos suscripciones de contrato", async () => {
  const f = fixture();
  const results = await Promise.allSettled([
    f.engine().submit(f.actor, f.command),
    f.engine().submit(f.actor, { ...f.command, id: "other-operation" }),
  ]);
  assert.equal(results.filter((item) => item.status === "fulfilled").length, 1);
  const failure = results.find((item) => item.status === "rejected");
  assert.ok(failure);
  assert.equal(failure.reason.code, "contract_checkout_exists");
  assert.equal(f.provider.created, 1);
});

test("05 · eventos repetidos o desordenados consultan lo canónico y no duplican una factura", async () => {
  const finalStates: unknown[] = [];
  for (const reverse of [false, true]) {
    const f = fixture();
    const old = f.signal("event-old", { created: 100, status: "past_due" });
    const recent = f.signal("event-recent", { created: 100, status: "active" });
    for (const input of reverse ? [recent, old] : [old, recent]) {
      assert.equal(await f.engine().receive(input, f.verifier), "new");
      await f.engine().reconcile(f.context, policy);
      assert.equal(await f.engine().receive(input, f.verifier), "duplicate");
    }
    const view = f.store.view(f.context);
    assert.equal(view.paidLedger.length, 1);
    assert.equal(view.history.length, 1);
    assert.equal(view.pending, false);
    finalStates.push([view.snapshot, view.decision, view.paidLedger]);
  }
  assert.deepEqual(finalStates[0], finalStates[1]);
});

test("06 · fixtures alteradas, entorno, cuenta u objeto incorrectos no registran hechos", async () => {
  const f = fixture();
  const input = f.signal("signed-fixture");
  for (
    const changed of [{ ...input, proof: "wrong" }, {
      ...input,
      body: input.body + " ",
    }]
  ) {
    await assert.rejects(
      f.engine().receive(changed, f.verifier),
      code("unverified_fixture_event"),
    );
  }
  for (
    const context of [
      {
        ...f.context,
        environment: { mode: "sandbox" as const, namespace: "fixture-A" },
      },
      {
        ...f.context,
        environment: { mode: "simulation" as const, namespace: "fixture-B" },
      },
      { ...f.context, accountId: "other-account" },
    ]
  ) {
    await assert.rejects(
      f.engine().receive(input, {
        verify: () =>
          Promise.resolve({
            id: "bad",
            context,
            subscriptionId: "subscription-A",
          }),
      }),
    );
  }
  assert.throws(
    () =>
      f.store.acceptVerifiedEvent({
        id: "wrong-object",
        context: f.context,
        subscriptionId: "other-subscription",
      }),
    code("event_object_mismatch"),
  );
  assert.deepEqual(f.store.view(f.context).paidLedger, []);
  assert.equal(f.store.view(f.context).pending, false);
});

test("07 · inbox pendiente sobrevive a recrear coordinador; una orden incierta nunca se reenvía a ciegas", async () => {
  const f = fixture();
  await f.engine().receive(f.signal("pending"), f.verifier);
  assert.equal(f.store.view(f.context).pending, true);
  await f.engine().reconcile(f.context, policy);
  assert.equal(f.store.view(f.context).pending, false);
  f.provider.available = false;
  await assert.rejects(
    f.engine().submit(f.actor, { ...f.command, expectedRevision: 1 }),
    code("provider_unavailable"),
  );
  f.provider.available = true;
  await assert.rejects(
    f.engine().submit(f.actor, { ...f.command, expectedRevision: 1 }),
    code("command_uncertain"),
  );
  assert.equal(f.provider.created, 0);
});

test("08 · fencing impide confirmar con lease vencido, sustituido o alterado", () => {
  const f = fixture();
  const old = f.store.claimReconciliation(f.context, f.now(), 10)!;
  assert.equal(f.store.claimReconciliation(f.context, f.now(), 10), null);
  f.advance(11);
  const current = f.store.claimReconciliation(f.context, f.now(), 10)!;
  assert.throws(
    () => f.store.commitFactsAndDecision(old, f.snapshot, policy, f.now()),
    code("stale_lease"),
  );
  assert.throws(
    () =>
      f.store.commitFactsAndDecision(
        { ...current, until: current.until + 1000 },
        f.snapshot,
        policy,
        f.now(),
      ),
    code("stale_lease"),
  );
  f.store.releaseReconciliation(old);
  f.store.commitFactsAndDecision(current, f.snapshot, policy, f.now());
  assert.equal(f.store.view(f.context).paidLedger.length, 1);
});

test("09 · active con pago pendiente, parcial o factura anterior abierta requiere política", async () => {
  for (
    const invoices of [
      [{
        ...fixture().paid,
        status: "open" as const,
        paymentId: null,
        paidMinorUnits: 0,
      }],
      [{ ...fixture().paid, paidMinorUnits: 500 }],
      [{ ...fixture().paid, paidMinorUnits: 1100 }],
      [fixture().paid, {
        ...fixture().paid,
        invoiceId: "old",
        lineId: "old",
        status: "open" as const,
        paymentId: null,
        paidMinorUnits: 0,
        end: 5000,
      }],
      [fixture().paid, {
        ...fixture().paid,
        invoiceId: "uncollectible",
        lineId: "uncollectible",
        status: "uncollectible" as const,
        paymentId: null,
        paidMinorUnits: 0,
        end: 5000,
      }],
      [fixture().paid, {
        ...fixture().paid,
        invoiceId: "partial",
        lineId: "partial",
        paidMinorUnits: 500,
      }],
    ]
  ) {
    const f = fixture();
    f.provider.setCanonical({ ...f.snapshot, invoices });
    const result = await f.engine().reconcile(f.context, policy);
    assert.ok(result !== "busy");
    assert.equal(result.kind, "policy_required");
    assert.equal(result.proposedCapacity, null);
  }
});

test("10 · pago tardío, devoluciones y disputa conservan el pago y requieren revisión", async () => {
  const f = fixture();
  f.provider.setCanonical({
    ...f.snapshot,
    invoices: [{
      ...f.paid,
      status: "open",
      paidMinorUnits: 0,
      paymentId: null,
    }],
  });
  await f.engine().reconcile(f.context, policy);
  f.provider.setCanonical(f.snapshot);
  const paid = await f.engine().reconcile(f.context, policy);
  assert.ok(paid !== "busy");
  assert.equal(paid.proposedCapacity, 5);
  for (
    const [kind, amount] of [["refund", 300], ["refund", 1000], [
      "dispute",
      1000,
    ]] as const
  ) {
    f.provider.setCanonical({
      ...f.snapshot,
      adjustments: [{
        id: `${kind}-${amount}`,
        invoiceId: "invoice-A",
        kind,
        status: kind === "refund" ? "succeeded" : "pending",
        money: { minorUnits: amount, currency: "EUR" },
      }],
    });
    const decision = await f.engine().reconcile(f.context, policy);
    assert.ok(decision !== "busy");
    assert.equal(decision.reason, "adjustment_requires_review");
    assert.equal(decision.proposedCapacity, null);
    assert.equal(f.store.view(f.context).paidLedger[0].money.minorUnits, 1000);
  }
  assert.equal(f.store.view(f.context).history.length, 5);
});

test("11 · factura cero, crédito, gratuidad y pago manual nunca simulan un ingreso del proveedor", async () => {
  for (const source of ["provider", "credit", "free", "manual"] as const) {
    const f = fixture();
    const invoice = {
      ...f.paid,
      source,
      ...(source === "provider"
        ? { due: { minorUnits: 0, currency: "EUR" }, paidMinorUnits: 0 }
        : {}),
    };
    f.provider.setCanonical({ ...f.snapshot, invoices: [invoice] });
    const decision = await f.engine().reconcile(f.context, policy);
    assert.ok(decision !== "busy");
    assert.equal(decision.kind, "policy_required");
    assert.deepEqual(f.store.view(f.context).paidLedger, []);
  }
});

test("12 · cobro al alumno queda en su cuenta y nunca renueva cupos de plataforma", async () => {
  const f = fixture("coach_service");
  const other: Binding = {
    ...f.binding,
    context: { ...f.context, accountId: "coach-B", sellerId: "coach-B" },
    offer: { ...f.binding.offer, sellerId: "coach-B" },
    subscriptionId: "subscription-B",
  };
  f.store.register(other);
  assert.throws(
    () =>
      f.store.acceptVerifiedEvent({
        id: "crossed",
        context: other.context,
        subscriptionId: "subscription-A",
      }),
    code("event_object_mismatch"),
  );
  const decision = await f.engine().reconcile(f.context, policy);
  assert.ok(decision !== "busy");
  assert.equal(decision.kind, "unchanged");
  assert.equal(decision.proposedCapacity, null);
  assert.deepEqual(f.store.view(other.context).paidLedger, []);
  f.provider.setCanonical({ ...f.snapshot, context: other.context });
  await assert.rejects(
    f.engine().reconcile(other.context, policy),
    code("snapshot_scope_mismatch"),
  );
});

test("13 · fuente manual permanece separada y no se sobrescribe con una factura pagada", async () => {
  const f = fixture();
  const sources = {
    ...f.binding.sources,
    manualGrant: { capacity: 9, validUntil: 30_000 },
  };
  f.store.updateSources(f.context, 0, sources);
  const decision = await f.engine().reconcile(f.context, policy);
  assert.ok(decision !== "busy");
  assert.equal(decision.reason, "manual_source_precedence_not_approved");
  assert.deepEqual(f.store.view(f.context).binding.sources, sources);
});

test("14 · capacidad menor que clientes activos informa conflicto sin eliminar nada", async () => {
  const f = fixture();
  f.store.updateSources(f.context, 0, {
    ...f.binding.sources,
    activeClients: 6,
  });
  const decision = await f.engine().reconcile(f.context, policy);
  assert.ok(decision !== "busy");
  assert.equal(decision.kind, "conflict");
  assert.equal(decision.proposedCapacity, null);
  assert.equal(f.store.view(f.context).binding.sources.activeClients, 6);
});

test("15 · cancelación, baja y desconexión son hechos distintos sin automatizar cobros o vínculo", async () => {
  const f = fixture();
  f.provider.setCanonical({ ...f.snapshot, status: "canceled" });
  const canceled = await f.engine().reconcile(f.context, policy);
  assert.ok(canceled !== "busy");
  assert.equal(canceled.kind, "policy_required");
  for (const state of ["ended", "disconnected"] as const) {
    const service = fixture("coach_service");
    service.store.updateSources(service.context, 0, {
      ...service.binding.sources,
      ...(state === "ended"
        ? { relation: "ended" as const }
        : { merchant: "disconnected" as const }),
    });
    const decision = await service.engine().reconcile(service.context, policy);
    assert.ok(decision !== "busy");
    assert.equal(decision.reason, "service_lifecycle_requires_review");
    assert.equal(
      service.store.view(service.context).snapshot?.status,
      "active",
    );
    await assert.rejects(
      service.engine().submit(service.actor, {
        ...service.command,
        expectedRevision: 2,
      }),
      code("service_not_chargeable"),
    );
  }
});

test("16 · proveedor caído, páginas parciales y estado desconocido no inventan cancelación", async () => {
  const f = fixture();
  await f.engine().reconcile(f.context, policy);
  const initial = f.store.view(f.context);
  f.provider.available = false;
  await assert.rejects(
    f.engine().reconcile(f.context, policy),
    code("provider_unavailable"),
  );
  assert.deepEqual(f.store.view(f.context), initial);
  f.provider.available = true;
  f.provider.setCanonical({ ...f.snapshot, complete: false, invoices: [] });
  await assert.rejects(
    f.engine().reconcile(f.context, policy),
    code("incomplete_snapshot"),
  );
  assert.deepEqual(f.store.view(f.context).snapshot, initial.snapshot);
  f.provider.setCanonical({ ...f.snapshot, status: "future_unknown_state" });
  const unknown = await f.engine().reconcile(f.context, policy);
  assert.ok(unknown !== "busy");
  assert.equal(unknown.kind, "policy_required");
  assert.equal(f.store.view(f.context).paidLedger.length, 1);
});

test("17 · evidencia de actor cambiado o sin MFA no abre Checkout", async () => {
  const f = fixture();
  await assert.rejects(
    f.engine().submit({ ...f.actor, mfa: false }, f.command),
    code("mfa_required"),
  );
  await assert.rejects(
    f.engine().submit({ userId: "other", mfa: true }, f.command),
    code("identity_mismatch"),
  );
  assert.equal(f.provider.created, 0);
});

test("18 · cambio de cupo/última plaza durante lectura invalida la propuesta anterior", async () => {
  const f = fixture();
  f.provider.beforeReadReturns = () => {
    f.store.updateSources(f.context, 0, {
      ...f.binding.sources,
      activeClients: 6,
    });
  };
  await assert.rejects(
    f.engine().reconcile(f.context, policy),
    code("revision_conflict"),
  );
  assert.equal(f.store.view(f.context).decision, null);
  assert.equal(f.store.view(f.context).pending, true);
  const current = await f.engine().reconcile(f.context, policy);
  assert.ok(current !== "busy");
  assert.equal(current.kind, "conflict");
  assert.throws(
    () => f.store.updateSources(f.context, 0, f.binding.sources),
    code("revision_conflict"),
  );
});

test("moneda, importes no enteros, contexto y líneas duplicadas se validan antes de registrar", async () => {
  const invalid: ProviderSnapshot[] = [];
  const f = fixture();
  invalid.push({ ...f.snapshot, currency: "USD" });
  invalid.push({
    ...f.snapshot,
    invoices: [{ ...f.paid, due: { minorUnits: 1000, currency: "USD" } }],
  });
  for (const amount of [-1, 0.1, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    invalid.push({
      ...f.snapshot,
      invoices: [{ ...f.paid, paidMinorUnits: amount }],
    });
  }
  invalid.push({ ...f.snapshot, invoices: [f.paid, f.paid] });
  invalid.push({ ...f.snapshot, offerVersion: 2 });
  for (const snapshot of invalid) {
    f.provider.setCanonical(snapshot);
    await assert.rejects(f.engine().reconcile(f.context, policy));
    assert.deepEqual(f.store.view(f.context).paidLedger, []);
  }
  assert.throws(
    () => canonical({ invalid: undefined }),
    code("non_json_value"),
  );
});

test("señal nueva durante consulta exige releer y nunca confirma una recomendación obsoleta", async () => {
  const f = fixture();
  await f.engine().receive(f.signal("first"), f.verifier);
  f.provider.beforeReadReturns = async () => {
    f.provider.setCanonical({ ...f.snapshot, status: "past_due" });
    await f.engine().receive(f.signal("second"), f.verifier);
  };
  await assert.rejects(
    f.engine().reconcile(f.context, policy),
    code("reconciliation_changed"),
  );
  assert.equal(f.store.view(f.context).decision, null);
  assert.equal(f.store.view(f.context).pending, true);
  const latest = await f.engine().reconcile(f.context, policy);
  assert.ok(latest !== "busy");
  assert.equal(latest.kind, "policy_required");
  assert.equal(f.store.view(f.context).pending, false);
});

test("un pago histórico no se reescribe y las copias no exponen estado mutable", async () => {
  const f = fixture();
  await f.engine().reconcile(f.context, policy);
  const outside = f.store.view(f.context);
  outside.binding.sources.activeClients = 99;
  outside.paidLedger[0].money.minorUnits = 1;
  assert.equal(f.store.view(f.context).binding.sources.activeClients, 3);
  assert.equal(f.store.view(f.context).paidLedger[0].money.minorUnits, 1000);
  f.provider.setCanonical({
    ...f.snapshot,
    invoices: [{ ...f.paid, paidMinorUnits: 1100 }],
  });
  await assert.rejects(
    f.engine().reconcile(f.context, policy),
    code("economic_fact_conflict"),
  );
  assert.equal(f.store.view(f.context).history.length, 1);
});
