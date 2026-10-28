import { requireThat } from "../_shared/trainer_commerce/model.ts";
import {
  StripeSandboxCheckout,
  verifyStripeSandboxSignal,
} from "../_shared/trainer_commerce/stripe_sandbox.ts";
import {
  PlatformCheckout,
  row,
} from "../_shared/trainer_commerce/platform_checkout.ts";
type Json = Record<string, unknown>;
type Config = {
  url: string;
  anonKey: string;
  serviceKey: string;
  stripeKey: string;
  webhookSecret: string;
  portalId: string;
  enabled: boolean;
};
const account = "acct_1UV6mYPhGz4xntMQ";
const origin = "https://trainer.entrenaop.es";
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
export function createCommerceHandler(
  config: Config,
  fetcher: typeof fetch = fetch,
) {
  const headers = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers":
      "authorization,apikey,content-type,x-client-info",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Vary": "Origin",
  };
  const respond = (body: Json, status = 200) =>
    new Response(JSON.stringify(body), { headers, status });
  const rpc = async (
    name: string,
    params: Json,
    key: string,
    authorization: string,
  ) => {
    const response = await fetcher(config.url + "/rest/v1/rpc/" + name, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: authorization,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(params),
      redirect: "error",
      signal: AbortSignal.timeout(12000),
    });
    requireThat(response.ok, "commerce_database_unavailable");
    return await response.json();
  };
  const server = (action: string, data: Json) =>
    rpc(
      "trainer_commerce_server",
      { p_action: action, p_data: data },
      config.serviceKey,
      "Bearer " + config.serviceKey,
    );
  return async (req: Request) => {
    if (req.headers.has("origin") && req.headers.get("origin") !== origin) {
      return respond({ error: "origin_not_allowed" }, 403);
    }
    if (req.method === "OPTIONS") {
      return new Response(null, { headers, status: 204 });
    }
    if (req.method !== "POST") {
      return respond({ error: "method_not_allowed" }, 405);
    }
    if (
      !config.enabled ||
      config.url !== "https://sxbxfjqgoddzhtcyhalw.supabase.co"
    ) return respond({ error: "commerce_unavailable" }, 503);
    try {
      requireThat(
        Number(req.headers.get("content-length") ?? "0") <= 262144,
        "request_too_large",
      );
      const reader = req.body?.getReader();
      requireThat(reader, "body_required");
      const chunks: Uint8Array[] = [];
      let size = 0;
      try {
        while (true) {
          const next = await reader.read();
          if (next.done) break;
          size += next.value.length;
          requireThat(size <= 262144, "request_too_large");
          chunks.push(next.value);
        }
      } finally {
        void reader.cancel().catch(() => {});
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.length;
      }
      const raw = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
      const stripe = new StripeSandboxCheckout({
        secretKey: config.stripeKey,
        platformAccountId: account,
        namespace: "entrenaop-dev",
        returnUrl: origin + "/#/subscription",
      }, fetcher);
      const engine = new PlatformCheckout(
        stripe,
        server,
        account,
        undefined,
        config.portalId,
      );
      if (new URL(req.url).pathname.endsWith("/webhook")) {
        const signal = await verifyStripeSandboxSignal({
          body: raw,
          signature: req.headers.get("stripe-signature") ?? "",
          secret: config.webhookSecret,
          platformAccountId: account,
          nowSeconds: Math.floor(Date.now() / 1000),
        });
        requireThat(signal.accountId === account, "webhook_account_mismatch");
        const supported = [
          "checkout.session.completed",
          "checkout.session.async_payment_succeeded",
          "checkout.session.expired",
          "invoice.paid",
          "invoice.payment_failed",
          "customer.subscription.created",
          "customer.subscription.updated",
          "customer.subscription.deleted",
        ];
        if (!supported.includes(signal.type)) {
          return respond({ received: true, ignored: true });
        }
        const recorded = row(
          await server("event", {
            event_id: signal.eventId,
            event_type: signal.type,
            object_id: signal.objectId,
          }),
        );
        if (recorded.done === true) return respond({ received: true });
        let lookup: Json;
        const context = {
          provider: "stripe",
          environment: { mode: "sandbox" as const, namespace: "entrenaop-dev" },
          circuit: "platform_access" as const,
          accountId: account,
          sellerId: account,
          buyerId: "internal-reconciliation",
          contractId: "internal-reconciliation",
        };
        if (signal.type.startsWith("checkout.")) {
          requireThat(
            /^cs_test_[A-Za-z0-9]+$/.test(signal.objectId),
            "invalid_event_object",
          );
          const session = await stripe.request(
            context,
            `checkout/sessions/${signal.objectId}`,
          );
          requireThat(
            session.livemode === false,
            "webhook_environment_mismatch",
          );
          lookup = { session_id: session.id, customer_id: session.customer };
        } else if (signal.type.startsWith("customer.subscription.")) {
          requireThat(
            /^sub_[A-Za-z0-9]+$/.test(signal.objectId),
            "invalid_event_object",
          );
          const sub = await stripe.request(
            context,
            `subscriptions/${signal.objectId}`,
          );
          requireThat(sub.livemode === false, "webhook_environment_mismatch");
          lookup = { subscription_id: sub.id, customer_id: sub.customer };
        } else {
          requireThat(
            /^in_[A-Za-z0-9]+$/.test(signal.objectId),
            "invalid_event_object",
          );
          const invoice = await stripe.request(
            context,
            `invoices/${signal.objectId}`,
          );
          requireThat(
            invoice.livemode === false,
            "webhook_environment_mismatch",
          );
          const parent = invoice.parent as Json | null;
          if (!parent?.subscription_details) {
            await server("event_done", { event_id: signal.eventId });
            return respond({ received: true, ignored: true });
          }
          lookup = {
            subscription_id: row(parent.subscription_details).subscription,
            customer_id: invoice.customer,
          };
        }
        const found = await server("lookup", lookup);
        // Los eventos ajenos a nuestro catálogo no conceden nada. Un evento
        // propio que llegue antes de guardar Checkout debe reintentarse.
        if (found) await engine.run(String(row(found).id), null, "refresh");
        await server("event_done", { event_id: signal.eventId });
        return respond({ received: true });
      }
      const auth = req.headers.get("authorization") ?? "";
      requireThat(
        auth.startsWith("Bearer ") && auth.length < 16384,
        "authentication_required",
      );
      const userResponse = await fetcher(config.url + "/auth/v1/user", {
        headers: { apikey: config.anonKey, Authorization: auth },
        redirect: "error",
        signal: AbortSignal.timeout(10000),
      });
      requireThat(userResponse.ok, "authentication_required");
      const user = row(await userResponse.json());
      requireThat(
        typeof user.id === "string" && uuid.test(user.id) &&
          !!user.email_confirmed_at && user.is_anonymous !== true,
        "authentication_required",
      );
      const assured = await rpc(
        "get_trainer_security_status",
        {},
        config.anonKey,
        auth,
      );
      requireThat(assured === true, "mfa_required");
      const data = row(JSON.parse(raw));
      requireThat(
        ["checkout", "refresh", "portal"].includes(String(data.action)),
        "invalid_action",
      );
      let orderId: string;
      if (data.action === "checkout") {
        requireThat(
          typeof data.offer_id === "string" && uuid.test(data.offer_id),
          "invalid_offer",
        );
        orderId = String(
          await rpc(
            "prepare_trainer_subscription",
            { p_expected_owner: user.id, p_offer: data.offer_id },
            config.anonKey,
            auth,
          ),
        );
      } else {
        const status = row(
          await rpc(
            "get_my_trainer_subscription",
            { p_expected_owner: user.id },
            config.anonKey,
            auth,
          ),
        );
        orderId = String(row(status.subscription).id);
      }
      requireThat(uuid.test(orderId), "invalid_order");
      return respond(
        await engine.run(
          orderId,
          { userId: String(user.id), mfa: true },
          data.action as "checkout" | "refresh" | "portal",
        ),
      );
    } catch (error) {
      const code = error instanceof Error ? error.message : "commerce_failed";
      const expected = [
        "authentication_required",
        "mfa_required",
        "origin_not_allowed",
        "invalid_offer",
        "invalid_action",
      ];
      // Sin cuerpos Stripe, datos de cliente ni credenciales en respuesta/logs.
      return respond({
        error: expected.includes(code)
          ? code
          : "commerce_temporarily_unavailable",
      }, expected.includes(code) ? 403 : 503);
    }
  };
}
