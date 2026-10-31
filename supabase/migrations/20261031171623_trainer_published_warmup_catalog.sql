begin;
-- Lectura acotada de recetas oficiales publicadas. No se amplía RLS de las
-- plantillas privadas, ni se habilita edición o publicación al preparador.
create function trainer_private.published_warmups(p_expected_owner uuid,p_after_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_owner
    or not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if not coalesce(public.is_admin(),false) then
   perform trainer_private.require_authoring_access();
 end if;
 with latest as (
   select distinct on (w.family_id) w.* from public.guided_warmups w
   join public.workout_templates t on t.id=w.template_id
   where w.status='published' and t.status='published' and t.origin='system'
     and not exists(select 1 from public.workout_blocks b
       join public.workout_items i on i.block_id=b.id
       join public.exercises e on e.id=i.exercise_id
       where b.template_id=t.id and (not e.is_public or e.origin<>'system'))
   order by w.family_id,w.version desc,w.id
 ), candidates as (
   select * from latest where p_after_id is null or template_id>p_after_id
   order by template_id limit 51
 ), page as (select * from candidates order by template_id limit 50)
 select jsonb_build_object('has_more',(select count(*)>50 from candidates),'items',
   coalesce((select jsonb_agg(jsonb_build_object(
     'id',t.id,'name',w.name,'description',t.description,
     'estimated_duration_minutes',t.estimated_duration_minutes,'version',w.version,
     'workout_blocks',coalesce((select jsonb_agg(to_jsonb(b)||jsonb_build_object(
       'workout_items',coalesce((select jsonb_agg(to_jsonb(i)||jsonb_build_object(
         'exercises',jsonb_build_object('id',e.id,'name',e.name,'description',e.description),
         'workout_sets',coalesce((select jsonb_agg(to_jsonb(s) order by s.order_index,s.id)
           from public.workout_sets s where s.item_id=i.id),'[]'::jsonb)) order by i.order_index,i.id)
         from public.workout_items i join public.exercises e on e.id=i.exercise_id
         where i.block_id=b.id),'[]'::jsonb)) order by b.order_index,b.id)
       from public.workout_blocks b where b.template_id=t.id),'[]'::jsonb)) order by t.id)
     from page w join public.workout_templates t on t.id=w.template_id),'[]'::jsonb)) into result;
 return result;
end $$;
create function public.list_published_workout_warmups(p_expected_owner uuid,p_after_id uuid default null)
returns jsonb language sql volatile security invoker set search_path='' as $$
 select trainer_private.published_warmups(p_expected_owner,p_after_id)
$$;
revoke all on function trainer_private.published_warmups(uuid,uuid),public.list_published_workout_warmups(uuid,uuid) from public,anon,authenticated;
grant execute on function trainer_private.published_warmups(uuid,uuid),public.list_published_workout_warmups(uuid,uuid) to authenticated;
commit;
