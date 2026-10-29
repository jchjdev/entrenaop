import { test } from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { handleExerciseVideo, signPlayback } from "../_shared/exercise_video.ts";
import type { VideoConfig } from "../_shared/exercise_video.ts";

const user = "10000000-0000-4000-8000-000000000001";
const id = "20000000-0000-4000-8000-000000000001";
const video = "30000000-0000-4000-8000-000000000001";
const url = `https://fixture.b-cdn.net/${video}/play_720p.mp4`;
const config: VideoConfig = { supabaseUrl: "https://sxbxfjqgoddzhtcyhalw.supabase.co",
  anonKey: "fixture-anon", serviceKey: "fixture-service", environment: "DEVELOPMENT",
  libraryId: "42", apiKey: "fixture-provider", cdnHost: "fixture.b-cdn.net", tokenKey: "fixture-signing" };
function request(body: Record<string, unknown>, token = "Bearer fixture-user") {
  return new Request("https://example.invalid/function", { method: "POST",
    headers: token ? { Authorization: token } : {},
    body: JSON.stringify({ expected_user_id: user, ...body }) });
}
function fixture(options: { admin?: boolean; canRead?: boolean; ready?: boolean;
  provider?: Record<string, unknown>; auth?: boolean; asset?: boolean;
  scope?: string; manage?: boolean; creationState?: string; searchItems?: unknown[];
  searchTotal?: number; providerTimeout?: boolean; voidResponse?: boolean; uploadLeaseDenied?: boolean } = {}) {
  const writes: Record<string, unknown>[] = [];
  const calls: string[] = [];
  const uploadLeases: Record<string, unknown>[] = [];
  const asset: Record<string, unknown> = {
    id, created_by: user, library_id: 42, provider_video_id: video, cdn_host: config.cdnHost,
    playback_url: url, playback_bytes: 1000, status: options.ready === false ? "processing" : "ready",
    scope: options.scope ?? "official", creation_state: options.creationState ?? "created",
    source_limit: options.scope && options.scope !== "official" ? 100 * 1024 * 1024 : 20 * 1024 * 1024,
    duration_limit: options.scope && options.scope !== "official" ? 180 : 10,
    playback_limit: options.scope && options.scope !== "official" ? 50 * 1024 * 1024 : 5 * 1024 * 1024,
  };
  const fetcher: typeof fetch = async (target, init) => {
    const path = String(target); calls.push(path);
    if (path.endsWith("/auth/v1/user")) return Response.json({ id: user }, { status: options.auth === false ? 401 : 200 });
    if (path.endsWith("/rpc/is_admin")) return Response.json(options.admin !== false);
    if (path.endsWith("/rpc/can_read_exercise_video")) return Response.json(options.canRead === true);
    if (path.endsWith("/rpc/authorize_exercise_video_asset")) {
      const b = JSON.parse(String(init?.body));
      return Response.json(b.p_action === "playback" ? options.canRead === true || (options.scope === undefined && options.admin !== false) : options.manage ?? options.admin !== false);
    }
    if (path.endsWith("/rpc/reserve_exercise_video_upload")) {
      if (options.admin === false && options.manage !== true) return Response.json({ code: "42501" }, { status: 403 });
      asset.status = "uploading"; return Response.json(id);
    }
    if (path.endsWith("/rpc/get_exercise_video_asset")) {
      if (options.manage === false || (options.manage === undefined && options.admin === false)) return Response.json({ code: "42501" }, { status: 403 });
      return Response.json(asset);
    }
    if (path.endsWith("/rpc/claim_exercise_video_creation")) return Response.json({ state: options.creationState ?? "claimed", video_id: video });
    if (path.endsWith("/rpc/complete_exercise_video_creation")) {
      asset.provider_video_id = video; asset.creation_state = "created";
      writes.push({ playback_url: url }); return options.voidResponse ? new Response(null, { status: 204 }) : Response.json(null);
    }
    if (path.endsWith("/rpc/mark_exercise_video_creation_uncertain")) { asset.creation_state = "uncertain"; return Response.json(null); }
    if (path.endsWith("/rpc/prepare_exercise_video_upload")) {
      uploadLeases.push(JSON.parse(String(init?.body)));
      return options.uploadLeaseDenied ? Response.json({ code: "42501" }, { status: 403 }) : new Response(null, { status: 204 });
    }
    if (path.includes("/exercise_video_assets?") && init?.method === "GET") return Response.json(options.asset === false ? [] : [asset]);
    if (path.includes("/exercise_video_assets?") && init?.method === "PATCH") {
      const change = JSON.parse(String(init.body)); Object.assign(asset, change);
      writes.push(change); return Response.json([]);
    }
    if (path.startsWith("https://video.bunnycdn.com/library/42/videos")) {
      if (options.providerTimeout && init?.method === "POST") throw new Error("timeout después de aceptar Bunny");
      if (path.includes("?")) return Response.json({ items: options.searchItems ?? [{ guid: video, videoLibraryId: 42, title: `EntrenaOP ${id}` }], totalItems: options.searchTotal ?? options.searchItems?.length ?? 1 });
      return Response.json({ guid: video, videoLibraryId: 42, status: 4, length: 5,
        hasMP4Fallback: true, availableResolutions: "360p,480p,720p", storageSize: 10000, ...options.provider });
    }
    if (path.startsWith("https://fixture.b-cdn.net/")) return new Response(null, {
      headers: { "Content-Length": "1000", "Content-Type": "video/mp4" } });
    throw new Error(`Solicitud inesperada: ${path}`);
  };
  return { fetcher, calls, writes, asset, uploadLeases };
}
test("sin JWT no consulta Auth, base de datos ni Bunny", async () => {
  const f = fixture();
  const response = await handleExerciseVideo(request({ action: "create", bytes: 10 }, ""), config, f.fetcher);
  assert.equal(response.status, 401); assert.equal(f.calls.length, 0);
});
test("rechaza JWT inválido, cambio de cuenta y configuración de producción", async () => {
  for (const [body, conf, options, code] of [
    [{ action: "create" }, config, { auth: false }, 401],
    [{ action: "create", expected_user_id: id }, config, {}, 409],
    [{ action: "create" }, { ...config, supabaseUrl: "https://production.invalid" }, {}, 503],
    [{ action: "create" }, { ...config, environment: "DISABLED" }, {}, 503],
  ] as const) {
    const f = fixture(options);
    assert.equal((await handleExerciseVideo(request(body), conf, f.fetcher)).status, code);
    assert.equal(f.writes.length, 0);
    assert.equal(f.calls.some((s) => s.includes("bunnycdn")), false);
  }
});
test("un deportista no puede crear subidas ni inspeccionar su estado", async () => {
  for (const action of ["create", "status", "thumbnail"]) {
    const f = fixture({ admin: false });
    assert.equal((await handleExerciseVideo(request({ action, bytes: 10, id, url }), config, f.fetcher)).status, 403);
    assert.equal(f.calls.some((s) => s.includes("bunnycdn")), false);
  }
});

