import {garminServerConfig} from '../_shared/garmin/config.ts';
import {handleGarminSync} from '../_shared/garmin/sync_http.ts';
Deno.serve(request=>handleGarminSync(request,garminServerConfig()));
