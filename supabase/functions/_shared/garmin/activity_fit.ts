import {Decoder, Stream} from '@garmin/fitsdk';
import {ActivityReturnError, validateRunningObservation} from '../device_activity/running_result.ts';
import type {ObservedRunningActivity} from '../device_activity/running_result.ts';
import {validateStrengthObservation} from '../device_activity/strength_result.ts';
import type {ObservedActivity, ObservedStrengthActivity} from '../device_activity/strength_result.ts';

export const maxActivityFileBytes = 4 * 1024 * 1024;
type Message = Record<string, unknown>;
const epoch = 631065600000;
function date(value: unknown): string {
  const v = value instanceof Date ? value : typeof value === 'number' ? new Date(epoch + value * 1000) : null;
  if (!v || !Number.isFinite(v.getTime())) throw new ActivityReturnError('invalid_activity_file');
  return v.toISOString();
}
function number(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new ActivityReturnError('invalid_activity_file');
  return value;
}
function optional(value: unknown): number | null { return value == null ? null : number(value); }

/** El SDK solo pertenece al adaptador. No se conservan posiciones GPS ni muestras crudas. */
export function garminFitActivity(bytes: Uint8Array, metadata: {activityId: string; activityName: string}): ObservedRunningActivity {
  const result=garminFitObservation(bytes,metadata);
  if(result.schemaVersion!==1)throw new ActivityReturnError('unsupported_activity');
  return result;
}
export function garminFitObservation(bytes: Uint8Array, metadata: {activityId: string; activityName: string}): ObservedActivity {
  if (bytes.length < 16 || bytes.length > maxActivityFileBytes) throw new ActivityReturnError('activity_file_too_large');
  const stream = Stream.fromArrayBuffer(bytes.slice().buffer);
  const decoder = new Decoder(stream);
  if (!decoder.isFIT() || !decoder.checkIntegrity()) throw new ActivityReturnError('invalid_activity_file');
  const {messages, errors} = decoder.read({expandComponents: false, mergeHeartRates: false, includeUnknownData: false});
  if (errors.length || messages.sessionMesgs?.length !== 1 || messages.fileIdMesgs?.[0]?.type !== 'activity') {
    throw new ActivityReturnError('unsupported_activity_file');
  }
  const session = messages.sessionMesgs[0] as Message;
  const activity = messages.activityMesgs?.[0] as Message | undefined;
  let offset: number | null = null;
  if (activity?.localTimestamp != null && activity.timestamp != null) {
    offset = (Date.parse(date(activity.localTimestamp)) - Date.parse(date(activity.timestamp))) / 1000;
  }
  if(session.sport==='training'&&session.subSport==='strengthTraining'){
    const result:ObservedStrengthActivity={schemaVersion:2,sport:'strength',externalId:metadata.activityId,name:metadata.activityName,
      startedAt:date(session.startTime),offsetSeconds:offset,elapsedSeconds:number(session.totalElapsedTime),timerSeconds:number(session.totalTimerTime),
      distanceMeters:null,averageHeartRate:optional(session.avgHeartRate),maxHeartRate:optional(session.maxHeartRate),
      sets:(messages.setMesgs??[]).map((raw,index)=>{
        const s=raw as Message;
        const categories=Array.isArray(s.category)?s.category:[],subtypes=Array.isArray(s.categorySubtype)?s.categorySubtype:[];
        // El SDK decodifica categorías; el subtipo conserva el índice del perfil FIT.
        const key=categories.length===1&&subtypes.length===1?`${categories[0]}:${subtypes[0]}`:'';
        const exerciseCode:Record<string,string>={'benchPress:1':'bench_press_barbell','pushUp:77':'push_up_standard','pullUp:38':'pull_up_pronated'};
        if(s.setType!=='active'&&s.setType!=='rest')throw new ActivityReturnError('unsupported_activity_file');
        return {index,startedAt:date(s.startTime),seconds:number(s.duration),kind:s.setType,
          repetitions:optional(s.repetitions),loadKg:optional(s.weight),exerciseCode:exerciseCode[key]??null,workoutStepIndex:optional(s.wktStepIndex)};
      }),
    };
    validateStrengthObservation(result);return result;
  }
  if (session.sport !== 'running') throw new ActivityReturnError('unsupported_activity');
  const result: ObservedRunningActivity = {
    schemaVersion: 1, externalId: metadata.activityId, name: metadata.activityName,
    startedAt: date(session.startTime), offsetSeconds: offset,
    elapsedSeconds: number(session.totalElapsedTime), timerSeconds: number(session.totalTimerTime),
    distanceMeters: number(session.totalDistance), averageHeartRate: optional(session.avgHeartRate),
    maxHeartRate: optional(session.maxHeartRate),
    laps: (messages.lapMesgs ?? []).map((lap, index) => ({
      index, startedAt: date(lap.startTime), elapsedSeconds: number(lap.totalElapsedTime),
      timerSeconds: number(lap.totalTimerTime), distanceMeters: number(lap.totalDistance),
      intensity: typeof lap.intensity === 'string' ? lap.intensity : null,
      workoutStepIndex: optional(lap.wktStepIndex),
    })),
  };
  validateRunningObservation(result);
  return result;
}

/** La URL de descarga es una capacidad de un solo uso: nunca redirigir ni registrarla. */
export function garminActivityCallback(value: unknown): URL {
  if (typeof value !== 'string' || value.length > 2048) throw new ActivityReturnError('invalid_callback_url');
  let uri: URL;
  try { uri = new URL(value); } catch { throw new ActivityReturnError('invalid_callback_url'); }
  if (uri.origin !== 'https://apis.garmin.com' || uri.pathname !== '/wellness-api/rest/activityFile' ||
      uri.username || uri.password || uri.hash || uri.searchParams.getAll('id').length !== 1 ||
      uri.searchParams.getAll('token').length !== 1 || !uri.searchParams.get('id') || !uri.searchParams.get('token') ||
      [...uri.searchParams.keys()].some(key => key !== 'id' && key !== 'token')) throw new ActivityReturnError('invalid_callback_url');
  return uri;
}

export async function downloadGarminFit(uri: string, token: string, f: typeof fetch = fetch): Promise<Uint8Array> {
  const url = garminActivityCallback(uri);
  const response = await f(url, {headers: {Authorization: `Bearer ${token}`}, redirect: 'error', signal: AbortSignal.timeout(15000)});
  if (!response.ok || !response.body) throw new ActivityReturnError(response.status === 410 ? 'activity_file_expired' : 'provider_unavailable');
  const length = Number(response.headers.get('content-length'));
  if (length > maxActivityFileBytes) throw new ActivityReturnError('activity_file_too_large');
  const reader = response.body.getReader(), chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const {done, value} = await reader.read(); if (done) break;
      size += value.length;
      if (size > maxActivityFileBytes) throw new ActivityReturnError('activity_file_too_large');
      chunks.push(value);
    }
  } finally { await reader.cancel(); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}
