# Preferencias de ejercicios de los editores

21/10/2026. Contrato de servidor compartido para ADMIN y Trainer, sin publicar
contenido ni trasladar permisos administrativos al espacio profesional. La
migración local es `20261021162903_trainer_editor_exercise_preferences.sql`.
Aplicada en Dev el 21/10/2026 dentro del conjunto profesional: 195 migraciones
locales/remotas coincidentes y 24 contratos revalidados con ROLLBACK.
No se ha aplicado en producción; publicación y aceptación UI se acreditan aparte.

## Identidad y selección

Los contextos exactos son `admin_official` y `trainer_private`. Cada preferencia
pertenece a `auth.uid()` y a uno de esos contextos; ninguna RPC recibe un usuario
libre. La misma cuenta puede tener ambos contextos con preferencias diferentes.
ADMIN no recibe acceso a las preferencias ni a ejercicios privados de otros.

Todas las entradas exigen sesión no anónima, AAL2 y TOTP verificado. El contexto
administrativo exige además el permiso editorial; el profesional, una concesión
profesional propia. Escribir exige que esa concesión siga habilitada y vigente.
Deshabilitarla conserva la consulta de preferencias propias, sin autorizar nuevas
selecciones o cambios. Los reintentos de escritura conservan ese requisito.

Se usa la elegibilidad del selector actual: ejercicios públicos y, en Trainer,
ejercicios coach propios cuya versión siga vigente. La referencia interna de
carrera no se ofrece. Las versiones antiguas que una receta retiene no se
convierten en opciones nuevas por estar en favoritos. El favorito pertenece al
ID concreto y no se traslada automáticamente a una revisión nueva.

Retirar o borrar un ejercicio conserva su preferencia y su revisión CAS; no hay
FK desde preferencias al catálogo. El snapshot omite referencias no elegibles.
Desmarcar una entrada conservada propia sigue siendo posible por su ID, sin
consultar ni devolver datos del recurso retirado. Un UUID privado ajeno que no
tenga una entrada propia no permite crear ni consultar una preferencia.

## API

```text
get_editor_exercise_preferences(p_context text)
  -> {entries: [entry], recent_limit: 20, favorite_limit: 500}

get_editor_exercise_preference(p_context text, p_exercise_id uuid)
  -> entry

set_editor_exercise_favorite(
  p_operation_id uuid, p_context text, p_exercise_id uuid,
  p_favorite boolean, p_expected_revision bigint
) -> entry

record_editor_exercise_selection(
  p_operation_id uuid, p_context text, p_exercise_id uuid
) -> entry

entry = {
  exercise_id, favorite, favorite_revision, last_selected_at
}
```

El snapshot es la unión autorizada de favoritos y recientes. Contiene como máximo
500 favoritos y 20 recientes adicionales, con IDs únicos; no es la primera página
de un listado mayor ni declara un total de catálogo. Los favoritos retirados
conservados también ocupan el límite técnico de 500 hasta desmarcarlos. No es un
precio, tarifa ni ampliación del cupo de alumnos.

El getter puntual recupera una fila propia conservada aunque ya no figure en el
snapshot. Si no existe fila, devuelve favorito falso/revisión 0/fecha nula solo
para un ejercicio elegible. Permite obtener el CAS de un favorito desmarcado y
evictado de recientes, sin cargar todos los tombstones en cada editor.

Cada orden nueva de favorito compara `favorite_revision` y la incrementa en uno;
una revisión obsoleta produce `40001`. La selección utiliza `clock_timestamp()`
del servidor, conserva favorito y su revisión, y retira los timestamps que
excedan los veinte más recientes. Evictar no elimina la fila ni reinicia su CAS.

## Reintentos y combinación de campos

El UUID de operación se acota por propietario y contexto. Acción y payload quedan
registrados junto con el recibo exacto; reutilizar ese UUID con otros parámetros
produce `22023`. Un reintento confirmado devuelve el recibo original y no vuelve
a seleccionar un ejercicio evictado ni consume otro favorito.

El adaptador hace preflight puntual cuando la revisión local no es conocida y
conserva después los parámetros normalizados de esa operación. Tras una respuesta
incierta reenvía exactamente esos parámetros; no recalcula el CAS ni genera otro
UUID. Un `40001` requiere obtener el estado canónico antes de proponer otra orden.

Un recibo de selección antiguo puede contener un favorito con revisión anterior
a un cambio posterior. La UI combina favorito por mayor `favorite_revision`, sin
dejar que la selección lo rebaje, o refresca el snapshot. El recibo no se modifica
para hacer pasar un estado posterior por la respuesta original. Las preferencias
no añaden campos a las recetas de ejercicios/sesiones/programas.

## Aislamiento y bloqueos

Las tablas y helpers de `editor_private` tienen RLS y no conceden acceso directo.
Solo las cuatro fachadas autorizadas se ejecutan por `authenticated`; `anon` no
puede invocarlas. Los helpers no reciben otro propietario ni permiten búsquedas
de metadata del catálogo privado.

Las mutaciones fijan primero el perfil del propietario con KeyShare, después el
permiso/acceso correspondiente y finalmente la fila de propietario/contexto.
Esa fila se actualiza incluso en el primer uso mediante `ON CONFLICT UPDATE`,
invalidando un snapshot REPEATABLE READ anterior, incluida la ausencia inicial
de la fila. Serializa cuota, CAS y recencia sin bloquear agendas ni contenidos.
Favorito y selección pueden combinarse sin pisar sus campos independientes.

## Evidencia y límites

`supabase/tests/trainer_editor_exercise_preferences.sql` pasa en Dev con migración
temporal y `ROLLBACK`: contextos/cuentas, ADMIN sin acceso privado ajeno, MFA,
selección autorizada, versiones retiradas, CAS, preflight tras evicción,
reintentos, cuota de 500 y recencia de 20. No deja actores ni preferencias.

`tools/test_editor_preferences_concurrency.py` pasa 36 contenciones observadas en
PostgreSQL17 local efímero
con las RPC reales y guards de MFA/acceso reales. Cubre CAS inicial sin fila,
reintentos simultáneos, favorito/selección en ambos órdenes, última plaza de
favoritos y recencia, en READ COMMITTED y REPEATABLE READ. El catálogo mínimo del
runner no sustituye las pruebas completas de permisos y catálogo de Dev.

La integración de los adaptadores y la UI pertenece a las aplicaciones y al
paquete compartido. Este contrato por sí solo no acredita una publicación web,
una prueba humana del editor ni la sincronización de otra función del producto.
