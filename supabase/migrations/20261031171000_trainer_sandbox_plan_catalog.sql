begin;
-- Catálogo de ensayo, no tarifas de producción ni concesiones Pro/directorio.
-- Las ofertas son inmutables: nuevas tarifas requieren nuevas identidades.
alter table commerce_private.offers
 add column plan_key text not null default 'legacy'
   check(plan_key in ('legacy','basic','professional','complete')),
 add column directory_option boolean not null default false;
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('a8bc43e2-24a0-569a-9a2f-ec148491c59a',1,'BÃ¡sico · 5 alumnos · ensayo','price_1UWfkaPhGz4xntMQyLepJiBH',1290,'EUR','month',5,true,'basic',false);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('c26ee330-7692-5f26-9818-f3625701cb84',1,'BÃ¡sico · 10 alumnos · ensayo','price_1UWfkwPhGz4xntMQ8e4u94dN',1990,'EUR','month',10,true,'basic',false);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('1f4d2397-470c-5d41-84e9-e0cdddf1c8e1',1,'BÃ¡sico · 20 alumnos · ensayo','price_1UWfkzPhGz4xntMQjZuT18Ce',2990,'EUR','month',20,true,'basic',false);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('2118484d-017a-5248-9cfd-6186b5341437',1,'BÃ¡sico · 50 alumnos · ensayo','price_1UWfl1PhGz4xntMQlhKhESMk',5990,'EUR','month',50,true,'basic',false);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('7abc84a6-2b63-5dff-b830-188bca15218f',1,'BÃ¡sico · 100 alumnos · ensayo','price_1UWfl3PhGz4xntMQfGpKZA7E',9990,'EUR','month',100,true,'basic',false);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('5c36e578-2a01-5205-9621-061326c9698a',1,'Profesional · 5 alumnos · ensayo','price_1UWflAPhGz4xntMQ3la93nyc',1990,'EUR','month',5,true,'professional',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('a0c3dae2-734f-59a3-9aa2-5c5c1d84113f',1,'Profesional · 10 alumnos · ensayo','price_1UWflCPhGz4xntMQmBK4Rm9e',2690,'EUR','month',10,true,'professional',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('48c7e985-ce02-5fbb-b832-7d9165f719d4',1,'Profesional · 20 alumnos · ensayo','price_1UWflFPhGz4xntMQ0pMUHSk3',3690,'EUR','month',20,true,'professional',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('343e420d-e61f-5551-82e7-00f179d6998a',1,'Profesional · 50 alumnos · ensayo','price_1UWflHPhGz4xntMQ7gljTefg',6690,'EUR','month',50,true,'professional',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('1cf63afc-e25e-5ba8-827f-90157b7bfb59',1,'Profesional · 100 alumnos · ensayo','price_1UWflKPhGz4xntMQp0bwQaG2',10690,'EUR','month',100,true,'professional',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('641381ab-180b-5622-8164-fa80620067a0',1,'Completo · 5 alumnos · ensayo','price_1UWflNPhGz4xntMQu8kJAvSR',2490,'EUR','month',5,true,'complete',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('7765ab28-29a2-5e8e-8519-253f36b08635',1,'Completo · 10 alumnos · ensayo','price_1UWflPPhGz4xntMQUXUvGLCq',3690,'EUR','month',10,true,'complete',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('05552a1f-f8d4-5662-8b64-78484d4f4be9',1,'Completo · 20 alumnos · ensayo','price_1UWflSPhGz4xntMQWPgYvv1h',5690,'EUR','month',20,true,'complete',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('e29e3022-4d28-5fda-83c0-c3470c1545de',1,'Completo · 50 alumnos · ensayo','price_1UWflUPhGz4xntMQtmjvZ08d',11690,'EUR','month',50,true,'complete',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('f4bd66f2-6d3d-5ec9-abfd-01f8dc017d8e',1,'Completo · 100 alumnos · ensayo','price_1UWflWPhGz4xntMQzRpirCsl',20690,'EUR','month',100,true,'complete',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('0147fe6f-e04f-53d8-a9c7-17b912ec9f00',1,'BÃ¡sico + directorio · 5 alumnos · ensayo','price_1UWflZPhGz4xntMQk60SIN7l',1780,'EUR','month',5,true,'basic',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('f1eb3953-ee63-597a-90cc-3c641a70b235',1,'BÃ¡sico + directorio · 10 alumnos · ensayo','price_1UWflcPhGz4xntMQPoOWIPde',2480,'EUR','month',10,true,'basic',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('d596e7ee-6def-5ea7-9a1a-a7b719302adb',1,'BÃ¡sico + directorio · 20 alumnos · ensayo','price_1UWflfPhGz4xntMQdofc6Wfe',3480,'EUR','month',20,true,'basic',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('9ca8c2a4-785a-5ac3-8c78-be755ee78bbc',1,'BÃ¡sico + directorio · 50 alumnos · ensayo','price_1UWfliPhGz4xntMQhJvnr5xb',6480,'EUR','month',50,true,'basic',true);
insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values
 ('542c2473-200d-5bbb-97cd-0fd1198f5078',1,'BÃ¡sico + directorio · 100 alumnos · ensayo','price_1UWflkPhGz4xntMQHoyYuObr',10480,'EUR','month',100,true,'basic',true);
create or replace function commerce_private.status(p_owner uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform commerce_private.assert_owner(p_owner);
 if exists(select 1 from public.trainer_access where trainer_id=p_owner) then
  perform commerce_private.refresh_access(p_owner);
 end if;
 select jsonb_build_object('sandbox',true,'enabled',s.enabled,'offers',
  coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'title',f.title,'amount',f.amount,'currency',f.currency,
   'interval',f.interval,'capacity',f.capacity,'plan_key',f.plan_key,'directory_option',f.directory_option) order by f.amount) from commerce_private.offers f where f.active),'[]'::jsonb),
  'subscription',(select jsonb_build_object('id',o.id,'state',o.state,'paid_until',o.paid_until,
    'cancel_at_period_end',o.cancel_at_period_end,'capacity',f.capacity,'checked_at',o.checked_at)
   from commerce_private.orders o join commerce_private.offers f on f.id=o.offer_id
   where o.owner_id=p_owner order by o.created_at desc,o.id desc limit 1))
 into result from commerce_private.settings s where singleton;
 return result;
end $$;

commit;
