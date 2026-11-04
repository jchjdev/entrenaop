begin;

do $migration$
declare
 definition text:=pg_get_functiondef('public.resolve_program_running_reference(uuid)'::regprocedure);
 change record;
begin
 for change in select * from (values
  (2,$old$jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,$old$,
     $new$jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'performed_at_epoch',extract(epoch from a.completed_at),'reference_selected',a.id::text=sel.reference_record_id,$new$),
  (1,$old$jsonb_build_object('date',t.completed_at::date,'seconds',t.duration_seconds,$old$,
     $new$jsonb_build_object('date',t.completed_at::date,'seconds',t.duration_seconds,
     'performed_at_epoch',extract(epoch from t.completed_at),'reference_selected',t.id::text=sel.reference_record_id,$new$),
  (1,$old$jsonb_build_object('date',a.assessed_on,'seconds',(d->>'mark')::numeric,$old$,
     $new$jsonb_build_object('date',a.assessed_on,'seconds',(d->>'mark')::numeric,
     'reference_selected',a.id::text=sel.reference_record_id,$new$)
 ) changes(expected_matches,old_sql,new_sql) loop
  if length(definition)-length(replace(definition,change.old_sql,''))<>length(change.old_sql)*change.expected_matches then
   raise exception 'Revisar el origen de las marcas comparables de 2 km.';
  end if;
  definition:=replace(definition,change.old_sql,change.new_sql);
 end loop;
 execute definition;
end;
$migration$;

create or replace function public.running_test_trend_v2(p jsonb,wk date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare x jsonb; a jsonb:='[]'; protocol text; last_day date; first_seconds numeric; last_seconds numeric;
begin
 -- La marca elegida representa su día. En otros días se usa el instante más
 -- reciente. Un empate sin orden y con marcas distintas no aporta una medida.
 for x in
  with marks as (
   select value control,(value->>'date')::date observed_on,value->>'protocol' method,
    (value->>'seconds')::numeric seconds,
    coalesce((value->>'reference_selected')::boolean,false) selected,
    (value->>'performed_at_epoch')::numeric performed_at
   from jsonb_array_elements(p)
   where (value->>'date')::date between wk-120 and wk
    and (value->>'seconds')::numeric between 240 and 1800 and value->>'protocol' is not null
  ), ranked as (
   select *,dense_rank() over(partition by observed_on,method
    order by selected desc,performed_at desc nulls last) as precedence from marks
  ), resolved as (
   select observed_on,method from ranked where precedence=1
   group by observed_on,method having count(distinct seconds)=1
  ), daily as (
   select distinct on (r.observed_on,r.method) r.*
   from ranked r join resolved d using(observed_on,method) where r.precedence=1
   order by r.observed_on,r.method,r.control
  )
  select control from daily order by observed_on desc,selected desc,performed_at desc nulls last,method
 loop
  protocol:=coalesce(protocol,x->>'protocol');
  if x->>'protocol' is distinct from protocol then continue; end if;
  if last_day is not null and last_day-(x->>'date')::date<14 then continue; end if;
  a:=a||jsonb_build_array(x); last_day:=(x->>'date')::date;
  exit when jsonb_array_length(a)=3;
 end loop;
 if jsonb_array_length(a)<3 then return jsonb_build_object('trend','unknown','samples',jsonb_array_length(a)); end if;
 first_seconds:=(a->2->>'seconds')::numeric; last_seconds:=(a->0->>'seconds')::numeric;
 return jsonb_build_object('trend',case when last_seconds<first_seconds*0.99 then 'improving'
  when last_seconds>first_seconds*1.01 then 'worsening' else 'stable' end,
  'samples',3,'controls',a,'confidence','declared_same_protocol','relative_change',last_seconds/first_seconds-1);
end $$;

commit;
