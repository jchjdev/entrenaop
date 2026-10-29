import { test } from "node:test";
import assert from "node:assert/strict";
import { handleMediaCleanup } from "../_shared/media_cleanup.ts";
import type { VideoConfig } from "../_shared/exercise_video.ts";

const owner = "10000000-0000-4000-8000-000000000001";
const other = "10000000-0000-4000-8000-000000000002";
const jobId = "20000000-0000-4000-8000-000000000001";
const asset = "30000000-0000-4000-8000-000000000001";
const video = "40000000-0000-4000-8000-000000000001";
const operation = "50000000-0000-4000-8000-000000000001";
const image = `${owner}/${asset}.jpg`;
const config: VideoConfig = {
  supabaseUrl: "https://sxbxfjqgoddzhtcyhalw.supabase.co", anonKey: "fixture-anon", serviceKey: "fixture-service",
  environment: "DEVELOPMENT", libraryId: "42", apiKey: "fixture-provider", cdnHost: "fixture.b-cdn.net", tokenKey: "fixture-token",
};
function request(body: Record<string, unknown> = {}, headers: Record<string, string> = {}) {
  return new Request("https://example.invalid/trainer-media-cleanup", {
    method: "POST", headers: { Authorization: "Bearer fixture-user", ...headers },
    body: JSON.stringify({ action: "run", scope: "trainer", expected_user_id: owner, ...body }),
  });
}
type Options = {
  kind?: "image" | "video"; jobs?: boolean; auth?: boolean; forbidden?: boolean; ticket?: boolean;
  wrongOwner?: boolean; wrongBucket?: boolean; scope?: "trainer" | "official";
  storageDelete?: number; storageAbsent?: boolean; storageAbsentCode?: string; storageTimeout?: boolean;
  videoBefore?: number; videoAfter?: number; deleteStatus?: number; deleteSuccess?: boolean; videoTimeout?: boolean;
  requiresReconciliation?: boolean; creationState?: string; providerId?: string | null;
  searchItems?: unknown[]; searchTotal?: number; wrongProvider?: boolean; ackFailure?: boolean;
  ackLostOnce?: boolean; providerIdentityConfirmed?: boolean; resolveFailure?: boolean;
  additionalInvalidJob?: boolean; queueProtected?: boolean; malformedQueue?: boolean; finalReportForbidden?: boolean;
  requesterDeleted?: boolean;
  resolveBlocked?: boolean; resolveMalformed?: "empty" | "other_job" | "other_guid" | "incoherent";
};
function fixture(options: Options = {}) {
  const calls: { url: string; method: string; body: Record<string, unknown> }[] = [];
  const finishes: Record<string, unknown>[] = [];
  const scope = options.scope ?? "trainer", kind = options.kind ?? "image";
  let videoReads = 0, finished = false, remotelyDeleted = false, identityConfirmed = options.providerIdentityConfirmed ?? false;
  let reportReads = 0, ticketUsed = false;
  let protectedByResolution = false;
  const job = {
    job_id: jobId, lease_id: "", kind, scope,
    owner_id: scope === "official" ? null : options.wrongOwner ? other : owner,
    requested_by: options.requesterDeleted ? null : options.wrongOwner ? other : owner,
    bucket: options.wrongBucket ? "avatars" : scope === "official" ? "exercise-images-public" : "trainer-exercise-images",
    path: image, asset_id: asset, library_id: 42,
    provider_video_id: options.providerId === undefined ? video : options.providerId,
    creation_state: options.creationState ?? "created", requires_reconciliation: options.requiresReconciliation ?? false,
    provider_identity_confirmed: identityConfirmed,
  };
  const report = () => ({
    items: [{ job_id: jobId, kind, scope, state: protectedByResolution ? "blocked" : finished ? "deleted" : "pending",
      created_at: "2026-10-29T12:00:00Z", updated_at: "2026-10-29T12:00:00Z", available_at: "2026-10-29T12:00:00Z",
      deleted_at: finished ? "2026-10-29T12:30:00Z" : null, blocked_reason: null, error_code: null,
      private_path: image, secret_value: "never-return-this" }],
    summary: { pending: finished || protectedByResolution ? 0 : 1, deleted: finished ? 1 : 0, protected: protectedByResolution ? 1 : 0, freed_images: finished && kind === "image" ? 1 : 0, freed_bytes: finished ? 1024 : 0 },
    service_role_key: "never-return-this",
  });
  const fetcher: typeof fetch = async (input, init = {}) => {
    const url = String(input), method = init.method ?? "GET";
    const body = init.body ? JSON.parse(String(init.body)) : {};
    calls.push({ url, method, body });
    if (url.endsWith("/auth/v1/user")) return Response.json({ id: owner }, { status: options.auth === false ? 401 : 200 });
    if (url.endsWith("/rpc/list_exercise_media_cleanup")) {
      reportReads++;
      if (options.forbidden || options.finalReportForbidden && reportReads > 1) return Response.json({ code: "42501" }, { status: 403 });
      return Response.json(report());
    }
    if (url.endsWith("/rpc/queue_exercise_media_cleanup")) return options.queueProtected
      ? Response.json({ code: "P0001" }, { status: 400 }) : Response.json(options.malformedQueue ? {} : report().items[0]);
    if (url.endsWith("/rpc/sweep_exercise_media_cleanup")) return Response.json({ items: report().items, queued: 1 });
    if (url.endsWith("/rpc/consume_exercise_media_cleanup_ticket")) {
      const accepted = options.ticket === true && !ticketUsed;
      ticketUsed = true;
      return Response.json(accepted);
    }
    if (url.endsWith("/rpc/claim_exercise_media_cleanup")) {
      job.lease_id = body.p_claim;
      job.provider_identity_confirmed = identityConfirmed;
      if (identityConfirmed) { job.provider_video_id = video; job.requires_reconciliation = false; }
      return Response.json(options.jobs === false ? [] : options.additionalInvalidJob ? [job, { ...job, owner_id: other }] : [job]);
    }
    if (url.endsWith("/rpc/resolve_exercise_media_cleanup_provider")) {
      if (options.resolveFailure) return Response.json({ code: "40001" }, { status: 409 });
      if (options.resolveBlocked) {
        protectedByResolution = true;
        return Response.json({ job_id: jobId, state: "blocked", provider_identity_confirmed: false, blocked_reason: "execution_history" });
      }
      if (options.resolveMalformed === "empty") return new Response(null, { status: 204 });
      identityConfirmed = true;
      return Response.json({ job_id: options.resolveMalformed === "other_job" ? other : jobId,
        provider_video_id: options.resolveMalformed === "other_guid" ? other : video,
        provider_identity_confirmed: true, ...(options.resolveMalformed === "incoherent" ? { state: "blocked" } : {}) });
    }
    if (url.endsWith("/rpc/finish_exercise_media_cleanup")) {
      finishes.push(body);
      if (options.ackFailure) return Response.json({ code: "server_down" }, { status: 503 });
      if (options.ackLostOnce && finishes.length === 1) throw new Error("ack never committed");
      finished = body.p_deleted === true;
      return Response.json({ state: finished ? "deleted" : "pending" });
    }
    if (url.includes("/storage/v1/object/info/")) {
      return options.storageAbsent === false ? Response.json({ name: image })
        : Response.json({ code: options.storageAbsentCode ?? "NoSuchKey" }, { status: 404 });
    }
    if (url.includes("/storage/v1/object/") && method === "DELETE") {
      if (options.storageTimeout) throw new Error("provider accepted request but response lost");
      return Response.json([], { status: options.storageDelete ?? 200 });
    }
    if (url.startsWith("https://video.bunnycdn.com/library/42/videos")) {
      if (url.includes("?")) return Response.json({ items: options.searchItems ?? [{ guid: video, videoLibraryId: 42, title: `EntrenaOP ${asset}` }],
        totalItems: options.searchTotal ?? options.searchItems?.length ?? 1 });
      if (method === "DELETE") {
        if (options.videoTimeout) throw new Error("provider accepted delete but response lost");
        if (options.deleteStatus === 204) return new Response(null, { status: 204 });
        remotelyDeleted = options.deleteSuccess !== false;
        return Response.json({ success: options.deleteSuccess ?? true }, { status: options.deleteStatus ?? 200 });
      }
      videoReads++;
      const status = remotelyDeleted && options.ackLostOnce ? 404 : videoReads === 1 ? options.videoBefore ?? 200 : options.videoAfter ?? 404;
      return Response.json({ guid: options.wrongProvider ? other : video, videoLibraryId: 42 }, { status });
    }
    throw new Error("Unexpected fixture endpoint");
  };
  return { fetcher, calls, finishes };
}

