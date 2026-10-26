import {garminServerConfig} from '../_shared/garmin/config.ts';
import {handleGarminCiq} from '../_shared/garmin/ciq_http.ts';
Deno.serve(request=>handleGarminCiq(request,garminServerConfig()));
