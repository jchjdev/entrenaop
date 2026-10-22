import { test } from "node:test";
import assert from "node:assert/strict";
import { createGarminAuthorization, GarminOAuthClient, GarminOAuthError,
  garminPermissions, parseGarminCallback, pkceChallenge } from "../_shared/garmin/oauth.ts";

const redirectUri = "https://fixture.supabase.co/functions/v1/garmin-oauth-callback";
const config = { clientId: "fixture-client", clientSecret: "fixture-secret", redirectUri };
const state = "a".repeat(43);
const verifier = "b".repeat(43);
const tokenResponse = { access_token: "fixture-access", refresh_token: "fixture-refresh",
  expires_in: 86400, refresh_token_expires_in: 7775998, token_type: "bearer",
  scope: "CONNECT_READ CONNECT_WRITE" };
function code(error: unknown, expected: string) {
  assert.ok(error instanceof GarminOAuthError);
  assert.equal(error.code, expected);
  assert.equal(error.message, expected);
  return true;
}

test("PKCE S256 coincide con el vector RFC 7636", async () => {
  assert.equal(await pkceChallenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
    "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
});

test("autorización genera state y verifier independientes sin exponer el verifier", async () => {
  const first = await createGarminAuthorization(config.clientId, redirectUri);
  const second = await createGarminAuthorization(config.clientId, redirectUri);
  assert.match(first.state, /^[A-Za-z0-9_-]{43}$/);
  assert.match(first.verifier, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(first.state, first.verifier);
  assert.notEqual(first.state, second.state);
  assert.notEqual(first.verifier, second.verifier);
  const url = new URL(first.authorizationUrl);
  assert.equal(url.origin + url.pathname, "https://connect.garmin.com/oauth2Confirm");
  assert.equal(url.searchParams.get("redirect_uri"), redirectUri);
  assert.equal(url.searchParams.get("code_challenge_method"), "S256");
  assert.equal(url.searchParams.get("code_challenge"), await pkceChallenge(first.verifier));
  assert.equal(url.searchParams.get("state"), first.state);
  assert.equal(url.searchParams.get("response_type"), "code");
  assert.equal(url.searchParams.has("client_secret"), false);
  assert.equal(first.authorizationUrl.includes(first.verifier), false);
});

test("rechaza retornos inseguros, ambiguos o con credenciales", async () => {
  for (const uri of ["http://fixture.invalid/cb", "https://u:p@fixture.invalid/cb",
    "https://fixture.invalid/cb?redirect=other", "https://fixture.invalid/cb#fragment", "invalid"]) {
    await assert.rejects(createGarminAuthorization(config.clientId, uri), e => code(e, "invalid_configuration"));
  }
  await assert.rejects(pkceChallenge("short"), e => code(e, "invalid_configuration"));
});

test("callback acepta solo el código con state esperado y retorno exacto", () => {
  assert.equal(parseGarminCallback(`${redirectUri}?state=${state}&code=fixture-code`, redirectUri, state), "fixture-code");
  for (const url of [
    `${redirectUri}?state=other&code=fixture-code`,
    `${redirectUri}?code=fixture-code`,
    `${redirectUri}?state=${state}&state=${state}&code=fixture-code`,
    `${redirectUri}?state=${state}&code=one&code=two`,
    `${redirectUri}?state=${state}&code=one&error=access_denied`,
    `${redirectUri}?state=${state}&error=a&error=b`,
    `${redirectUri}?state=${state}&code=`,
    `${redirectUri}?state=${state}&code=bad%0Acode`,
    `${redirectUri}?state=${state}&code=one#fragment`,
    `https://other.invalid/cb?state=${state}&code=one`,
    `${redirectUri}/other?state=${state}&code=one`,
    "invalid",
  ]) assert.throws(() => parseGarminCallback(url, redirectUri, state), e => code(e, "invalid_callback"));
  assert.throws(() => parseGarminCallback(`${redirectUri}?state=${state}&error=access_denied`, redirectUri, state), e => code(e, "authorization_denied"));
});

test("canje en servidor usa Basic, formulario y retorno fijado, sin seguir redirecciones", async () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const client = new GarminOAuthClient(config, async (target, init) => {
    calls.push({ url: String(target), init: init! });
    return Response.json(tokenResponse);
  });
  const tokens = await client.exchange("fixture-code", verifier);
  assert.equal(tokens.accessToken, "fixture-access");
  assert.equal(tokens.refreshExpiresInSeconds, 7775998);
  assert.equal(calls[0].url, "https://diauth.garmin.com/di-oauth2-service/oauth/token");
  const request = calls[0].init;
  assert.equal(request.redirect, "error");
  assert.ok(request.signal);
  assert.equal(new Headers(request.headers).get("Authorization"), `Basic ${btoa("fixture-client:fixture-secret")}`);
  const body = new URLSearchParams(String(request.body));
  assert.equal(body.get("grant_type"), "authorization_code");
  assert.equal(body.get("code_verifier"), verifier);
  assert.equal(body.get("redirect_uri"), redirectUri);
  assert.equal(calls[0].url.includes("fixture-secret"), false);
});

test("renovación conserva el token nuevo y no reintenta un canje incierto", async () => {
  let count = 0;
  const client = new GarminOAuthClient(config, async (_url, init) => {
    count++;
    assert.equal(new URLSearchParams(String(init?.body)).get("grant_type"), "refresh_token");
    return Response.json({ ...tokenResponse, refresh_token: "fixture-rotated" });
  });
  assert.equal((await client.refresh("fixture-old")).refreshToken, "fixture-rotated");
  assert.equal(count, 1);
  const uncertain = new GarminOAuthClient(config, async () => { count++; throw new Error("private provider detail"); });
  await assert.rejects(uncertain.refresh("fixture-old"), e => code(e, "provider_unavailable"));
  assert.equal(count, 2);
});

test("identidad y permisos se consultan con el token del usuario; permiso parcial válido", async () => {
  const client = new GarminOAuthClient(config, async (url, init) => {
    assert.equal(new Headers(init?.headers).get("Authorization"), "Bearer fixture-access");
    if (String(url).endsWith("/id")) return Response.json({ userId: "fixture-garmin-user" });
    assert.equal(String(url), "https://apis.garmin.com/partner-gateway/rest/user/permissions");
    return Response.json({ permissions: ["ACTIVITY_EXPORT", "FUTURE_PERMISSION"] });
  });
  assert.equal(await client.userId("fixture-access"), "fixture-garmin-user");
  assert.deepEqual(await client.permissions("fixture-access"), { canReadActivities: true, canSendWorkouts: false });
  assert.deepEqual(garminPermissions(["WORKOUT_IMPORT"]), { canReadActivities: false, canSendWorkouts: true });
  assert.deepEqual(garminPermissions([]), { canReadActivities: false, canSendWorkouts: false });
});

test("errores sanitizados y respuestas inválidas no filtran cuerpos del proveedor", async () => {
  for (const [status, expected] of [[400,"provider_rejected"], [401,"reauthorization_required"],
    [403,"permission_denied"], [429,"rate_limited"], [500,"provider_unavailable"], [302,"provider_unavailable"]] as const) {
    const client = new GarminOAuthClient(config, async () => new Response("private-secret", {status}));
    await assert.rejects(client.refresh("fixture-old"), e => code(e, expected));
  }
  for (const body of [[], {}, { ...tokenResponse, expires_in: -1 },
    { ...tokenResponse, refresh_token: null }, { ...tokenResponse, token_type: "other" },
    { ...tokenResponse, refresh_token_expires_in: 1.5 }, { ...tokenResponse, access_token: "bad\r\ntoken" }]) {
    const client = new GarminOAuthClient(config, async () => Response.json(body));
    await assert.rejects(client.exchange("fixture-code", verifier), e => code(e, "invalid_response"));
  }
  for (const body of ["not JSON", "x".repeat(65537)]) {
    const client = new GarminOAuthClient(config, async () => new Response(body));
    await assert.rejects(client.refresh("fixture-old"), e => code(e, "invalid_response"));
  }
});

test("identidad o permisos malformados se rechazan sin habilitar capacidades", async () => {
  for (const body of [{userId: ""}, {userId: 42}]) {
    const client = new GarminOAuthClient(config, async () => Response.json(body));
    await assert.rejects(client.userId("fixture-access"), e => code(e, "invalid_response"));
  }
  for (const body of [{permissions: null}, {permissions: [42]}, {permissions: ["ACTIVITY_EXPORT\n"]}]) {
    const client = new GarminOAuthClient(config, async () => Response.json(body));
    await assert.rejects(client.permissions("fixture-access"), e => code(e, "invalid_response"));
  }
});
