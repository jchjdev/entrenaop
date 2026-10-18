-- Metadatos de las dos demos ya autorizadas; no modifica recetas ni seguimientos.
begin;
do $$
declare p public.guided_programs; primary_name text; names text[];
begin
  for p in select * from public.guided_programs where status='published' and content->>'name' in
    ('Demo · Empuje, tirón y pierna','Demo · Mejora de dominadas') for update loop
    if exists(select 1 from public.guided_program_category_links where program_id=p.id) then continue; end if;
    if p.content->>'name'='Demo · Empuje, tirón y pierna' then
      names:=array['Hipertrofia','Fuerza']; primary_name:='Hipertrofia';
    else names:=array['Fuerza','Iniciación']; primary_name:='Fuerza'; end if;
    if (select count(*) from public.guided_program_categories where name=any(names) and is_active)<>2 then
      raise exception 'Revisa las categorías disponibles antes de clasificar las demos.';
    end if;
    insert into public.guided_program_category_links(program_id,category_id,is_primary)
      select p.id,c.id,c.name=primary_name from public.guided_program_categories c where c.name=any(names) and c.is_active;
  end loop;
end $$;
select p.content->>'name' as program,c.name as category,l.is_primary
  from public.guided_programs p join public.guided_program_category_links l on l.program_id=p.id
  join public.guided_program_categories c on c.id=l.category_id
  where p.content->>'name' in ('Demo · Empuje, tirón y pierna','Demo · Mejora de dominadas')
  order by p.id,l.is_primary desc,c.name;
rollback; -- @demo-transaction-end
