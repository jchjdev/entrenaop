begin;

-- Organización del autor, separada del contenido y de sus clasificaciones.
create table editor_private.exercise_labels (
 user_id uuid not null, context text not null, exercise_id uuid not null,
 labels text[] not null default '{}', revision bigint not null default 0 check(revision>=0),
 primary key(user_id,context,exercise_id),
 foreign key(user_id,context) references editor_private.exercise_preference_owners(user_id,context) on delete cascade,
 check(cardinality(labels)<=8 and octet_length(labels::text)<=1024)
);
alter table editor_private.exercise_labels enable row level security;
revoke all on editor_private.exercise_labels from public,anon,authenticated;

create function editor_private.read_exercise_labels(p_context text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform editor_private.require_context(p_context);
 return (select coalesce(jsonb_agg(jsonb_build_object('exercise_id',exercise_id,'labels',labels,'revision',revision) order by exercise_id),'[]')
  from editor_private.exercise_labels where user_id=auth.uid() and context=p_context
   and editor_private.can_select_exercise(p_context,exercise_id));
end $$;

create function editor_private.set_exercise_labels(p_context text,p_operation_id uuid,p_exercise_id uuid,p_labels text[],p_expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior editor_private.exercise_preference_writes; current_revision bigint; payload jsonb; result jsonb; label text;
begin
 if p_operation_id is null or p_exercise_id is null or p_expected_revision is null or p_expected_revision not between 0 and 2147483646
  or p_labels is null or coalesce(array_ndims(p_labels),1)<>1 or cardinality(p_labels)>8 then raise invalid_parameter_value; end if;
 if array_position(p_labels,null) is not null then raise invalid_parameter_value; end if;
 foreach label in array p_labels loop
  if label<>btrim(label) or length(label) not between 1 and 32 or label ~ '[[:cntrl:],]' then raise invalid_parameter_value; end if;
 end loop;
 if (select count(distinct lower(x)) from unnest(p_labels) x)<>cardinality(p_labels) then raise invalid_parameter_value; end if;
 perform editor_private.lock_owner(p_context);
 payload:=jsonb_build_object('action','labels','exercise_id',p_exercise_id,'labels',p_labels,'expected_revision',p_expected_revision);
 select * into prior from editor_private.exercise_preference_writes where user_id=auth.uid() and context=p_context and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 if not editor_private.can_select_exercise(p_context,p_exercise_id) then raise insufficient_privilege; end if;
 select revision into current_revision from editor_private.exercise_labels where user_id=auth.uid() and context=p_context and exercise_id=p_exercise_id;
 if coalesce(current_revision,0)<>p_expected_revision then raise serialization_failure; end if;
 -- Límite técnico de metadatos, sin incrementar derechos de creación.
 if current_revision is null and (select count(*) from editor_private.exercise_labels where user_id=auth.uid() and context=p_context)>=5000 then
  raise exception 'Se ha alcanzado el límite de ejercicios etiquetados.' using errcode='54000'; end if;
 insert into editor_private.exercise_labels(user_id,context,exercise_id,labels,revision)
  values(auth.uid(),p_context,p_exercise_id,p_labels,p_expected_revision+1)
  on conflict(user_id,context,exercise_id) do update set labels=excluded.labels,revision=excluded.revision;
 result:=jsonb_build_object('exercise_id',p_exercise_id,'labels',p_labels,'revision',p_expected_revision+1);
 insert into editor_private.exercise_preference_writes values(auth.uid(),p_context,p_operation_id,payload,result);
 return result;
end $$;

create function public.get_editor_exercise_labels(p_context text) returns jsonb
language sql stable security invoker set search_path='' as $$select editor_private.read_exercise_labels(p_context)$$;
create function public.set_editor_exercise_labels(p_context text,p_operation_id uuid,p_exercise_id uuid,p_labels text[],p_expected_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select editor_private.set_exercise_labels(p_context,p_operation_id,p_exercise_id,p_labels,p_expected_revision)$$;
revoke all on function editor_private.read_exercise_labels(text),editor_private.set_exercise_labels(text,uuid,uuid,text[],bigint),
 public.get_editor_exercise_labels(text),public.set_editor_exercise_labels(text,uuid,uuid,text[],bigint) from public,anon,authenticated;
grant execute on function editor_private.read_exercise_labels(text),editor_private.set_exercise_labels(text,uuid,uuid,text[],bigint),
 public.get_editor_exercise_labels(text),public.set_editor_exercise_labels(text,uuid,uuid,text[],bigint) to authenticated;
commit;
