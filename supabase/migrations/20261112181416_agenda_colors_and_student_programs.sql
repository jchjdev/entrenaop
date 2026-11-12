begin;

create table trainer_private.agenda_client_colors (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null references public.profiles(id) on delete cascade,
 color text not null check (color in ('sky','violet','green','orange','pink','indigo','teal','yellow')),
 primary key (trainer_id,client_id)
);
create index agenda_client_colors_client on trainer_private.agenda_client_colors(client_id);
alter table trainer_private.agenda_client_colors enable row level security;
revoke all on trainer_private.agenda_client_colors from public,anon,authenticated;

create function trainer_private.list_trainer_agenda_colors() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 return coalesce((select jsonb_object_agg(client_id,color) from trainer_private.agenda_client_colors
   where trainer_id=auth.uid()),'{}'::jsonb);
end $$;

create function trainer_private.set_trainer_agenda_color(p_client_id uuid,p_color text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform trainer_private.require_authoring_access();
 if not exists(select 1 from public.trainer_client_relations
    where trainer_id=auth.uid() and client_id=p_client_id) then raise insufficient_privilege; end if;
 if p_color is null then
  delete from trainer_private.agenda_client_colors where trainer_id=auth.uid() and client_id=p_client_id;
 else
  insert into trainer_private.agenda_client_colors(trainer_id,client_id,color)
   values(auth.uid(),p_client_id,p_color)
   on conflict(trainer_id,client_id) do update set color=excluded.color;
 end if;
end $$;

create function public.list_trainer_agenda_colors() returns jsonb
language sql stable security invoker set search_path='' as $$
 select trainer_private.list_trainer_agenda_colors();
$$;
create function public.set_trainer_agenda_color(p_client_id uuid,p_color text) returns void
language sql security invoker set search_path='' as $$
 select trainer_private.set_trainer_agenda_color(p_client_id,p_color);
$$;

alter table public.trainer_assignments add column program_phase_index integer
 check (program_phase_index is null or (program_phase_index>=0 and program_delivery_id is not null));
create index trainer_assignments_student_programs on public.trainer_assignments(client_id,program_delivery_id)
 where program_delivery_id is not null;

-- La fecha y la receta originales sobreviven a los movimientos y adaptaciones.
-- Si un envío antiguo no permite distinguir dos fases, se mantiene la sesión
-- sin atribuirle una fase arbitraria.
with matched as (
 select a.scheduled_id, min(ps.phase_index) as phase_index
 from public.trainer_assignments a
 join trainer_private.assignment_origins o on o.assignment_id=a.scheduled_id
 join trainer_private.program_deliveries d on d.id=a.program_delivery_id
 join trainer_private.programs p on p.id=d.program_id
 cross join lateral jsonb_array_elements(d.entries) e(value)
 join trainer_private.program_sessions ps on ps.program_id=p.id
  and ps.phase_index=(e.value->>'phase')::integer and ps.session_index=(e.value->>'session')::integer
 where ps.template_id=o.template_id and (e.value->>'date')::date=o.scheduled_date
  and o.note=btrim((p.content->>'name')||' · '||(p.content->'phases'->ps.phase_index->>'name')||
   coalesce(E'\n'||d.note,''))
 group by a.scheduled_id having count(distinct ps.phase_index)=1
)
update public.trainer_assignments a set program_phase_index=m.phase_index
 from matched m where a.scheduled_id=m.scheduled_id;

do $migration$
declare definition text; anchor text:='set program_delivery_id=p_id where scheduled_id=sid';
begin
 definition:=pg_get_functiondef('trainer_private.assign_trainer_program(uuid,uuid,uuid,jsonb,text)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar la asignación de programas antes de migrar.'; end if;
 execute replace(definition,anchor,'set program_delivery_id=p_id, program_phase_index=pi where scheduled_id=sid');
end $migration$;

create view trainer_private.student_program_schedules as
 select a.program_delivery_id as delivery_id,a.program_phase_index as phase_index,
  s.id,s.template_name as name,s.scheduled_date,s.status
 from public.trainer_assignments a
 join public.scheduled_workouts s on s.id=a.scheduled_id and s.user_id=a.client_id
 join public.trainer_client_relations r on r.id=a.relation_id and r.client_id=a.client_id
 where a.client_id=(select auth.uid()) and a.program_delivery_id is not null
  and s.source='coach' and s.status<>'cancelled'
  and (r.ended_at is null or s.execution_id is not null);
revoke all on trainer_private.student_program_schedules from public,anon,authenticated;

create function trainer_private.student_assigned_programs(
 p_expected_owner uuid,p_delivery_id uuid,p_before_at timestamptz,p_before_id uuid
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 if (p_before_at is null)<>(p_before_id is null)
  or (p_delivery_id is not null and p_before_at is not null) then raise invalid_parameter_value; end if;

 return (
  with page as (
   select d.id,d.created_at,d.note,p.content,
    coalesce(nullif(btrim(coach.full_name),''),'Preparador') as trainer_name
   from public.trainer_client_relations r
   join trainer_private.program_deliveries d on d.relation_id=r.id
   join trainer_private.programs p on p.id=d.program_id
   join public.profiles coach on coach.id=d.trainer_id
   where r.client_id=auth.uid()
    and (p_delivery_id is null or d.id=p_delivery_id)
    and (p_before_at is null or (d.created_at,d.id)<(p_before_at,p_before_id))
    and exists(select 1 from trainer_private.student_program_schedules s where s.delivery_id=d.id)
   order by d.created_at desc,d.id desc limit 21
  ), rows as (
   select d.id,d.created_at,jsonb_build_object(
    'id',d.id,'created_at',d.created_at,'name',d.content->>'name',
    'trainer_name',d.trainer_name,'total',progress.total,'completed',progress.completed,
    'description',case when p_delivery_id is not null then d.content->>'description' end,
    'note',case when p_delivery_id is not null then d.note end,
    'phases',case when p_delivery_id is not null then (
     select jsonb_agg(jsonb_build_object(
      'name',coalesce(d.content->'phases'->f.phase_index->>'name','Sesiones del programa'),
      'instructions',d.content->'phases'->f.phase_index->>'instructions','sessions',f.sessions
     ) order by f.phase_index nulls last)
     from (
      select s.phase_index,jsonb_agg(jsonb_build_object(
       'id',s.id,'name',s.name,'date',s.scheduled_date,'status',s.status
      ) order by s.scheduled_date,s.id) as sessions
      from trainer_private.student_program_schedules s where s.delivery_id=d.id group by s.phase_index
     ) f
    ) end
   ) as item
   from (select * from page order by created_at desc,id desc limit 20) d
   cross join lateral (
    select count(*) as total,count(*) filter (where s.status='completed') as completed
    from trainer_private.student_program_schedules s where s.delivery_id=d.id
   ) progress
  )
  select jsonb_build_object(
   'items',coalesce((select jsonb_agg(item order by created_at desc,id desc) from rows),'[]'::jsonb),
   'has_more',(select count(*)>20 from page)
  )
 );
end $$;

create function public.list_my_assigned_programs(
 p_expected_owner uuid,p_delivery_id uuid default null,p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb
language sql stable security invoker set search_path='' as $$
 select trainer_private.student_assigned_programs(p_expected_owner,p_delivery_id,p_before_at,p_before_id);
$$;

-- Reutiliza el resumen de Preparador para mostrar el acceso solo si hay programas.
do $migration$
declare definition text; anchor text:='resources:=jsonb_build_object(';
begin
 definition:=pg_get_functiondef('trainer_private.student_notice_snapshot(uuid,timestamptz,uuid,text)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar los recursos del alumno antes de migrar.'; end if;
 execute replace(definition,anchor,anchor||
  '''has_assigned_programs'',exists(select 1 from trainer_private.student_program_schedules),');
end $migration$;

revoke all on function trainer_private.list_trainer_agenda_colors(),
 trainer_private.set_trainer_agenda_color(uuid,text),
 trainer_private.student_assigned_programs(uuid,uuid,timestamptz,uuid),
 public.list_trainer_agenda_colors(),public.set_trainer_agenda_color(uuid,text),
 public.list_my_assigned_programs(uuid,uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.list_trainer_agenda_colors(),
 trainer_private.set_trainer_agenda_color(uuid,text),
 trainer_private.student_assigned_programs(uuid,uuid,timestamptz,uuid),
 public.list_trainer_agenda_colors(),public.set_trainer_agenda_color(uuid,text),
 public.list_my_assigned_programs(uuid,uuid,timestamptz,uuid) to authenticated;

commit;
