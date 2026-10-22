import type { GarminServerConfig } from "./http.ts";
export function garminServerConfig():GarminServerConfig {
  return {environment:Deno.env.get("GARMIN_ENVIRONMENT")??"DISABLED",supabaseUrl:Deno.env.get("SUPABASE_URL")??"",
    anonKey:Deno.env.get("SUPABASE_ANON_KEY")??"",serviceKey:Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"",
    clientId:Deno.env.get("GARMIN_CLIENT_ID")??"",clientSecret:Deno.env.get("GARMIN_CLIENT_SECRET")??"",
    encryptionKey:Deno.env.get("GARMIN_TOKEN_ENCRYPTION_KEY")??""};
}
