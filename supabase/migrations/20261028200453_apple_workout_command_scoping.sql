do $migration$ declare d text;begin
 d:=pg_get_functiondef('device_private.apple_training_command(uuid,text,jsonb)'::regprocedure);
 if strpos(d,'left join public.scheduled_workouts s on s.id=a.scheduled_id')=0 then raise exception 'Revisar proyección Apple';end if;
 d:=replace(d,$old$'needs_removal',s.id is null or s.status in ('cancelled','skipped'),'started',s.execution_id is not null$old$,
 $new$'needs_removal',sw.id is null or sw.status in ('cancelled','skipped'),'started',sw.execution_id is not null$new$);
 d:=replace(d,'left join public.scheduled_workouts s on s.id=a.scheduled_id','left join public.scheduled_workouts sw on sw.id=a.scheduled_id');
 execute d;
end $migration$;
