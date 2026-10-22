import {garminServerConfig} from "../_shared/garmin/config.ts";
import {handleGarminTraining} from "../_shared/garmin/training_http.ts";
Deno.serve(request=>handleGarminTraining(request,garminServerConfig()));
