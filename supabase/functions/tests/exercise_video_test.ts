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
  provider?: Record<string, unknown>; auth?: boolean; asset?: boolean } = {}) {
  const writes: Record<string, unknown>[] = [];
  const calls: string[] = [];
  const fetcher: typeof fetch = async (target, init) => {
    const path = String(target); calls.push(path);
    if (path.endsWith("/auth/v1/user")) return Response.json({ id: user }, { status: options.auth === false ? 401 : 200 });
    if (path.endsWith("/rpc/is_admin")) return Response.json(options.admin !== false);
    if (path.endsWith("/rpc/can_read_exercise_video")) return Response.json(options.canRead === true);
    if (path.endsWith("/rpc/reserve_official_exercise_video")) return Response.json(id);
    if (path.includes("/exercise_video_assets?") && init?.method === "GET") return Response.json(options.asset === false ? [] : [{
      id, created_by: user, library_id: 42, provider_video_id: video, cdn_host: config.cdnHost,
      playback_url: url, playback_bytes: 1000, status: options.ready === false ? "processing" : "ready",
    }]);
    if (path.includes("/exercise_video_assets?") && init?.method === "PATCH") {
      writes.push(JSON.parse(String(init.body))); return Response.json([]);
    }
    if (path.startsWith("https://video.bunnycdn.com/library/42/videos")) {
      return Response.json({ guid: video, videoLibraryId: 42, status: 4, length: 5,
        hasMP4Fallback: true, availableResolutions: "360p,480p,720p", storageSize: 10000, ...options.provider });
    }
    if (path.startsWith("https://fixture.b-cdn.net/")) return new Response(null, {
      headers: { "Content-Length": "1000", "Content-Type": "video/mp4" } });
    throw new Error(`Solicitud inesperada: ${path}`);
  };
  return { fetcher, calls, writes };
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
  for (const action of ["create", "status"]) {
    const f = fixture({ admin: false });
    assert.equal((await handleExerciseVideo(request({ action, bytes: 10, id }), config, f.fetcher)).status, 403);
    assert.equal(f.calls.some((s) => s.includes("bunnycdn")), false);
  }
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
