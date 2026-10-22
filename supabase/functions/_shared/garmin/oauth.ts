// Adaptador de servidor. No importa Flutter ni modifica el historial deportivo.
const authorizationEndpoint = "https://connect.garmin.com/oauth2Confirm";
const tokenEndpoint = "https://diauth.garmin.com/di-oauth2-service/oauth/token";
const userEndpoint = "https://apis.garmin.com/partner-gateway/rest/user";

export class GarminOAuthError extends Error {
  readonly code: "invalid_configuration" | "invalid_callback" |
    "authorization_denied" | "reauthorization_required" | "rate_limited" |
    "provider_unavailable" | "provider_rejected" | "permission_denied" | "invalid_response";
  constructor(code: GarminOAuthError["code"]) {
    // Nunca propagar cuerpos, códigos OAuth, tokens o secretos del proveedor.
    super(code);
    this.name = "GarminOAuthError";
    this.code = code;
  }
}

export type GarminOAuthConfig = {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
};
export type GarminTokens = {
  accessToken: string;
  refreshToken: string;
  expiresInSeconds: number;
  refreshExpiresInSeconds: number;
  scope: string;
};
export type GarminPermissions = {
  canReadActivities: boolean;
  canSendWorkouts: boolean;
};

function opaque(value: unknown, max = 8192): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= max &&
    !/[\s\u0000-\u001f\u007f]/u.test(value);
}
function callbackUrl(value: string): URL {
  let url: URL;
  try { url = new URL(value); } catch { throw new GarminOAuthError("invalid_configuration"); }
  if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
    throw new GarminOAuthError("invalid_configuration");
  }
  return url;
}
function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
export async function pkceChallenge(verifier: string): Promise<string> {
  if (!/^[A-Za-z0-9._~-]{43,128}$/.test(verifier)) {
    throw new GarminOAuthError("invalid_configuration");
  }
  return base64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))));
}

/** Guardar state y verifier solo en servidor, vinculados a cuenta/entorno y caducidad. */
export async function createGarminAuthorization(clientId: string, redirectUri: string) {
  if (!opaque(clientId, 256)) throw new GarminOAuthError("invalid_configuration");
  const redirect = callbackUrl(redirectUri);
  const verifier = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const state = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const url = new URL(authorizationEndpoint);
  url.search = new URLSearchParams({
    client_id: clientId, response_type: "code", state,
    redirect_uri: redirect.href, code_challenge: await pkceChallenge(verifier),
    code_challenge_method: "S256",
  }).toString();
  return { authorizationUrl: url.href, state, verifier };
}

/** La capa de aplicación debe reclamar el intento una sola vez antes del canje. */
export function parseGarminCallback(actualUrl: string, redirectUri: string, expectedState: string): string {
  const expected = callbackUrl(redirectUri);
  let actual: URL;
  try { actual = new URL(actualUrl); } catch { throw new GarminOAuthError("invalid_callback"); }
  const params = actual.searchParams;
  if (actual.origin !== expected.origin || actual.pathname !== expected.pathname ||
    actual.username || actual.password || actual.hash ||
    !/^[A-Za-z0-9_-]{43}$/.test(expectedState) ||
    params.getAll("state").length !== 1 || params.get("state") !== expectedState ||
    params.getAll("code").length > 1 || params.getAll("error").length > 1 ||
    (params.has("code") && params.has("error"))) {
    throw new GarminOAuthError("invalid_callback");
  }
  if (params.has("error")) throw new GarminOAuthError("authorization_denied");
  const code = params.get("code");
  if (!opaque(code, 2048)) throw new GarminOAuthError("invalid_callback");
  return code;
}

export function garminPermissions(values: readonly string[]): GarminPermissions {
  // Los scopes del token no acreditan los permisos concretos elegidos por el usuario.
  return { canReadActivities: values.includes("ACTIVITY_EXPORT"), canSendWorkouts: values.includes("WORKOUT_IMPORT") };
}

export class GarminOAuthClient {
  private readonly config: GarminOAuthConfig;
  private readonly fetcher: typeof fetch;
  constructor(config: GarminOAuthConfig, fetcher: typeof fetch = fetch) {
    callbackUrl(config.redirectUri);
    if (!opaque(config.clientId, 256) || !opaque(config.clientSecret, 4096) || config.clientId.includes(":")) {
      throw new GarminOAuthError("invalid_configuration");
    }
    this.config = { ...config };
    this.fetcher = fetcher;
  }

