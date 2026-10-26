begin;

-- La autoridad sigue resolviéndose en training_source. Esta proyección interna
-- solo admite ejercicios públicos o privados del autor de la plantilla pautada.
-- No se infieren equivalencias de Garmin desde nombres o grupos musculares.
create or replace function device_private.strength_snapshot(p_recipe jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare b jsonb; i jsonb; ex public.exercises; blocks jsonb:='[]'; items jsonb;
 author uuid; code text;
begin
 if exists(select 1 from jsonb_array_elements(p_recipe->'blocks') x where x->>'format'='running') then return p_recipe; end if;
 if p_recipe->>'source'<>'coach' then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 select owner_user_id into author from public.workout_templates
  where id=(p_recipe->>'template_id')::uuid and origin='coach';
 for b in select value from jsonb_array_elements(p_recipe->'blocks') loop
  if b->>'format'<>'straight_sets' then raise exception 'unsupported_prescription' using errcode='22023'; end if;
  items:='[]';
  for i in select value from jsonb_array_elements(b->'items') loop
   select * into ex from public.exercises where id=(i->>'exercise_id')::uuid
    and (is_public or (origin='coach' and created_by=author));
   if not found then raise exception 'unsupported_prescription' using errcode='22023'; end if;
   code:=case when ex.is_public and ex.training_profile_version=1
     and ex.training_profile_code in ('bench_press_barbell','push_up_standard','pull_up_pronated')
     then ex.training_profile_code else null end;
   items:=items||jsonb_build_array(i||jsonb_build_object('exercise_code',code,'exercise_name',ex.name));
  end loop;
  blocks:=blocks||jsonb_build_array(b||jsonb_build_object('items',items));
 end loop;
 return p_recipe||jsonb_build_object('sport','strength','blocks',blocks);
end $$;
revoke all on function device_private.strength_snapshot(jsonb) from public,anon,authenticated,service_role;

create or replace function device_private.device_training_template(p_template uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.workout_blocks b where b.template_id=p_template and b.format='running')
 or (exists(select 1 from public.workout_blocks where template_id=p_template)
 and not exists(select 1 from public.workout_blocks b where b.template_id=p_template and
  (b.format<>'straight_sets' or b.rounds<>1 or b.rest_after_seconds<>0 or b.time_cap_seconds is not null))
 and not exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
  join public.workout_templates t on t.id=b.template_id
  left join public.exercises e on e.id=i.exercise_id where b.template_id=p_template and
   (e.id is null or not (e.is_public or
     (e.origin='coach' and t.origin='coach' and e.created_by=t.owner_user_id)))));
$$;
revoke all on function device_private.device_training_template(uuid) from public,anon,authenticated,service_role;

commit;
