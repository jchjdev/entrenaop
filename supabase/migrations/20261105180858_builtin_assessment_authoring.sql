-- Autoría de baremos nativos. Ninguna publicación sustituye las versiones usadas
-- por evaluaciones ni cambia el vínculo de una preparación ya creada.
begin;

create schema builtin_assessment_private;
revoke all on schema builtin_assessment_private from public, anon, authenticated;
grant usage on schema builtin_assessment_private to anon, authenticated;

create table public.builtin_assessment_revisions (
  id uuid primary key default gen_random_uuid(),
  program_id text not null references public.preparation_programs(id) on delete restrict,
  revision integer not null check (revision > 0),
  status text not null check (status in ('draft','published','withdrawn')),
  base_id uuid references public.builtin_assessment_revisions(id) on delete restrict,
  definition jsonb not null check (jsonb_typeof(definition)='object' and octet_length(definition::text)<262144),
  catalog_version text not null unique,
  scoring_version text not null unique,
  change_reason text not null default '',
  edit_version integer not null default 1 check (edit_version>0),
  created_at timestamptz not null default clock_timestamp(),
  published_at timestamptz,
  unique(program_id,revision),
  check(program_id in ('armed_forces_troop_entry','fas_periodic_assessment')),
  check((status='draft' and published_at is null) or (status<>'draft' and published_at is not null)),
  check(definition->>'programId'=program_id and definition->>'version'=scoring_version)
);
alter table public.builtin_assessment_revisions enable row level security;
revoke all on public.builtin_assessment_revisions from public,anon,authenticated;
grant select on public.builtin_assessment_revisions to anon,authenticated;
create policy builtin_revision_read on public.builtin_assessment_revisions for select to anon,authenticated
using(status in ('published','withdrawn') or ((select public.is_admin()) and (auth.jwt()->>'aal')='aal2'));

create table public.builtin_assessment_goal_revisions (
  goal_id uuid primary key references public.preparation_goals(id) on delete cascade,
  revision_id uuid not null references public.builtin_assessment_revisions(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);
create index builtin_goal_revision_idx on public.builtin_assessment_goal_revisions(revision_id);
alter table public.builtin_assessment_goal_revisions enable row level security;
revoke all on public.builtin_assessment_goal_revisions from public,anon,authenticated;
grant select on public.builtin_assessment_goal_revisions to authenticated;
create policy builtin_goal_revision_read on public.builtin_assessment_goal_revisions for select to authenticated
using(exists(select 1 from public.preparation_goals g where g.id=goal_id and g.user_id=auth.uid()) or ((select public.is_admin()) and (auth.jwt()->>'aal')='aal2'));

create table builtin_assessment_private.creation_requests (
  actor_id uuid not null, request_id uuid not null,
  program_id text not null, base_id uuid not null,
  revision_id uuid not null references public.builtin_assessment_revisions(id),
  primary key(actor_id,request_id)
);
create table builtin_assessment_private.events (
  id bigint generated always as identity primary key,
  revision_id uuid not null references public.builtin_assessment_revisions(id),
  actor_id uuid, action text not null,
  occurred_at timestamptz not null default clock_timestamp(),
  before_data jsonb, after_data jsonb not null
);
alter table builtin_assessment_private.creation_requests enable row level security;
alter table builtin_assessment_private.events enable row level security;
revoke all on all tables in schema builtin_assessment_private from public,anon,authenticated;

-- Las definiciones iniciales conservan identidad y magnitudes históricas.
insert into public.builtin_assessment_revisions(program_id,revision,status,definition,
  catalog_version,scoring_version,change_reason,published_at)
select 'armed_forces_troop_entry',1,'published',jsonb_build_object(
  'schemaVersion',1,'programId','armed_forces_troop_entry','version',c.version,
  'name',p.name,'description','Ingreso y formación de tropa y marinería.',
  'sourceUrl',c.source_url,'effectiveFrom',c.effective_from::text,
  'tests',(select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'unit',t.unit,
    'betterDirection',t.better_direction) order by t.id)
    from public.physical_test_definitions t where exists(select 1 from public.assessment_standards s
      where s.catalog_version=c.version and s.test_id=t.id)),
  'standards',(select jsonb_agg(jsonb_build_object('testId',s.test_id,'category',s.category,
    'group',s.milestone,'threshold',s.threshold) order by s.test_id,s.category,s.milestone)
    from public.assessment_standards s where s.catalog_version=c.version)
),c.version,c.version,'Definición original conservada.',clock_timestamp()
from public.assessment_catalogs c cross join public.preparation_programs p
where c.version='es_def_15_2026_troop_v1' and p.id='armed_forces_troop_entry';

