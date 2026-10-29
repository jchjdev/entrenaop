import type { VideoConfig } from "./exercise_video.ts";

type Json = Record<string, unknown>;
type Scope = "trainer" | "official";
type Fetcher = typeof fetch;
type Config = VideoConfig;
type Job = {
  job_id: string; lease_id: string; kind: "image" | "video"; scope: Scope;
  owner_id: string | null; requested_by: string | null; bucket: string | null;
  path: string | null; asset_id: string | null; library_id: number | string | null;
  provider_video_id: string | null; creation_state: string | null;
  requires_reconciliation: boolean; provider_identity_confirmed: boolean;
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
class CleanupError extends Error {
  readonly status: number;
  readonly code: string;
  constructor(status: number, code: string) { super(code); this.status = status; this.code = code; }
}
function object(value: unknown): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new CleanupError(503, "cleanup_invalid_response");
  }
  return value as Json;
}
function response(value: unknown, status = 200): Response {
  return Response.json(value, { status, headers: { ...cors, "Cache-Control": "no-store" } });
}
function scope(value: unknown): Scope {
  if (value !== "trainer" && value !== "official") throw new CleanupError(400, "invalid_request");
  return value;
}
function configured(c: Config): void {
  if (c.environment !== "DEVELOPMENT" || c.supabaseUrl !== "https://sxbxfjqgoddzhtcyhalw.supabase.co" ||
    !c.anonKey || !c.serviceKey) throw new CleanupError(503, "cleanup_not_configured");
}
function pathIsSafe(value: unknown): value is string {
  return typeof value === "string" && value.length <= 300 &&
    /^[a-zA-Z0-9_/-]+\.(jpg|jpeg)$/.test(value) && value.split("/").every((p) => p.length > 0);
}
function validId(value: unknown): value is string { return typeof value === "string" && uuid.test(value); }
function integer(value: unknown): number {
  if (!Number.isSafeInteger(value) || Number(value) < 0) throw new CleanupError(503, "cleanup_invalid_response");
  return Number(value);
}
function publicReport(raw: unknown): Json {
  const value = object(raw), summary = object(value.summary);
  if (!Array.isArray(value.items) || value.items.length > 50) throw new CleanupError(503, "cleanup_invalid_response");
  return {
    items: value.items.map((rawItem) => {
      const item = object(rawItem);
      if (!validId(item.job_id) || !["image", "video"].includes(String(item.kind)) ||
        !["trainer", "official"].includes(String(item.scope)) ||
        typeof item.state !== "string" || !/^[a-z_]{1,30}$/.test(item.state)) {
        throw new CleanupError(503, "cleanup_invalid_response");
      }
      const result: Json = { job_id: item.job_id, kind: item.kind, scope: item.scope, state: item.state };
      for (const key of ["created_at", "updated_at", "available_at", "deleted_at"]) {
        const stamp = item[key];
        if (stamp !== null && stamp !== undefined &&
          (typeof stamp !== "string" || stamp.length > 40 || !Number.isFinite(Date.parse(stamp)))) {
          throw new CleanupError(503, "cleanup_invalid_response");
        }
        result[key] = stamp ?? null;
      }
      result.blocked_reason = typeof item.blocked_reason === "string" ? item.blocked_reason.slice(0, 500) : null;
      result.error_code = typeof item.error_code === "string" && /^[a-z0-9_]{1,64}$/.test(item.error_code)
        ? item.error_code : null;
      return result;
    }),
    summary: Object.fromEntries(["pending", "deleted", "protected", "freed_images", "freed_bytes"]
      .map((key) => [key, integer(summary[key])])),
  };
}

