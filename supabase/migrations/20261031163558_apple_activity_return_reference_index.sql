begin;
-- Índices de las referencias que intervienen al retirar/borrar una pauta.
create index apple_result_plan on device_private.apple_activity_results(plan_id);
create index apple_delivery_schedule on device_private.apple_training_deliveries(scheduled_id);
commit;
