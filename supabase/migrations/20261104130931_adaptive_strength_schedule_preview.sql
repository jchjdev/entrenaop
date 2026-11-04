begin;

-- La alternativa usa las mismas reglas con una fecha hipotética para una sola
-- cita. No escribe en la agenda ni cambia las fechas del historial realizado.
create function public.preparation_preview_load_on_v1(sw public.scheduled_workouts,moved uuid,new_date date)
returns date language sql stable set search_path='' as $$
 select case when sw.id=moved then new_date else public.workout_load_on_v1(sw) end
$$;

do $migration$
declare
 change record;
 original text;
 definition text;
 replacement text;
begin
 for change in select * from (values
   ('public.calculate_running_week_constrained(uuid,date,boolean,boolean,jsonb)'::regprocedure,
    'p_constraints jsonb','p_goal_id,p_week_start,p_replay_initial,p_preview_future,p_constraints',
    'public.workout_load_on_v1(scheduled_workouts)','public.preparation_preview_load_on_v1(scheduled_workouts,p_moved,p_new_date)',2,
    'public.workout_load_on_v1(sw)','public.preparation_preview_load_on_v1(sw,p_moved,p_new_date)',2,false),
   ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[])'::regprocedure,
    'p_excluded uuid[]','p_goal_id,p_week_start,p_revision,p_scope,p_excluded',
    'public.workout_load_on_v1(scheduled_workouts)','public.preparation_preview_load_on_v1(scheduled_workouts,p_moved,p_new_date)',2,
    'public.workout_load_on_v1(sw)','public.preparation_preview_load_on_v1(sw,p_moved,p_new_date)',4,false),
   ('public.adaptive_control_prior_load_conflict_v1(date,date)'::regprocedure,
    'wk date','test_day,wk',
    'public.workout_load_on_v1(sw)','public.preparation_preview_load_on_v1(sw,p_moved,p_new_date)',2,
    '','',0,true),
   ('public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb)'::regprocedure,
    'plan jsonb','goal,wk,plan',
    'public.adaptive_control_prior_load_conflict_v1(day,wk)','public.adaptive_control_prior_load_conflict_v1(day,wk,p_moved,p_new_date)',2,
    '','',0,true)
 ) as changes(signature,last_arg,call_args,old1,new1,n1,old2,new2,n2,is_stable) loop
  original:=pg_get_functiondef(change.signature);
  if length(original)-length(replace(original,change.old1,''))<>length(change.old1)*change.n1
   or (change.n2>0 and length(original)-length(replace(original,change.old2,''))<>length(change.old2)*change.n2) then
   raise exception 'Revisar la lectura de agenda de %',change.signature;
  end if;
  definition:=replace(original,change.last_arg||')',change.last_arg||', p_moved uuid, p_new_date date)');
  if definition=original then raise exception 'Revisar argumentos de %',change.signature; end if;
  definition:=replace(definition,change.old1,change.new1);
  if change.n2>0 then definition:=replace(definition,change.old2,change.new2); end if;
  if change.call_args='p_goal_id,p_week_start,p_revision,p_scope,p_excluded' then
   definition:=replace(definition,$old$'leg_load_days','[]'::jsonb));$old$,$new$'leg_load_days','[]'::jsonb),p_moved,p_new_date);$new$);
   definition:=replace(definition,'false,true,running_constraints);','false,true,running_constraints,p_moved,p_new_date);');
   if position('running_constraints,p_moved,p_new_date)' in definition)=0
    or position($expected$'leg_load_days','[]'::jsonb),p_moved,p_new_date)$expected$ in definition)=0 then
    raise exception 'Revisar las dos llamadas al motor de carrera.';
   end if;
  end if;
  execute definition;
  select format('create or replace function public.%I(%s) returns %s language sql %s security definer set search_path='''' as %L',
    proname,pg_get_function_arguments(oid),pg_get_function_result(oid),
    case when change.is_stable then 'stable' else 'volatile' end,
    format('select public.%I(%s,null::uuid,null::date)',proname,change.call_args))
   into replacement from pg_proc where oid=change.signature;
  execute replacement;
 end loop;
end;
$migration$;

revoke all on function public.preparation_preview_load_on_v1(public.scheduled_workouts,uuid,date),
 public.calculate_running_week_constrained(uuid,date,boolean,boolean,jsonb,uuid,date),
 public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date),
 public.adaptive_control_prior_load_conflict_v1(date,date,uuid,date),
 public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb,uuid,date) from public,anon,authenticated;

create function public.preview_preparation_strength_move(p_goal_id uuid,p_week_start date,p_mode text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); original jsonb; alternative jsonb; moved record; agenda jsonb;
 scope text; revision boolean; excluded uuid[]:='{}'; replaced uuid[]:='{}'; editable uuid[];
begin
 perform public.require_preparation_pro_access(p_goal_id);
 editable:=array(
  select sw.id from public.scheduled_workouts sw
  where sw.user_id=u and sw.source in ('user','library') and sw.preparation_goal_id is null
   and sw.status='planned' and sw.execution_id is null and sw.estimated_duration_minutes is not null
   and sw.scheduled_date between greatest(p_week_start,current_date) and p_week_start+6
   and exists(select 1 from public.workout_blocks b join public.workout_items wi on wi.block_id=b.id
    join public.exercises ex on ex.id=wi.exercise_id
    left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
    where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down')
    and (ep.code is null or ep.definition->'body_regions' ? 'lower_body')));
 if cardinality(editable)=0 then return null; end if;
 case p_mode
  when 'activation' then original:=public.preview_adaptive_program_activation(p_goal_id,p_week_start);
  when 'revision' then original:=public.preview_preparation_week_revision(p_goal_id,p_week_start);
  when 'weekly' then original:=public.calculate_preparation_week(p_goal_id,p_week_start);
  else raise exception 'Vista previa no compatible.' using errcode='22023';
 end case;
 scope:=original->>'training_scope';
 if original->>'status' is distinct from 'ready' or original->>'decision_id' is not null
   or original#>>'{running,mode}' is distinct from 'normal'
   or exists(select 1 from jsonb_array_elements(original#>'{running,sessions}') r where r->>'family' in ('T','V','S','C')) then
  return null;
 end if;
 revision:=p_mode in ('activation','revision');
 if p_mode='activation' then
  excluded:=array(select value::uuid from jsonb_array_elements_text(original#>'{activation,cancel_ids}'));
 end if;
 if revision then
  replaced:=array(select public.preparation_revision_session_ids(p_goal_id,p_week_start));
 end if;
 for moved in
  select sw.id,sw.scheduled_date,sw.template_name,sw.estimated_duration_minutes,p_week_start+d.new_day as new_date
  from public.scheduled_workouts sw cross join generate_series(0,6) d(new_day)
  where sw.id=any(editable)
   and p_week_start+d.new_day>=current_date and sw.scheduled_date<>p_week_start+d.new_day
   and sw.estimated_duration_minutes<=(original->'availability'->>(d.new_day+1)::text)::int
   and not exists(select 1 from public.scheduled_workouts other
    where other.user_id=u and public.workout_load_on_v1(other)=p_week_start+d.new_day
    and other.status not in ('cancelled','skipped'))
  order by abs(p_week_start+d.new_day-sw.scheduled_date),sw.scheduled_date,
   (p_week_start+d.new_day<sw.scheduled_date),d.new_day,sw.id
  limit 6
 loop
  alternative:=public.calculate_preparation_week_training_v4(p_goal_id,p_week_start,revision,scope,excluded,moved.id,moved.new_date);
  alternative:=public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,alternative,moved.id,moved.new_date);
  if alternative->>'status' is distinct from 'ready'
   or jsonb_array_length(alternative#>'{running,sessions}')<jsonb_array_length(original#>'{running,sessions}')
   or not exists(select 1 from jsonb_array_elements(alternative#>'{running,sessions}') r where r->>'family' in ('T','V','S'))
   or exists(
    select w->>'reference_id' from jsonb_array_elements(original->'sessions') s cross join jsonb_array_elements(s->'work') w
    except all
    select w->>'reference_id' from jsonb_array_elements(alternative->'sessions') s cross join jsonb_array_elements(s->'work') w
   ) then continue; end if;
  select coalesce(jsonb_agg(jsonb_build_object('date',d.load_date,'name',sw.template_name,'kind','scheduled',
   'minutes',sw.estimated_duration_minutes) order by d.load_date,sw.order_index,sw.id),'[]') into agenda
  from public.scheduled_workouts sw
  cross join lateral (select public.preparation_preview_load_on_v1(sw,moved.id,moved.new_date) as load_date) d
  where sw.user_id=u and d.load_date between p_week_start and p_week_start+6
   and sw.status not in ('cancelled','skipped') and not sw.id=any(excluded||replaced);
  return jsonb_build_object('scheduled_id',moved.id,'name',moved.template_name,
   'from_date',moved.scheduled_date,'to_date',moved.new_date,
   'running',alternative#>'{running,sessions}','performance',alternative->'sessions','agenda',agenda);
 end loop;
 return null;
end $$;

revoke all on function public.preview_preparation_strength_move(uuid,date,text) from public,anon;
grant execute on function public.preview_preparation_strength_move(uuid,date,text) to authenticated;

commit;