/** Solo usa destinos sellados por SQL; ni rutas ni GUID libres del cliente llegan al proveedor. */
export async function handleMediaCleanup(request: Request, config: Config, fetcher: Fetcher = fetch): Promise<Response> {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  // El lote está acotado para terminar también con proveedores lentos. Una falta
  // de confirmación deja el medio cerrado y su cuota intacta para el reintento.
  const deadline = Date.now() + 45000;
  let queueConfirmed = false;
  async function call(url: string, init: RequestInit, reserve = 0): Promise<Response> {
    const left = deadline - Date.now() - reserve;
    if (left < 100) throw new CleanupError(503, "cleanup_time_budget");
    return await fetcher(url, { ...init, signal: AbortSignal.timeout(Math.min(7000, left)), redirect: "error" });
  }
  async function rpc(name: string, params: Json, bearer?: string): Promise<unknown> {
    const key = bearer ? config.anonKey : config.serviceKey;
    const result = await call(`${config.supabaseUrl}/rest/v1/rpc/${name}`, {
      method: "POST", headers: { apikey: key, Authorization: bearer ?? `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify(params),
    });
    if (!result.ok) {
      const failed = await result.json().catch(() => ({})) as Json;
      const code = typeof failed.code === "string" ? failed.code : "";
      if (code === "42501") throw new CleanupError(403, "forbidden");
      if (code === "22023") throw new CleanupError(400, "invalid_request");
      if (code === "P0001") throw new CleanupError(409, "media_protected");
      if (code === "40001") throw new CleanupError(409, "cleanup_changed");
      throw new CleanupError(503, "cleanup_database_unavailable");
    }
    const text = await result.text();
    return text.length === 0 ? null : JSON.parse(text);
  }
  function parseJob(raw: unknown, claim: string, owner: string | null, requestedScope: Scope | null): Job {
    const job = object(raw);
    if (!validId(job.job_id) || job.lease_id !== claim ||
      !["image", "video"].includes(String(job.kind)) || !["trainer", "official"].includes(String(job.scope)) ||
      (requestedScope !== null && job.scope !== requestedScope) ||
      (job.scope === "trainer" ? !validId(job.owner_id) : job.owner_id !== null) ||
      (job.requested_by !== null && !validId(job.requested_by)) ||
      (owner !== null && (job.scope === "trainer" ? job.owner_id !== owner : job.requested_by !== owner)) ||
      typeof job.requires_reconciliation !== "boolean" || typeof job.provider_identity_confirmed !== "boolean") throw new CleanupError(503, "cleanup_invalid_job");
    if (job.kind === "image") {
      const bucket = job.scope === "trainer" ? "trainer-exercise-images" : "exercise-images-public";
      if (job.bucket !== bucket || !pathIsSafe(job.path) ||
        (job.scope === "trainer" && (job.owner_id === null || !job.path.startsWith(`${job.owner_id}/`)))) {
        throw new CleanupError(503, "cleanup_invalid_job");
      }
    } else if (!validId(job.asset_id) ||
      (job.provider_video_id !== null && !validId(job.provider_video_id)) ||
      (job.provider_identity_confirmed && !validId(job.provider_video_id)) ||
      !["reserved", "creating", "created", "uncertain"].includes(String(job.creation_state)) ||
      String(job.library_id) !== config.libraryId) throw new CleanupError(503, "cleanup_invalid_job");
    return job as Job;
  }
  async function removeImage(job: Job): Promise<void> {
    const result = await call(`${config.supabaseUrl}/storage/v1/object/${job.bucket}`, {
      method: "DELETE", headers: { apikey: config.serviceKey, Authorization: `Bearer ${config.serviceKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ prefixes: [job.path] }),
    }, 3000);
    if (!result.ok) throw new CleanupError(503, "storage_delete_failed");
    const encoded = job.path!.split("/").map(encodeURIComponent).join("/");
    const check = await call(`${config.supabaseUrl}/storage/v1/object/info/${job.bucket}/${encoded}`, {
      method: "GET", headers: { apikey: config.serviceKey, Authorization: `Bearer ${config.serviceKey}` },
    }, 3000);
    // Un 404 genérico, de bucket inexistente o de gateway no prueba la ausencia
    // del objeto. Se exige el error de objeto concreto documentado por Storage.
    const missing = await check.json().catch(() => null) as Json | null;
    if (![400, 404].includes(check.status) || !missing ||
      !(missing.code === "NoSuchKey" ||
        (String(missing.statusCode) === "404" && missing.message === "Object not found"))) {
      throw new CleanupError(503, "storage_absence_unconfirmed");
    }
  }
  async function bunny(suffix: string, method: string): Promise<Response> {
    if (!config.apiKey || !/^[1-9][0-9]*$/.test(config.libraryId)) {
      throw new CleanupError(503, "video_not_configured");
    }
    return await call(`https://video.bunnycdn.com/library/${config.libraryId}/videos${suffix}`, {
      method, headers: { AccessKey: config.apiKey, Accept: "application/json" },
    }, 3000);
  }
  async function removeVideo(job: Job): Promise<"reconciled_absent" | "protected" | null> {
    let providerId = job.provider_video_id;
    if (!job.provider_identity_confirmed && (job.requires_reconciliation || job.creation_state === "uncertain" ||
      job.creation_state === "creating" || providerId === null && job.creation_state !== "reserved")) {
      const title = `EntrenaOP ${job.asset_id}`;
      const searched = await bunny(`?page=1&itemsPerPage=100&search=${encodeURIComponent(title)}`, "GET");
      if (!searched.ok) throw new CleanupError(503, "video_reconciliation_failed");
      const page = object(await searched.json());
      if (!Array.isArray(page.items) || page.items.length > 100 || !Number.isSafeInteger(page.totalItems) ||
        Number(page.totalItems) < 0 || Number(page.totalItems) > page.items.length) {
        throw new CleanupError(503, "video_creation_uncertain");
      }
      const exact = page.items.map(object).filter((item) => item.title === title && String(item.videoLibraryId) === config.libraryId);
      // Cero coincidencias no acredita que una creación incierta no esté todavía
      // en curso o pendiente de indexación. Nunca se libera cuota por ese vacío.
      if (exact.length !== 1 || !validId(exact[0].guid) ||
        providerId !== null && providerId !== exact[0].guid) throw new CleanupError(503, "video_creation_uncertain");
      providerId = exact[0].guid;
      // Se fija la identidad antes del borrado. Si luego se pierde el ACK,
      // el reintento comprobará ese GUID y no una búsqueda ya vacía.
      const resolved = object(await rpc("resolve_exercise_media_cleanup_provider", {
        p_job_id: job.job_id, p_lease_id: job.lease_id, p_provider_video_id: providerId,
      }));
      if (resolved.job_id !== job.job_id) throw new CleanupError(503, "video_resolution_invalid");
      // El GUID puede descubrir referencias antiguas que solo guardaban la
      // URL del proveedor. SQL conserva entonces el archivo y cierra el job.
      if (resolved.state === "blocked" && resolved.provider_identity_confirmed === false) return "protected";
      if (resolved.provider_identity_confirmed !== true || resolved.provider_video_id !== providerId ||
        (resolved.state !== undefined && resolved.state !== "deleting")) throw new CleanupError(503, "video_resolution_invalid");
    }
    if (providerId === null) {
      // SQL solo reclama reserved sin creación iniciada después de cerrar el
      // acceso. No hay una identidad remota que pueda haber sido creada aún.
      if (job.creation_state !== "reserved") throw new CleanupError(503, "video_creation_uncertain");
      return null;
    }
    const before = await bunny(`/${providerId}`, "GET");
    if (before.status === 404) return job.requires_reconciliation ? "reconciled_absent" : null;
    if (!before.ok) throw new CleanupError(503, "video_lookup_failed");
    const actual = object(await before.json());
    if (actual.guid !== providerId || String(actual.videoLibraryId) !== config.libraryId) {
      throw new CleanupError(503, "video_identity_mismatch");
    }
    const deleted = await bunny(`/${providerId}`, "DELETE");
    if (!deleted.ok && deleted.status !== 404) throw new CleanupError(503, "video_delete_failed");
    if (deleted.ok && deleted.status !== 204 && object(await deleted.json()).success !== true) {
      throw new CleanupError(503, "video_delete_failed");
    }
    const after = await bunny(`/${providerId}`, "GET");
    if (after.status !== 404) throw new CleanupError(503, "video_absence_unconfirmed");
    return job.requires_reconciliation ? "reconciled_absent" : null;
  }
  async function run(owner: string | null, requestedScope: Scope | null): Promise<Json> {
    const claim = crypto.randomUUID();
    const raw = await rpc("claim_exercise_media_cleanup", { p_limit: 3, p_owner: owner, p_claim: claim, p_scope: requestedScope });
    if (!Array.isArray(raw) || raw.length > 3) throw new CleanupError(503, "cleanup_invalid_response");
    // Se valida todo el lote antes del primer efecto externo.
    const jobs = raw.map((job) => parseJob(job, claim, owner, requestedScope));
    const counts = { deleted: 0, retry: 0, errors: 0, deferred: 0 };
    for (const job of jobs) {
      let deleted = false, errorCode: string | null = null;
      try {
        if (Date.now() > deadline - 12000) throw new CleanupError(503, "batch_budget");
        if (job.kind === "image") await removeImage(job);
        else {
          const result = await removeVideo(job);
          if (result === "protected") continue;
          errorCode = result;
        }
        deleted = true;
      } catch (error) {
        errorCode = error instanceof CleanupError ? error.code : "provider_unavailable";
      }
      try {
        const finished = object(await rpc("finish_exercise_media_cleanup", {
          p_job_id: job.job_id, p_lease_id: job.lease_id, p_deleted: deleted, p_error_code: errorCode,
        }));
        if (deleted && finished.state === "deleted") counts.deleted++;
        else if (deleted) counts.errors++;
        else if (errorCode === "batch_budget") counts.deferred++;
        else counts.retry++;
      } catch { counts.errors++; }
    }
    return counts;
  }
  try {
    if (request.method !== "POST") throw new CleanupError(405, "method_not_allowed");
    configured(config);
    const source = await request.text();
    if (source.length > 2048) throw new CleanupError(413, "request_too_large");
    let body: Json;
    try { body = object(JSON.parse(source)); } catch { throw new CleanupError(400, "invalid_request"); }
    if (body.action === "tick") {
      const ticket = request.headers.get("X-EntrenaOP-Media-Ticket");
      if (!ticket || !/^[A-Za-z0-9_-]{43}$/.test(ticket) ||
        await rpc("consume_exercise_media_cleanup_ticket", { p_token: ticket }) !== true) {
        throw new CleanupError(401, "unauthorized");
      }
      return response({ batch: await run(null, null) });
    }
    if (!["inspect", "sweep", "delete", "run"].includes(String(body.action))) throw new CleanupError(400, "invalid_request");
    const context = scope(body.scope);
    const bearer = request.headers.get("Authorization");
    if (!bearer?.startsWith("Bearer ")) throw new CleanupError(401, "unauthorized");
    const identity = await call(`${config.supabaseUrl}/auth/v1/user`, { headers: { apikey: config.anonKey, Authorization: bearer } });
    if (!identity.ok) throw new CleanupError(401, "unauthorized");
    const owner = object(await identity.json()).id;
    if (!validId(owner)) throw new CleanupError(401, "unauthorized");
    if (body.expected_user_id !== owner) throw new CleanupError(409, "account_changed");
    const cursorAt = body.before_at ?? null, cursorId = body.before_id ?? null;
    if ((cursorAt === null) !== (cursorId === null) || cursorId !== null && !validId(cursorId) ||
      cursorAt !== null && (typeof cursorAt !== "string" || !Number.isFinite(Date.parse(cursorAt)))) {
      throw new CleanupError(400, "invalid_request");
    }
    const reportParams = { p_scope: context, p_before_at: cursorAt, p_before_id: cursorId, p_limit: 50 };
    // La lectura también comprueba permisos/MFA antes de cualquier claim de
    // servicio: un JWT válido de alumno no autoriza ejecutar la cola profesional.
    let report = publicReport(await rpc("list_exercise_media_cleanup", reportParams, bearer));
    if (body.action === "inspect") return response(report);
    let receipt: Json | undefined;
    if (body.action === "sweep" || body.action === "delete") {
      if (!validId(body.operation_id)) throw new CleanupError(400, "invalid_request");
      if (body.action === "sweep") {
        const queued = object(await rpc("sweep_exercise_media_cleanup", { p_operation_id: body.operation_id, p_scope: context, p_limit: 50 }, bearer));
        queueConfirmed = true;
        if (integer(queued.queued) > 50) throw new CleanupError(503, "cleanup_invalid_response");
        publicReport({ items: queued.items, summary: { pending: 0, deleted: 0, protected: 0, freed_images: 0, freed_bytes: 0 } });
      } else {
        if (!["image", "video"].includes(String(body.kind)) ||
          (body.kind === "image" ? !pathIsSafe(body.target) : !validId(body.target))) {
          throw new CleanupError(400, "invalid_request");
        }
        const queued = object(await rpc("queue_exercise_media_cleanup", {
          p_operation_id: body.operation_id, p_scope: context, p_kind: body.kind, p_target: body.target,
        }, bearer));
        queueConfirmed = true;
        if (queued.scope !== context || queued.kind !== body.kind) throw new CleanupError(503, "cleanup_invalid_response");
        publicReport({ items: [queued], summary: { pending: 0, deleted: 0, protected: 0, freed_images: 0, freed_bytes: 0 } });
      }
      receipt = { operation_id: body.operation_id, action: body.action, scope: context,
        expected_user_id: owner, ...(body.action === "delete" ? { kind: body.kind, target: body.target } : {}) };
    }
    const batch = await run(owner, context);
    report = publicReport(await rpc("list_exercise_media_cleanup", reportParams, bearer));
    return response({ ...report, batch, ...(receipt ? { receipt } : {}) });
  } catch (error) {
    // Sin rutas, nombres, credenciales ni mensajes del proveedor en errores.
    // Tras encolar, un fallo posterior no invalida aquella escritura: la UI
    // mantiene su UUID en vez de empezar otra operación con un recibo distinto.
    if (queueConfirmed) return response({ error: "cleanup_pending" }, 503);
    return error instanceof CleanupError
      ? response({ error: error.code }, error.status)
      : response({ error: "cleanup_unavailable" }, 503);
  }
}
