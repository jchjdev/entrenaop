-- Cuatro esfuerzos comparables, con los dos centrales realizados el mismo día.
begin;
do $$
declare
 wk date:='2026-10-19'; v jsonb:=public.running_session_v2('V',0,595,35);
 e jsonb:=public.running_session_v2('E',0,595,30);
 h jsonb; shuffled jsonb; swapped jsonb; historical jsonb; baseline jsonb; input jsonb;
begin
 select jsonb_agg(jsonb_build_object('date',wk+z.day,'scheduled_date',wk+z.day,
    'session',v,'execution',jsonb_build_object('status','completed','rpe',7,
    'id',z.i,'completed_at',z.i,'performed_at_epoch',z.instant,'sets',sets)) order by z.i)
 into h
 from (values (1,-21,100,300.5),(2,-14,200,292),(3,-14,300,309),(4,-7,400,300.5))
   z(i,day,instant,pace)
 cross join lateral (
   select jsonb_agg(jsonb_build_object('status','completed',
     'seconds',coalesce((s->>'seconds')::numeric,(s->>'meters')::numeric*z.pace/1000),
     'meters',coalesce((s->>'meters')::numeric,(s->>'seconds')::numeric*1000/z.pace),
     'recovery_seconds',s->'recovery_seconds') order by ord) sets
   from jsonb_array_elements(v->'segments') with ordinality a(s,ord)
 ) results;
 input:=jsonb_build_object('week_start',wk,'target_date',wk+70,'anchor_seconds',595,
   'anchor_age_days',2,'goal_seconds',500,'recent_days',array[3,3,3,3],
   'recent_minutes',array[95,95,95,95],'capacity_minutes',45,
   'availability','{"1":60,"3":60,"6":60}'::jsonb,'previous',
   jsonb_build_object('week_start',wk-7,'normal_budget',95,'anchor_seconds',595,
     'load_weeks',0,'rotation',1,'mode','normal','sessions',jsonb_build_array(v,e,e)));
 select jsonb_agg(jsonb_set(jsonb_set(o,'{execution,id}',to_jsonb(5-ord)),
   '{execution,completed_at}',to_jsonb(5-ord)) order by ord desc) into shuffled
 from jsonb_array_elements(h) with ordinality a(o,ord);
 baseline:=public.running_evidence_v6(h,wk);
 if baseline#>>'{families,V,trend}' is distinct from 'worsening'
    or baseline#>>'{families,V,samples}' is distinct from '4'
    or public.running_evidence_v6(shuffled,wk) is distinct from baseline
    or public.running_plan_v6(input||jsonb_build_object('history',shuffled))
       is distinct from public.running_plan_v6(input||jsonb_build_object('history',h)) then
   raise exception 'La tendencia o el plan dependen del orden de envío y no del observado';
 end if;
 swapped:=jsonb_set(jsonb_set(h,'{1,execution,performed_at_epoch}','300'),
   '{2,execution,performed_at_epoch}','200');
 if public.running_evidence_v6(swapped,wk)#>>'{families,V,trend}' is distinct from 'improving' then
   raise exception 'La tendencia ignora el orden observado';
 end if;
 select jsonb_agg(o#-'{execution,performed_at_epoch}' order by ord) into historical
 from jsonb_array_elements(h) with ordinality a(o,ord);
 select jsonb_agg(o#-'{execution,performed_at_epoch}' order by ord) into shuffled
 from jsonb_array_elements(shuffled) with ordinality a(o,ord);
 if public.running_evidence_v6(shuffled,wk) is distinct from public.running_evidence_v6(historical,wk)
    or public.running_plan_v6(input||jsonb_build_object('history',shuffled))
       is distinct from public.running_plan_v6(input||jsonb_build_object('history',historical)) then
   raise exception 'El histórico sin hora cambia al permutar el orden de envío';
 end if;
 if has_function_privilege('authenticated','public.running_history_sequence_v1(jsonb)','execute')
    or has_function_privilege('anon','public.running_evidence_v6(jsonb,date)','execute') then
   raise exception 'Lector de evidencia accesible desde el cliente';
 end if;
end $$;
rollback;
