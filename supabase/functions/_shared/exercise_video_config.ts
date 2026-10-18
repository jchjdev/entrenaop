export function exerciseVideoConfig() {
  return {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    environment: Deno.env.get("BUNNY_ENVIRONMENT") ?? "DISABLED",
    libraryId: Deno.env.get("BUNNY_STREAM_LIBRARY_ID") ?? "",
    apiKey: Deno.env.get("BUNNY_STREAM_API_KEY") ?? "",
    cdnHost: Deno.env.get("BUNNY_STREAM_CDN_HOST") ?? "",
    tokenKey: Deno.env.get("BUNNY_STREAM_TOKEN_KEY") ?? "",
  };
}
