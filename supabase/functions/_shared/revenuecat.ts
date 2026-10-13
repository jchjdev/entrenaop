// Sin paquetes externos: HTTP nativo, Auth de Supabase y conciliación del proveedor.
export type Config = {
  supabaseUrl: string;
  anonKey: string;
  serviceKey: string;
  revenuecatKey: string;
  environment: string;
  appId: string;
  webhookToken: string;
};
type Fetcher = typeof fetch;
type Json = Record<string, unknown>;
const products = new Set(["entrenaop_pro_monthly", "entrenaop_pro_annual"]);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export class RequestError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string) {
    super(code);
    this.status = status;
    this.code = code;
  }
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
function object(value: unknown): Json {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestError(502, "invalid_provider_response");
  }
  return value as Json;
}
function ready(config: Config) {
  if (
    !config.supabaseUrl || !config.anonKey || !config.serviceKey ||
    !config.revenuecatKey || !config.appId ||
    !["SANDBOX", "PRODUCTION"].includes(config.environment)
  ) {
    throw new RequestError(503, "billing_not_configured");
  }
  // Ninguna compra de prueba puede abrir derechos en otra base de datos.
  if (
    config.environment === "SANDBOX" &&
    config.supabaseUrl !== "https://sxbxfjqgoddzhtcyhalw.supabase.co"
  ) {
    throw new RequestError(503, "billing_environment_mismatch");
  }
  if (
    config.environment === "PRODUCTION" &&
    config.supabaseUrl === "https://sxbxfjqgoddzhtcyhalw.supabase.co"
  ) {
    throw new RequestError(503, "billing_environment_mismatch");
  }
}
async function boundedFetch(fetcher: Fetcher, url: string, init: RequestInit) {
  return await fetcher(url, { ...init, signal: AbortSignal.timeout(8000) });
}
async function rpc(config: Config, fetcher: Fetcher, name: string, body: Json) {
  const response = await boundedFetch(
    fetcher,
    `${config.supabaseUrl}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        apikey: config.serviceKey,
        Authorization: `Bearer ${config.serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) {
    throw new RequestError(503, "billing_reconciliation_failed");
  }
  return await response.json();
}
function instant(value: unknown): number {
  const ms = typeof value === "string" ? Date.parse(value) : NaN;
  if (!Number.isFinite(ms)) {
    throw new RequestError(502, "invalid_provider_response");
  }
  return ms;
}
export function snapshot(payload: unknown, environment: string, now: number) {
  const body = object(payload);
  const observed = instant(body.request_date);
  if (Math.abs(observed - now) > 300000) {
    throw new RequestError(502, "stale_provider_response");
  }
  const subscriber = object(body.subscriber);
  const entitlement = object(subscriber.entitlements).pro;
  if (entitlement == null) {
    return {
      p_active: false,
      p_product_identifier: null,
      p_store: null,
      p_valid_until: null,
      p_observed_at: new Date(observed).toISOString(),
    };
  }
  const access = object(entitlement);
  const product = access.product_identifier;
  if (typeof product !== "string" || !products.has(product)) {
    throw new RequestError(502, "unexpected_product");
  }
  const subscription = object(object(subscriber.subscriptions)[product]);
  const store = subscription.store;
  if (
    !["test_store", "app_store", "play_store"].includes(String(store)) ||
    typeof subscription.is_sandbox !== "boolean" ||
    subscription.is_sandbox !== (environment === "SANDBOX") ||
    (environment === "PRODUCTION" && store === "test_store")
  ) {
    throw new RequestError(502, "unexpected_purchase_environment");
  }
  // Solo suscripciones: una concesión sin vencimiento no habilita el producto.
  let expiry = instant(access.expires_date);
  if (subscription.grace_period_expires_date != null) {
    expiry = Math.max(expiry, instant(subscription.grace_period_expires_date));
  }
  return {
    p_active: expiry > now,
    p_product_identifier: product,
    p_store: store,
    p_valid_until: new Date(expiry).toISOString(),
    p_observed_at: new Date(observed).toISOString(),
  };
}
async function reconcile(
  config: Config,
  fetcher: Fetcher,
  userId: string,
  eventId?: string,
  eventType?: string,
) {
  const response = await boundedFetch(
    fetcher,
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    {
      headers: { Authorization: `Bearer ${config.revenuecatKey}` },
    },
  );
  let verified;
  if (response.status === 404) {
    verified = {
      p_active: false,
      p_product_identifier: null,
      p_store: null,
      p_valid_until: null,
      p_observed_at: new Date().toISOString(),
    };
  } else {
    if (!response.ok) throw new RequestError(502, "provider_unavailable");
    verified = snapshot(await response.json(), config.environment, Date.now());
  }
  return await rpc(config, fetcher, "apply_revenuecat_pro_snapshot", {
    p_user_id: userId,
    p_environment: config.environment,
    ...verified,
    p_event_id: eventId ?? null,
    p_event_type: eventType ?? null,
  });
}
async function bodyOf(request: Request) {
  const reader = request.body?.getReader();
  if (!reader) throw new RequestError(400, "invalid_request");
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 65536) {
      await reader.cancel();
      throw new RequestError(413, "request_too_large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  const text = new TextDecoder().decode(bytes);
  try {
    return object(JSON.parse(text));
  } catch {
    throw new RequestError(400, "invalid_request");
  }
}
async function sameSecret(a: string, b: string) {
  const bytes = (value: string) =>
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  const [x, y] = await Promise.all([bytes(a), bytes(b)]);
  const ax = new Uint8Array(x), ay = new Uint8Array(y);
  let difference = 0;
  for (let i = 0; i < ax.length; i++) difference |= ax[i] ^ ay[i];
  return difference === 0;
}
export async function handle(
  request: Request,
  config: Config,
  mode: "sync" | "webhook",
  fetcher: Fetcher = fetch,
): Promise<Response> {
  try {
    if (request.method !== "POST") {
      throw new RequestError(405, "method_not_allowed");
    }
    ready(config);
    if (mode === "sync") {
      const authorization = request.headers.get("Authorization");
      if (!authorization?.startsWith("Bearer ")) {
        throw new RequestError(401, "unauthorized");
      }
      const identity = await boundedFetch(
        fetcher,
        `${config.supabaseUrl}/auth/v1/user`,
        {
          headers: { apikey: config.anonKey, Authorization: authorization },
        },
      );
      if (!identity.ok) throw new RequestError(401, "unauthorized");
      const userId = object(await identity.json()).id;
      const body = await bodyOf(request);
      if (
        typeof userId !== "string" || !uuid.test(userId) ||
        body.expected_user_id !== userId
      ) {
        throw new RequestError(409, "account_changed");
      }
      const claim = object(
        await rpc(config, fetcher, "claim_revenuecat_sync", {
          p_user_id: userId,
        }),
      );
      if (claim.should_sync !== true) return json({ access: claim.access });
      return json({ access: await reconcile(config, fetcher, userId) });
    }
    if (!config.webhookToken) {
      throw new RequestError(503, "billing_not_configured");
    }
    if (
      !await sameSecret(
        request.headers.get("Authorization") ?? "",
        `Bearer ${config.webhookToken}`,
      )
    ) {
      throw new RequestError(401, "unauthorized");
    }
    const event = object((await bodyOf(request)).event);
    if (event.type === "TEST") return json({ received: true });
    if (
      event.app_id !== config.appId ||
      (event.environment !== config.environment &&
        !(event.type === "TRANSFER" && event.environment == null))
    ) {
      throw new RequestError(400, "unexpected_webhook_environment");
    }
    if (
      typeof event.id !== "string" || !event.id || event.id.length > 256 ||
      typeof event.type !== "string" || !event.type || event.type.length > 80
    ) {
      throw new RequestError(400, "invalid_event");
    }
    const candidates = event.type === "TRANSFER"
      ? [
        ...(Array.isArray(event.transferred_from)
          ? event.transferred_from
          : []),
        ...(Array.isArray(event.transferred_to) ? event.transferred_to : []),
      ]
      : [event.app_user_id];
    const users = [
      ...new Set(
        candidates.filter((id): id is string =>
          typeof id === "string" && uuid.test(id)
        ),
      ),
    ];
    if (users.length > 20) throw new RequestError(400, "invalid_event");
    for (const userId of users) {
      // El evento avisa; su importe/vigencia no se utiliza como concesión directa.
      await reconcile(config, fetcher, userId, event.id, event.type);
    }
    return json({ received: true });
  } catch (error) {
    // No devolver respuestas completas del proveedor, tokens o errores de SQL.
    return error instanceof RequestError
      ? json({ code: error.code }, error.status)
      : json({ code: "billing_temporarily_unavailable" }, 503);
  }
}
