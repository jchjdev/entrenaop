export function billingConfig() {
  return {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    revenuecatKey: Deno.env.get("REVENUECAT_SECRET_KEY") ?? "",
    environment: Deno.env.get("REVENUECAT_ENVIRONMENT") ?? "DISABLED",
    appId: Deno.env.get("REVENUECAT_APP_ID") ?? "",
    webhookToken: Deno.env.get("REVENUECAT_WEBHOOK_TOKEN") ?? "",
  };
}
