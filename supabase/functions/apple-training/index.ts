import {handleAppleTraining} from '../_shared/apple_training/http.ts';
Deno.serve(request=>handleAppleTraining(request,{
 url:Deno.env.get('SUPABASE_URL')??'',key:Deno.env.get('SUPABASE_ANON_KEY')??'',
 enabled:Deno.env.get('APPLE_WORKOUTS_ENVIRONMENT')==='DEVELOPMENT',
}));
