import {test} from "node:test";
import assert from "node:assert/strict";
import {GarminCipher} from "../_shared/garmin/cipher.ts";
import {handleGarminConnection,handleGarminCallback} from "../_shared/garmin/http.ts";
import type {GarminServerConfig} from "../_shared/garmin/http.ts";

const owner="10000000-0000-4000-8000-000000000001",session="20000000-0000-4000-8000-000000000001";
const key=Buffer.alloc(32,7).toString("base64url");
const c:GarminServerConfig={environment:"DEVELOPMENT",supabaseUrl:"https://sxbxfjqgoddzhtcyhalw.supabase.co",
  anonKey:"fixture-anon",serviceKey:"fixture-service",clientId:"fixture-client",clientSecret:"fixture-secret",encryptionKey:key};
const jwt=`fixture.${Buffer.from(JSON.stringify({session_id:session})).toString("base64url")}.fixture`;
const callback=`${c.supabaseUrl}/functions/v1/garmin-oauth-callback`;
function request(action:string,extra:Record<string,unknown>={},authorization=`Bearer ${jwt}`) {
  return new Request(`${c.supabaseUrl}/functions/v1/garmin-connection`,{method:"POST",headers:{Authorization:authorization},
    body:JSON.stringify({action,expected_user_id:owner,...extra})});
}
function fixture(options:{allowed?:boolean;auth?:boolean;revokeFailure?:boolean;expired?:boolean;idFailure?:boolean}={}) {
  const calls:string[]=[],commands:string[]=[];
  const row:Record<string,unknown>={allowed:options.allowed!==false,status:"disconnected",generation:0,can_read:false,can_send:false,
    updated_at:null,authorization_expires_at:null};
  const snapshot=()=>Object.fromEntries(Object.entries(row).filter(([name])=>["allowed","status","generation","can_read","can_send","updated_at","authorization_expires_at"].includes(name)));
  const f:typeof fetch=async(url,init)=>{
    const path=String(url);calls.push(path);
    if(path.endsWith("/auth/v1/user")) return Response.json({id:owner},{status:options.auth===false?401:200});
    if(path.endsWith("/rpc/garmin_account_command")) {
      assert.equal(new Headers(init?.headers).get("apikey"),"fixture-service");
      const body=JSON.parse(String(init?.body)); const input=body.p_input; commands.push(body.p_action);
      const invalid=(message:string,status=409)=>Response.json({message},{status});
      switch(body.p_action) {
        case "status":return Response.json(snapshot());
        case "begin":
          if(!row.allowed) return invalid("access_required",403);
          Object.assign(row,{status:"authorizing",generation:Number(row.generation)+1,...input});
          return Response.json(snapshot());
        case "claim":
          if(row.status!=="authorizing" || row.claim_id || row.state_hash!==input.state_hash) return invalid("invalid_attempt");
          row.claim_id=input.claim_id;
          return Response.json({owner_id:owner,generation:row.generation,verifier_cipher:row.verifier_cipher,
            state_hash:row.state_hash,claim_id:input.claim_id});
        case "stash_grant":Object.assign(row,input);return Response.json(snapshot());
        case "complete":Object.assign(row,input,{status:"connected",claim_id:null});return Response.json(snapshot());
        case "fail":Object.assign(row,{status:input.no_grant?"authorization_failed":"revocation_pending"});return Response.json(snapshot());
        case "disconnect":
          if(input.generation!==row.generation) return invalid("stale_attempt");
          Object.assign(row,{status:row.tokens_cipher?"disconnecting":"disconnected",can_read:false,can_send:false});return Response.json(snapshot());
        case "claim_revoke":return Response.json({generation:row.generation,tokens_cipher:row.tokens_cipher,
          access_expires_at:options.expired?"2000-01-01T00:00:00Z":row.access_expires_at,refresh_expires_at:row.refresh_expires_at});
        case "identify_revoke":return Response.json(snapshot());
        case "rotate_revoke":Object.assign(row,input);return Response.json(snapshot());
        case "finish_revoke":Object.assign(row,{status:"disconnected",tokens_cipher:null,garmin_user_id:null});return Response.json(snapshot());
        case "fail_revoke":row.status="revocation_pending";return Response.json(snapshot());
        default:throw new Error("Unexpected command");
      }
    }
    if(path==="https://diauth.garmin.com/di-oauth2-service/oauth/token") {
      assert.equal(init?.redirect,"error");
      const refresh=new URLSearchParams(String(init?.body)).get("grant_type")==="refresh_token";
      return Response.json({access_token:refresh?"fixture-rotated-access":"fixture-access",refresh_token:refresh?"fixture-rotated-refresh":"fixture-refresh",
        token_type:"bearer",expires_in:3600,refresh_token_expires_in:7200,scope:"CONNECT_READ CONNECT_WRITE"});
    }
    if(path.endsWith("/user/id")) return options.idFailure?new Response(null,{status:503}):Response.json({userId:"fixture-garmin-account"});
    if(path.endsWith("/user/permissions")) return Response.json({permissions:["ACTIVITY_EXPORT"]});
    if(path.endsWith("/user/registration")) {
      assert.equal(init?.method,"DELETE");assert.equal(init?.redirect,"error");
      if(options.expired) assert.equal(commands.at(-1),"identify_revoke");
      return new Response(null,{status:options.revokeFailure?503:204});
    }
    throw new Error(`Unexpected destination ${path}`);
  };
  return {f,calls,commands,row};
}
async function connect(f:typeof fetch,callbackBase=callback) {
  const start=await handleGarminConnection(request("begin"),c,f);
  assert.equal(start.status,200);
  const body=await start.json();const url=new URL(body.authorization_url);
  const result=await handleGarminCallback(new Request(`${callbackBase}?state=${url.searchParams.get("state")}&code=fixture-code`),c,f);
  assert.equal(result.status,200);
  return url.searchParams.get("state")!;
}

