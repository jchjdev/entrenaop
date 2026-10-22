import {garminServerConfig} from "../_shared/garmin/config.ts";
import {handleGarminCallback} from "../_shared/garmin/http.ts";
Deno.serve(request=>handleGarminCallback(request,garminServerConfig()));
