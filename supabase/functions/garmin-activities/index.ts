import {garminServerConfig} from '../_shared/garmin/config.ts';
import {handleActivityUser} from '../_shared/garmin/activity_http.ts';
Deno.serve(request=>handleActivityUser(request,garminServerConfig()));
