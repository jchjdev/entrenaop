begin;

-- Perfil y programa leen el mismo contexto que consume el coordinador.
-- Las preferencias generales anteriores se conservan como ayuda inicial.
create function public.get_training_context_settings()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
 return jsonb_build_object(
   'context',(select to_jsonb(c)-'user_id' from public.performance_training_contexts c where c.user_id=auth.uid()),
   'previous_preferences',(select jsonb_build_object(
     'session_duration_minutes',p.session_duration_minutes,
     'available_days_per_week',p.available_days_per_week,
     'equipment',p.equipment,'requires_professional_review',p.requires_professional_review)
     from public.training_preferences p where p.user_id=auth.uid()),
   'equipment_options',coalesce((select jsonb_agg(code order by code) from (
     select distinct eq.code
     from public.exercise_training_profiles ep
     cross join lateral jsonb_array_elements_text(
       coalesce(ep.definition->'required_equipment','[]'::jsonb)||coalesce(ep.definition->'optional_equipment','[]'::jsonb)
     ) eq(code)
     where exists(select 1 from public.exercises ex where ex.is_public
       and ex.training_profile_code=ep.code and ex.training_profile_version=ep.definition_version)
   ) materials),'[]'::jsonb)
 );
end $$;
revoke all on function public.get_training_context_settings() from public,anon;
grant execute on function public.get_training_context_settings() to authenticated;

commit;
