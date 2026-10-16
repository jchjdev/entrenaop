-- Al resolver AMRAP, las filas de ejecución también deben declarar la fuente.
-- No se inventan resultados por ejercicio: la declaración vive en el agregado.
begin;

create or replace function public.complete_amrap_block_idempotent(
  p_operation_id uuid,
  p_execution_id uuid,
  p_block_order integer,
  p_completed_rounds integer,
  p_partial_item_order integer default null,
  p_partial_reps integer default 0
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_status text;
  v_target integer;
  v_partial integer := p_partial_item_order;
  v_existing public.workout_amrap_results%rowtype;
  v_receipt public.workout_mutation_receipts%rowtype;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if p_operation_id is null or p_block_order is null or p_block_order < 0
    or p_completed_rounds is null or p_completed_rounds < 0
    or p_partial_reps is null or p_partial_reps < 0
    or (p_partial_item_order is null and p_partial_reps <> 0) then
    raise exception 'Invalid AMRAP result' using errcode='22023';
  end if;

  -- Un único bloqueo de ejecución serializa dos toques o dos dispositivos.
  select e.status into v_status from public.workout_executions e
    where e.id=p_execution_id and e.user_id=v_user for update;
  if not found then
    raise exception 'Workout execution is not accessible' using errcode='42501';
  end if;
  select r.* into v_receipt from public.workout_mutation_receipts r where r.id=p_operation_id;
  if found then
    if v_receipt.user_id=v_user and v_receipt.resource_id=p_execution_id
      and v_receipt.mutation_kind='complete_amrap' then return; end if;
    raise exception 'Mutation identifier already used' using errcode='22023';
  end if;

  if v_partial is not null then
    select s.target_reps into v_target from public.workout_execution_sets s
      where s.execution_id=p_execution_id and s.block_order=p_block_order
      and s.block_format='amrap' and s.item_order=v_partial;
    if not found or v_target is null or p_partial_reps >= v_target then
      raise exception 'Partial repetitions must be below the exercise target' using errcode='22023';
    end if;
    if p_partial_reps=0 and v_partial=(
      select min(s.item_order) from public.workout_execution_sets s
      where s.execution_id=p_execution_id and s.block_order=p_block_order
    ) then v_partial:=null; end if;
  end if;

  select a.* into v_existing from public.workout_amrap_results a
    where a.execution_id=p_execution_id and a.block_order=p_block_order;
  if found then
    -- Reintento tras una respuesta perdida, incluso con un identificador nuevo.
    -- Un resultado diferente necesita un corrector; nunca se sobrescribe aquí.
    if v_existing.completed_rounds is distinct from p_completed_rounds
      or v_existing.partial_item_order is distinct from v_partial
      or v_existing.partial_reps is distinct from p_partial_reps then
      raise exception 'AMRAP block already has a different result' using errcode='22023';
    end if;
  else
    if v_status <> 'in_progress' or p_block_order is distinct from (
      select min(s.block_order) from public.workout_execution_sets s
      where s.execution_id=p_execution_id and s.status='pending'
    ) or not exists (
      select 1 from public.workout_execution_sets s where s.execution_id=p_execution_id
      and s.block_order=p_block_order and s.block_format='amrap' and s.status='pending'
    ) then
      raise exception 'AMRAP block is not current' using errcode='22023';
    end if;
    insert into public.workout_amrap_results (
      execution_id,block_order,completed_rounds,partial_item_order,partial_reps
    ) values(p_execution_id,p_block_order,p_completed_rounds,v_partial,p_partial_reps);
    -- La cuenta de vueltas/parcial la declara el usuario, no un dispositivo.
    -- Se conserva la restricción general de fuente en todo resultado completado.
    update public.workout_execution_sets s
      set status='completed',completed_at=now(),result_source='manual'
      where s.execution_id=p_execution_id and s.block_order=p_block_order
      and s.block_format='amrap' and s.status='pending';
  end if;
  insert into public.workout_mutation_receipts(id,user_id,mutation_kind,resource_id)
    values(p_operation_id,v_user,'complete_amrap',p_execution_id);
end;
$$;
revoke all on function public.complete_amrap_block_idempotent(uuid,uuid,integer,integer,integer,integer)
  from public,anon,authenticated;
grant execute on function public.complete_amrap_block_idempotent(uuid,uuid,integer,integer,integer,integer)
  to authenticated;

commit;