test("solo admin obtiene la miniatura del vídeo registrado y listo", async () => {
  const f = fixture();
  const response = await handleExerciseVideo(request({ action: "thumbnail", url }), config, f.fetcher);
  const data = await response.json();
  assert.equal(response.status, 200);
  assert.equal(new URL(data.url).pathname, `/${video}/thumbnail.jpg`);
  assert.ok(new URL(data.url).searchParams.get("token")?.startsWith("HS256-"));
  assert.equal(JSON.stringify(data).includes(config.apiKey), false);
  for (const options of [{ asset: false }, { ready: false }]) {
    const blocked = fixture(options);
    const result = await handleExerciseVideo(request({ action: "thumbnail", url }), config, blocked.fetcher);
    assert.equal(result.status, options.asset === false ? 404 : 409);
  }
});

test("leer un vídeo público no concede permiso de generar portadas ni subidas", async () => {
  const f = fixture({ admin: false, canRead: true });
  const result = await handleExerciseVideo(request({ action: "thumbnail", url }), config, f.fetcher);
  assert.equal(result.status, 403);
  assert.equal(f.writes.length, 0);
  assert.equal(f.calls.some((s) => s.includes("bunnycdn")), false);
});
test("no firma un vídeo oculto o una URL arbitraria aunque el cliente conozca el ID", async () => {
  for (const options of [{ admin: false }, { admin: true, asset: false }]) {
    const f = fixture(options);
    const response = await handleExerciseVideo(request({ action: "playback", url }), config, f.fetcher);
    assert.equal(response.status, options.asset === false ? 404 : 403);
    assert.equal(f.writes.length, 0);
  }
});
test("una referencia autorizada recibe firma temporal y clave estable sin secretos", async () => {
  const f = fixture({ admin: false, canRead: true });
  const response = await handleExerciseVideo(request({ action: "playback", url }), config, f.fetcher);
  const body = await response.json();
  assert.equal(response.status, 200); assert.equal(body.cache_key, id);
  assert.equal(new URL(body.url).pathname, new URL(url).pathname);
  assert.ok(body.expires > Date.now() / 1000);
  assert.equal(JSON.stringify(body).includes(config.apiKey), false);
  assert.equal(JSON.stringify(body).includes(config.tokenKey), false);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
});
test("la firma coincide con HMAC-SHA256 y no permite inyectar querystrings", async () => {
  const result = new URL(await signPlayback(url, "fixture", 1800000000));
  const expected = createHmac("sha256", "fixture").update(`${result.pathname}1800000000`).digest("base64url");
  assert.equal(result.searchParams.get("token"), `HS256-${expected}`);
  await assert.rejects(signPlayback(`${url}?token_path=/`, "fixture", 1800000000));
});
test("crea credenciales limitadas a un vídeo sin devolver la clave de biblioteca", async () => {
  const f = fixture();
  const response = await handleExerciseVideo(request({ action: "create", bytes: 1000 }), config, f.fetcher);
  const body = await response.json();
  assert.equal(response.status, 200); assert.equal(body.video_id, video);
  assert.match(body.signature, /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(body).includes(config.apiKey), false);
  assert.equal(f.writes[0].playback_url, url);
});
test("rechaza archivos vacíos o mayores que el límite antes de reservar o crear", async () => {
  for (const bytes of [0, -1, 20 * 1024 * 1024 + 1, 0.5]) {
    const f = fixture();
    assert.equal((await handleExerciseVideo(request({ action: "create", bytes }), config, f.fetcher)).status, 400);
    assert.equal(f.calls.some((s) => s.includes("reserve_") || s.includes("bunnycdn")), false);
  }
});
test("admite clips de ocho y diez segundos y conserva los de cinco", async () => {
  for (const length of [5, 8, 10]) {
    const f = fixture({ ready: false, provider: { length } });
    const result = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
    assert.equal((await result.json()).status, "ready");
    assert.equal(f.writes[0].duration_seconds, length);
  }
});

