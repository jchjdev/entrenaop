import {garminServerConfig} from '../_shared/garmin/config.ts';
import {handleActivityIngest} from '../_shared/garmin/activity_http.ts';
Deno.serve(request=>handleActivityIngest(request,
  {...garminServerConfig(),webhookSecret:Deno.env.get('GARMIN_ACTIVITY_WEBHOOK_SECRET')??''},fetch,
  work=>EdgeRuntime.waitUntil(work)));
