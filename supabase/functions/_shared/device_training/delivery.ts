import {runningTrainingCompatibility} from "./capabilities.ts";
import type {RunningTrainingCapabilities} from "./capabilities.ts";
import {TrainingError} from "./prescription.ts";
import {trainingPrescription,isStrength} from './strength.ts';
import type {TrainingPrescription} from './strength.ts';
type Json=Record<string,unknown>;
export type DeliveryActor={actor:string;owner:string;session:string|null};
export type AccessGrant={accessToken:string;refreshToken:string;expiresInSeconds:number;refreshExpiresInSeconds:number;scope:string};
export interface TrainingDeliveryStore {command(action:string,who:DeliveryActor,input:Json):Promise<Json>}
export interface TrainingGateway {
  readonly capabilities:RunningTrainingCapabilities;
  supportsStrength?(prescription:TrainingPrescription):boolean;
  create(token:string,prescription:TrainingPrescription):Promise<number>;
  schedule(token:string,workout:number,date:string):Promise<void>;
  confirmSchedule(token:string,workout:number,date:string):Promise<number>;
}
export interface AccountGateway {
  refresh(token:string):Promise<AccessGrant>;userId(token:string):Promise<string>;
  permissions(token:string):Promise<{canReadActivities:boolean;canSendWorkouts:boolean}>;
}
export interface GrantCipher {seal(value:unknown,context:string):Promise<string>;open<T>(value:string,context:string):Promise<T>}
export class DeliveryFailure extends Error {
  readonly uncertain:boolean;
  constructor(code:string,uncertain=false){super(code);this.name="DeliveryFailure";this.uncertain=uncertain;}
}
const codes=new Set(["provider_rejected","provider_unavailable","rate_limited","permission_denied","reauthorization_required",
  "invalid_provider_response","schedule_not_confirmed","delivery_uncertain","connection_changed","stale_prescription","garmin_unavailable"]);
export class TrainingDeliveryService {
  private readonly store:TrainingDeliveryStore;private readonly gateway:TrainingGateway;
  private readonly account:AccountGateway;private readonly cipher:GrantCipher;
  private readonly now:()=>number;private readonly afterRelease:(owner:string)=>Promise<void>;
  constructor(store:TrainingDeliveryStore,gateway:TrainingGateway,account:AccountGateway,cipher:GrantCipher,
    now:()=>number=Date.now,afterRelease:(owner:string)=>Promise<void>=async()=>{}){
    this.store=store;this.gateway=gateway;this.account=account;this.cipher=cipher;this.now=now;this.afterRelease=afterRelease;
  }
  list(who:DeliveryActor){return this.store.command("list",who,{});}
  async preview(who:DeliveryActor,scheduled:string) {
    const source=await this.store.command("preview",who,{scheduled_id:scheduled});
    const prescription=trainingPrescription(source.snapshot);
    if(isStrength(prescription)?!this.gateway.supportsStrength?.(prescription):runningTrainingCompatibility(prescription,this.gateway.capabilities).length) throw new TrainingError('unsupported_prescription');
    return {revision:source.revision,prescription};
  }
  async send(who:DeliveryActor,scheduled:string,revision:string):Promise<Json> {
    // Validar antes de reservar trabajo; claim vuelve a fijar la misma revisión.
    const preview=await this.preview(who,scheduled);
    if(preview.revision!==revision)throw new TrainingError("stale_prescription");
    const lease=crypto.randomUUID();
    const claim=await this.store.command("claim",who,{scheduled_id:scheduled,revision,lease_id:lease});
    if(claim.done)return claim.receipt as Json;
    const input={id:claim.id,lease_id:lease};
    const command=(action:string,fields:Json={})=>this.store.command(action,who,{...input,...fields});
    let inFlight=false,awaitingReceipt=false;
    try {
      const prescription=trainingPrescription(claim.snapshot);
      const context=`tokens:${who.owner}:${claim.generation}`;
      let grant=await this.cipher.open<AccessGrant>(String(claim.tokens_cipher),context);
      if(Date.parse(String(claim.access_expires_at))<=this.now()+60000){
        if(Date.parse(String(claim.refresh_expires_at))<=this.now())throw new DeliveryFailure("reauthorization_required");
        await command("mark_refreshing");inFlight=true;
        grant=await this.account.refresh(grant.refreshToken);
        awaitingReceipt=true;
        const now=this.now();
        await command("rotate",{tokens_cipher:await this.cipher.seal(grant,context),
          access_expires_at:new Date(now+grant.expiresInSeconds*1000).toISOString(),
          refresh_expires_at:new Date(now+grant.refreshExpiresInSeconds*1000).toISOString()});
        inFlight=false;awaitingReceipt=false;
      }
      if(await this.account.userId(grant.accessToken)!==claim.garmin_user_id)throw new DeliveryFailure("connection_changed");
      const permissions=await this.account.permissions(grant.accessToken);
      await command("permissions",{can_read:permissions.canReadActivities,can_send:permissions.canSendWorkouts});
      if(!permissions.canSendWorkouts)throw new DeliveryFailure("permission_denied");
      let workout=claim.workout_id as number|null;
      if(workout==null){
        await command("mark_creating");inFlight=true;
        workout=await this.gateway.create(grant.accessToken,prescription);
        awaitingReceipt=true;
        await command("save_workout",{workout_id:workout});inFlight=false;awaitingReceipt=false;
      }
      await command("mark_scheduling");inFlight=true;
      await this.gateway.schedule(grant.accessToken,workout,prescription.date);
      awaitingReceipt=true;
      const schedule=await this.gateway.confirmSchedule(grant.accessToken,workout,prescription.date);
      const receipt=await command("save_schedule",{schedule_id:schedule});inFlight=false;awaitingReceipt=false;
      return receipt;
    }catch(error){
      const raw=error instanceof Error?error.message:"garmin_unavailable";
      const code=codes.has(raw)?raw:"garmin_unavailable";
      const knownRejection=["reauthorization_required","provider_rejected","permission_denied","rate_limited"].includes(raw);
      const uncertain=awaitingReceipt||(error instanceof DeliveryFailure?error.uncertain:inFlight&&!knownRejection);
      // Un timeout o un guardado perdido después de POST nunca vuelve a crear.
      const receipt=await command("fail",{code,uncertain}).catch(()=>null);
      if(receipt)return receipt;
      throw new DeliveryFailure(uncertain?"delivery_uncertain":code,uncertain);
    }finally{
      // El lease permite guardar hechos/limpiar aunque la sesión o vínculo
      // desaparezcan durante HTTP; nunca autoriza nuevas escrituras al proveedor.
      await command("release").catch(()=>{});
      await this.afterRelease(who.owner).catch(()=>{});
    }
  }
}