test("rechaza duración nula, inválida o superior a diez segundos", async () => {
  for (const length of [0, -1, "invalid", 10.01, 11]) {
    const f = fixture({ ready: false, provider: { length } });
    const result = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
    assert.equal((await result.json()).status, "rejected");
    assert.equal(f.writes[0].duration_seconds, null);
  }
});
test("solo queda listo al comprobar el MP4 final y conserva resoluciones inferiores", async () => {
  const f = fixture({ ready: false, provider: { availableResolutions: "480p,360p" } });
  const result = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
  const data = await result.json();
  assert.equal(data.status, "ready"); assert.ok(data.url.endsWith("play_480p.mp4"));
  assert.equal(f.writes[0].playback_bytes, 1000);
});
test("un resultado en proceso no publica ni permite reproducción", async () => {
  const f = fixture({ ready: false, provider: { status: 3 } });
  const result = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
  assert.equal((await result.json()).status, "processing");
  const playback = await handleExerciseVideo(request({ action: "playback", url }), config, f.fetcher);
  assert.equal(playback.status, 409);
});

test("ADMIN no abre vídeo privado ajeno por su permiso global", async () => {
  const f = fixture({ admin: true, scope: "trainer_exercise", manage: false, canRead: false });
  for (const action of ["playback", "thumbnail", "status"]) {
    assert.equal((await handleExerciseVideo(request({ action, id, url }), config, f.fetcher)).status, 403);
  }
  assert.equal(f.calls.some((s) => s.startsWith("https://video.bunnycdn.com")), false);
});