test("cifrado no se puede trasladar entre cuenta, generación ni finalidad",async()=>{
  const cipher=new GarminCipher(key);
  const value={accessToken:"fixture-token"};
  const first=await cipher.seal(value,`tokens:${owner}:1`);
  const second=await cipher.seal(value,`tokens:${owner}:1`);
  assert.notEqual(first,second);assert.equal(first.includes("fixture-token"),false);
  assert.deepEqual(await cipher.open(first,`tokens:${owner}:1`),value);
  for(const context of [`tokens:${owner}:2`,`tokens:another:1`,`verifier:${owner}:1`]) {
    await assert.rejects(cipher.open(first,context),/invalid_ciphertext/);
  }
  await assert.rejects(cipher.open(first.slice(0,-2)+"AA",`tokens:${owner}:1`),/invalid_ciphertext/);
  assert.throws(()=>new GarminCipher("invalid"));
});

test("desactivado y configuración de producción no hacen llamadas",async()=>{
  for(const config of [{...c,environment:"DISABLED"},{...c,supabaseUrl:"https://production.invalid"},{...c,encryptionKey:""}]) {
    const fx=fixture();const response=await handleGarminConnection(request("begin"),config,fx.f);
    assert.equal(response.status,503);assert.deepEqual(fx.calls,[]);
  }
});

test("JWT, cuenta esperada y acceso comercial se verifican antes de Garmin",async()=>{
  const fx=fixture();
  assert.equal((await handleGarminConnection(request("begin",{},""),c,fx.f)).status,401);
  assert.deepEqual(fx.calls,[]);
  assert.equal((await handleGarminConnection(request("begin",{expected_user_id:"other"}),c,fx.f)).status,409);
  assert.equal(fx.commands.length,0);
  const denied=fixture({allowed:false});
  assert.equal((await handleGarminConnection(request("begin"),c,denied.f)).status,403);
  assert.equal(denied.calls.some(url=>url.includes("diauth")),false);
});

