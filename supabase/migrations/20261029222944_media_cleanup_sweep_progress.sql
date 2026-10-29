-- Cada solicitud nueva debe revisar otro lote, aunque los anteriores estén
-- protegidos. El recibo de una misma operación conserva los IDs ya revisados.
begin;
create or replace function trainer_private.sweep_media(p_operation_id uuid,p_scope text,p_limit integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous trainer_private.media_cleanup_operations;j trainer_private.media_cleanup_jobs;request jsonb;ids uuid[]:='{}';r record;
begin
 perform trainer_private.media_context(p_scope);
 if p_operation_id is null then raise invalid_parameter_value;end if;
 p_limit:=greatest(1,least(coalesce(p_limit,50),100));request:=jsonb_build_object('action','sweep','scope',p_scope,'limit',p_limit);
 perform pg_advisory_xact_lock(hashtextextended('media-operation:'||auth.uid()::text||p_operation_id::text,0));
 select * into previous from trainer_private.media_cleanup_operations where actor_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if previous.request is distinct from request then raise invalid_parameter_value;end if;ids:=previous.job_ids;
 else
  for r in with candidates as (
   select 'image' kind,i.path target,'image:trainer-exercise-images:'||i.path resource_key
    from trainer_private.exercise_images i where p_scope='trainer' and i.trainer_id=auth.uid() and i.deleted_at is null
    and i.created_at<clock_timestamp()-interval '24 hours'
   union all select 'image',o.name,'image:exercise-images-public:'||o.name from storage.objects o
    where p_scope='official' and o.bucket_id='exercise-images-public' and o.name like 'official/%' and o.created_at<clock_timestamp()-interval '24 hours'
   union all select 'video',a.id::text,'video:'||a.id::text from public.exercise_video_assets a
    where a.deleted_at is null and a.created_at<clock_timestamp()-interval '24 hours'
    and((p_scope='trainer' and a.scope='trainer_exercise' and a.created_by=auth.uid()) or(p_scope='official' and a.scope='official'))
    and((a.creation_state='reserved' and a.provider_video_id is null) or a.status in('failed','rejected'))
  ) select c.kind,c.target from candidates c left join trainer_private.media_cleanup_jobs seen on seen.resource_key=c.resource_key
   order by(seen.id is null)desc,seen.updated_at asc nulls first,c.resource_key limit p_limit loop
   j:=trainer_private.enqueue_media(p_scope,r.kind,r.target);ids:=array_append(ids,j.id);
  end loop;
  insert into trainer_private.media_cleanup_operations values(auth.uid(),p_operation_id,request,ids);
 end if;
 return jsonb_build_object('items',(select coalesce(jsonb_agg(trainer_private.media_job_json(x) order by x.created_at desc,x.id desc),'[]') from trainer_private.media_cleanup_jobs x where x.id=any(ids)),
  'queued',(select count(*) from trainer_private.media_cleanup_jobs where id=any(ids) and state in('queued','deleting','retry')));
end $$;
commit;
