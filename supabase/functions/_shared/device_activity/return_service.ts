import {ActivityReturnError, validateRunningObservation, proposeRunningActivityMapping,recordedActivityRpe} from './running_result.ts';
import type {ObservedRunningActivity} from './running_result.ts';
import {isStrengthActivity,validateStrengthObservation} from './strength_result.ts';
import type {ObservedActivity} from './strength_result.ts';
import {strengthPrescription} from '../device_training/strength.ts';
import {runningPrescription} from '../device_training/prescription.ts';
import type {AccessGrant, AccountGateway, GrantCipher} from '../device_training/delivery.ts';
type Json = Record<string, unknown>;
export interface ActivityReturnStore {command(action: string, owner: string | null, session: string | null, input: Json): Promise<Json>}
export interface ActivityFileGateway {read(callback: string, accessToken: string, metadata: Json): Promise<ObservedActivity>;
  reference?(snapshot:unknown):string|null;
  lapStepIndices?(snapshot:unknown):readonly number[]}
export type ActivityJob = {id: string; owner: string; generation: number; lease: string; callback: string; metadata: Json;
  tokens: string; accessExpiresAt: string; refreshExpiresAt: string; providerUserId: string};

export class ActivityReturnService {
  private readonly store: ActivityReturnStore;
  private readonly account: AccountGateway;
  private readonly cipher: GrantCipher;
  private readonly files: ActivityFileGateway;
  private readonly now: () => number;
  constructor(store: ActivityReturnStore, account: AccountGateway, cipher: GrantCipher,
    files: ActivityFileGateway, now: () => number = Date.now) {
    this.store = store; this.account = account; this.cipher = cipher; this.files = files; this.now = now;
  }

  async process(job: ActivityJob): Promise<void> {
    const command = (action: string, extra: Json = {}) => this.store.command(action, job.owner, null,
      {id: job.id, lease_id: job.lease, ...extra});
    let refreshing = false, downloading = false, received = false;
    try {
      const context = `tokens:${job.owner}:${job.generation}`;
      let grant = await this.cipher.open<AccessGrant>(job.tokens, context);
      if (Date.parse(job.accessExpiresAt) <= this.now() + 60000) {
        if (Date.parse(job.refreshExpiresAt) <= this.now()) throw new ActivityReturnError('reauthorization_required');
        await command('refreshing'); refreshing = true;
        grant = await this.account.refresh(grant.refreshToken);
        await command('rotate', {tokens_cipher: await this.cipher.seal(grant, context),
          access_expires_at: new Date(this.now() + grant.expiresInSeconds * 1000).toISOString(),
          refresh_expires_at: new Date(this.now() + grant.refreshExpiresInSeconds * 1000).toISOString()});
        refreshing = false;
      }
      if (await this.account.userId(grant.accessToken) !== job.providerUserId) throw new ActivityReturnError('connection_changed');
      if (!(await this.account.permissions(grant.accessToken)).canReadActivities) throw new ActivityReturnError('permission_denied');
      const callback = await this.cipher.open<string>(job.callback, `activity-callback:${job.id}`);
      await command('downloading'); downloading = true;
      const activity = await this.files.read(callback, grant.accessToken, job.metadata);
      received = true;
      if(isStrengthActivity(activity))validateStrengthObservation(activity);else validateRunningObservation(activity);
      const saved=await command('save', {activity});
      if(this.files.reference){
        // La ingesta ya está guardada. Conciliar nunca vuelve a descargar el
        // callback ni presenta una recepción válida como un fallo de descarga.
        const bound=(action:string,input:Json={})=>command(action,{activity_id:saved.activity_id,activity_revision:saved.activity_revision,...input});
        try {
          if(activity.prescriptionReference)await this.automaticallyComplete(activity,bound);
          else await bound('automatic.review',{code:'prescription_not_identified'});
        }
        catch {
          // Un fallo de conciliación se diagnostica sin identidad, mediciones,
          // callbacks ni mensajes/causas que puedan contener secretos.
          console.warn(JSON.stringify({event:'device_activity_completion_failed',code:'review_required'}));
          try { await bound('automatic.review',{code:'review_required'}); }
          catch { console.warn(JSON.stringify({event:'device_activity_review_checkpoint_failed',code:'review_required'})); }
        }
      }
    } catch (error) {
      const allowed = ['connection_changed', 'permission_denied', 'reauthorization_required', 'activity_file_expired',
        'activity_file_too_large', 'invalid_activity', 'invalid_activity_file', 'unsupported_activity',
        'unsupported_activity_file', 'provider_unavailable', 'rate_limited'];
      const reason = error instanceof Error && allowed.includes(error.message) ? error.message : 'activity_unavailable';
      // Descargar consume el callback. Un efecto incierto exige reenvío oficial,
      // nunca inventar datos ni repetir automáticamente una renovación incierta.
      await command('failed', {code: reason, uncertain: refreshing || downloading || received});
    } finally {
      // Una retirada concurrente puede haber liberado ya este lease.
      try { await command('release'); } catch { /* El checkpoint durable resuelve la caída. */ }
    }
  }
  private async automaticallyComplete(activity:ObservedActivity,command:(action:string,extra?:Json)=>Promise<Json>):Promise<void>{
    const context=await command('automatic.context');
    if(context.completed||context.blocked)return;
    const candidates=context.candidates as Json[];
    if(!Array.isArray(candidates)){
      await command('automatic.review',{code:'review_required'});return;
    }
    const matched=candidates.filter(c=>this.files.reference!(c.snapshot)===activity.prescriptionReference);
    const schedules=new Set(matched.map(c=>c.scheduled_id));
    if(schedules.size!==1){await command('automatic.review',{code:schedules.size?'ambiguous_prescription':'prescription_not_identified'});return;}
    const current=matched.find(c=>c.current===true);
    if(!current){await command('automatic.review',{code:'stale_prescription'});return;}
    const linked={scheduled_id:current.scheduled_id,delivery_revision:current.revision};
    // Conservar una grabación sin desplazamiento, sin completar por sus
    // tiempos una pauta de carrera que el reloj no acredita haber realizado.
    if(!isStrengthActivity(activity)&&activity.distanceMeters===0){
      await command('automatic.review',{code:'intervals_require_review',...linked});return;
    }
    const review=activityReview({snapshot:current.snapshot,activity},
      isStrengthActivity(activity)?undefined:this.files.lapStepIndices?.(current.snapshot),true);
    const rows=review.rows as Json[];
    if(!rows.length||rows.some(r=>!(r.lap_indices as number[])?.length||r.requires_recovery&&!(r.recovery_lap_indices as number[])?.length)){
      await command('automatic.review',{code:'intervals_require_review',...linked});return;
    }
    const covered=new Set(rows.flatMap(r=>[...(r.lap_indices as number[]),...((r.recovery_lap_indices as number[])??[])]));
    const expected=isStrengthActivity(activity)?activity.sets.filter(s=>s.kind==='active').map(s=>s.index):activity.laps.map(l=>l.index);
    if(expected.some(i=>!covered.has(i)&&i!==review.post_workout_lap)){await command('automatic.review',{code:'intervals_require_review',...linked});return;}
    if(isStrengthActivity(activity)){
      const work=strengthPrescription(current.snapshot).steps.filter(s=>s.kind==='strength');
      if(work.some((s,i)=>{
        const actual=activity.sets.find(a=>a.index===(rows[i].lap_indices as number[])[0]);
        return !actual||s.measure==='reps'&&actual.repetitions===null||s.loadKg!==null&&actual.loadKg===null;
      })){
        await command('automatic.review',{code:'intervals_require_review',...linked});return;
      }
    }
    await command('automatic.complete',{activity_id:context.activity_id,activity_revision:context.activity_revision,
      scheduled_id:current.scheduled_id,delivery_revision:current.revision,
      mapping:rows.map(r=>({block_order:r.block_order,item_order:r.item_order,set_order:r.set_order,
        lap_indices:r.lap_indices,recovery_lap_indices:r.recovery_lap_indices??[],skipped:false}))});
  }
}

