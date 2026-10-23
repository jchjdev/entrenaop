import {ActivityReturnError, validateRunningObservation, proposeLapMapping} from './running_result.ts';
import type {ObservedRunningActivity} from './running_result.ts';
import {runningPrescription} from '../device_training/prescription.ts';
import type {AccessGrant, AccountGateway, GrantCipher} from '../device_training/delivery.ts';
type Json = Record<string, unknown>;
export interface ActivityReturnStore {command(action: string, owner: string | null, session: string | null, input: Json): Promise<Json>}
export interface ActivityFileGateway {read(callback: string, accessToken: string, metadata: Json): Promise<ObservedRunningActivity>}
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
      validateRunningObservation(activity);
      await command('save', {activity});
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
}

export function activityReview(source: Json): Json {
  const prescription = runningPrescription(source.snapshot);
  const activity = source.activity as ObservedRunningActivity;
  validateRunningObservation(activity);
  const suggested = proposeLapMapping(prescription.steps, activity.laps);
  const rows: Json[] = []; let step = 0;
  const snapshot = source.snapshot as {blocks: {order_index: number; items: {order_index: number; sets: Json[]}[]}[]};
  for (const block of snapshot.blocks) for (const item of block.items) for (const set of item.sets) {
    const work = prescription.steps[step], lap = suggested[step++];
    const recovery = set.recovery_type != null ? suggested[step++] : undefined;
    rows.push({block_order: block.order_index, item_order: item.order_index, set_order: set.order_index,
      label: work.description, kind: work.kind, measure: work.measure, value: work.value,
      lap_indices: lap ?? [], requires_recovery: recovery !== undefined, recovery_lap_indices: recovery ?? []});
  }
  return {...source, rows};
}
