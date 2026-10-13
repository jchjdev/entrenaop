import { test } from "node:test";
import assert from "node:assert/strict";
import { handle, snapshot } from "../_shared/revenuecat.ts";
import type { Config } from "../_shared/revenuecat.ts";

const user = "10000000-0000-4000-8000-000000000001";
const other = "10000000-0000-4000-8000-000000000002";
const config: Config = {
  supabaseUrl: "https://sxbxfjqgoddzhtcyhalw.supabase.co",
  anonKey: "fixture-anon",
  serviceKey: "fixture-service",
  revenuecatKey: "fixture-provider",
  environment: "SANDBOX",
  appId: "app-test",
  webhookToken: "fixture-hook",
};
function payload(now = Date.now(), overrides: Record<string, unknown> = {}) {
  return {
    request_date: new Date(now).toISOString(),
    subscriber: {
      entitlements: {
        pro: {
          product_identifier: "entrenaop_pro_monthly",
          expires_date: new Date(now + 60000).toISOString(),
        },
      },
      subscriptions: {
        entrenaop_pro_monthly: {
          store: "test_store",
          is_sandbox: true,
          ...overrides,
        },
      },
    },
  };
}
function request(body: unknown, authorization = "Bearer fixture-user") {
  return new Request("https://example.invalid/function", {
    method: "POST",
    headers: { Authorization: authorization },
    body: JSON.stringify(body),
  });
}
function fixture(
  options: {
    identity?: string;
    authStatus?: number;
    providerStatus?: number;
    provider?: unknown;
    throttled?: boolean;
  } = {},
) {
  const writes: Record<string, unknown>[] = [];
  const reads: string[] = [];
  const fetcher: typeof fetch = async (url, init) => {
    await Promise.resolve();
    const path = String(url);
    reads.push(path);
    if (path.endsWith("/auth/v1/user")) {
      return Response.json({ id: options.identity ?? user }, {
        status: options.authStatus ?? 200,
      });
    }
    if (path.endsWith("/claim_revenuecat_sync")) {
      return Response.json(
        options.throttled
          ? { should_sync: false, access: { tier: "free" } }
          : { should_sync: true },
      );
    }
    if (path.startsWith("https://api.revenuecat.com/")) {
      assert.equal(
        (init!.headers as Record<string, string>).Authorization,
        "Bearer fixture-provider",
      );
      return Response.json(options.provider ?? payload(), {
        status: options.providerStatus ?? 200,
      });
    }
    if (path.endsWith("/apply_revenuecat_pro_snapshot")) {
      const body = JSON.parse(String(init!.body));
      writes.push(body);
      return Response.json({
        user_id: body.p_user_id,
        tier: body.p_active ? "pro" : "free",
      });
    }
    throw new Error("Llamada inesperada");
  };
  return { fetcher, writes, reads };
}
test("sin configuración no escribe ni consulta proveedores", async () => {
  const f = fixture();
  const response = await handle(
    request({}),
    { ...config, revenuecatKey: "" },
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 503);
  assert.equal(f.reads.length, 0);
});
test("el usuario autenticado coincide con la cuenta esperada antes de verificar", async () => {
  const f = fixture({ identity: other });
  const actual = await handle(
    request({ expected_user_id: user }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(actual.status, 409);
  assert.equal(f.writes.length, 0);
  assert.ok(!f.reads.some((path) => path.includes("revenuecat.com")));
});
test("la vigencia la obtiene del proveedor, ignorando importes y fechas del cliente", async () => {
  const f = fixture();
  const response = await handle(
    request({
      expected_user_id: user,
      active: true,
      valid_until: "2099-01-01",
    }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.equal(f.writes[0].p_user_id, user);
  assert.equal(f.writes[0].p_active, true);
  assert.ok(
    Date.parse(String(f.writes[0].p_valid_until)) < Date.parse("2099-01-01"),
  );
});
test("fallar el proveedor no revoca ni concede derechos", async () => {
  const f = fixture({ providerStatus: 503 });
  const response = await handle(
    request({ expected_user_id: user }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 502);
  assert.equal(f.writes.length, 0);
});
test("cliente sin autorización se rechaza antes de consultar Auth", async () => {
  const f = fixture();
  const response = await handle(
    request({ expected_user_id: user }, ""),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 401);
  assert.equal(f.reads.length, 0);
});
test("intervalo devuelve la instantánea sin consultar de nuevo RevenueCat", async () => {
  const f = fixture({ throttled: true });
  const response = await handle(
    request({ expected_user_id: user }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.equal(f.writes.length, 0);
  assert.ok(!f.reads.some((path) => path.includes("revenuecat.com")));
});
test("webhook falso no escribe ni consulta el proveedor", async () => {
  const f = fixture();
  const response = await handle(
    request({ event: {} }, "Bearer incorrecto"),
    config,
    "webhook",
    f.fetcher,
  );
  assert.equal(response.status, 401);
  assert.equal(f.reads.length, 0);
});
test("webhook de otra app o entorno se rechaza", async () => {
  for (const overrides of [{ app_id: "otra" }, { environment: "PRODUCTION" }]) {
    const f = fixture();
    const response = await handle(
      request({
        event: {
          id: "e1",
          type: "RENEWAL",
          app_id: "app-test",
          environment: "SANDBOX",
          ...overrides,
        },
      }, "Bearer fixture-hook"),
      config,
      "webhook",
      f.fetcher,
    );
    assert.equal(response.status, 400);
    assert.equal(f.writes.length, 0);
  }
});
test("una cancelación concilia el estado real y mantiene el identificador idempotente", async () => {
  const f = fixture();
  const response = await handle(
    request({
      event: {
        id: "e1",
        type: "CANCELLATION",
        app_id: "app-test",
        environment: "SANDBOX",
        app_user_id: user,
        expiration_at_ms: 1,
      },
    }, "Bearer fixture-hook"),
    config,
    "webhook",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.equal(f.writes[0].p_active, true);
  assert.equal(f.writes[0].p_event_id, "e1");
});
test("transferencia concilia ambas cuentas sin duplicar una misma identidad", async () => {
  const f = fixture();
  const response = await handle(
    request({
      event: {
        id: "e2",
        type: "TRANSFER",
        app_id: "app-test",
        environment: "SANDBOX",
        transferred_from: [user, user],
        transferred_to: [other],
      },
    }, "Bearer fixture-hook"),
    config,
    "webhook",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.deepEqual(f.writes.map((w) => w.p_user_id), [user, other]);
});
test("sandbox no se acepta en la base de producción y viceversa", async () => {
  for (
    const cfg of [
      { ...config, supabaseUrl: "https://production.supabase.co" },
      { ...config, environment: "PRODUCTION" },
    ]
  ) {
    const f = fixture();
    const response = await handle(request({}), cfg, "sync", f.fetcher);
    assert.equal(response.status, 503);
    assert.equal(f.reads.length, 0);
  }
});
test("respuesta inválida, producto distinto o entorno incorrecto no conceden Pro", () => {
  const now = Date.now();
  assert.throws(() =>
    snapshot(payload(now, { is_sandbox: false }), "SANDBOX", now)
  );
  assert.throws(() =>
    snapshot(payload(now, { store: "unknown" }), "SANDBOX", now)
  );
  assert.throws(() => snapshot(payload(now - 600000), "SANDBOX", now));
  assert.throws(() =>
    snapshot(
      {
        request_date: new Date(now).toISOString(),
        subscriber: { entitlements: { pro: { product_identifier: "otro" } } },
      },
      "SANDBOX",
      now,
    )
  );
});
test("caducidad y gracia dependen de los límites explícitos del proveedor", () => {
  const now = Date.now();
  const value = payload(now - 120000);
  value.request_date = new Date(now).toISOString();
  assert.equal(snapshot(value, "SANDBOX", now).p_active, false);
  const grace = payload(now - 120000, {
    grace_period_expires_date: new Date(now + 60000).toISOString(),
  });
  grace.request_date = new Date(now).toISOString();
  assert.equal(snapshot(grace, "SANDBOX", now).p_active, true);
});
test("JWT inválido no consulta compras ni escribe derechos", async () => {
  const f = fixture({ authStatus: 401 });
  const response = await handle(
    request({ expected_user_id: user }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 401);
  assert.equal(f.reads.length, 1);
  assert.equal(f.writes.length, 0);
});
test("un aviso TEST autenticado se reconoce sin crear derechos", async () => {
  const f = fixture();
  const response = await handle(
    request({ event: { type: "TEST" } }, "Bearer fixture-hook"),
    config,
    "webhook",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.equal(f.reads.length, 0);
});
test("una transferencia sin environment sigue verificando ambas cuentas con el proveedor", async () => {
  const f = fixture();
  const response = await handle(
    request({
      event: {
        id: "transfer",
        type: "TRANSFER",
        app_id: "app-test",
        transferred_from: [user],
        transferred_to: [other],
      },
    }, "Bearer fixture-hook"),
    config,
    "webhook",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.deepEqual(f.writes.map((w) => w.p_user_id), [user, other]);
});
test("una cuenta ausente en el proveedor concilia Free sin inventar una vigencia", async () => {
  const f = fixture({ providerStatus: 404 });
  const response = await handle(
    request({ expected_user_id: user }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 200);
  assert.equal(f.writes[0].p_active, false);
  assert.equal(f.writes[0].p_valid_until, null);
});
test("petición demasiado grande se rechaza antes de consultar compras", async () => {
  const f = fixture();
  const response = await handle(
    request({ expected_user_id: user, extra: "x".repeat(65536) }),
    config,
    "sync",
    f.fetcher,
  );
  assert.equal(response.status, 413);
  assert.equal(f.writes.length, 0);
  assert.ok(!f.reads.some((path) => path.includes("revenuecat.com")));
});
