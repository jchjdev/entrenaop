import { createGarminAuthorization, parseGarminCallback } from "./oauth.ts";
import type { GarminOAuthConfig, GarminPermissions, GarminTokens } from "./oauth.ts";
import { garminStateHash } from "./cipher.ts";

export type GarminSnapshot = {
  allowed: boolean; status: string; generation: number; can_read: boolean; can_send: boolean;
  updated_at: string | null; authorization_expires_at: string | null;
};
type Json = Record<string, unknown>;
export interface GarminConnectionStore {
  command(action: string, owner: string | null, session: string | null, input: Json): Promise<Json>;
}
export interface GarminAccountProvider {
  exchange(code: string, verifier: string): Promise<GarminTokens>;
  refresh(token: string): Promise<GarminTokens>;
  userId(token: string): Promise<string>;
  permissions(token: string): Promise<GarminPermissions>;
  disconnect(token: string): Promise<void>;
}
export interface GarminSecretBox {
  seal(value:unknown,context:string):Promise<string>;
  open<T>(value:string,context:string):Promise<T>;
}
type AuthorizationConfig=Pick<GarminOAuthConfig,"clientId"|"redirectUri">;
type CallbackStage="authorization"|"open_verifier"|"exchange_code"|"save_grant"|"read_identity"|"read_permissions"|"complete";
export class GarminCallbackError extends Error {
  readonly stage:CallbackStage;
  constructor(stage:CallbackStage,error:unknown) {
    super(error instanceof Error ? error.message : "garmin_unavailable",{cause:error});
    this.name="GarminCallbackError";
    this.stage=stage;
  }
}
export class GarminConnectionService {
  private readonly store: GarminConnectionStore;
  private readonly provider: GarminAccountProvider;
  private readonly cipher: GarminSecretBox;
  private readonly config: AuthorizationConfig;
  private readonly now: () => number;
  constructor(store: GarminConnectionStore, provider: GarminAccountProvider, cipher: GarminSecretBox,
    config: AuthorizationConfig, now: () => number = Date.now) {
    this.store=store; this.provider=provider; this.cipher=cipher; this.config={...config}; this.now=now;
  }
  status(owner: string, session: string) { return this.store.command("status",owner,session,{}); }
  async begin(owner: string, session: string) {
    const authorization = await createGarminAuthorization(this.config.clientId,this.config.redirectUri);
    const hash = await garminStateHash(authorization.state);
    const encrypted = await this.cipher.seal(authorization.verifier,`verifier:${owner}:${hash}`);
    const snapshot = await this.store.command("begin",owner,session,{state_hash:hash,verifier_cipher:encrypted});
    // Verifier, secreto, identidad Garmin y tokens no salen del servidor.
    return {...snapshot,authorization_url:authorization.authorizationUrl};
  }
  async callback(url: string) {
    const parsed = new URL(url);
    const state = parsed.searchParams.get("state") ?? "";
    // Valida estructura y retorno antes de consumir un intento persistente.
    // La denegación se procesa tras reclamar el state para no dejarlo reutilizable.
    let authorizationCode: string | null = null;
    let denied = false;
    try { authorizationCode=parseGarminCallback(url,this.config.redirectUri,state); }
    catch(error) {
      if (error instanceof Error && error.message === "authorization_denied") denied=true;
      else throw error;
    }
    const claim = crypto.randomUUID();
    const attempt = await this.store.command("claim",null,null,{state_hash:await garminStateHash(state),claim_id:claim});
    const owner = String(attempt.owner_id), generation = Number(attempt.generation);
    let exchanged = false;
    let stage:CallbackStage="authorization";
    try {
      if (denied) throw new Error("authorization_denied");
      stage="open_verifier";
      const verifier = await this.cipher.open<string>(String(attempt.verifier_cipher),`verifier:${owner}:${attempt.state_hash}`);
      stage="exchange_code";
      const tokens = await this.provider.exchange(authorizationCode!,verifier);
      exchanged=true;
      stage="save_grant";
      const encrypted = await this.cipher.seal(tokens,`tokens:${owner}:${generation}`);
      const expirations=this.expirations(tokens);
      await this.store.command("stash_grant",owner,null,{generation,claim_id:claim,
        tokens_cipher:encrypted,...expirations});
      stage="read_identity";
      const userId = await this.provider.userId(tokens.accessToken);
      stage="read_permissions";
      const permissions = await this.provider.permissions(tokens.accessToken);
      stage="complete";
      const snapshot = await this.store.command("complete",owner,null,{generation,claim_id:claim,
        garmin_user_id:userId,tokens_cipher:encrypted,can_read:permissions.canReadActivities,can_send:permissions.canSendWorkouts,
        ...expirations});
      if (snapshot.status !== "connected") await this.revoke(owner);
      return snapshot.status === "connected" ? "connected" : "disconnected";
    } catch(error) {
      const accountInUse=error instanceof Error && error.message === "provider_account_in_use";
      await this.store.command("fail",owner,null,{generation,claim_id:claim,no_grant:denied && !exchanged,account_in_use:accountInUse}).catch(()=>{});
      // No revocar una identidad que podría pertenecer a otra conexión legítima.
      if(exchanged && !accountInUse) await this.revoke(owner).catch(()=>{});
      throw new GarminCallbackError(stage,error);
    }
  }
  async disconnect(owner: string, session: string, generation: number) {
    const snapshot = await this.store.command("disconnect",owner,session,{generation});
    if(snapshot.status !== "disconnected") await this.revoke(owner);
    return this.status(owner,session);
  }
  // Limpieza interna tras liberar un envío que coincidió con desconectar.
  // claim_revoke no concede trabajo mientras la conexión siga operativa.
  async finishPendingDisconnect(owner:string){await this.revoke(owner);}
  private expirations(tokens: GarminTokens) {
    const now = this.now();
    return { access_expires_at:new Date(now+tokens.expiresInSeconds*1000).toISOString(),
      refresh_expires_at:new Date(now+tokens.refreshExpiresInSeconds*1000).toISOString() };
  }
  private async revoke(owner: string) {
    const lease=crypto.randomUUID();
    const claim=await this.store.command("claim_revoke",owner,null,{lease_id:lease});
    if(claim.pending) return;
    const generation=Number(claim.generation);
    try {
      let tokens=await this.cipher.open<GarminTokens>(String(claim.tokens_cipher),`tokens:${owner}:${generation}`);
      if(Date.parse(String(claim.access_expires_at))<=this.now()+30000) {
        if(Date.parse(String(claim.refresh_expires_at))<=this.now()) throw new Error("reauthorization_required");
        tokens=await this.provider.refresh(tokens.refreshToken);
        // Guardar el token rotado antes de otra petición o de reconocer el trabajo.
        await this.store.command("rotate_revoke",owner,null,{generation,lease_id:lease,
          tokens_cipher:await this.cipher.seal(tokens,`tokens:${owner}:${generation}`),...this.expirations(tokens)});
      }
      // Un canje fallido a mitad de camino podría corresponder a otro Garmin ya
      // vinculado: verificar identidad y exclusividad antes de retirar su permiso.
      const identity=await this.provider.userId(tokens.accessToken);
      await this.store.command("identify_revoke",owner,null,{generation,lease_id:lease,garmin_user_id:identity});
      await this.provider.disconnect(tokens.accessToken);
      await this.store.command("finish_revoke",owner,null,{generation,lease_id:lease});
    } catch {
      await this.store.command("fail_revoke",owner,null,{generation,lease_id:lease}).catch(()=>{});
    }
  }
}