test("autoriza con PKCE y consulta estado sin filtrar tokens, verifier o identidad Garmin",async()=>{
  const fx=fixture();await connect(fx.f);
  const status=await handleGarminConnection(request("status"),c,fx.f);const text=await status.text();
  assert.equal(JSON.parse(text).status,"connected");
  assert.equal(JSON.parse(text).can_read,true);assert.equal(JSON.parse(text).can_send,false);
  for(const secret of ["fixture-access","fixture-secret","tokens_cipher","verifier_cipher","fixture-garmin-account"]) assert.equal(text.includes(secret),false);
  assert.match(String(fx.row.tokens_cipher),/^v1\./);
  assert.deepEqual(fx.commands.slice(0,4),["begin","claim","stash_grant","complete"]);
});

test("un callback repetido no vuelve a canjear el código",async()=>{
  const fx=fixture();const state=await connect(fx.f);
  const tokensBefore=fx.calls.filter(x=>x.includes("/oauth/token")).length;
  const response=await handleGarminCallback(new Request(`${callback}?state=${state}&code=fixture-code`),c,fx.f);
  assert.equal(response.status,409);
  assert.equal(fx.calls.filter(x=>x.includes("/oauth/token")).length,tokensBefore);
});

test("el callback Edge reescrito conserva el retorno público fijado",async()=>{
  const fx=fixture();
  await connect(fx.f,"http://edge-runtime.internal/garmin-oauth-callback");
  assert.equal(fx.row.status,"connected");
});

test("denegar consume el intento sin pedir tokens; el HTML no refleja parámetros",async()=>{
  const fx=fixture();const response=await handleGarminConnection(request("begin"),c,fx.f);
  const state=new URL((await response.json()).authorization_url).searchParams.get("state");
  const result=await handleGarminCallback(new Request(`${callback}?state=${state}&error=access_denied&error_description=PRIVATE_DETAIL`),c,fx.f);
  assert.equal(fx.row.status,"authorization_failed");assert.equal(fx.calls.some(url=>url.includes("diauth")),false);
  const html=await result.text();assert.equal(html.includes("PRIVATE_DETAIL"),false);assert.equal(html.includes(String(state)),false);
  assert.equal(result.headers.get("Referrer-Policy"),"no-referrer");
});

test("desconectar revoca en Garmin y limpia tokens solo tras confirmación",async()=>{
  const fx=fixture();await connect(fx.f);
  const result=await handleGarminConnection(request("disconnect",{generation:1}),c,fx.f);
  assert.equal((await result.json()).status,"disconnected");assert.equal(fx.row.tokens_cipher,null);
  assert.ok(fx.commands.indexOf("identify_revoke")<fx.commands.indexOf("finish_revoke"));
  assert.equal(fx.calls.filter(url=>url.endsWith("/registration")).length,1);
});

test("fallo de Garmin conserva desconexión pendiente sin fingir éxito ni perder credenciales",async()=>{
  const fx=fixture({revokeFailure:true});await connect(fx.f);
  const result=await handleGarminConnection(request("disconnect",{generation:1}),c,fx.f);
  assert.equal((await result.json()).status,"revocation_pending");assert.ok(fx.row.tokens_cipher);
  assert.equal(fx.commands.includes("finish_revoke"),false);
});

test("access token caducado rota el refresh en servidor antes de revocar",async()=>{
  const fx=fixture({expired:true});await connect(fx.f);
  const result=await handleGarminConnection(request("disconnect",{generation:1}),c,fx.f);
  assert.equal((await result.json()).status,"disconnected");
  assert.ok(fx.commands.indexOf("rotate_revoke")<fx.commands.indexOf("identify_revoke"));
  assert.equal(fx.calls.filter(x=>x.includes("/oauth/token")).length,2);
});

test("identidad no comprobable impide revocar por error otra cuenta Garmin",async()=>{
  const fx=fixture();await connect(fx.f);
  const original=fx.f;
  const f:typeof fetch=(url,init)=>String(url).endsWith("/user/id")?Promise.resolve(new Response(null,{status:503})):original(url,init);
  await handleGarminConnection(request("disconnect",{generation:1}),c,f);
  assert.equal(fx.row.status,"revocation_pending");assert.equal(fx.calls.some(url=>url.endsWith("/registration")),false);
});