  async exchange(code: string, verifier: string): Promise<GarminTokens> {
    if (!opaque(code, 2048)) throw new GarminOAuthError("invalid_callback");
    await pkceChallenge(verifier);
    return this.token(new URLSearchParams({ grant_type: "authorization_code", code,
      code_verifier: verifier, redirect_uri: this.config.redirectUri }));
  }

  async refresh(refreshToken: string): Promise<GarminTokens> {
    if (!opaque(refreshToken)) throw new GarminOAuthError("invalid_configuration");
    // Sin reintento automático: el proveedor rota el refresh token en cada canje.
    return this.token(new URLSearchParams({ grant_type: "refresh_token", refresh_token: refreshToken }));
  }

  async userId(accessToken: string): Promise<string> {
    const body = await this.userRequest("/id", accessToken);
    if (!opaque(body.userId, 256)) throw new GarminOAuthError("invalid_response");
    return body.userId;
  }

  async permissions(accessToken: string): Promise<GarminPermissions> {
    const body = await this.userRequest("/permissions", accessToken);
    if (!Array.isArray(body.permissions) || body.permissions.length > 100 ||
      !body.permissions.every(value => opaque(value, 256))) throw new GarminOAuthError("invalid_response");
    return garminPermissions(body.permissions);
  }

  private userRequest(path: "/id" | "/permissions", token: string) {
    if (!opaque(token)) throw new GarminOAuthError("invalid_configuration");
    return this.request(userEndpoint + path, { headers: { Authorization: `Bearer ${token}` } });
  }

  private async token(body: URLSearchParams): Promise<GarminTokens> {
    const basic = btoa(String.fromCharCode(...new TextEncoder().encode(`${this.config.clientId}:${this.config.clientSecret}`)));
    const data = await this.request(tokenEndpoint, { method: "POST", body,
      headers: { Authorization: `Basic ${basic}`, "Content-Type": "application/x-www-form-urlencoded" } });
    const positive = (value: unknown): value is number => typeof value === "number" && Number.isSafeInteger(value) && value > 0;
    if (!opaque(data.access_token) || !opaque(data.refresh_token) ||
      typeof data.token_type !== "string" || data.token_type.toLowerCase() !== "bearer" ||
      !positive(data.expires_in) || !positive(data.refresh_token_expires_in) ||
      typeof data.scope !== "string" || data.scope.length > 4096) throw new GarminOAuthError("invalid_response");
    return { accessToken: data.access_token, refreshToken: data.refresh_token,
      expiresInSeconds: data.expires_in, refreshExpiresInSeconds: data.refresh_token_expires_in,
      scope: data.scope };
  }

  private async request(url: string, init: RequestInit): Promise<Record<string, unknown>> {
    try {
      // Una redirección jamás recibe Authorization ni códigos/secretos del canje.
      const response = await this.fetcher(url, { ...init, redirect: "error", signal: AbortSignal.timeout(10_000) });
      if (response.status === 429) throw new GarminOAuthError("rate_limited");
      if (response.status === 400) throw new GarminOAuthError("provider_rejected");
      if (response.status === 403) throw new GarminOAuthError("permission_denied");
      if (response.status === 401) {
        throw new GarminOAuthError("reauthorization_required");
      }
      if (!response.ok) throw new GarminOAuthError("provider_unavailable");
      const reader = response.body?.getReader();
      if (!reader) throw new GarminOAuthError("invalid_response");
      const chunks: Uint8Array[] = [];
      let size = 0;
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          size += value.length;
          if (size > 64 * 1024) throw new GarminOAuthError("invalid_response");
          chunks.push(value);
        }
      } finally { await reader.cancel().catch(() => {}); }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
      let data: unknown;
      try { data = JSON.parse(new TextDecoder().decode(bytes)); } catch { throw new GarminOAuthError("invalid_response"); }
      if (!data || typeof data !== "object" || Array.isArray(data)) throw new GarminOAuthError("invalid_response");
      return data as Record<string, unknown>;
    } catch (error) {
      if (error instanceof GarminOAuthError) throw error;
      throw new GarminOAuthError("provider_unavailable");
    }
  }
}
