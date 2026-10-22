import {garminServerConfig} from "../_shared/garmin/config.ts";
import {handleGarminConnection} from "../_shared/garmin/http.ts";
Deno.serve(request=>handleGarminConnection(request,garminServerConfig()));