test("autor profesional obtiene subida scoped y exige operación estable", async () => {
  const f = fixture({ admin: false, manage: true, scope: "trainer_exercise" });
  const invalid = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", bytes: 21 * 1024 * 1024 }), config, f.fetcher);
  assert.equal(invalid.status, 400);
  const result = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", operation_id: id, bytes: 21 * 1024 * 1024 }), config, f.fetcher);
  const data = await result.json();
  assert.equal(result.status, 200); assert.equal(data.scope, "trainer_exercise");
  assert.equal(data.duration_limit, 180); assert.equal(data.playback_limit, 50 * 1024 * 1024);
});

test("una creación incierta se reconcilia por título único sin otro POST", async () => {
  const f = fixture({ admin: false, manage: true, scope: "trainer_exercise", creationState: "uncertain" });
  const result = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", operation_id: id, bytes: 1000 }), config, f.fetcher);
  assert.equal(result.status, 200);
  assert.ok(f.calls.some((s) => s.includes("search=EntrenaOP%20")));
  assert.equal(f.calls.filter((s) => s === "https://video.bunnycdn.com/library/42/videos").length, 0);
});

test("recuperación con cero, múltiples o resultados incompletos conserva incertidumbre", async () => {
  for (const options of [
    { searchItems: [] },
    { searchItems: [{ guid: video, videoLibraryId: 42, title: `EntrenaOP ${id}` }, { guid: user, videoLibraryId: 42, title: `EntrenaOP ${id}` }] },
    { searchTotal: 101 },
    { searchItems: [{ guid: video, videoLibraryId: 999, title: `EntrenaOP ${id}` }] },
    { searchItems: [{ guid: video, videoLibraryId: 42, title: "Otro título" }] },
  ]) {
    const f = fixture({ manage: true, scope: "trainer_exercise", creationState: "uncertain", ...options });
    const response = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", operation_id: id, bytes: 1000 }), config, f.fetcher);
    const data = await response.json(); assert.equal(response.status, 409);
    assert.equal(data.error, "video_creation_uncertain"); assert.equal(data.asset_id, id);
    assert.equal(f.writes.length, 0);
  }
});

test("timeout del proveedor conserva ID recuperable y no marca fallo definitivo", async () => {
  const f = fixture({ manage: true, scope: "trainer_exercise", providerTimeout: true });
  const response = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", operation_id: id, bytes: 1000 }), config, f.fetcher);
  const data = await response.json(); assert.equal(response.status, 503);
  assert.equal(data.asset_id, id); assert.equal(data.error, "video_creation_uncertain");
  assert.equal(f.asset.creation_state, "uncertain"); assert.equal(f.asset.status, "uploading");
});

test("activo ya creado renueva el mismo vídeo sin otra creación", async () => {
  const f = fixture({ manage: true, scope: "trainer_exercise", creationState: "created", provider: { status: 0 } });
  const response = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", operation_id: id, bytes: 1000 }), config, f.fetcher);
  assert.equal(response.status, 200); assert.equal((await response.json()).video_id, video);
  assert.equal(f.calls.some((s) => s === "https://video.bunnycdn.com/library/42/videos"), false);
});

test("confirmación void 204 entrega credenciales tras crear sin inventar incertidumbre", async () => {
  const f = fixture({ manage: true, scope: "trainer_exercise", voidResponse: true });
  const response = await handleExerciseVideo(request({ action: "create", scope: "trainer_exercise", operation_id: id, bytes: 1000 }), config, f.fetcher);
  const data = await response.json();
  assert.equal(response.status, 200);
  assert.equal(data.id, id); assert.equal(data.video_id, video);
  assert.match(data.signature, /^[a-f0-9]{64}$/);
  assert.equal(f.asset.creation_state, "created");
  assert.equal(f.calls.some((path) => path.endsWith("/rpc/mark_exercise_video_creation_uncertain")), false);
});

