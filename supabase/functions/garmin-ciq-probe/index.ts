import {ciqProbeHandler} from '../_shared/garmin/ciq_probe.ts';

Deno.serve(ciqProbeHandler({
  environment: Deno.env.get('GARMIN_ENVIRONMENT') ?? 'DISABLED',
  supabaseUrl: Deno.env.get('SUPABASE_URL') ?? '',
}));