export function activityReview(source: Json, lapStepIndices?: readonly number[], exactPrescription=false): Json {
  const observed=source.activity as ObservedActivity;
  const effort={recorded_rpe:source.recorded_rpe??recordedActivityRpe(observed)};
  if(isStrengthActivity(observed)){
    validateStrengthObservation(observed);
    const p=strengthPrescription(source.snapshot);
    const work=p.steps.filter(s=>s.kind==='strength'),active=observed.sets.filter(s=>s.kind==='active');
    const indices=observed.prescriptionStepIndices;
    // Cada SET activo es una serie explícita. Los índices del FIT pueden volver
    // al cuerpo del bucle; exigimos todas las series en orden y su ejercicio.
    const nativeAligned=indices?.length===p.steps.length&&active.length===work.length&&work.every((s,index)=>
      s.exerciseCode!==null&&active[index].exerciseCode===s.exerciseCode&&
      active[index].workoutStepIndex===indices[p.steps.indexOf(s)]);
    const rows=work.map((s,index)=>{
      const position=p.steps.indexOf(s);
      // Dos códigos desconocidos no acreditan que sean el mismo ejercicio.
      // Los ejercicios privados necesitan la correspondencia explícita del alumno.
      const matches=observed.sets.filter(a=>s.exerciseCode!==null&&a.kind==='active'&&a.workoutStepIndex===position&&a.exerciseCode===s.exerciseCode);
      return {block_order:s.block,item_order:s.item,set_order:s.set,label:s.description,kind:s.kind,measure:s.measure,value:s.value,
        lap_indices:nativeAligned?[active[index].index]:matches.length===1?[matches[0].index]:[],requires_recovery:false,recovery_lap_indices:[]};
    });
    return {...source,...effort,rows};
  }
  if((source.snapshot as Json).sport==='strength')throw new ActivityReturnError('unsupported_activity');
  const prescription = runningPrescription(source.snapshot);
  const activity = source.activity as ObservedRunningActivity;
  validateRunningObservation(activity);
  // El FIT recibido manda: puede representar la última vuelta sin descanso
  // con un tramo fuera del bucle. La proyección del envío queda para evidencia
  // anterior que no conservaba sus índices nativos expandidos.
  const {mapping:suggested,postWorkoutLap} = proposeRunningActivityMapping(
    prescription.steps, activity, activity.prescriptionStepIndices??lapStepIndices, exactPrescription);
  const rows: Json[] = []; let step = 0;
  const snapshot = source.snapshot as {blocks: {order_index: number; items: {order_index: number; sets: Json[]}[]}[]};
  for (const block of snapshot.blocks) for (const item of block.items) for (const set of item.sets) {
    const work = prescription.steps[step], lap = suggested[step++];
    const recovery = set.recovery_type != null ? suggested[step++] : undefined;
    rows.push({block_order: block.order_index, item_order: item.order_index, set_order: set.order_index,
      label: work.description, kind: work.kind, measure: work.measure, value: work.value,
      lap_indices: lap ?? [], requires_recovery: recovery !== undefined, recovery_lap_indices: recovery ?? []});
  }
  return {...source,...effort, rows,...(postWorkoutLap===undefined?{}:{post_workout_lap:postWorkoutLap})};
}
