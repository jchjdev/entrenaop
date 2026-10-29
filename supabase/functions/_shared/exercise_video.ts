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
const privateSource = 100 * 1024 * 1024;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export class VideoError extends Error {
  status: number;
  code: string;
  details?: Json;
  constructor(status: number, code: string, details?: Json) { super(code); this.status = status; this.code = code; this.details = details; }
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
    // Diagnóstico acotado: nunca registrar JWT, claves, cuerpos ni datos del alumno.
    console.warn(JSON.stringify({ event: "exercise_video_database_failure", http_status: response.status,
      sql_state: typeof failure.code === "string" && /^[A-Z0-9]{5}$/.test(failure.code) ? failure.code : "unknown" }));
    if (failure.code === "54000") throw new VideoError(429, "upload_limit");
    if (failure.code === "42501") throw new VideoError(403, "forbidden");
    if (failure.code === "22023") throw new VideoError(400, "invalid_request");
    throw new VideoError(response.status === 403 ? 403 : 503, "video_database_error");
  }
  // Las RPC que devuelven void responden 204 sin JSON. La escritura ya puede
  // estar confirmada: intentar parsearla como JSON inventaba un fallo incierto.
  if (response.status === 204) return null;
  const text = await response.text();
  return text.length === 0 ? null : JSON.parse(text);
}
async function provider(c: VideoConfig, f: Fetcher, suffix: string, body?: unknown) {
  const response = await call(f, `https://video.bunnycdn.com/library/${c.libraryId}/videos${suffix}`, {
    method: body === undefined ? "GET" : "POST",
    headers: { AccessKey: c.apiKey, "Content-Type": "application/json", Accept: "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    console.warn(JSON.stringify({ event: "exercise_video_provider_failure", http_status: response.status }));
    throw new VideoError(502, "video_provider_error");
  }
  return object(await response.json());
}
async function uploadCredentials(c: VideoConfig, f: Fetcher, id: string, asset: Json) {
  if (String(asset.library_id) !== c.libraryId || asset.cdn_host !== c.cdnHost) {
    throw new VideoError(409, "video_environment_mismatch");
  }
  const videoId = asset.provider_video_id;
  if (typeof videoId !== "string" || !uuid.test(videoId)) throw new VideoError(409, "video_creation_uncertain");
  if (asset.status !== "uploading") throw new VideoError(409, "video_upload_closed", { asset_id: id, status: asset.status });
  const expiration = Math.floor(Date.now() / 1000) + 3600;
  // La firma solo se emite tras registrar su plazo bajo el mismo cierre que
  // usa la limpieza. Así no se elimina un destino con una subida aún válida.
  await db(c, f, "rpc/prepare_exercise_video_upload", {
    p_id: id, p_expires_at: new Date(expiration * 1000).toISOString(),
  });
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256",
    new TextEncoder().encode(`${c.libraryId}${c.apiKey}${expiration}${videoId}`)));
  return json({ id, video_id: videoId, library_id: c.libraryId, expiration,
    signature: [...hash].map((x) => x.toString(16).padStart(2, "0")).join(""),
    scope: asset.scope, source_limit: asset.source_limit,
    duration_limit: asset.duration_limit, playback_limit: asset.playback_limit });
}
async function recoverUploadCredentials(c: VideoConfig, f: Fetcher, id: string, asset: Json) {
  if (String(asset.library_id) !== c.libraryId || asset.cdn_host !== c.cdnHost) {
    throw new VideoError(409, "video_environment_mismatch");
  }
  if (asset.status === "uploading" || asset.status === "processing") {
    // Compatibilidad con reservas que versiones anteriores marcaron processing
    // antes de enviar el archivo. No se rebaja el estado SQL ni se relaja su guard.
    const video = await provider(c, f, `/${asset.provider_video_id}`);
    if (video.guid !== asset.provider_video_id || String(video.videoLibraryId) !== c.libraryId) {
      throw new VideoError(502, "invalid_response");
    }
    if (video.status === 0) return await uploadCredentials(c, f, id, { ...asset, status: "uploading" });
    throw new VideoError(409, "video_upload_closed", { asset_id: id, status: "processing" });
  }
  return await uploadCredentials(c, f, id, asset);
}
async function reconcileCreation(c: VideoConfig, f: Fetcher, id: string): Promise<string> {
  // Bunny documenta búsqueda por título y totalItems. Solo una coincidencia
  // exacta, en un resultado completo, acredita una creación ya aceptada.
  const title = `EntrenaOP ${id}`;
  const page = await provider(c, f, `?page=1&itemsPerPage=100&search=${encodeURIComponent(title)}`);
  if (!Array.isArray(page.items) || !Number.isInteger(page.totalItems) || Number(page.totalItems) > page.items.length) {
    throw new VideoError(409, "video_creation_uncertain");
  }
  const exact = page.items.map(object).filter((v) => v.title === title && String(v.videoLibraryId) === c.libraryId);
  if (exact.length !== 1 || typeof exact[0].guid !== "string" || !uuid.test(exact[0].guid)) {
    throw new VideoError(409, "video_creation_uncertain");
  }
  return exact[0].guid;
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
    const expires = Math.floor(Date.now() / 1000) + 900;
    if (body.action === "playback" || body.action === "thumbnail") {
      const url = body.url;
      if (typeof url !== "string" || url.length > 500) throw new VideoError(400, "invalid_video_url");
      // Búsqueda exacta: nunca firmar una ruta aportada libremente por el cliente.
      const rows = await db(c, f, `exercise_video_assets?playback_url=eq.${encodeURIComponent(url)}&select=*`, undefined, undefined, "GET");
      if (!Array.isArray(rows) || rows.length !== 1) throw new VideoError(404, "video_not_managed");
      configured(c);
      const asset = object(rows[0]);
      if (await db(c, f, "rpc/authorize_exercise_video_asset", { p_id: asset.id, p_action: body.action }, authorization) !== true) {
        throw new VideoError(403, "forbidden");
      }
      if (asset.status !== "ready") throw new VideoError(409, "video_not_ready");
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
        cache_key: String(asset.id), bytes: asset.playback_bytes,
        scope: asset.scope, playback_limit: asset.playback_limit, duration_limit: asset.duration_limit });
    }
    configured(c);
    if (body.action === "create") {
      const scope = body.scope ?? "official";
      if (!["official", "trainer_exercise", "client_technique"].includes(String(scope))) throw new VideoError(400, "invalid_scope");
      if (!Number.isInteger(body.bytes) || Number(body.bytes) < 1 || Number(body.bytes) > (scope === "official" ? maxSource : privateSource)) {
        throw new VideoError(400, "invalid_file_size");
      }
      // ADMIN antiguo puede no enviar operación. El flujo nuevo la conserva
      // desde el formulario; los scopes privados la exigen para reintentar.
      const operation = body.operation_id ?? (scope === "official" ? crypto.randomUUID() : null);
      if (typeof operation !== "string" || !uuid.test(operation)) throw new VideoError(400, "invalid_operation_id");
      const id = await db(c, f, "rpc/reserve_exercise_video_upload", {
        p_scope: scope, p_operation_id: operation,
        p_library_id: Number(c.libraryId), p_cdn_host: c.cdnHost, p_source_bytes: body.bytes,
        p_assignment_id: body.assignment_id ?? null, p_execution_id: body.execution_id ?? null,
        p_execution_set_id: body.execution_set_id ?? null,
      }, authorization);
      if (typeof id !== "string" || !uuid.test(id)) throw new VideoError(503, "video_database_error");
      const asset = object(await db(c, f, "rpc/get_exercise_video_asset", { p_id: id, p_action: "create" }, authorization));
      const claimId = crypto.randomUUID();
      const claim = object(await db(c, f, "rpc/claim_exercise_video_creation", { p_id: id, p_claim: claimId }));
      if (claim.state === "created") return await recoverUploadCredentials(c, f, id, { ...asset, provider_video_id: claim.video_id });
      if (claim.state !== "claimed") {
        try {
          const recovered = await reconcileCreation(c, f, id);
          await db(c, f, "rpc/complete_exercise_video_creation", { p_id: id, p_claim: null, p_video_id: recovered, p_recovery: true });
          return await uploadCredentials(c, f, id, { ...asset, provider_video_id: recovered });
        } catch {
          throw new VideoError(409, "video_creation_uncertain", { asset_id: id, operation_id: operation });
        }
      }
      try {
        const created = await provider(c, f, "", { title: `EntrenaOP ${id}` });
        if (typeof created.guid !== "string" || !uuid.test(created.guid) || String(created.videoLibraryId) !== c.libraryId) {
          throw new VideoError(502, "invalid_response");
        }
        const videoId = created.guid;
        await db(c, f, "rpc/complete_exercise_video_creation", { p_id: id, p_claim: claimId, p_video_id: videoId, p_recovery: false });
        return await uploadCredentials(c, f, id, { ...asset, provider_video_id: videoId });
      } catch (error) {
        await db(c, f, "rpc/mark_exercise_video_creation_uncertain", { p_id: id, p_claim: claimId }).catch(() => {});
        if (error instanceof VideoError && error.code === "video_upload_closed") throw error;
        throw new VideoError(503, "video_creation_uncertain", { asset_id: id, operation_id: operation });
      }
    }
    if (!["status", "recover"].includes(String(body.action)) || typeof body.id !== "string" || !uuid.test(body.id)) {
      throw new VideoError(400, "invalid_request");
    }
    const asset = object(await db(c, f, "rpc/get_exercise_video_asset", { p_id: body.id, p_action: body.action }, authorization));
    if (body.action === "recover") {
      if (asset.creation_state === "created") return await recoverUploadCredentials(c, f, body.id, asset);
      if (!["creating", "uncertain"].includes(String(asset.creation_state))) throw new VideoError(409, "video_creation_not_uncertain");
      const videoId = await reconcileCreation(c, f, body.id);
      await db(c, f, "rpc/complete_exercise_video_creation", { p_id: body.id, p_claim: null, p_video_id: videoId, p_recovery: true });
      return await uploadCredentials(c, f, body.id, { ...asset, provider_video_id: videoId });
    }
    if (String(asset.library_id) !== c.libraryId || asset.cdn_host !== c.cdnHost ||
      typeof asset.provider_video_id !== "string" || !uuid.test(asset.provider_video_id)) {
      throw new VideoError(409, "video_environment_mismatch");
    }
    if (asset.status === "ready") return json({ status: "ready", url: asset.playback_url, scope: asset.scope, playback_limit: asset.playback_limit, duration_limit: asset.duration_limit });
    if (["failed", "rejected"].includes(String(asset.status))) return json({ status: asset.status, scope: asset.scope });
    const video = await provider(c, f, `/${asset.provider_video_id}`);
    if (video.guid !== asset.provider_video_id || String(video.videoLibraryId) !== c.libraryId) {
      throw new VideoError(502, "invalid_response");
    }
    console.info(JSON.stringify({ event: "exercise_video_provider_state", provider_status: Number.isInteger(video.status) ? video.status : "unknown",
      has_mp4: video.hasMP4Fallback === true, has_playback_resolution: ["720p", "480p", "360p"].some((r) => String(video.availableResolutions).split(",").includes(r)) }));
    // Created no acredita transferencia ni debe inventar preparación. La lectura
    // conserva el guard SQL monotónico incluso para reservas antiguas afectadas.
    if (video.status === 0) return json({ status: "uploading", scope: asset.scope });
    let status = "processing";
    let duration: number | null = null;
    let playbackBytes: number | null = null;
    if ([5, 6].includes(Number(video.status))) status = "failed";
    if (Number(video.status) === 4) {
      duration = Number(video.length);
      const durationLimit = asset.scope === "official" ? maxDurationSeconds : Number(asset.duration_limit);
      const playbackLimit = asset.scope === "official" ? maxPlayback : Number(asset.playback_limit);
      const storedBytes = Number(video.storageSize);
      const storageLimit = asset.scope === "official" ? 100 * 1024 * 1024 : Number(asset.source_limit);
      if (!Number.isFinite(duration) || duration <= 0 || duration > durationLimit || !Number.isSafeInteger(storedBytes) || storedBytes <= 0 || storedBytes > storageLimit) {
        status = "rejected"; duration = null;
      } else if (video.hasMP4Fallback === true) {
        const resolution = ["720p", "480p", "360p"].find((r) => String(video.availableResolutions).split(",").includes(r));
        if (!resolution) return json({ status: "processing", scope: asset.scope });
        asset.playback_url = `https://${c.cdnHost}/${asset.provider_video_id}/play_${resolution}.mp4`;
        const signed = await signPlayback(String(asset.playback_url), c.tokenKey, expires);
        const mp4 = await call(f, signed, { method: "HEAD" });
        const size = Number(mp4.headers.get("Content-Length"));
        if (mp4.ok && Number.isSafeInteger(size) && size > 0 && size <= playbackLimit &&
          (mp4.headers.get("Content-Type") ?? "").split(";")[0] === "video/mp4") {
          status = "ready"; playbackBytes = size;
        } else if (mp4.ok && size > playbackLimit) { status = "rejected"; duration = null; }
      }
    }
    await db(c, f, `exercise_video_assets?id=eq.${body.id}&status=in.(uploading,processing)`, {
      status, playback_url: asset.playback_url, duration_seconds: duration, playback_bytes: playbackBytes,
      provider_storage_bytes: status === "ready" ? Number(video.storageSize) : null, updated_at: new Date().toISOString(),
    }, undefined, "PATCH");
    // La respuesta puede haber perdido la carrera con otra consulta. Devolver
    // el estado persistido evita mostrar processing después de ready.
    const settled = object(await db(c, f, "rpc/get_exercise_video_asset", { p_id: body.id, p_action: "status" }, authorization));
    return json({ status: settled.status, scope: settled.scope, playback_limit: settled.playback_limit,
      duration_limit: settled.duration_limit, ...(settled.status === "ready" ? { url: settled.playback_url } : {}) });
  } catch (error) {
    console.warn(JSON.stringify({ event: "exercise_video_failure", code: error instanceof VideoError ? error.code : "video_unavailable" }));
    return error instanceof VideoError ? json({ error: error.code, ...error.details }, error.status) : json({ error: "video_unavailable" }, 503);
  }
}
