import {DeliveryFailure} from './delivery.ts';
import type {TrainingDeliveryService} from './delivery.ts';
import type {AccessGrant,AccountGateway,GrantCipher,DeliveryActor} from './delivery.ts';
import {trainingPrescription} from './strength.ts';
import type {TrainingPrescription} from './strength.ts';

type Json=Record<string,unknown>;
// La entrega manual puede devolver un recibo fallido en lugar de lanzar.
// Ambos recorridos deben conservar la causa y aplicar la misma recuperación.
const needsReview = new Set(['delivery_needs_review','delivery_uncertain','unsupported_prescription',
  'invalid_prescription','provider_rejected','provider_missing','invalid_provider_response',
  'connection_changed','reauthorization_required','permission_denied']);
export interface TrainingSyncStore {
  command(action:string,input:Json):Promise<Json>;
}
export interface TrainingLifecycleGateway {
  update(token:string,id:number,p:TrainingPrescription):Promise<void>;
  updateSchedule(token:string,id:number,workout:number,date:string):Promise<void>;
  removeSchedule(token:string,id:number):Promise<void>;
  remove(token:string,id:number):Promise<void>;
}
// La cola proporciona autoridad persistente y referencias propias. El dominio no
// conoce Supabase, cron, pantallas ni detalles del JSON del fabricante.
export class TrainingSyncService {
  private readonly store:TrainingSyncStore;private readonly delivery:Pick<TrainingDeliveryService,'send'>;
  private readonly gateway:TrainingLifecycleGateway;private readonly account:AccountGateway;private readonly cipher:GrantCipher;
  private readonly now:()=>number;private readonly afterRelease:(owner:string)=>Promise<void>;
  constructor(store:TrainingSyncStore,delivery:Pick<TrainingDeliveryService,'send'>,
    gateway:TrainingLifecycleGateway,account:AccountGateway,cipher:GrantCipher,
    now:()=>number=Date.now,afterRelease:(owner:string)=>Promise<void>=async()=>{}){
    this.store=store;this.delivery=delivery;this.gateway=gateway;this.account=account;this.cipher=cipher;
    this.now=now;this.afterRelease=afterRelease;
  }
  async run(job:Json):Promise<void>{
    const proof={job_id:job.id,job_lease:job.lease};
    const command=(action:string,input:Json={})=>this.store.command(action,{...proof,...input});
    const who:DeliveryActor={actor:String(job.owner),owner:String(job.owner),session:null};
    let claim:Json|undefined,inFlight=false,refreshing=false;
    try{
      const target=job.target as Json;
      if(target.mode==='review'){await command('finish',{outcome:'review'});return;}
      if(target.mode==='hold'){await command('finish',{outcome:'done'});return;}
      if(job.operation==='create'){
        // Se reutiliza íntegra la entrega manual, incluidos sus guardados antes
        // de agendar y su prohibición de repetir una creación incierta.
        const receipt=await this.delivery.send(who,String(job.scheduled),String(target.revision));
        const code=typeof receipt.error_code==='string'?receipt.error_code:undefined;
        const outcome=receipt.status==='sent'?'done':receipt.status==='uncertain'||code!=null&&needsReview.has(code)?'review':'retry';
        await command('finish',{outcome,...(code?{code}:{})});return;
      }
      claim=await command('claim_change');
      const context=`tokens:${who.owner}:${claim.generation}`;
      let grant=await this.cipher.open<AccessGrant>(String(claim.tokens_cipher),context);
      if(Date.parse(String(claim.access_expires_at))<=this.now()+60000){
        if(Date.parse(String(claim.refresh_expires_at))<=this.now())throw new DeliveryFailure('reauthorization_required');
        await command('mark_refreshing');refreshing=true;
        grant=await this.account.refresh(grant.refreshToken);
        await command('rotate',{tokens_cipher:await this.cipher.seal(grant,context),
          access_expires_at:new Date(this.now()+grant.expiresInSeconds*1000).toISOString(),
          refresh_expires_at:new Date(this.now()+grant.refreshExpiresInSeconds*1000).toISOString()});
        refreshing=false;
      }
      if(await this.account.userId(grant.accessToken)!==claim.garmin_user_id)throw new DeliveryFailure('connection_changed');
      const permissions=await this.account.permissions(grant.accessToken);
      await command('permissions',{can_read:permissions.canReadActivities,can_send:permissions.canSendWorkouts});
      if(!permissions.canSendWorkouts)throw new DeliveryFailure('permission_denied');
      const workout=Number(claim.workout_id),schedule=claim.schedule_id as number|null;
      if(target.mode==='cancel'){
        if(schedule!==null){await command('before_write');inFlight=true;
          await this.gateway.removeSchedule(grant.accessToken,schedule);inFlight=false;}
        await command('before_write');inFlight=true;
        await this.gateway.remove(grant.accessToken,workout);inFlight=false;
      }else{
        const prescription=trainingPrescription(target.snapshot);
        await command('before_write');inFlight=true;
        await this.gateway.update(grant.accessToken,workout,prescription);inFlight=false;
        if(schedule===null)throw new DeliveryFailure('delivery_uncertain',true);
        await command('before_write');inFlight=true;
        await this.gateway.updateSchedule(grant.accessToken,schedule,workout,prescription.date);inFlight=false;
      }
      await command('save_change');
      await command('finish',{outcome:'done'});
    }catch(error){
      // PUT/DELETE con ID conocido se pueden repetir. Un refresh ambiguo puede
      // haber consumido el token: requiere revisión y frena la concesión.
      const code=error instanceof Error?error.message:'garmin_unavailable';
      const review=refreshing||needsReview.has(code);
      await command('finish',{outcome:review?'review':'retry',code,refresh_uncertain:refreshing,
        write_pending:inFlight||error instanceof DeliveryFailure&&error.uncertain}).catch(()=>{});
    }finally{
      if(claim)await command('release_change').catch(()=>{});
      await this.afterRelease(who.owner).catch(()=>{});
    }
  }
}
