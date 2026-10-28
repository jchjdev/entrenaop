import { createCommerceHandler } from "./handler.ts";
const env = (key: string) => Deno.env.get(key) ?? "";
Deno.serve(
  createCommerceHandler({
    url: env("SUPABASE_URL"),
    anonKey: env("SUPABASE_ANON_KEY"),
    serviceKey: env("SUPABASE_SERVICE_ROLE_KEY"),
    stripeKey: env("TRAINER_STRIPE_TEST_KEY"),
    webhookSecret: env("TRAINER_STRIPE_WEBHOOK_SECRET"),
    portalId: env("TRAINER_STRIPE_PORTAL_ID"),
    enabled: env("TRAINER_STRIPE_ENABLED") === "true",
  }),
);