test("configuración Dev, método y tamaño se validan sin tocar proveedor", async () => {
  const f = fixture();
  for (const environment of ["DISABLED", "PRODUCTION"]) {
    assert.equal((await handleMediaCleanup(request(), { ...config, environment }, f.fetcher)).status, 503);
  }
  assert.equal((await handleMediaCleanup(new Request("https://example.invalid", { method: "GET" }), config, f.fetcher)).status, 405);
  assert.equal((await handleMediaCleanup(request({ padding: "x".repeat(2100) }), config, f.fetcher)).status, 413);
  assert.equal(f.calls.length, 0);
});
test("preflight es inocuo y ofrece CORS sin secretos", async () => {
  const f = fixture();
  const result = await handleMediaCleanup(new Request("https://example.invalid", { method: "OPTIONS" }), config, f.fetcher);
  assert.equal(result.status, 204);
  assert.equal(result.headers.get("Access-Control-Allow-Origin"), "*");
  assert.equal(f.calls.length, 0);
});
test("Auth, identidad y MFA se verifican antes del claim de servicio", async () => {
  for (const options of [{ auth: false }, { forbidden: true }]) {
    const f = fixture(options), result = await handleMediaCleanup(request(), config, f.fetcher);
    assert.equal(result.status, options.auth === false ? 401 : 403);
    assert.equal(f.calls.some((c) => c.url.includes("claim_") || c.url.includes("storage/v1")), false);
  }
  const f = fixture();
  assert.equal((await handleMediaCleanup(request({ expected_user_id: other }), config, f.fetcher)).status, 409);
  assert.equal(f.calls.length, 1);
});
test("inspeccionar no encola ni reclama y no filtra rutas, claves o datos internos", async () => {
  const f = fixture();
  const result = await handleMediaCleanup(request({ action: "inspect" }), config, f.fetcher), text = await result.text();
  assert.equal(result.status, 200);
  assert.equal(result.headers.get("Cache-Control"), "no-store");
  assert.equal(f.calls.length, 2);
  assert.equal(text.includes(image), false);
  assert.equal(text.includes("never-return-this"), false);
});
test("el lote completo se valida: nunca borra un medio de otro dueño o bucket", async () => {
  for (const options of [{ wrongOwner: true }, { wrongBucket: true }, { additionalInvalidJob: true }]) {
    const f = fixture(options);
    assert.equal((await handleMediaCleanup(request(), config, f.fetcher)).status, 503);
    assert.equal(f.calls.some((c) => c.url.includes("storage/v1") || c.url.includes("bunnycdn")), false);
    assert.equal(f.finishes.length, 0);
  }
});
test("imagen: Storage API más ausencia confirmada preceden la liberación de cuota", async () => {
  const f = fixture();
  const result = await handleMediaCleanup(request(), config, f.fetcher), body = await result.json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(body.summary.freed_images, 1);
  assert.equal(f.finishes[0].p_deleted, true);
  const remove = f.calls.find((c) => c.method === "DELETE")!;
  assert.deepEqual(remove.body, { prefixes: [image] });
  assert.equal(f.calls.findIndex((c) => c.url.includes("object/info")) < f.calls.findIndex((c) => c.url.endsWith("finish_exercise_media_cleanup")), true);
});
test("Storage: timeout, fallo, objeto presente o bucket inexistente no liberan cuota", async () => {
  for (const options of [{ storageTimeout: true }, { storageDelete: 500 }, { storageAbsent: false }, { storageAbsentCode: "NoSuchBucket" }]) {
    const f = fixture(options), result = await handleMediaCleanup(request(), config, f.fetcher), body = await result.json();
    assert.equal(body.batch.deleted, 0);
    assert.equal(body.batch.retry, 1);
    assert.equal(body.summary.freed_images, 0);
    assert.equal(f.finishes[0].p_deleted, false);
  }
});
test("ack perdido conserva resultado incierto y no declara la cuota liberada", async () => {
  const f = fixture({ ackFailure: true });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 0);
  assert.equal(body.batch.errors, 1);
  assert.equal(body.summary.freed_images, 0);
});
test("vídeo: solo GET identidad correcta, DELETE success y GET404 permiten completar", async () => {
  const f = fixture({ kind: "video" });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(f.finishes[0].p_deleted, true);
  assert.deepEqual(f.calls.filter((c) => c.url.includes("bunnycdn")).map((c) => c.method), ["GET", "DELETE", "GET"]);
});
test("vídeo ya ausente permite reintentar un borrado perdido sin repetir DELETE", async () => {
  const f = fixture({ kind: "video", videoBefore: 404 });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(f.calls.some((c) => c.method === "DELETE"), false);
});
test("Bunny success:false, autorización, timeout, presencia y GUID ajeno mantienen cuota", async () => {
  for (const options of [{ deleteSuccess: false }, { videoBefore: 401 }, { videoBefore: 403 }, { videoTimeout: true }, { videoAfter: 200 }, { videoAfter: 503 }, { wrongProvider: true }]) {
    const f = fixture({ kind: "video", ...options });
    const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
    assert.equal(body.batch.deleted, 0);
    assert.equal(f.finishes[0].p_deleted, false);
    if (options.wrongProvider) assert.equal(f.calls.some((c) => c.method === "DELETE"), false);
  }
});
test("creación incierta vacía, ambigua o con búsqueda truncada nunca se da por ausente", async () => {
  const item = { guid: video, videoLibraryId: 42, title: `EntrenaOP ${asset}` };
  for (const options of [{ searchItems: [] }, { searchItems: [item, item] }, { searchItems: [item], searchTotal: 101 }]) {
    const f = fixture({ kind: "video", creationState: "uncertain", requiresReconciliation: true, providerId: null, ...options });
    const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
    assert.equal(body.batch.deleted, 0);
    assert.equal(f.finishes[0].p_deleted, false);
    assert.equal(f.calls.some((c) => c.method === "DELETE"), false);
  }
});
test("creación incierta con único título e identidad coincidentes se elimina y acredita reconciliación", async () => {
  const f = fixture({ kind: "video", creationState: "uncertain", requiresReconciliation: true, providerId: null });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(f.finishes[0].p_error_code, "reconciled_absent");
});
test("reserved sin inicio de creación no inventa ni consulta un GUID remoto", async () => {
  const f = fixture({ kind: "video", creationState: "reserved", providerId: null });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(f.calls.some((c) => c.url.includes("bunnycdn")), false);
});
test("reconciliar persiste GUID antes del DELETE: un ACK perdido se recupera por identidad sellada", async () => {
  const f = fixture({ kind: "video", creationState: "uncertain", requiresReconciliation: true, providerId: null, ackLostOnce: true });
  const first = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(first.batch.deleted, 0);
  assert.equal(first.batch.errors, 1);
  assert.equal(f.calls.findIndex((c) => c.url.endsWith("resolve_exercise_media_cleanup_provider")) < f.calls.findIndex((c) => c.method === "DELETE"), true);
  const callsBeforeRetry = f.calls.length;
  const second = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(second.batch.deleted, 1);
  assert.equal(f.finishes[1].p_deleted, true);
  const retryProvider = f.calls.slice(callsBeforeRetry).filter((c) => c.url.includes("bunnycdn"));
  assert.equal(retryProvider.length, 1);
  assert.equal(retryProvider[0].url.endsWith(`/videos/${video}`), true);
  assert.equal(retryProvider[0].method, "GET");
});
test("si no puede fijar el GUID reconciliado, no se llega a borrar el proveedor", async () => {
  const f = fixture({ kind: "video", creationState: "uncertain", requiresReconciliation: true, providerId: null, resolveFailure: true });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 0);
  assert.equal(f.calls.some((c) => c.method === "DELETE"), false);
  assert.equal(f.finishes[0].p_deleted, false);
});
test("resolver GUID descubre historial: conserva vídeo y cuota sin DELETE ni finish posterior", async () => {
  const f = fixture({ kind: "video", creationState: "uncertain", requiresReconciliation: true, providerId: null, resolveBlocked: true });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 0);
  assert.equal(body.batch.retry, 0);
  assert.equal(body.batch.errors, 0);
  assert.equal(body.summary.protected, 1);
  assert.equal(body.summary.freed_bytes, 0);
  assert.equal(f.calls.some((c) => c.method === "DELETE"), false);
  assert.equal(f.finishes.length, 0);
});
test("respuesta resolve incompleta, con otro job/GUID o incoherente jamás autoriza DELETE", async () => {
  for (const resolveMalformed of ["empty", "other_job", "other_guid", "incoherent"] as const) {
    const f = fixture({ kind: "video", creationState: "uncertain", requiresReconciliation: true, providerId: null, resolveMalformed });
    const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
    assert.equal(body.batch.deleted, 0);
    assert.equal(f.calls.some((c) => c.method === "DELETE"), false);
    assert.equal(f.finishes[0].p_deleted, false);
  }
});
test("cola vacía o diferida por SQL no llama proveedores", async () => {
  const f = fixture({ jobs: false });
  const body = await (await handleMediaCleanup(request(), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 0);
  assert.equal(f.calls.some((c) => c.url.includes("storage/v1") || c.url.includes("bunnycdn")), false);
});
test("sweep y delete confirman recibo de identidad y UUID sin exponer targets remotos del job", async () => {
  for (const action of ["sweep", "delete"]) {
    const f = fixture();
    const result = await handleMediaCleanup(request({ action, operation_id: operation, kind: "image", target: image }), config, f.fetcher);
    const body = await result.json();
    assert.equal(body.receipt.operation_id, operation);
    assert.equal(body.receipt.expected_user_id, owner);
    assert.equal(body.receipt.action, action);
    assert.equal(body.batch.deleted, 1);
  }
});
test("protección SQL impide borrar y una URL libre nunca llega al destino externo", async () => {
  const protectedFixture = fixture({ queueProtected: true });
  const result = await handleMediaCleanup(request({ action: "delete", operation_id: operation, kind: "image", target: image }), config, protectedFixture.fetcher);
  assert.equal(result.status, 409);
  assert.equal((await result.json()).error, "media_protected");
  assert.equal(protectedFixture.calls.some((c) => c.url.includes("claim_") || c.method === "DELETE"), false);
  const invalidFixture = fixture();
  assert.equal((await handleMediaCleanup(request({ action: "delete", operation_id: operation, kind: "image", target: "https://example.invalid/not-my-file.jpg" }), config, invalidFixture.fetcher)).status, 400);
  assert.equal(invalidFixture.calls.some((c) => c.url.includes("queue_") || c.method === "DELETE"), false);
});
test("después de encolar, un recibo incompleto o perder permisos no se declara fallo definitivo", async () => {
  for (const options of [{ malformedQueue: true }, { finalReportForbidden: true }]) {
    const f = fixture(options);
    const result = await handleMediaCleanup(request({ action: "delete", operation_id: operation, kind: "image", target: image }), config, f.fetcher);
    assert.equal(result.status, 503);
    assert.equal((await result.json()).error, "cleanup_pending");
  }
});
test("cron solo consume ticket de un uso y procesa cola; jamás barre bibliotecas", async () => {
  const f = fixture({ ticket: true });
  const body = await (await handleMediaCleanup(request({ action: "tick" }, { "X-EntrenaOP-Media-Ticket": "t".repeat(43) }), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(f.calls.some((c) => c.url.includes("auth/v1/user") || c.url.includes("sweep_") || c.url.includes("queue_")), false);
  assert.equal(f.calls.find((c) => c.url.endsWith("claim_exercise_media_cleanup"))!.body.p_owner, null);
  const replay = await handleMediaCleanup(request({ action: "tick" }, { "X-EntrenaOP-Media-Ticket": "t".repeat(43) }), config, f.fetcher);
  assert.equal(replay.status, 401);
  assert.equal(f.calls.filter((c) => c.url.endsWith("claim_exercise_media_cleanup")).length, 1);
});
test("ticket ausente, inventado o consumido no reclama trabajos", async () => {
  for (const ticket of ["", "t".repeat(43)]) {
    const f = fixture();
    const result = await handleMediaCleanup(request({ action: "tick" }, { "X-EntrenaOP-Media-Ticket": ticket }), config, f.fetcher);
    assert.equal(result.status, 401);
    assert.equal(f.calls.some((c) => c.url.includes("claim_")), false);
  }
});
test("contexto oficial usa bucket oficial y valida requested_by incluso con owner NULL", async () => {
  const f = fixture({ scope: "official" });
  const body = await (await handleMediaCleanup(request({ scope: "official" }), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
  assert.equal(f.calls.find((c) => c.method === "DELETE")!.url.endsWith("/exercise-images-public"), true);
});
test("cron puede terminar la limpieza oficial si la cuenta que la pidió ya no existe", async () => {
  const f = fixture({ scope: "official", requesterDeleted: true, ticket: true });
  const body = await (await handleMediaCleanup(request({ action: "tick" }, { "X-EntrenaOP-Media-Ticket": "t".repeat(43) }), config, f.fetcher)).json();
  assert.equal(body.batch.deleted, 1);
});