test("recuperar un activo listo nunca vuelve a emitir autorización de subida", async () => {
  const f = fixture({ manage: true, scope: "trainer_exercise", creationState: "created" });
  const response = await handleExerciseVideo(request({ action: "recover", id }), config, f.fetcher);
  const data = await response.json(); assert.equal(response.status, 409);
  assert.equal(data.error, "video_upload_closed"); assert.equal(data.signature, undefined);
});

test("duración privada no amplía las demostraciones oficiales", async () => {
  const privateClip = fixture({ manage: true, scope: "client_technique", ready: false, provider: { length: 120 } });
  const allowed = await handleExerciseVideo(request({ action: "status", id }), config, privateClip.fetcher);
  assert.equal((await allowed.json()).status, "ready");
  const official = fixture({ ready: false, provider: { length: 120 } });
  const rejected = await handleExerciseVideo(request({ action: "status", id }), config, official.fetcher);
  assert.equal((await rejected.json()).status, "rejected");
});

test("reproducción entrega cota privada autenticada sin claves", async () => {
  const f = fixture({ admin: false, scope: "client_technique", canRead: true });
  const response = await handleExerciseVideo(request({ action: "playback", url }), config, f.fetcher);
  const data = await response.json(); assert.equal(response.status, 200);
  assert.equal(data.scope, "client_technique"); assert.equal(data.playback_limit, 50 * 1024 * 1024);
  assert.equal(JSON.stringify(data).includes(config.apiKey), false);
});

test("bytes declarados no sustituyen el almacenamiento medido por Bunny", async () => {
  for (const storageSize of [0, -1, "invalid", 100 * 1024 * 1024 + 1]) {
    const f = fixture({ manage: true, scope: "trainer_exercise", ready: false, provider: { storageSize } });
    const result = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
    assert.equal((await result.json()).status, "rejected");
    assert.equal(f.writes[0].provider_storage_bytes, null);
  }
  const f = fixture({ manage: true, scope: "client_technique", ready: false, provider: { storageSize: 12345 } });
  assert.equal((await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher)).status, 200);
  assert.equal(f.writes[0].provider_storage_bytes, 12345);
});

test("archivo privado fuera de cota o scope desconocido no llega al proveedor", async () => {
  for (const body of [
    { scope: "trainer_exercise", bytes: 100 * 1024 * 1024 + 1 },
    { scope: "arbitrary", bytes: 100 },
  ]) {
    const f = fixture({ manage: true, scope: "trainer_exercise" });
    const result = await handleExerciseVideo(request({ action: "create", operation_id: id, ...body }), config, f.fetcher);
    assert.equal(result.status, 400); assert.equal(f.calls.some((s) => s.includes("bunnycdn")), false);
  }
});
test("preflight devuelve CORS y nunca consulta secretos ni proveedores", async () => {
  const f = fixture();
  const response = await handleExerciseVideo(new Request("https://fixture.invalid", { method: "OPTIONS" }), config, f.fetcher);
  assert.equal(response.status, 204); assert.equal(f.calls.length, 0);
});
test("un enlace externo se identifica sin exigir configuración de Bunny ni firmarlo", async () => {
  const f = fixture({ asset: false });
  const response = await handleExerciseVideo(request({ action: "playback", url }),
    { ...config, environment: "DISABLED", apiKey: "" }, f.fetcher);
  assert.equal(response.status, 404);
  assert.equal((await response.json()).error, "video_not_managed");
  assert.equal(f.calls.some((s) => s.includes("bunnycdn")), false);
});

test("estados terminales y espera de resolución conservan el scope privado", async () => {
  for (const scope of ["trainer_exercise", "client_technique"]) {
    for (const status of ["failed", "rejected"]) {
      const f = fixture({ manage: true, scope });
      f.asset.status = status;
      const response = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
      assert.deepEqual(await response.json(), { status, scope });
      assert.equal(f.calls.some((path) => path.startsWith("https://video.bunnycdn.com")), false);
    }
    const f = fixture({ manage: true, scope, ready: false, provider: { availableResolutions: "1080p" } });
    const response = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
    assert.deepEqual(await response.json(), { status: "processing", scope });
    assert.equal(f.writes.length, 0);
  }
});

