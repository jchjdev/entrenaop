-- El usuario declara su nacimiento una vez en el perfil. La edad de cada
-- intento se calcula para su fecha local, no se acepta una edad arbitraria.
begin;

create or replace function public.validate_fas_periodic_profile_age()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_birth_date date;
  v_test_date date := (new.completed_at at time zone 'Europe/Madrid')::date;
  v_age integer;
begin
  select p.fecha_nacimiento into v_birth_date
  from public.profiles p where p.id = new.user_id;
  if v_birth_date is null then
    raise exception 'Indica tu fecha de nacimiento en el perfil.' using errcode = '22023';
  end if;
  -- El aniversario de un 29 de febrero se alcanza el 1 de marzo en los
  -- años no bisiestos, igual que en el cálculo de la app.
  v_age := extract(year from v_test_date)::integer
    - extract(year from v_birth_date)::integer
    - case when (extract(month from v_test_date), extract(day from v_test_date))
        < (extract(month from v_birth_date), extract(day from v_birth_date))
      then 1 else 0 end;
  if v_age <> new.age_at_assessment then
    raise exception 'La edad no coincide con la fecha de nacimiento.' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger fas_periodic_profile_age_guard
before insert on public.fas_periodic_assessments
for each row execute function public.validate_fas_periodic_profile_age();

revoke all on function public.validate_fas_periodic_profile_age() from public, anon, authenticated;
commit;
