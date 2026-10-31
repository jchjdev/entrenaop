begin;
-- Correccion de etiquetas del ensayo; no cambia precios, cupos o identidades.
update commerce_private.offers
set title=replace(title,'B'||chr(195)||chr(161)||'sico','B'||chr(225)||'sico')
where plan_key='basic' and price_id in ('price_1UWfkaPhGz4xntMQyLepJiBH','price_1UWfkwPhGz4xntMQ8e4u94dN','price_1UWfkzPhGz4xntMQjZuT18Ce','price_1UWfl1PhGz4xntMQlhKhESMk','price_1UWfl3PhGz4xntMQfGpKZA7E','price_1UWflZPhGz4xntMQk60SIN7l','price_1UWflcPhGz4xntMQPoOWIPde','price_1UWflfPhGz4xntMQdofc6Wfe','price_1UWfliPhGz4xntMQhJvnr5xb','price_1UWflkPhGz4xntMQHoyYuObr');
commit;