test("un vídeo creado sin archivo conserva la recuperación aunque antes figurara processing", async () => {
  for (const scope of ["official", "trainer_exercise", "client_technique"]) {
    const f = fixture({ manage: true, scope, ready: false, provider: { status: 0 } });
    const response = await handleExerciseVideo(request({ action: "status", id }), config, f.fetcher);
    const data = await response.json();
    assert.equal(data.status, "uploading"); assert.equal(data.scope, scope);
    assert.equal(f.asset.status, "processing"); assert.equal(f.writes.length, 0);
    const recovery = await handleExerciseVideo(request({ action: "recover", id }), config, f.fetcher);
    const upload = await recovery.json();
    assert.equal(recovery.status, 200); assert.equal(upload.id, id); assert.equal(upload.video_id, video);
    assert.equal(f.calls.filter((path) => path.endsWith("/rpc/reserve_exercise_video_upload")).length, 0);
    assert.equal(f.calls.filter((path) => path === "https://video.bunnycdn.com/library/42/videos").length, 0);
  }
});

test("recuperar processing no permite sobrescribir un archivo ya entregado", async () => {
  for (const status of [1, 2, 3, 4, 5, 6, 7, 8]) for (const local of ["uploading", "processing"]) {
    const f = fixture({ manage: true, scope: "trainer_exercise", ready: false, provider: { status } });
    f.asset.status = local;
    const response = await handleExerciseVideo(request({ action: "recover", id }), config, f.fetcher);
    const data = await response.json();
    assert.equal(response.status, 409); assert.equal(data.error, "video_upload_closed");
    assert.equal(data.signature, undefined); assert.equal(f.writes.length, 0);
    assert.equal(f.uploadLeases.length, 0);
  }
});

test("recuperar no firma ni consulta el proveedor con un activo de otro entorno", async () => {
  const f = fixture({ manage: true, scope: "trainer_exercise", ready: false, provider: { status: 0 } });
  f.asset.library_id = 99;
  const response = await handleExerciseVideo(request({ action: "recover", id }), config, f.fetcher);
  const data = await response.json();
  assert.equal(response.status, 409); assert.equal(data.error, "video_environment_mismatch");
  assert.equal(data.signature, undefined); assert.equal(f.calls.some((path) => path.startsWith("https://video.bunnycdn.com")), false);
});

test("cada firma registra primero su caducidad para que limpieza respete la subida vigente", async () => {
  for (const action of ["create", "recover"]) {
    const f = fixture({ manage: true, scope: "trainer_exercise", ready: false, provider: { status: 0 } });
    const result = await handleExerciseVideo(request({ action, id, operation_id: id, scope: "trainer_exercise", bytes: 1000 }), config, f.fetcher);
    const body = await result.json();
    assert.equal(result.status, 200);
    assert.equal(f.uploadLeases.length, 1);
    assert.equal(f.uploadLeases[0].p_id, id);
    assert.equal(Date.parse(String(f.uploadLeases[0].p_expires_at)), body.expiration * 1000);
    assert.ok(Date.parse(String(f.uploadLeases[0].p_expires_at)) > Date.now());
    if (action === "recover") assert.equal(f.asset.status, "processing");
  }
});

test("un destino sellado por limpieza rechaza credenciales nuevas y recuperadas", async () => {
  for (const action of ["create", "recover"]) {
    const f = fixture({ manage: true, scope: "trainer_exercise", ready: false, provider: { status: 0 }, uploadLeaseDenied: true });
    const result = await handleExerciseVideo(request({ action, id, operation_id: id, scope: "trainer_exercise", bytes: 1000 }), config, f.fetcher);
    const body = await result.json();
    assert.notEqual(result.status, 200);
    assert.equal(body.signature, undefined);
    assert.equal(body.expiration, undefined);
    assert.equal(f.uploadLeases.length, 1);
  }
});
