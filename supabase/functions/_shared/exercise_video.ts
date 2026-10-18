// HTTP y Web Crypto nativos: ninguna clave de Bunny llega a Flutter.
export type VideoConfig = {
  supabaseUrl: string; anonKey: string; serviceKey: string; environment: string;
  libraryId: string; apiKey: string; cdnHost: string; tokenKey: string;
};
type Json = Record<string, unknown>;
type Fetcher = typeof fetch;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const maxSource = 20 * 1024 * 1024;
const maxPlayback = 5 * 1024 * 1024;
const maxDurationSeconds = 10;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export class VideoError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string) { super(code); this.status = status; this.code = code; }
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
function object(value: unknown): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new VideoError(502, "invalid_response");
  }
  return value as Json;
}
function configured(c: VideoConfig) {
  // La primera integración solo se habilita en desarrollo, nunca por accidente en producción.
  if (c.environment !== "DEVELOPMENT" ||
    c.supabaseUrl !== "https://sxbxfjqgoddzhtcyhalw.supabase.co" ||
    !c.anonKey || !c.serviceKey || !c.apiKey || !c.tokenKey ||
    !/^[1-9][0-9]*$/.test(c.libraryId) ||
    !/^[a-z0-9][a-z0-9-]*\.b-cdn\.net$/.test(c.cdnHost)) {
    throw new VideoError(503, "video_not_configured");
  }
}
async function call(fetcher: Fetcher, url: string, init: RequestInit) {
  return await fetcher(url, { ...init, signal: AbortSignal.timeout(15000), redirect: "error" });
}
async function db(c: VideoConfig, f: Fetcher, path: string, body?: unknown, token?: string, method = "POST") {
  const key = token ? c.anonKey : c.serviceKey;
  const response = await call(f, `${c.supabaseUrl}/rest/v1/${path}`, {
    method, headers: { apikey: key, Authorization: token ?? `Bearer ${key}`,
      "Content-Type": "application/json", Prefer: "return=representation" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    const failure = await response.json().catch(() => ({}));
    if (failure.code === "54000") throw new VideoError(429, "upload_limit");
    throw new VideoError(response.status === 403 ? 403 : 503, "video_database_error");
  }
  return await response.json();
}
async function provider(c: VideoConfig, f: Fetcher, suffix: string, body?: unknown) {
  const response = await call(f, `https://video.bunnycdn.com/library/${c.libraryId}/videos${suffix}`, {
    method: body === undefined ? "GET" : "POST",
    headers: { AccessKey: c.apiKey, "Content-Type": "application/json", Accept: "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new VideoError(502, "video_provider_error");
  return object(await response.json());
}
export async function signPlayback(url: string, key: string, expires: number) {
  const uri = new URL(url);
  if (uri.protocol !== "https:" || uri.search || uri.hash || uri.username || uri.password) {
    throw new VideoError(400, "invalid_video_url");
  }
  const encoder = new TextEncoder();
  const hmacKey = await crypto.subtle.importKey("raw", encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", hmacKey,
    encoder.encode(`${uri.pathname}${expires}`)));
  const hash = btoa(String.fromCharCode(...signature)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  uri.searchParams.set("token", `HS256-${hash}`);
  uri.searchParams.set("expires", String(expires));
  return uri.toString();
}
export async function handleExerciseVideo(request: Request, c: VideoConfig, f: Fetcher = fetch): Promise<Response> {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  try {
    if (request.method !== "POST") throw new VideoError(405, "method_not_allowed");
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) throw new VideoError(401, "unauthorized");
    const identity = await call(f, `${c.supabaseUrl}/auth/v1/user`, {
      headers: { apikey: c.anonKey, Authorization: authorization },
    });
    if (!identity.ok) throw new VideoError(401, "unauthorized");
    const user = object(await identity.json()).id;
    if (typeof user !== "string" || !uuid.test(user)) throw new VideoError(401, "unauthorized");
    const text = await request.text();
    if (text.length > 2048) throw new VideoError(413, "request_too_large");
    let body: Json;
    try { body = object(JSON.parse(text)); } catch { throw new VideoError(400, "invalid_request"); }
    if (body.expected_user_id !== user) throw new VideoError(409, "account_changed");
    const admin = await db(c, f, "rpc/is_admin", {}, authorization) === true;
    const expires = Math.floor(Date.now() / 1000) + 900;
    if (body.action === "playback" || body.action === "thumbnail") {
      if (body.action === "thumbnail" && !admin) throw new VideoError(403, "forbidden");
      const url = body.url;
      if (typeof url !== "string" || url.length > 500) throw new VideoError(400, "invalid_video_url");
      // Búsqueda exacta: nunca firmar una ruta aportada libremente por el cliente.
      const rows = await db(c, f, `exercise_video_assets?playback_url=eq.${encodeURIComponent(url)}&select=*`, undefined, undefined, "GET");
      if (!Array.isArray(rows) || rows.length !== 1) throw new VideoError(404, "video_not_managed");
      configured(c);
      const asset = object(rows[0]);
      if (asset.status !== "ready") throw new VideoError(409, "video_not_ready");
      if (!admin && await db(c, f, "rpc/can_read_exercise_video", { p_video_url: url }, authorization) !== true) {
        throw new VideoError(403, "forbidden");
      }
      if (asset.cdn_host !== c.cdnHost || String(asset.library_id) !== c.libraryId) throw new VideoError(409, "video_environment_mismatch");
      if (body.action === "thumbnail") {
        // Ruta fija de un activo registrado: nunca firmar imágenes arbitrarias.
        if (typeof asset.provider_video_id !== "string" || !uuid.test(asset.provider_video_id)) {
          throw new VideoError(409, "video_environment_mismatch");
        }
        const thumbnail = `https://${c.cdnHost}/${asset.provider_video_id}/thumbnail.jpg`;
        return json({ url: await signPlayback(thumbnail, c.tokenKey, expires), expires });
      }
      return json({ url: await signPlayback(url, c.tokenKey, expires), expires,
        cache_key: String(asset.id), bytes: asset.playback_bytes });
    }
    configured(c);
    if (!admin) throw new VideoError(403, "forbidden");
    if (body.action === "create") {
      if (!Number.isInteger(body.bytes) || Number(body.bytes) < 1 || Number(body.bytes) > maxSource) {
        throw new VideoError(400, "invalid_file_size");
      }
      const id = await db(c, f, "rpc/reserve_official_exercise_video", {
        p_library_id: Number(c.libraryId), p_cdn_host: c.cdnHost, p_source_bytes: body.bytes,
      }, authorization);
      if (typeof id !== "string" || !uuid.test(id)) throw new VideoError(503, "video_database_error");
      try {
        const created = await provider(c, f, "", { title: `EntrenaOP ${id}` });
        if (typeof created.guid !== "string" || !uuid.test(created.guid) || String(created.videoLibraryId) !== c.libraryId) {
          throw new VideoError(502, "invalid_response");
        }
        const videoId = created.guid;
        const stableUrl = `https://${c.cdnHost}/${videoId}/play_720p.mp4`;
        await db(c, f, `exercise_video_assets?id=eq.${id}`, {
          provider_video_id: videoId, playback_url: stableUrl, updated_at: new Date().toISOString(),
        }, undefined, "PATCH");
        const expiration = Math.floor(Date.now() / 1000) + 3600;
        const hash = new Uint8Array(await crypto.subtle.digest("SHA-256",
          new TextEncoder().encode(`${c.libraryId}${c.apiKey}${expiration}${videoId}`)));
        const signature = [...hash].map((x) => x.toString(16).padStart(2, "0")).join("");
        return json({ id, video_id: videoId, library_id: c.libraryId, expiration, signature });
      } catch (error) {
        await db(c, f, `exercise_video_assets?id=eq.${id}`, { status: "failed" }, undefined, "PATCH").catch(() => {});
        throw error;
      }
    }
    if (body.action !== "status" || typeof body.id !== "string" || !uuid.test(body.id)) {
      throw new VideoError(400, "invalid_request");
    }
    const rows = await db(c, f, `exercise_video_assets?id=eq.${body.id}&select=*`, undefined, undefined, "GET");
    if (!Array.isArray(rows) || rows.length !== 1) throw new VideoError(404, "video_not_found");
    const asset = object(rows[0]);
    if (String(asset.library_id) !== c.libraryId || asset.cdn_host !== c.cdnHost ||
      typeof asset.provider_video_id !== "string" || !uuid.test(asset.provider_video_id)) {
      throw new VideoError(409, "video_environment_mismatch");
    }
    if (asset.status === "ready") return json({ status: "ready", url: asset.playback_url });
    if (["failed", "rejected"].includes(String(asset.status))) return json({ status: asset.status });
    const video = await provider(c, f, `/${asset.provider_video_id}`);
    if (video.guid !== asset.provider_video_id || String(video.videoLibraryId) !== c.libraryId) {
      throw new VideoError(502, "invalid_response");
    }
    let status = "processing";
    let duration: number | null = null;
    let playbackBytes: number | null = null;
    if ([5, 6].includes(Number(video.status))) status = "failed";
    if (Number(video.status) === 4) {
      duration = Number(video.length);
      if (!Number.isFinite(duration) || duration <= 0 || duration > maxDurationSeconds || Number(video.storageSize) > 100 * 1024 * 1024) {
        status = "rejected"; duration = null;
      } else if (video.hasMP4Fallback === true) {
        const resolution = ["720p", "480p", "360p"].find((r) => String(video.availableResolutions).split(",").includes(r));
        if (!resolution) return json({ status: "processing" });
        asset.playback_url = `https://${c.cdnHost}/${asset.provider_video_id}/play_${resolution}.mp4`;
        const signed = await signPlayback(String(asset.playback_url), c.tokenKey, expires);
        const mp4 = await call(f, signed, { method: "HEAD" });
        const size = Number(mp4.headers.get("Content-Length"));
        if (mp4.ok && Number.isSafeInteger(size) && size > 0 && size <= maxPlayback &&
          (mp4.headers.get("Content-Type") ?? "").split(";")[0] === "video/mp4") {
          status = "ready"; playbackBytes = size;
        } else if (mp4.ok && size > maxPlayback) { status = "rejected"; duration = null; }
      }
    }
    await db(c, f, `exercise_video_assets?id=eq.${body.id}&status=in.(uploading,processing)`, {
      status, playback_url: asset.playback_url, duration_seconds: duration, playback_bytes: playbackBytes, updated_at: new Date().toISOString(),
    }, undefined, "PATCH");
    return json({ status, ...(status === "ready" ? { url: asset.playback_url } : {}) });
  } catch (error) {
    return error instanceof VideoError ? json({ error: error.code }, error.status) : json({ error: "video_unavailable" }, 503);
  }
}
