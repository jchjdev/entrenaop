-- Un control medido conserva su fuente; no se convierte en evaluación oficial.
begin;
alter table public.running_reference_selections drop constraint running_reference_source_check;
alter table public.running_reference_selections add constraint running_reference_source_check
 check(reference_source in ('troopControl','trainingControl','troopOfficialAssessment','fasPeriodicAssessment','programAssessment'));
create or replace function public.resolve_program_running_reference(p_goal_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 sel public.running_reference_selections%rowtype; r record; selected_test uuid;
 standard jsonb; controls jsonb:='[]'; n int;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 select * into sel from public.running_reference_selections where preparation_goal_id=g.id;
 if not found then raise exception 'Choose a compatible 2 km mark in this preparation'; end if;
 if g.program_id='fas_periodic_assessment' and sel.reference_source='fasPeriodicAssessment' then
   select a.completed_at,m.value/1000.0 seconds into r from public.fas_periodic_assessments a
   join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',a.catalog_version,
     'category',a.category,'age_band',a.age_band,'scope','minimum_20_points_not_global_pass') into standard
   from public.fas_periodic_assessments a join public.fas_periodic_standards s
     on s.catalog_version=a.catalog_version and s.category=a.category and s.age_band=a.age_band and s.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'protocol',a.catalog_version||':run_2000_m') order by a.completed_at),'[]') into controls
   from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.preparation_goal_id=g.id and a.user_id=u and a.completed_at<=r.completed_at and a.completed_at<=now();
 elsif g.program_id='armed_forces_troop_entry' and sel.reference_source='troopOfficialAssessment' then
   select a.completed_at,m.value/1000.0 seconds into r from public.physical_assessments a
   join public.physical_assessment_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',a.catalog_version,
     'category',a.category,'scope','test_minimum_not_global_pass') into standard
   from public.physical_assessments a join public.assessment_standards s
   on s.catalog_version=a.catalog_version and s.category=a.category and s.milestone=a.milestone and s.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'protocol',a.catalog_version||':run_2000_m') order by a.completed_at),'[]') into controls
   from public.physical_assessments a join public.physical_assessment_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.preparation_goal_id=g.id and a.user_id=u and a.completed_at<=r.completed_at and a.completed_at<=now();
 elsif sel.reference_source='trainingControl' or (g.program_id='armed_forces_troop_entry' and sel.reference_source='troopControl') then
   if g.program_id not in ('fas_periodic_assessment','armed_forces_troop_entry') and not exists(select 1 from public.program_training_modules where program_id=g.program_id and module_key='running_2000m_v1') then raise exception 'Este programa no tiene preparación de 2 km.'; end if;
   select t.completed_at,t.duration_seconds::numeric seconds into r from public.preparation_running_tests t
   where t.id::text=sel.reference_record_id and t.user_id=u and t.preparation_goal_id=g.id and t.protocol_version='run_2000m_v1';
   select coalesce(jsonb_agg(jsonb_build_object('date',t.completed_at::date,'seconds',t.duration_seconds,
     'protocol',t.protocol_version) order by t.completed_at),'[]') into controls
   from public.preparation_running_tests t where t.user_id=u and t.preparation_goal_id=g.id
     and t.completed_at<=r.completed_at and t.completed_at<=now();
   -- Un control sin evaluación no inventa categoría ni umbral oficial.
 elsif sel.reference_source='programAssessment' then
   select count(*) into n from public.program_assessment_attempts a
   cross join lateral jsonb_array_elements(a.result->'details') d
   join public.program_training_modules tm on tm.test_id::text=d->>'test_id' and tm.program_id=g.program_id and tm.module_key='running_2000m_v1'
   join public.preparation_programs pp on pp.id=tm.program_id and pp.enabled
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
   if n<>1 then raise exception 'Choose one unambiguous module-linked 2 km result'; end if;
   select a.assessed_on::timestamptz completed_at,(d->>'mark')::numeric seconds,
     (d->>'test_id')::uuid test_id,jsonb_build_object('seconds',(d->>'minimum_mark')::numeric,
       'catalog_version',a.scoring_version,'category',a.category,'age',a.result->'age',
       'scope','test_minimum_not_global_pass') official into r
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   join public.program_training_modules tm on tm.test_id::text=d->>'test_id' and tm.program_id=g.program_id and tm.module_key='running_2000m_v1'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
   selected_test:=r.test_id; standard:=r.official;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.assessed_on,'seconds',(d->>'mark')::numeric,
     'protocol','run_2000m_v1:'||selected_test::text) order by a.assessed_on),'[]') into controls
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   where a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id and d->>'test_id'=selected_test::text
     and a.assessed_on<=r.completed_at::date and a.assessed_on<=current_date
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
 else raise exception 'Reference source does not belong to this running program'; end if;
 if r.completed_at is null or r.seconds is null or r.seconds not between 240 and 1800 then
   raise exception 'Choose a compatible 2 km mark in this preparation'; end if;
 return jsonb_build_object('reference_source',sel.reference_source,'reference_record_id',sel.reference_record_id,
   'continuity_confirmed_at',sel.continuity_confirmed_at,'completed_at',r.completed_at,'value',r.seconds*1000,
   'standard',standard,'controls',controls);
end $$;
commit;