-- FAS_SEED_BEGIN
-- Importación íntegra de assets/programs/fas_periodic_2027/assessment_reference_v1.json.
insert into public.builtin_assessment_revisions(program_id,revision,status,definition,catalog_version,scoring_version,change_reason,published_at)
values('fas_periodic_assessment',1,'published',$fas_seed${"version":"es_def_15_2026_periodic_2027_v2_full_scores","programId":"fas_periodic_assessment","status":"future_reference","effectiveFrom":"2027-01-01","sourceUrl":"https://www.boe.es/eli/es/o/2026/01/13/def15","sourceDocument":"BOE-A-2026-1379","sourceSection":"Artículo 12.1, disposición transitoria segunda y anexo II (II.1–II.4)","verifiedOn":"2026-09-24","sourceNotes":["La tabla II.3 publicada contiene, después de 15:14, las filas 16:22, 16:30, 16:38, 16:46, 16:54 y 16:02. Se conservan literalmente: no se corrigen ni extrapolan sin una corrección oficial."],"minimumPointsPerTest":20,"ageBands":[{"id":"17_25","minAge":17,"maxAge":25},{"id":"26_30","minAge":26,"maxAge":30},{"id":"31_35","minAge":31,"maxAge":35},{"id":"36_40","minAge":36,"maxAge":40},{"id":"41_45","minAge":41,"maxAge":45},{"id":"46_50","minAge":46,"maxAge":50},{"id":"51_55","minAge":51,"maxAge":55},{"id":"56_59","minAge":56,"maxAge":59},{"id":"60_plus","minAge":60,"maxAge":null}],"tests":[{"id":"upper_body_push_ups_2_min","name":"Flexo-extensiones de brazos (2 min)","unit":"repetitions","betterDirection":"higher","categoriesPerAgeBand":true,"rows":[[73,[100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[72,[100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[71,[99,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[70,[98,100,99,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[69,[97,100,98,100,99,100,100,100,100,100,100,100,100,100,100,100,100,100]],[68,[96,100,97,100,98,100,99,100,100,100,100,100,100,100,100,100,100,100]],[67,[95,100,96,100,97,100,98,100,99,100,100,100,100,100,100,100,100,100]],[66,[94,100,95,100,96,100,97,100,98,100,99,100,100,100,100,100,100,100]],[65,[93,99,94,100,95,100,96,100,97,100,98,100,99,100,100,100,100,100]],[64,[92,98,93,99,94,100,95,100,96,100,97,100,98,100,100,100,100,100]],[63,[91,97,92,98,93,99,94,100,95,100,96,100,97,100,99,100,100,100]],[62,[90,96,91,97,92,98,93,99,94,100,95,100,96,100,98,100,99,100]],[61,[89,95,90,96,91,97,92,98,93,99,94,100,95,100,97,100,98,100]],[60,[88,94,89,95,90,96,91,97,92,98,93,99,94,99,96,99,97,100]],[59,[87,93,88,94,89,95,90,96,91,97,92,98,93,98,95,98,96,99]],[58,[86,92,87,93,88,94,89,95,90,96,91,97,92,97,94,97,95,98]],[57,[85,91,86,92,87,93,88,94,89,95,90,96,91,96,93,96,94,97]],[56,[84,90,85,91,86,92,87,93,88,94,89,95,90,95,92,95,93,96]],[55,[83,89,84,90,85,91,86,92,87,93,88,94,89,94,91,94,92,95]],[54,[82,88,83,89,84,90,85,91,86,92,87,93,88,93,90,93,91,94]],[53,[81,87,82,88,83,89,84,90,85,91,86,92,87,92,89,92,90,93]],[52,[80,86,81,87,82,88,83,89,84,90,85,91,86,91,88,91,89,92]],[51,[79,85,80,86,81,87,82,88,83,89,84,90,85,90,87,90,88,91]],[50,[78,84,79,85,80,86,81,87,82,88,83,89,84,89,86,89,87,90]],[49,[77,83,78,84,79,85,80,86,81,87,82,88,83,88,85,88,86,89]],[48,[76,82,77,83,78,84,79,85,80,86,81,87,82,87,84,87,85,88]],[47,[75,81,76,82,77,83,78,84,79,85,80,86,81,86,83,86,84,87]],[46,[74,80,75,81,76,82,77,83,78,84,79,85,80,85,82,85,83,86]],[45,[72,79,74,80,75,81,76,82,77,83,78,84,79,84,81,84,82,85]],[44,[70,78,72,79,74,80,75,81,76,82,77,83,78,83,80,83,81,84]],[43,[68,77,70,78,72,79,74,80,75,81,76,82,77,82,79,82,80,83]],[42,[66,76,68,77,70,78,72,79,74,80,75,81,76,81,78,81,79,82]],[41,[64,75,66,76,68,77,70,78,72,79,74,80,75,80,77,80,78,81]],[40,[62,74,64,75,66,76,68,77,70,78,72,79,74,79,76,79,77,80]],[39,[60,72,62,74,64,75,66,76,68,77,70,78,72,78,75,78,76,79]],[38,[58,70,60,72,62,74,64,75,66,76,68,77,70,77,74,77,75,78]],[37,[56,68,58,70,60,72,62,74,64,75,66,76,68,76,72,76,74,77]],[36,[54,66,56,68,58,70,60,72,62,74,64,75,66,75,70,75,72,76]],[35,[52,64,54,66,56,68,58,70,60,72,62,74,64,74,68,74,70,75]],[34,[50,62,52,64,54,66,56,68,58,70,60,72,62,72,66,72,68,74]],[33,[48,60,50,62,52,64,54,66,56,68,58,70,60,70,64,70,66,72]],[32,[46,58,48,60,50,62,52,64,54,66,56,68,58,68,62,68,64,70]],[31,[44,56,46,58,48,60,50,62,52,64,54,66,56,66,60,66,62,68]],[30,[42,54,44,56,46,58,48,60,50,62,52,64,54,64,58,64,60,66]],[29,[40,52,42,54,44,56,46,58,48,60,50,62,52,62,56,62,58,64]],[28,[38,50,40,52,42,54,44,56,46,58,48,60,50,60,54,60,56,62]],[27,[36,48,38,50,40,52,42,54,44,56,46,58,48,58,52,58,54,60]],[26,[34,46,36,48,38,50,40,52,42,54,44,56,46,56,50,56,52,58]],[25,[32,44,34,46,36,48,38,50,40,52,42,54,44,54,48,54,50,56]],[24,[30,42,32,44,34,46,36,48,38,50,40,52,42,52,46,52,48,54]],[23,[29,40,30,42,32,44,34,46,36,48,38,50,40,50,44,50,46,52]],[22,[28,38,29,40,30,42,32,44,34,46,36,48,38,48,42,48,44,50]],[21,[27,36,28,38,29,40,30,42,32,44,34,46,36,46,40,46,42,48]],[20,[26,34,27,36,28,38,29,40,30,42,32,44,34,44,38,44,40,46]],[19,[25,32,26,34,27,36,28,38,29,40,30,42,32,42,36,42,38,44]],[18,[24,30,25,32,26,34,27,36,28,38,29,40,30,40,34,40,36,42]],[17,[23,29,24,30,25,32,26,34,27,36,28,38,29,38,32,38,34,40]],[16,[22,28,23,29,24,30,25,32,26,34,27,36,28,36,30,36,32,38]],[15,[21,27,22,28,23,29,24,30,25,32,26,34,27,34,29,34,30,36]],[14,[20,26,21,27,22,28,23,29,24,30,25,32,26,32,28,32,29,34]],[13,[18,25,20,26,21,27,22,28,23,29,24,30,25,30,27,30,28,32]],[12,[16,24,18,25,20,26,21,27,22,28,23,29,24,29,26,29,27,30]],[11,[14,23,16,24,18,25,20,26,21,27,22,28,23,28,25,28,26,29]],[10,[12,22,14,23,16,24,18,25,20,26,21,27,22,27,24,27,25,28]],[9,[10,21,12,22,14,23,16,24,18,25,20,26,21,26,23,26,24,27]],[8,[9,20,10,21,12,22,14,23,16,24,18,25,20,25,22,25,23,26]],[7,[8,18,9,20,10,21,12,22,14,23,16,24,18,24,21,24,22,25]],[6,[7,16,8,18,9,20,10,21,12,22,14,23,16,23,20,23,21,24]],[5,[6,14,6,16,8,18,9,20,10,21,12,22,14,22,18,22,20,23]],[4,[5,12,5,14,6,15,8,16,9,20,10,21,12,21,16,21,16,22]],[3,[4,10,4,12,5,13,6,14,8,15,9,20,10,20,14,20,12,21]],[2,[3,6,3,10,4,10,4,10,6,11,8,15,9,15,12,15,8,20]],[1,[2,3,2,6,3,6,3,6,4,6,6,8,6,8,6,8,6,8]],[0,[1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]]]},{"id":"abdominal_plank","name":"Plancha isométrica","unit":"milliseconds","betterDirection":"higher","categoriesPerAgeBand":false,"rows":[[315000,[100,100,100,100,100,100,100,100,100]],[310000,[99,100,100,100,100,100,100,100,100]],[305000,[98,99,100,100,100,100,100,100,100]],[300000,[97,98,99,100,100,100,100,100,100]],[295000,[95,97,98,99,100,100,100,100,100]],[290000,[94,95,97,98,99,100,100,100,100]],[285000,[93,94,95,97,98,99,100,100,100]],[280000,[91,93,94,95,97,98,99,100,100]],[275000,[90,91,93,94,95,97,98,99,100]],[270000,[89,90,91,93,94,95,97,98,100]],[265000,[88,89,90,91,93,94,95,97,99]],[260000,[86,88,89,90,91,93,94,95,98]],[255000,[85,86,88,89,90,91,93,94,97]],[250000,[84,85,86,88,89,90,91,93,95]],[245000,[82,84,85,86,88,89,90,91,94]],[240000,[81,82,84,85,86,88,89,90,93]],[235000,[80,81,82,84,85,86,88,89,91]],[230000,[78,80,81,82,84,85,86,88,90]],[225000,[77,78,80,81,82,84,85,86,89]],[220000,[76,77,78,80,81,82,84,85,88]],[215000,[74,76,77,78,80,81,82,84,86]],[210000,[73,74,76,77,78,80,81,82,85]],[205000,[72,73,74,76,77,78,80,81,84]],[200000,[70,72,73,74,76,77,78,80,82]],[195000,[69,70,72,73,74,76,77,78,81]],[190000,[68,69,70,72,73,74,76,77,80]],[185000,[66,68,69,70,72,73,74,76,78]],[180000,[65,66,68,69,70,72,73,74,77]],[175000,[64,65,66,68,69,70,72,73,76]],[170000,[62,64,65,66,68,69,70,72,74]],[165000,[61,62,64,65,66,68,69,70,73]],[160000,[60,61,62,64,65,66,68,69,72]],[155000,[58,60,61,62,64,65,66,68,70]],[150000,[57,58,60,61,62,64,65,66,69]],[145000,[56,57,58,60,61,62,64,65,68]],[140000,[54,56,57,58,60,61,62,64,66]],[135000,[53,54,56,57,58,60,61,62,65]],[130000,[52,53,54,56,57,58,60,61,64]],[125000,[50,52,53,54,56,57,58,60,62]],[120000,[49,50,52,53,54,56,57,58,61]],[115000,[48,49,50,52,53,54,56,57,60]],[110000,[47,48,49,50,52,53,54,56,58]],[105000,[45,47,48,49,50,52,53,54,57]],[100000,[44,45,47,48,49,50,52,53,56]],[95000,[43,44,45,47,48,49,50,52,54]],[90000,[41,43,44,45,47,48,49,50,53]],[85000,[40,41,43,44,45,47,48,49,52]],[82000,[39,40,41,43,44,45,47,48,50]],[79000,[37,39,40,41,43,44,45,47,49]],[76000,[36,37,39,40,41,43,44,45,48]],[73000,[35,36,37,39,40,41,43,44,47]],[70000,[33,35,36,37,39,40,41,43,45]],[67000,[32,33,35,36,37,39,40,41,44]],[64000,[31,32,33,35,36,37,39,40,43]],[61000,[30,31,32,33,35,36,37,39,41]],[58000,[28,30,31,32,33,35,36,37,40]],[55000,[27,28,30,31,32,33,35,36,39]],[52000,[25,27,28,30,31,32,33,35,37]],[49000,[24,25,27,28,30,31,32,33,36]],[46000,[23,24,25,27,28,30,31,32,35]],[43000,[21,23,24,25,27,28,30,31,33]],[40000,[20,21,23,24,25,27,28,30,32]],[36000,[19,20,21,23,24,25,27,28,31]],[35000,[18,19,20,21,23,24,25,27,30]],[34000,[17,18,19,20,21,23,24,25,28]],[33000,[16,17,18,19,20,21,23,24,27]],[32000,[15,16,17,18,19,20,21,23,25]],[31000,[14,15,16,17,18,19,20,21,24]],[30000,[13,14,15,16,17,18,19,20,23]],[29000,[12,13,14,15,16,17,18,19,21]],[28000,[11,12,13,14,15,16,17,18,20]],[27000,[10,11,12,13,14,15,16,17,19]],[26000,[9,10,11,12,13,14,15,16,18]],[25000,[8,9,10,11,12,13,14,15,17]],[24000,[7,8,9,10,11,12,13,14,16]],[23000,[6,7,8,9,10,11,12,13,15]],[22000,[5,6,7,8,9,10,11,12,14]],[21000,[4,5,6,7,8,9,10,11,13]],[20000,[3,4,5,6,7,8,9,10,12]],[19000,[2,3,4,5,6,7,8,9,11]],[18000,[1,2,3,4,5,6,7,8,9]],[17000,[0,1,2,3,4,5,6,7,8]],[16000,[0,0,1,2,3,4,5,6,7]],[15000,[0,0,0,0,0,0,0,0,0]]]},{"id":"run_2000_m","name":"Carrera continua de 2.000 m","unit":"milliseconds","betterDirection":"lower","categoriesPerAgeBand":true,"rows":[[386000,[100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[394000,[98,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[402000,[96,100,98,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100]],[410000,[94,100,96,100,98,100,100,100,100,100,100,100,100,100,100,100,100,100]],[418000,[92,100,94,100,96,100,98,100,100,100,100,100,100,100,100,100,100,100]],[426000,[90,100,92,100,94,100,96,100,98,100,100,100,100,100,100,100,100,100]],[434000,[88,100,90,100,92,100,94,100,96,100,98,100,100,100,100,100,100,100]],[442000,[86,98,88,100,90,100,92,100,94,100,96,100,100,100,100,100,100,100]],[450000,[84,96,86,98,88,100,90,100,92,100,94,100,100,100,100,100,100,100]],[458000,[82,94,84,96,86,98,88,100,90,100,92,100,100,100,100,100,100,100]],[466000,[80,92,82,94,84,96,86,100,88,100,90,100,100,100,100,100,100,100]],[474000,[78,90,80,92,82,94,84,98,86,100,88,100,98,100,100,100,100,100]],[482000,[76,88,78,90,80,92,82,96,84,100,86,100,96,100,100,100,100,100]],[490000,[74,86,76,88,78,90,80,94,82,98,84,100,94,100,100,100,100,100]],[498000,[72,84,74,86,76,88,78,92,80,96,82,100,92,100,100,100,100,100]],[506000,[70,82,72,84,74,86,76,90,78,94,80,98,90,100,98,100,100,100]],[514000,[68,80,70,82,72,84,74,88,76,92,78,96,88,100,96,100,100,100]],[522000,[66,78,68,80,70,82,72,86,74,90,76,94,86,100,94,100,100,100]],[530000,[64,76,66,78,68,80,70,84,72,88,74,92,84,100,92,100,98,100]],[536000,[62,74,64,76,66,78,68,82,70,86,72,90,82,100,90,100,96,100]],[546000,[60,72,62,74,64,76,66,80,68,84,70,88,80,100,88,100,94,100]],[554000,[58,70,60,72,62,74,64,78,66,82,68,86,78,100,86,100,92,100]],[562000,[56,68,58,70,60,72,62,76,64,80,66,84,76,100,84,100,90,100]],[570000,[54,66,56,68,58,70,60,74,62,78,64,82,74,100,82,100,88,100]],[576000,[52,64,54,66,56,68,58,72,60,76,62,80,72,100,80,100,86,100]],[586000,[50,62,52,64,54,66,56,70,58,74,60,78,70,98,78,100,84,100]],[594000,[48,60,50,62,52,64,54,68,56,72,58,76,68,96,76,100,82,100]],[602000,[46,58,48,60,50,62,52,66,54,70,56,74,66,94,74,100,80,100]],[610000,[44,56,46,58,48,60,50,64,52,68,54,72,64,92,72,100,78,100]],[618000,[42,54,44,56,46,58,48,62,50,66,52,70,62,90,70,98,76,100]],[626000,[40,52,42,54,44,56,46,60,48,64,50,68,60,88,68,96,74,100]],[634000,[38,50,40,52,42,54,44,58,46,62,48,66,58,86,66,94,72,98]],[642000,[36,48,38,50,40,52,42,56,44,60,46,64,56,84,64,92,70,96]],[650000,[34,46,36,48,38,50,40,54,42,58,44,62,54,82,62,90,68,94]],[656000,[32,44,34,46,36,48,38,52,40,56,42,60,52,80,60,88,66,92]],[666000,[30,42,32,44,34,46,36,50,38,54,40,58,50,78,58,86,64,90]],[674000,[28,40,30,42,32,44,34,48,36,52,38,56,48,76,56,84,62,88]],[682000,[26,38,28,40,30,42,32,46,34,50,36,54,46,74,54,82,60,86]],[690000,[24,36,26,38,28,40,30,44,32,48,34,52,44,72,52,80,58,84]],[698000,[22,34,24,36,26,38,28,42,30,46,32,50,42,70,50,78,56,82]],[706000,[20,32,22,34,24,36,26,40,28,44,30,48,40,68,48,76,54,80]],[714000,[19,30,20,32,22,34,24,38,26,42,28,46,38,66,46,74,52,78]],[722000,[18,28,19,30,20,32,22,36,24,40,26,44,36,64,44,72,50,76]],[730000,[17,26,18,28,19,30,20,34,22,38,24,42,34,62,42,70,48,74]],[738000,[16,24,17,26,18,28,19,32,20,36,22,40,32,60,40,68,46,72]],[746000,[15,22,16,24,17,26,18,30,19,34,20,38,30,58,38,66,44,70]],[754000,[14,20,15,22,16,24,17,28,18,32,20,36,28,56,36,64,42,68]],[762000,[13,19,14,20,15,22,16,26,17,30,19,34,26,54,34,62,40,66]],[770000,[12,18,13,19,14,20,15,24,16,28,18,32,24,52,32,60,38,64]],[778000,[11,17,12,18,13,19,14,22,15,26,17,30,22,50,30,58,36,62]],[786000,[10,16,11,17,12,18,13,20,14,24,16,28,20,48,28,56,34,60]],[794000,[9,15,10,16,11,17,12,19,13,22,15,26,20,46,26,54,32,58]],[802000,[8,14,9,15,10,16,11,18,12,20,14,24,19,44,24,52,30,56]],[810000,[7,13,8,14,9,15,10,17,11,19,13,22,18,42,22,50,28,54]],[818000,[6,12,7,13,8,14,9,16,10,18,12,20,17,40,20,48,26,52]],[826000,[5,11,6,12,7,13,8,15,9,17,11,19,16,38,20,46,24,50]],[834000,[4,10,5,11,6,12,7,14,8,16,10,18,15,36,19,44,22,48]],[842000,[3,9,4,10,5,11,6,13,7,15,9,17,14,34,18,42,20,46]],[850000,[2,8,3,9,4,10,5,12,6,14,8,16,13,32,17,40,19,44]],[858000,[1,7,2,8,3,9,4,11,5,13,7,15,12,30,16,38,18,42]],[866000,[0,6,1,7,2,8,3,10,4,12,6,14,11,28,15,36,17,40]],[874000,[0,5,0,6,1,7,2,9,3,11,5,13,10,26,14,34,16,38]],[882000,[0,4,0,5,0,6,1,8,2,10,4,12,8,24,13,32,15,36]],[890000,[0,3,0,4,0,5,0,7,1,9,3,11,6,22,12,30,14,34]],[898000,[0,2,0,3,0,4,0,6,0,8,2,10,4,20,11,28,13,32]],[906000,[0,1,0,2,0,3,0,5,0,7,1,9,3,18,10,26,12,30]],[914000,[0,0,0,1,0,2,0,4,0,6,0,8,2,16,6,24,11,28]],[982000,[0,0,0,1,0,1,0,3,0,5,0,7,1,14,3,22,10,26]],[990000,[0,0,0,0,0,2,0,2,0,4,0,6,0,12,2,20,4,24]],[998000,[0,0,0,0,0,1,0,1,0,3,0,5,0,10,1,14,3,22]],[1006000,[0,0,0,0,0,0,0,1,0,2,0,4,0,4,0,6,2,20]],[1014000,[0,0,0,0,0,0,0,0,0,1,0,3,0,3,0,4,1,14]],[962000,[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]]]},{"id":"agility_speed_circuit","name":"Circuito de agilidad-velocidad","unit":"milliseconds","betterDirection":"lower","requiredBelowAge":45,"ageBands":["17_25","26_30","31_35","36_40","41_45"],"categoriesPerAgeBand":true,"rows":[[11600,[100,100,100,100,100,100,100,100,100,100]],[11700,[100,100,100,100,100,100,100,100,100,100]],[11800,[100,100,100,100,100,100,100,100,100,100]],[11900,[99,100,100,100,100,100,100,100,100,100]],[12000,[97,100,100,100,100,100,100,100,100,100]],[12100,[95,100,99,100,100,100,100,100,100,100]],[12200,[93,100,97,100,100,100,100,100,100,100]],[12300,[91,100,95,100,99,100,100,100,100,100]],[12400,[89,100,93,100,97,100,100,100,100,100]],[12500,[86,100,91,100,95,100,99,100,100,100]],[12600,[83,100,89,100,93,100,97,100,100,100]],[12700,[80,100,86,100,91,100,95,100,100,100]],[12800,[77,98,83,100,89,100,93,100,100,100]],[12900,[74,96,80,100,86,100,91,100,99,100]],[13000,[72,94,77,98,83,100,89,100,97,100]],[13100,[71,92,74,96,80,100,86,100,95,100]],[13200,[68,90,72,94,77,98,83,100,93,100]],[13300,[65,88,71,92,74,96,80,100,91,100]],[13400,[62,86,68,90,72,94,77,98,89,100]],[13500,[59,84,65,88,71,92,74,96,86,100]],[13600,[56,82,62,86,68,90,72,94,83,98]],[13700,[53,80,59,84,65,88,71,92,80,96]],[13800,[50,78,56,82,62,86,68,90,77,100]],[13900,[48,76,53,80,59,84,65,88,74,98]],[14000,[46,74,50,78,56,82,62,86,72,96]],[14100,[43,72,48,76,53,80,59,84,71,94]],[14200,[40,70,46,74,50,78,56,82,68,92]],[14300,[38,68,43,72,48,76,53,80,65,90]],[14400,[36,66,40,70,46,74,50,78,62,88]],[14500,[34,64,38,68,43,72,48,76,59,86]],[14600,[32,62,36,66,40,70,46,74,56,84]],[14700,[30,60,34,64,38,68,43,72,53,82]],[14800,[28,58,32,62,36,66,40,70,50,80]],[14900,[26,56,30,60,34,64,38,68,48,78]],[15000,[24,54,28,58,32,62,36,66,46,76]],[15100,[22,52,26,56,30,60,34,64,43,74]],[15200,[20,50,24,54,28,58,32,62,40,72]],[15300,[19,48,22,52,26,56,30,60,38,70]],[15400,[18,46,20,50,24,54,28,58,36,68]],[15500,[17,44,19,48,22,52,26,56,34,66]],[15600,[16,42,18,46,20,50,24,54,32,64]],[15700,[15,40,17,44,19,48,22,52,30,62]],[15800,[14,38,16,42,18,46,20,50,28,60]],[15900,[13,36,15,40,17,44,19,48,26,58]],[16000,[12,34,14,38,16,42,18,46,24,56]],[16100,[11,32,13,36,15,40,17,44,22,54]],[16200,[10,30,12,34,14,38,16,42,20,52]],[16300,[9,28,11,32,13,36,15,40,19,50]],[16400,[8,26,10,30,12,34,14,38,18,48]],[16500,[7,24,9,28,11,32,13,36,17,46]],[16600,[6,22,8,26,10,30,12,34,16,44]],[16700,[5,20,7,24,9,28,11,32,15,42]],[16800,[4,19,6,22,8,26,10,30,14,40]],[16900,[3,18,5,20,7,24,9,28,13,38]],[17000,[2,17,4,19,6,22,8,26,12,36]],[17100,[1,16,3,18,5,20,7,24,11,34]],[17200,[0,15,2,17,4,19,6,22,10,32]],[17300,[0,14,1,16,3,18,5,20,7,30]],[17400,[0,13,0,15,2,17,4,19,6,28]],[17500,[0,12,0,14,1,16,3,18,5,26]],[17600,[0,11,0,13,0,15,2,17,4,24]],[17700,[0,10,0,12,0,14,1,16,3,22]],[17800,[0,9,0,11,0,13,0,15,2,20]],[17900,[0,8,0,10,0,12,0,14,1,19]],[18000,[0,7,0,9,0,11,0,13,0,18]],[18100,[0,6,0,8,0,10,0,12,0,17]],[18200,[0,5,0,7,0,9,0,11,0,16]],[18300,[0,4,0,6,0,8,0,10,0,15]],[18400,[0,3,0,5,0,7,0,9,0,14]],[18500,[0,2,0,4,0,6,0,8,0,10]],[18600,[0,1,0,3,0,5,0,7,0,9]],[18700,[0,0,0,2,0,4,0,6,0,8]],[18800,[0,0,0,1,0,3,0,5,0,7]],[18900,[0,0,0,0,0,2,0,4,0,6]],[19000,[0,0,0,0,0,0,0,0,0,0]]]}],"schemaVersion":1,"name":"Evaluación periódica FAS · PAFAS/PAEF 2027","description":"Referencia completa de puntos por marca, sexo y edad, con mínimos de referencia de 20 puntos."}$fas_seed$::jsonb,
'es_def_15_2026_periodic_2027_v1','es_def_15_2026_periodic_2027_v2_full_scores','Definición original conservada.',clock_timestamp());
-- FAS_SEED_END

-- La calculadora conserva su referencia completa; los mínimos del servidor
-- siguen vinculados a la versión original, sin reconstruir los resultados.
insert into public.builtin_assessment_goal_revisions(goal_id,revision_id)
select g.id,r.id from public.preparation_goals g
join public.builtin_assessment_revisions r on r.program_id=g.program_id and r.revision=1;

create function builtin_assessment_private.require_admin() returns void
language plpgsql stable security invoker set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false)
    or (auth.jwt()->>'aal') is distinct from 'aal2' then
    raise exception 'Administración con segundo factor requerida.' using errcode='42501';
  end if;
end $$;

create function builtin_assessment_private.workspace(p_program_id text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform builtin_assessment_private.require_admin();
  if p_program_id not in ('armed_forces_troop_entry','fas_periodic_assessment') or p_program_id is null then
    raise exception 'Preparación integrada no disponible.' using errcode='22023'; end if;
  return jsonb_build_object('revisions',coalesce((select jsonb_agg(to_jsonb(r) order by revision desc)
    from public.builtin_assessment_revisions r where program_id=p_program_id),'[]'::jsonb),
    'current_revision_id',builtin_assessment_private.current_revision(p_program_id));
end $$;

create function builtin_assessment_private.create_revision(p_program_id text,p_base_id uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare b public.builtin_assessment_revisions; r public.builtin_assessment_revisions;
  receipt builtin_assessment_private.creation_requests; next_id uuid:=gen_random_uuid(); next_revision integer; v text;
begin
  perform builtin_assessment_private.require_admin();
  if p_request_id is null or p_base_id is null or p_program_id is null then raise exception 'Falta identificar la revisión.' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('builtin:'||p_program_id,0));
  select * into receipt from builtin_assessment_private.creation_requests where actor_id=auth.uid() and request_id=p_request_id;
  if found then
    if receipt.program_id<>p_program_id or receipt.base_id<>p_base_id then raise exception 'La solicitud ya tiene otro destino.' using errcode='40001'; end if;
    return (select to_jsonb(x) from public.builtin_assessment_revisions x where x.id=receipt.revision_id);
  end if;
  select * into b from public.builtin_assessment_revisions where id=p_base_id and program_id=p_program_id and status in ('published','withdrawn');
  if not found then raise exception 'La versión de origen no está disponible.' using errcode='22023'; end if;
  select max(revision)+1 into next_revision from public.builtin_assessment_revisions where program_id=p_program_id;
  v:='builtin_'||replace(next_id::text,'-','');
  insert into public.builtin_assessment_revisions(id,program_id,revision,status,base_id,definition,catalog_version,scoring_version)
  values(next_id,p_program_id,next_revision,'draft',b.id,jsonb_set(b.definition,'{version}',to_jsonb(v)),
    case when p_program_id='fas_periodic_assessment' then v||'_minimums' else v end,v) returning * into r;
  insert into builtin_assessment_private.creation_requests values(auth.uid(),p_request_id,p_program_id,b.id,r.id);
  insert into builtin_assessment_private.events(revision_id,actor_id,action,after_data) values(r.id,auth.uid(),'created',to_jsonb(r));
  return to_jsonb(r);
end $$;

create function builtin_assessment_private.save_revision(p_revision_id uuid,p_expected_edit_version integer,p_definition jsonb,p_change_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.builtin_assessment_revisions; previous jsonb; issues jsonb;
begin
  perform builtin_assessment_private.require_admin();
  select * into r from public.builtin_assessment_revisions where id=p_revision_id for update;
  if not found or r.status<>'draft' then raise exception 'El borrador no está disponible.' using errcode='22023'; end if;
  if p_expected_edit_version is distinct from r.edit_version then raise exception 'El borrador cambió. Recarga antes de guardar.' using errcode='40001'; end if;
  issues:=builtin_assessment_private.definition_issues(r.program_id,p_definition,r.scoring_version,false);
  if jsonb_array_length(issues)>0 then raise exception '%',issues->>0 using errcode='22023'; end if;
  if length(coalesce(p_change_reason,''))>2000 then raise exception 'El motivo debe ser un texto de hasta 2000 caracteres.' using errcode='22023'; end if;
  previous:=to_jsonb(r);
  update public.builtin_assessment_revisions set definition=p_definition,change_reason=btrim(coalesce(p_change_reason,'')),edit_version=edit_version+1
    where id=r.id returning * into r;
  insert into builtin_assessment_private.events(revision_id,actor_id,action,before_data,after_data) values(r.id,auth.uid(),'saved',previous,to_jsonb(r));
  return to_jsonb(r);
end $$;

create function builtin_assessment_private.change_count(p_before jsonb,p_after jsonb) returns integer
language plpgsql immutable security invoker set search_path='' as $$
declare n integer:=0; k text; i integer; j integer; c integer;
begin
  foreach k in array array['name','description','sourceUrl','effectiveFrom'] loop
    if p_before->k is distinct from p_after->k then n:=n+1; end if;
  end loop;
  if p_after->>'programId'='fas_periodic_assessment' then
    for i in 0..jsonb_array_length(p_after->'tests')-1 loop
      for j in 0..jsonb_array_length(p_after->'tests'->i->'rows')-1 loop
        for c in 0..jsonb_array_length(p_after->'tests'->i->'rows'->j->1)-1 loop
          if p_before->'tests'->i->'rows'->j->1->c is distinct from p_after->'tests'->i->'rows'->j->1->c then n:=n+1; end if;
        end loop;
      end loop;
    end loop;
  else
    for i in 0..jsonb_array_length(p_after->'standards')-1 loop
      if p_before->'standards'->i->'threshold' is distinct from p_after->'standards'->i->'threshold' then n:=n+1; end if;
    end loop;
  end if;
  return n;
end $$;

create function builtin_assessment_private.review_revision(p_revision_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.builtin_assessment_revisions; base jsonb; issues jsonb; warnings jsonb:='[]'; changes integer:=0;
begin
  perform builtin_assessment_private.require_admin();
  select * into r from public.builtin_assessment_revisions where id=p_revision_id;
  if not found then raise exception 'Revisión no disponible.' using errcode='22023'; end if;
  issues:=builtin_assessment_private.definition_issues(r.program_id,r.definition,r.scoring_version);
  if length(btrim(r.change_reason))<4 then issues:=issues||'"Explica el motivo del cambio antes de publicar."'::jsonb; end if;
  select definition into base from public.builtin_assessment_revisions where id=r.base_id;
  if base is not null and jsonb_array_length(issues)=0 then changes:=builtin_assessment_private.change_count(base,r.definition); end if;
  if r.program_id='fas_periodic_assessment' then
    warnings:=warnings||'"La tabla FAS original contiene anomalías literales documentadas. Las marcas de fila se conservan, sin corregirlas ni interpolarlas."'::jsonb;
  end if;
  if r.revision>1 and changes=0 then warnings:=warnings||'"No hay cambios de contenido respecto al origen."'::jsonb; end if;
  warnings:=warnings||'"Las pruebas, unidades, edades, protocolos y marcas de fila están bloqueados; esta revisión solo edita metadatos y valores de baremo."'::jsonb;
  return jsonb_build_object('issues',issues,'warnings',warnings,'change_count',changes,'existing_goals_preserved',
    (select count(*) from public.builtin_assessment_goal_revisions b join public.preparation_goals g on g.id=b.goal_id where g.program_id=r.program_id));
end $$;

create function builtin_assessment_private.preview_revision(p_revision_id uuid,p_category text,p_age integer,p_milestone text,p_marks jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.builtin_assessment_revisions;
begin
  perform builtin_assessment_private.require_admin();
  select * into r from public.builtin_assessment_revisions where id=p_revision_id;
  if not found then raise exception 'Revisión no disponible.' using errcode='22023'; end if;
  return builtin_assessment_private.preview_definition(r.definition,r.catalog_version,r.scoring_version,p_category,p_age,p_milestone,p_marks)
    ||jsonb_build_object('revision_id',r.id);
end $$;

create function builtin_assessment_private.publish_revision(p_revision_id uuid,p_expected_edit_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.builtin_assessment_revisions; previous jsonb; report jsonb; x jsonb; b jsonb; v_category text; marks jsonb; result jsonb;
begin
  perform builtin_assessment_private.require_admin();
  select * into r from public.builtin_assessment_revisions where id=p_revision_id for update;
  if not found then raise exception 'Borrador no disponible.' using errcode='22023'; end if;
  if r.status='published' and p_expected_edit_version in (r.edit_version,r.edit_version-1) then return to_jsonb(r); end if;
  if r.status<>'draft' then raise exception 'Esta revisión ya no es un borrador.' using errcode='22023'; end if;
  if p_expected_edit_version is distinct from r.edit_version then raise exception 'El borrador cambió. Revisa sus cambios antes de publicar.' using errcode='40001'; end if;
  perform pg_advisory_xact_lock(hashtextextended('builtin:'||r.program_id,0));
  report:=builtin_assessment_private.review_revision(r.id);
  if jsonb_array_length(report->'issues')>0 then raise exception '%',report->'issues'->>0 using errcode='22023'; end if;
  insert into public.assessment_catalogs(version,name,source_url,effective_from)
    values(r.catalog_version,r.definition->>'name',r.definition->>'sourceUrl',(r.definition->>'effectiveFrom')::date);
  if r.scoring_version<>r.catalog_version then
    insert into public.assessment_catalogs(version,name,source_url,effective_from)
      values(r.scoring_version,r.definition->>'name',r.definition->>'sourceUrl',(r.definition->>'effectiveFrom')::date);
  end if;
  if r.program_id='fas_periodic_assessment' then
    for b in select value from jsonb_array_elements(r.definition->'ageBands') loop
      select jsonb_agg(jsonb_build_object('test_id',t->>'id','value',0)) into marks
        from jsonb_array_elements(r.definition->'tests') t
        where t->>'requiredBelowAge' is null or (b->>'minAge')::integer < (t->>'requiredBelowAge')::integer;
      foreach v_category in array array['men','women'] loop
        result:=builtin_assessment_private.preview_definition(r.definition,r.catalog_version,r.scoring_version,v_category,(b->>'minAge')::integer,null,marks);
        for x in select value from jsonb_array_elements(result->'results') loop
          insert into public.fas_periodic_standards(catalog_version,test_id,age_band,category,threshold)
            values(r.catalog_version,x->>'test_id',b->>'id',v_category,(x->>'threshold')::bigint);
        end loop;
      end loop;
    end loop;
  else
    insert into public.assessment_standards(catalog_version,test_id,category,milestone,threshold)
      select r.catalog_version,entry->>'testId',entry->>'category',entry->>'group',(entry->>'threshold')::bigint
      from jsonb_array_elements(r.definition->'standards') entry;
  end if;
  -- El selector legado permanece en su semilla para clientes antiguos. Las
  -- nuevas altas usan current_revision; los motores leen el catálogo del intento.
  insert into public.preparation_program_catalogs(program_id,catalog_version,is_current) values(r.program_id,r.catalog_version,false);
  previous:=to_jsonb(r);
  update public.builtin_assessment_revisions set status='published',published_at=clock_timestamp(),edit_version=edit_version+1
    where id=r.id returning * into r;
  insert into builtin_assessment_private.events(revision_id,actor_id,action,before_data,after_data) values(r.id,auth.uid(),'published',previous,to_jsonb(r));
  return to_jsonb(r);
end $$;

create function builtin_assessment_private.withdraw_revision(p_revision_id uuid,p_expected_edit_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.builtin_assessment_revisions; previous jsonb;
begin
  perform builtin_assessment_private.require_admin();
  select * into r from public.builtin_assessment_revisions where id=p_revision_id for update;
  if not found then raise exception 'Revisión no disponible.' using errcode='22023'; end if;
  if r.status='withdrawn' and p_expected_edit_version in (r.edit_version,r.edit_version-1) then return to_jsonb(r); end if;
  if r.status<>'published' then raise exception 'Solo se puede retirar una revisión publicada.' using errcode='22023'; end if;
  if p_expected_edit_version is distinct from r.edit_version then raise exception 'La revisión cambió. Recarga antes de retirarla.' using errcode='40001'; end if;
  previous:=to_jsonb(r);
  update public.builtin_assessment_revisions set status='withdrawn',edit_version=edit_version+1 where id=r.id returning * into r;
  insert into builtin_assessment_private.events(revision_id,actor_id,action,before_data,after_data) values(r.id,auth.uid(),'withdrawn',previous,to_jsonb(r));
  return to_jsonb(r);
end $$;

create function builtin_assessment_private.current_revision(p_program_id text) returns uuid
language sql stable security definer set search_path='' as $$
  with published as materialized (select * from public.builtin_assessment_revisions where program_id=p_program_id and status='published')
  select r.id from published r
  where true
    and ((r.definition->>'effectiveFrom')::date <= (now() at time zone 'Europe/Madrid')::date or r.revision=1)
  order by ((r.definition->>'effectiveFrom')::date <= (now() at time zone 'Europe/Madrid')::date) desc,
    (r.definition->>'effectiveFrom')::date desc,r.revision desc limit 1
$$;

create function builtin_assessment_private.bind_goal() returns trigger
language plpgsql security definer set search_path='' as $$
declare selected uuid;
begin
  if new.program_id not in ('armed_forces_troop_entry','fas_periodic_assessment') then return new; end if;
  selected:=builtin_assessment_private.current_revision(new.program_id);
  if selected is null then raise exception 'Esta preparación no tiene un baremo publicado disponible.' using errcode='22023'; end if;
  insert into public.builtin_assessment_goal_revisions(goal_id,revision_id) values(new.id,selected);
  return new;
end $$;
create trigger builtin_goal_revision_insert after insert on public.preparation_goals
for each row execute function builtin_assessment_private.bind_goal();

create function builtin_assessment_private.guard_binding() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if TG_OP='UPDATE' then
    if new.goal_id is distinct from old.goal_id or new.revision_id is distinct from old.revision_id then
      raise exception 'La versión de una preparación no puede cambiar silenciosamente.' using errcode='22023';
    end if;
  end if;
  if not exists(select 1 from public.preparation_goals g join public.builtin_assessment_revisions r on r.program_id=g.program_id
    where g.id=new.goal_id and r.id=new.revision_id and r.status in ('published','withdrawn')) then
    raise exception 'El vínculo no corresponde a una revisión publicada de esta preparación.' using errcode='22023';
  end if;
  return new;
end $$;
create trigger builtin_goal_revision_update before insert or update on public.builtin_assessment_goal_revisions
for each row execute function builtin_assessment_private.guard_binding();

-- Extrae la estructura protegida, dejando editables únicamente metadatos y
-- valores. Las marcas de fila FAS son su identidad, no una interpolación.
create function builtin_assessment_private.structure(p_definition jsonb) returns jsonb
language plpgsql immutable security invoker set search_path='' as $$
declare d jsonb:=p_definition-array['version','name','description','sourceUrl','effectiveFrom']; t jsonb; tests jsonb:='[]'; rows jsonb; r jsonb;
begin
  if d->>'programId'='fas_periodic_assessment' then
    for t in select value from jsonb_array_elements(d->'tests') loop
      rows:='[]';
      for r in select value from jsonb_array_elements(t->'rows') loop
        rows:=rows||jsonb_build_array(jsonb_build_array(r->0,jsonb_array_length(r->1)));
      end loop;
      tests:=tests||jsonb_build_array(jsonb_set(t,'{rows}',rows));
    end loop;
    return jsonb_set(d,'{tests}',tests);
  end if;
  return jsonb_set(d,'{standards}',(select jsonb_agg(value-'threshold') from jsonb_array_elements(d->'standards')));
end $$;

create function builtin_assessment_private.definition_issues(p_program_id text,p_definition jsonb,p_scoring_version text,p_for_publication boolean default true)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare seed jsonb; issues jsonb:='[]'; t jsonb; r jsonb; v jsonb; threshold numeric; dummy_date date; seed_test jsonb; column_index integer;
begin
  select definition into seed from public.builtin_assessment_revisions where program_id=p_program_id and revision=1;
  if seed is null or p_definition is null or jsonb_typeof(p_definition) is distinct from 'object'
    or octet_length(p_definition::text)>=262144 then return '["Definición vacía o incompatible."]'::jsonb; end if;
  if p_definition->>'programId' is distinct from p_program_id or p_definition->>'version' is distinct from p_scoring_version
    or builtin_assessment_private.structure(p_definition) is distinct from builtin_assessment_private.structure(seed) then
    return '["La estructura, pruebas, unidades, edades, protocolos y marcas de fila están protegidos en esta primera versión."]'::jsonb;
  end if;
  if jsonb_typeof(p_definition->'name') is distinct from 'string' or jsonb_typeof(p_definition->'description') is distinct from 'string'
    or jsonb_typeof(p_definition->'sourceUrl') is distinct from 'string' or jsonb_typeof(p_definition->'effectiveFrom') is distinct from 'string' then
    return '["Los metadatos deben ser textos, aunque todavía estén incompletos."]'::jsonb;
  end if;
  if p_for_publication then
  if jsonb_typeof(p_definition->'name') is distinct from 'string' or length(btrim(p_definition->>'name')) not between 1 and 180 then
    issues:=issues||'"Indica un nombre de entre 1 y 180 caracteres."'::jsonb; end if;
  if jsonb_typeof(p_definition->'description') is distinct from 'string' or length(p_definition->>'description')>6000 then
    issues:=issues||'"La descripción debe ser un texto de hasta 6000 caracteres."'::jsonb; end if;
  if jsonb_typeof(p_definition->'sourceUrl') is distinct from 'string' or length(p_definition->>'sourceUrl')>2048
    or (p_definition->>'sourceUrl') !~ '^https://[^[:space:]/]+(/[^[:space:]]*)?$' then
    issues:=issues||'"Indica una fuente HTTPS válida."'::jsonb; end if;
  if jsonb_typeof(p_definition->'effectiveFrom') is distinct from 'string' or (p_definition->>'effectiveFrom') !~ '^\d{4}-\d{2}-\d{2}$' then
    issues:=issues||'"Indica una fecha de vigencia válida."'::jsonb;
  else
    begin dummy_date:=(p_definition->>'effectiveFrom')::date;
    exception when others then issues:=issues||'"La fecha de vigencia no existe."'::jsonb; end;
  end if;
  end if;
  if p_program_id='fas_periodic_assessment' then
    for t in select value from jsonb_array_elements(p_definition->'tests') loop
      for r in select value from jsonb_array_elements(t->'rows') loop
        for v in select value from jsonb_array_elements(r->1) loop
          if jsonb_typeof(v) is distinct from 'number' or v::text !~ '^\d+$' or v::numeric not between 0 and 100 then
            return issues||'"Cada puntuación FAS debe ser un entero entre 0 y 100."'::jsonb;
          end if;
        end loop;
      end loop;
      -- Se toleran únicamente pares anómalos que conservan ambos valores
      -- originales. Una edición no puede introducir o modificar incoherencias.
      if p_for_publication then
        select value into seed_test from jsonb_array_elements(seed->'tests') where value->>'id'=t->>'id';
        for column_index in 0..jsonb_array_length(t->'rows'->0->1)-1 loop
          if exists(
            with cells as (select (x.value->>0)::bigint as mark,(x.value->1->>column_index)::integer as points,
              (seed_test->'rows'->(x.ordinality::integer-1)->1->>column_index)::integer as original
              from jsonb_array_elements(t->'rows') with ordinality x(value,ordinality)),
            pairs as (select *,lag(points) over(order by mark) as previous,
              lag(original) over(order by mark) as previous_original from cells)
            select 1 from pairs where previous is not null and
              (case when t->>'betterDirection'='higher' then points<previous else points>previous end)
              and (points<>original or previous<>previous_original)
          ) then
            issues:=issues||jsonb_build_array(format('%s: la edición introduce una incoherencia entre marca y puntos.',t->>'name'));
            exit;
          end if;
        end loop;
      end if;
      -- Cada columna conserva al menos un mínimo alcanzable.
      for threshold in select generate_series(0,jsonb_array_length(t->'rows'->0->1)-1) loop
        if not exists(select 1 from jsonb_array_elements(t->'rows') x
          where (x->1->>(threshold::integer))::integer >= (p_definition->>'minimumPointsPerTest')::integer) then
          issues:=issues||jsonb_build_array(format('%s: falta un mínimo alcanzable en alguna columna.',t->>'name'));
          exit;
        end if;
      end loop;
    end loop;
  else
    for r in select value from jsonb_array_elements(p_definition->'standards') loop
      if jsonb_typeof(r->'threshold') is distinct from 'number' or (r->>'threshold') !~ '^\d+$'
        or (r->>'threshold')::numeric>9223372036854775807 then
        issues:=issues||'"Cada mínimo de Tropa debe ser un entero no negativo válido."'::jsonb; exit;
      end if;
    end loop;
  end if;
  return issues;
exception when others then
  return '["El formato de la definición no es compatible con el catálogo original."]'::jsonb;
end $$;

create function builtin_assessment_private.preview_definition(p_definition jsonb,p_catalog_version text,p_scoring_version text,
  p_category text,p_age integer,p_milestone text,p_marks jsonb) returns jsonb
language plpgsql immutable security invoker set search_path='' as $$
declare fas boolean:=p_definition->>'programId'='fas_periodic_assessment'; t jsonb; s jsonb; r jsonb; band jsonb;
  results jsonb:='[]'; mark bigint; scored bigint; threshold bigint; points integer; col integer; idx integer;
  expected integer:=0; count_marks integer; distinct_marks integer; valid_marks boolean; limit_age integer;
begin
  if p_category is null or p_category not in ('men','women') or jsonb_typeof(p_marks) is distinct from 'array' then
    raise exception 'Indica sexo y una lista válida de marcas.' using errcode='22023'; end if;
  if fas then
    if p_age is null or p_age not between 17 and 120 then raise exception 'Edad fuera del baremo.' using errcode='22023'; end if;
    select value into band from jsonb_array_elements(p_definition->'ageBands') where
      p_age >= (value->>'minAge')::integer and (value->>'maxAge' is null or p_age <= (value->>'maxAge')::integer);
    if band is null then raise exception 'No hay un tramo de edad válido.' using errcode='22023'; end if;
  elsif p_milestone is null or p_milestone not in ('entry','end_of_general_military_training','end_of_training') then
    raise exception 'Indica el hito de Tropa.' using errcode='22023';
  end if;
  select count(*),count(distinct x->>'test_id'),coalesce(bool_and(jsonb_typeof(x->'value')='number'
    and (x->>'value') ~ '^\d+$' and (x->>'value')::numeric<=9223372036854775807),false)
    into count_marks,distinct_marks,valid_marks from jsonb_array_elements(p_marks) x;
  if not valid_marks or count_marks<>distinct_marks then raise exception 'Las marcas deben ser enteros no negativos únicos.' using errcode='22023'; end if;
  for t in select value from jsonb_array_elements(p_definition->'tests') loop
    limit_age:=(t->>'requiredBelowAge')::integer;
    if fas and limit_age is not null and p_age>=limit_age then continue; end if;
    expected:=expected+1;
    select (x->>'value')::bigint into mark from jsonb_array_elements(p_marks) x where x->>'test_id'=t->>'id';
    if mark is null then raise exception 'Falta una marca de %.',t->>'name' using errcode='22023'; end if;
    scored:=mark; points:=null;
    if fas then
      select ordinality::integer-1 into idx from jsonb_array_elements(
        coalesce(t->'ageBands',(select jsonb_agg(b->'id') from jsonb_array_elements(p_definition->'ageBands') b))) with ordinality
        where value=band->'id';
      if idx is null then raise exception 'Prueba ajena al tramo de edad.' using errcode='22023'; end if;
      col:=case when (t->>'categoriesPerAgeBand')::boolean then idx*2+case when p_category='men' then 0 else 1 end else idx end;
      if t->>'id'='agility_speed_circuit' then scored:=mark-(mark%100); end if;
      select coalesce(max((x->1->>col)::integer),0) into points from jsonb_array_elements(t->'rows') x
        where case when t->>'betterDirection'='higher' then scored >= (x->>0)::bigint else scored <= (x->>0)::bigint end;
      select case when t->>'betterDirection'='higher' then min((x->>0)::bigint) else max((x->>0)::bigint) end into threshold
        from jsonb_array_elements(t->'rows') x where (x->1->>col)::integer >= (p_definition->>'minimumPointsPerTest')::integer;
    else
      select value into s from jsonb_array_elements(p_definition->'standards') where
        value->>'testId'=t->>'id' and value->>'category'=p_category and value->>'group'=p_milestone;
      threshold:=(s->>'threshold')::bigint;
    end if;
    if threshold is null then raise exception 'Falta un mínimo para %.',t->>'name' using errcode='22023'; end if;
    results:=results||jsonb_build_array(jsonb_build_object('test_id',t->>'id','name',t->>'name','unit',t->>'unit',
      'direction',t->>'betterDirection','mark',mark,'scored_mark',scored,'threshold',threshold,'points',points,
      'meets_minimum',case when fas then points >= (p_definition->>'minimumPointsPerTest')::integer
        when t->>'betterDirection'='higher' then mark>=threshold else mark<=threshold end));
  end loop;
  if count_marks<>expected or expected=0 then raise exception 'Hay marcas incompletas o ajenas al baremo.' using errcode='22023'; end if;
  return jsonb_build_object('results',results,'meets_all_minimums',(select bool_and((x->>'meets_minimum')::boolean) from jsonb_array_elements(results) x),
    'catalog_version',p_catalog_version,'scoring_version',p_scoring_version);
end $$;

create function builtin_assessment_private.reference(p_program_id text,p_goal_id uuid,p_revision_id uuid,p_scoring_version text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare selected uuid; r public.builtin_assessment_revisions;
begin
  if p_program_id is null or p_program_id not in ('fas_periodic_assessment','armed_forces_troop_entry') then
    raise exception 'Preparación integrada no disponible.' using errcode='22023'; end if;
  if p_goal_id is not null then
    select b.revision_id into selected from public.builtin_assessment_goal_revisions b join public.preparation_goals g on g.id=b.goal_id
      where b.goal_id=p_goal_id and g.user_id=auth.uid() and g.program_id=p_program_id;
    if not found then raise exception 'Preparación no disponible para esta cuenta.' using errcode='42501'; end if;
    if p_revision_id is not null and p_revision_id<>selected then raise exception 'La revisión no corresponde a la preparación.' using errcode='22023'; end if;
  elsif p_revision_id is not null then selected:=p_revision_id;
  elsif p_scoring_version is not null then
    select id into selected from public.builtin_assessment_revisions where program_id=p_program_id and scoring_version=p_scoring_version;
  else selected:=builtin_assessment_private.current_revision(p_program_id);
  end if;
  select * into r from public.builtin_assessment_revisions where id=selected and program_id=p_program_id and status in ('published','withdrawn');
  if not found then raise exception 'No hay una versión publicada compatible.' using errcode='22023'; end if;
  if p_scoring_version is not null and p_scoring_version<>r.scoring_version then raise exception 'La puntuación no corresponde a esta revisión.' using errcode='22023'; end if;
  return to_jsonb(r);
end $$;

alter table public.fas_periodic_assessments add column result_snapshot jsonb;

create function builtin_assessment_private.record_assessment(p_revision_id uuid,p_goal_id uuid,p_category text,p_age integer,
  p_milestone text,p_marks jsonb,p_completed_at timestamptz) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.builtin_assessment_revisions; g public.preparation_goals; result jsonb; assessment_id uuid; age_band text;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para guardar una evaluación.' using errcode='42501'; end if;
  select * into r from public.builtin_assessment_revisions where id=p_revision_id and status in ('published','withdrawn') for share;
  if not found then raise exception 'Baremo publicado no disponible.' using errcode='22023'; end if;
  if p_completed_at is null or p_completed_at>now()+interval '5 minutes' or p_completed_at<date '2026-01-21' then
    raise exception 'Fecha de evaluación no válida.' using errcode='22023'; end if;
  if p_goal_id is not null then
    select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and program_id=r.program_id and status='active' for share;
    if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
    if not exists(select 1 from public.builtin_assessment_goal_revisions where goal_id=g.id and revision_id=r.id) then
      raise exception 'El baremo cambió. Vuelve a abrir la evaluación de tu preparación.' using errcode='22023'; end if;
    if r.program_id='armed_forces_troop_entry' and p_milestone is distinct from 'entry' then
      raise exception 'La preparación de ingreso utiliza su propio hito.' using errcode='22023'; end if;
  elsif r.status<>'published' or r.id is distinct from builtin_assessment_private.current_revision(r.program_id) then
    raise exception 'La calculadora tiene otra versión publicada. Recarga antes de guardar.'
      using errcode='22023',detail='builtin_reference_changed';
  end if;
  result:=builtin_assessment_private.preview_definition(r.definition,r.catalog_version,r.scoring_version,p_category,p_age,p_milestone,p_marks)
    ||jsonb_build_object('revision_id',r.id);
  if r.program_id='fas_periodic_assessment' then
    select value->>'id' into age_band from jsonb_array_elements(r.definition->'ageBands') where
      p_age>=(value->>'minAge')::integer and (value->>'maxAge' is null or p_age<=(value->>'maxAge')::integer);
    -- El disparador de edad existente contrasta nacimiento y fecha de la prueba.
    insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,scoring_version,category,
      age_at_assessment,age_band,completed_at,is_pre_effective_reference,result_snapshot)
    values(auth.uid(),p_goal_id,r.catalog_version,r.scoring_version,p_category,p_age,age_band,p_completed_at,
      (p_completed_at at time zone 'Europe/Madrid')::date < (r.definition->>'effectiveFrom')::date,result)
    returning id into assessment_id;
    insert into public.fas_periodic_marks(assessment_id,test_id,value)
      select assessment_id,x->>'test_id',(x->>'value')::bigint from jsonb_array_elements(p_marks) x;
  else
    insert into public.physical_assessments(user_id,preparation_goal_id,catalog_version,category,milestone,completed_at)
      values(auth.uid(),p_goal_id,r.catalog_version,p_category,p_milestone,p_completed_at) returning id into assessment_id;
    insert into public.physical_assessment_marks(assessment_id,test_id,value)
      select assessment_id,x->>'test_id',(x->>'value')::bigint from jsonb_array_elements(p_marks) x;
  end if;
  return assessment_id;
end $$;

-- Las columnas previas conservan orden/tipos. El snapshot solo se aplica a
-- intentos nuevos que pasaron la validación de record_builtin_assessment.
create or replace view public.fas_periodic_results with (security_invoker=true) as
select a.id as assessment_id,a.user_id,a.preparation_goal_id,a.catalog_version,a.category,a.age_at_assessment,a.age_band,
  a.completed_at,a.is_pre_effective_reference,m.test_id,t.name as test_name,t.unit,t.better_direction,m.value,
  coalesce((snapshot.value->>'threshold')::bigint,s.threshold) as threshold,
  coalesce((snapshot.value->>'meets_minimum')::boolean,case t.better_direction when 'higher' then m.value>=s.threshold
    when 'lower' then m.value<=s.threshold end) as meets_minimum,a.scoring_version,a.result_snapshot
from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id
join public.fas_periodic_standards s on s.catalog_version=a.catalog_version and s.age_band=a.age_band and s.category=a.category and s.test_id=m.test_id
join public.physical_test_definitions t on t.id=m.test_id
left join lateral (select value from jsonb_array_elements(a.result_snapshot->'results') where value->>'test_id'=m.test_id) snapshot on true;

create function builtin_assessment_private.guard_assessment_binding() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.builtin_assessment_revisions;
begin
  if new.preparation_goal_id is null then return new; end if;
  select br.* into r from public.builtin_assessment_goal_revisions b join public.builtin_assessment_revisions br on br.id=b.revision_id
    where b.goal_id=new.preparation_goal_id;
  if found then
    if r.catalog_version is distinct from new.catalog_version then raise exception 'El intento y la preparación usan distintas versiones.' using errcode='22023'; end if;
    if TG_TABLE_NAME='fas_periodic_assessments' then
      if r.scoring_version is distinct from new.scoring_version then
        raise exception 'La puntuación no corresponde a esta preparación.' using errcode='22023'; end if;
    end if;
  end if;
  return new;
end $$;
create trigger builtin_fas_assessment_binding before insert or update of preparation_goal_id,catalog_version,scoring_version on public.fas_periodic_assessments
for each row execute function builtin_assessment_private.guard_assessment_binding();
create trigger builtin_troop_assessment_binding before insert or update of preparation_goal_id,catalog_version on public.physical_assessments
for each row execute function builtin_assessment_private.guard_assessment_binding();

-- Se conservan los registradores anteriores como implementación privada. Los
-- clientes antiguos solo pueden registrar la semilla, nunca puntuar una revisión
-- nueva con sus tablas locales antiguas.
alter function public.record_physical_assessment(text,text,text,jsonb,timestamptz) set schema builtin_assessment_private;
alter function public.record_fas_periodic_assessment(uuid,text,integer,jsonb,timestamptz) set schema builtin_assessment_private;

create function builtin_assessment_private.require_legacy(p_program_id text,p_goal_id uuid) returns void
language plpgsql stable security definer set search_path='' as $$
declare selected uuid; version_number integer;
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  if p_goal_id is null then selected:=builtin_assessment_private.current_revision(p_program_id);
  else
    select b.revision_id into selected from public.builtin_assessment_goal_revisions b join public.preparation_goals g on g.id=b.goal_id
      where g.id=p_goal_id and g.user_id=auth.uid() and g.program_id=p_program_id and g.status='active';
    if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
  end if;
  select revision into version_number from public.builtin_assessment_revisions where id=selected;
  if version_number is distinct from 1 then
    raise exception 'Esta preparación utiliza un baremo nuevo. Actualiza la aplicación antes de registrar marcas.' using errcode='22023'; end if;
end $$;

create function builtin_assessment_private.record_legacy_troop(p_goal_id uuid,p_catalog_version text,p_category text,p_marks jsonb,p_completed_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare assessment_id uuid;
begin
  if p_goal_id is null then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
  perform builtin_assessment_private.require_legacy('armed_forces_troop_entry',p_goal_id);
  if p_catalog_version is distinct from 'es_def_15_2026_troop_v1' then raise exception 'Baremo incompatible con este cliente.' using errcode='22023'; end if;
  assessment_id:=builtin_assessment_private.record_physical_assessment(p_catalog_version,p_category,'entry',p_marks,p_completed_at);
  update public.physical_assessments set preparation_goal_id=p_goal_id where id=assessment_id;
  return assessment_id;
end $$;
create function builtin_assessment_private.record_legacy_global(p_catalog_version text,p_category text,p_milestone text,p_marks jsonb,p_completed_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
begin
  perform builtin_assessment_private.require_legacy('armed_forces_troop_entry',null);
  if p_catalog_version is distinct from 'es_def_15_2026_troop_v1' then raise exception 'Baremo incompatible con este cliente.' using errcode='22023'; end if;
  return builtin_assessment_private.record_physical_assessment(p_catalog_version,p_category,p_milestone,p_marks,p_completed_at);
end $$;
create function builtin_assessment_private.record_legacy_fas(p_preparation_goal_id uuid,p_category text,p_age integer,p_marks jsonb,p_completed_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
begin
  perform builtin_assessment_private.require_legacy('fas_periodic_assessment',p_preparation_goal_id);
  return builtin_assessment_private.record_fas_periodic_assessment(p_preparation_goal_id,p_category,p_age,p_marks,p_completed_at);
end $$;

create function builtin_assessment_private.guard_revision() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.status<>'draft' then
    if TG_OP='DELETE' then raise exception 'Las versiones publicadas conservan su historial.' using errcode='22023'; end if;
    if (to_jsonb(new)-array['status','edit_version']) is distinct from (to_jsonb(old)-array['status','edit_version'])
      or old.status<>'published' or new.status<>'withdrawn' or new.edit_version<>old.edit_version+1 then
      raise exception 'Una versión publicada no se sobrescribe. Crea una revisión.' using errcode='22023'; end if;
  end if;
  return case when TG_OP='DELETE' then old else new end;
end $$;
create trigger builtin_revision_immutable before update or delete on public.builtin_assessment_revisions
for each row execute function builtin_assessment_private.guard_revision();

create function builtin_assessment_private.guard_native_definition() returns trigger
language plpgsql security definer set search_path='' as $$
declare row_data jsonb:=case when TG_OP='INSERT' then to_jsonb(new) else to_jsonb(old) end; version text;
begin
  if TG_TABLE_NAME='physical_test_definitions' then
    if exists(select 1 from public.builtin_assessment_revisions r,jsonb_array_elements(r.definition->'tests') t
      where r.revision=1 and t->>'id'=row_data->>'id') then
      raise exception 'La identidad y unidad de estas pruebas forman parte del historial.' using errcode='22023'; end if;
  else
    version:=coalesce(row_data->>'catalog_version',row_data->>'version');
    if exists(select 1 from public.builtin_assessment_revisions r where r.status in ('published','withdrawn')
      and (r.catalog_version=version or r.scoring_version=version
        or (TG_OP='UPDATE' and (r.catalog_version=coalesce(to_jsonb(new)->>'catalog_version',to_jsonb(new)->>'version')
          or r.scoring_version=coalesce(to_jsonb(new)->>'catalog_version',to_jsonb(new)->>'version'))))) then
      raise exception 'Los baremos publicados son inmutables.' using errcode='22023'; end if;
  end if;
  return case when TG_OP='DELETE' then old else new end;
end $$;
create trigger builtin_catalog_immutable before update or delete on public.assessment_catalogs
for each row execute function builtin_assessment_private.guard_native_definition();
create trigger builtin_troop_standards_immutable before insert or update or delete on public.assessment_standards
for each row execute function builtin_assessment_private.guard_native_definition();
create trigger builtin_fas_standards_immutable before insert or update or delete on public.fas_periodic_standards
for each row execute function builtin_assessment_private.guard_native_definition();
create trigger builtin_test_identity_immutable before update or delete on public.physical_test_definitions
for each row execute function builtin_assessment_private.guard_native_definition();

create function builtin_assessment_private.guard_goal_identity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.program_id is distinct from old.program_id and
    (old.program_id in ('armed_forces_troop_entry','fas_periodic_assessment') or new.program_id in ('armed_forces_troop_entry','fas_periodic_assessment')) then
    raise exception 'Crea otra preparación para cambiar de programa; esta conserva su historial.' using errcode='22023'; end if;
  return new;
end $$;
create trigger builtin_goal_identity before update of program_id on public.preparation_goals
for each row execute function builtin_assessment_private.guard_goal_identity();

create function public.admin_builtin_assessment_workspace(p_program_id text) returns jsonb
language sql stable security invoker set search_path='' as $$select builtin_assessment_private.workspace(p_program_id)$$;
create function public.admin_builtin_assessment_create_revision(p_program_id text,p_base_id uuid,p_request_id uuid) returns jsonb
language sql security invoker set search_path='' as $$select builtin_assessment_private.create_revision(p_program_id,p_base_id,p_request_id)$$;
create function public.admin_builtin_assessment_save(p_revision_id uuid,p_expected_edit_version integer,p_definition jsonb,p_change_reason text) returns jsonb
language sql security invoker set search_path='' as $$select builtin_assessment_private.save_revision(p_revision_id,p_expected_edit_version,p_definition,p_change_reason)$$;
create function public.admin_builtin_assessment_review(p_revision_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select builtin_assessment_private.review_revision(p_revision_id)$$;
create function public.admin_builtin_assessment_preview(p_revision_id uuid,p_category text,p_age integer,p_milestone text,p_marks jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$select builtin_assessment_private.preview_revision(p_revision_id,p_category,p_age,p_milestone,p_marks)$$;
create function public.admin_builtin_assessment_publish(p_revision_id uuid,p_expected_edit_version integer) returns jsonb
language sql security invoker set search_path='' as $$select builtin_assessment_private.publish_revision(p_revision_id,p_expected_edit_version)$$;
create function public.admin_builtin_assessment_withdraw(p_revision_id uuid,p_expected_edit_version integer) returns jsonb
language sql security invoker set search_path='' as $$select builtin_assessment_private.withdraw_revision(p_revision_id,p_expected_edit_version)$$;
create function public.builtin_assessment_reference(p_program_id text,p_goal_id uuid default null,p_revision_id uuid default null,p_scoring_version text default null) returns jsonb
language sql stable security invoker set search_path='' as $$select builtin_assessment_private.reference(p_program_id,p_goal_id,p_revision_id,p_scoring_version)$$;
create function public.record_builtin_assessment(p_revision_id uuid,p_goal_id uuid,p_category text,p_age integer,p_milestone text,p_marks jsonb,p_completed_at timestamptz default now()) returns uuid
language sql security invoker set search_path='' as $$select builtin_assessment_private.record_assessment(p_revision_id,p_goal_id,p_category,p_age,p_milestone,p_marks,p_completed_at)$$;
create function public.record_physical_assessment(p_catalog_version text,p_category text,p_milestone text,p_marks jsonb,p_completed_at timestamptz default now()) returns uuid
language sql security invoker set search_path='' as $$select builtin_assessment_private.record_legacy_global(p_catalog_version,p_category,p_milestone,p_marks,p_completed_at)$$;
create function public.record_fas_periodic_assessment(p_preparation_goal_id uuid,p_category text,p_age integer,p_marks jsonb,p_completed_at timestamptz default now()) returns uuid
language sql security invoker set search_path='' as $$select builtin_assessment_private.record_legacy_fas(p_preparation_goal_id,p_category,p_age,p_marks,p_completed_at)$$;
create or replace function public.record_troop_goal_assessment(p_goal_id uuid,p_catalog_version text,p_category text,p_marks jsonb,p_completed_at timestamptz default now()) returns uuid
language sql security invoker set search_path='' as $$select builtin_assessment_private.record_legacy_troop(p_goal_id,p_catalog_version,p_category,p_marks,p_completed_at)$$;

revoke all on all functions in schema builtin_assessment_private from public,anon,authenticated;
grant execute on function builtin_assessment_private.workspace(text),builtin_assessment_private.create_revision(text,uuid,uuid),
  builtin_assessment_private.save_revision(uuid,integer,jsonb,text),builtin_assessment_private.review_revision(uuid),
  builtin_assessment_private.preview_revision(uuid,text,integer,text,jsonb),builtin_assessment_private.publish_revision(uuid,integer),
  builtin_assessment_private.withdraw_revision(uuid,integer),builtin_assessment_private.record_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz),
  builtin_assessment_private.record_legacy_global(text,text,text,jsonb,timestamptz),builtin_assessment_private.record_legacy_troop(uuid,text,text,jsonb,timestamptz),
  builtin_assessment_private.record_legacy_fas(uuid,text,integer,jsonb,timestamptz) to authenticated;
grant execute on function builtin_assessment_private.reference(text,uuid,uuid,text) to anon,authenticated;
revoke all on function public.admin_builtin_assessment_workspace(text),public.admin_builtin_assessment_create_revision(text,uuid,uuid),
  public.admin_builtin_assessment_save(uuid,integer,jsonb,text),public.admin_builtin_assessment_review(uuid),
  public.admin_builtin_assessment_preview(uuid,text,integer,text,jsonb),public.admin_builtin_assessment_publish(uuid,integer),
  public.admin_builtin_assessment_withdraw(uuid,integer),public.record_builtin_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz),
  public.record_physical_assessment(text,text,text,jsonb,timestamptz),public.record_troop_goal_assessment(uuid,text,text,jsonb,timestamptz),
  public.record_fas_periodic_assessment(uuid,text,integer,jsonb,timestamptz) from public,anon,authenticated;
grant execute on function public.admin_builtin_assessment_workspace(text),public.admin_builtin_assessment_create_revision(text,uuid,uuid),
  public.admin_builtin_assessment_save(uuid,integer,jsonb,text),public.admin_builtin_assessment_review(uuid),
  public.admin_builtin_assessment_preview(uuid,text,integer,text,jsonb),public.admin_builtin_assessment_publish(uuid,integer),
  public.admin_builtin_assessment_withdraw(uuid,integer),public.record_builtin_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz),
  public.record_physical_assessment(text,text,text,jsonb,timestamptz),public.record_troop_goal_assessment(uuid,text,text,jsonb,timestamptz),
  public.record_fas_periodic_assessment(uuid,text,integer,jsonb,timestamptz) to authenticated;
revoke all on function public.builtin_assessment_reference(text,uuid,uuid,text) from public;
grant execute on function public.builtin_assessment_reference(text,uuid,uuid,text) to anon,authenticated;

notify pgrst,'reload schema';
commit;
