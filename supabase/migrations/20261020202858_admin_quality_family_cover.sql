-- La portada pertenece a la familia, también al revisar versiones posteriores.
create or replace function public.admin_catalog_quality() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(to_jsonb(q) || case when q.resource_type='session' then
    jsonb_build_object('program_id',(select program_id from public.program_workout_templates
      where template_id=q.resource_id and catalog_scope='program')) else '{}'::jsonb end
    order by case q.severity when 'error' then 0 when 'attention' then 1 else 2 end,q.name,q.code) from (
    select 'exercise'::text resource_type,e.id resource_id,e.name,'incomplete_exercise'::text code,'attention'::text severity,
      'Faltan descripción o grupos musculares.'::text message
      from public.exercises e where e.origin='system' and e.id<>'20000000-0000-4000-8000-000000000004'::uuid
      and (nullif(btrim(e.description),'') is null or cardinality(e.muscle_groups)=0)
    union all select 'exercise',e.id,e.name,'missing_media','attention','Sin vídeo ni imagen asignados.'
      from public.exercises e where e.origin='system' and e.id<>'20000000-0000-4000-8000-000000000004'::uuid
      and nullif(e.video_url,'') is null and nullif(e.image_path,'') is null
    union all select 'program',p.id,p.content->>'name','missing_cover','attention','Sin portada de tarjeta.'
      from public.guided_programs p left join public.guided_program_covers c on c.program_id=p.family_id
      where p.status<>'archived' and c.card_image_path is null
    union all select 'program',p.id,p.content->>'name','draft_program','pending','Programa pendiente de revisión/publicación.'
      from public.guided_programs p where p.status='draft'
    union all select 'session',t.id,t.name,'draft_session','pending','Sesión guardada en borrador.'
      from public.workout_templates t where t.origin='system' and t.owner_user_id is null and t.status='draft'
    union all select 'program',p.id,p.content->>'name','unavailable_session','error','El programa referencia una sesión retirada o no disponible.'
      from public.guided_programs p where p.status<>'archived' and exists(
        select 1 from jsonb_array_elements(p.content->'phases') phase,
          jsonb_array_elements(phase->'sessions') slot left join public.workout_templates t on t.id=(slot->>'template_id')::uuid
        where t.id is null or t.status not in ('draft','published'))
    union all select 'program',p.id,p.content->>'name','unavailable_warmup','error','El programa referencia un calentamiento retirado o no disponible.'
      from public.guided_programs p where p.status<>'archived' and exists(
        select 1 from jsonb_array_elements(p.content->'phases') phase,
          jsonb_array_elements(phase->'sessions') slot left join public.guided_warmups w on w.id=(slot->>'warmup_id')::uuid
        where slot->>'warmup_id' is not null and (w.id is null or w.status<>'published'))
    union all select 'video',a.id,'Vídeo '||left(a.id::text,8),'video_failed','error',
      'El último estado registrado del vídeo es '||a.status||'.'
      from public.exercise_video_assets a where a.status in ('failed','rejected')
  ) q),'[]'::jsonb);
end $$;
