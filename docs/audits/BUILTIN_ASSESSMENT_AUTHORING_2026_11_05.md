# Autoría FAS/Tropa · auditoría del bloque · 05/11/2026

## Entrega y fronteras

El recorrido aprobado incorpora crear/retomar revisión, presentación/fuente/vigencia,
mínimos Tropa y puntos FAS, comparación/simulador, revisión, publicación y retirada
para nuevas preparaciones. Las condiciones deportivas y los editores de sesiones
conservan sus contratos. Se fijan las preparaciones a revisiones; no se actualizan
silenciosamente. Cambios de protocolo/estructura y actualización explícita de una
preparación existente son siguientes capacidades, no funciones entregadas aquí.

ADMIN 0.7.0+12; deportista 1.17.0+37. Sin nuevos paquetes ni dependencias. La
retención de compilados y el arreglo de copias se guardan como infraestructura
separada, con autorización y evidencia propias.

## Implementación contrastada

- Revisiones completas e inmutables tras publicación; borradores privados con
  edición concurrente e idempotencia de creación. Escritura por RPC invoker a
  funciones privadas, permiso administrativo y AAL2; propiedad/revisión/estado
  comprobados al guardar evaluaciones. Sin acceso directo de escritura cliente.
- Tropa conserva 24 referencias y cuatro pruebas. FAS importa literalmente 306
  filas del asset; sus 64 mínimos se proyectan desde la tabla de puntuación y
  coinciden exactamente con los originales. Se conserva la anomalía documental
  de carrera; la publicación bloquea nuevas incoherencias de puntos.
- Las proyecciones se insertan como catálogos nuevos. No cambian is_current legado,
  las filas de mínimos usadas, las definiciones compartidas ni los motores. Una
  preparación antigua mantiene semilla; las altas nuevas eligen la revisión
  publicada vigente. Retirar no rompe el historial ni sus vínculos existentes.
- Los nuevos resultados FAS conservan snapshot calculado en servidor, incluyendo
  la décima de agilidad. La vista mantiene las columnas antiguas y añade snapshot
  al final; los registros anteriores conservan su semántica. No se inventa un
  resultado normativo agregado.
- App, calculadora e historial leen su revisión exacta. El asset sólo representa
  una versión antigua conocida. Los fallos de red no cambian de baremo. La
  calculadora personal ofrece Actualizar baremo si la publicación cambió, conserva
  las marcas y recalcula únicamente tras la acción explícita; la recarga fallida
  se puede reintentar. Los clientes anteriores conservan semilla o reciben una
  incompatibilidad explícita al intentar guardar en una preparación nueva.
- ADMIN muestra una columna y 20 filas por página para la matriz FAS, protege
  estructura/unidades/protocolos y conserva datos al fallar. La revisión queda
  invalidada al editar. Las respuestas de otro contexto se descartan.

## Validación previa a aplicar Dev

- 1.872 pruebas raíz y una omisión previa; 406 ADMIN y dos omisiones previas.
- Análisis raíz y ADMIN sin incidencias; compilaciones web exclusivamente Dev.
- 48 pruebas de herramientas ADMIN, 32 Trainer y tres de semilla/contrato SQL.
- Pruebas focales incluyen 320 px/texto 2×, precisión, reintentos, concurrencia,
  recuperar/retirar, publicación durante formulario, snapshots y separación de
  versiones. La inspección independiente del SQL no detecta otro bloqueo.
- Migración y smoke completos ejecutados juntos en Dev con ROLLBACK; comprueban
  publicación/retirada/legacy, 64 mínimos, permisos, propiedad, vínculos, guards y
  señal de actualización personal. Se corrigió una ambigüedad de alias Tropa
  detectada en el primer ensayo antes de aplicar nada definitivamente.

## Aplicación y publicación

La copia previa 42085037509-3 queda verified, restaurada el 05/11/2026 a las
19:06:45 UTC y conservada cifrada (4.235.835 bytes) hasta el 12/11. La migración
20261105180858 se aplica exclusivamente en entrenaop-dev; el historial CLI acredita
309 migraciones coincidentes. El smoke nuevo, fas_periodic_security_smoke y
troop_goal_assessment_smoke pasan sobre el esquema instalado, todos con ROLLBACK.

Se conservan exactamente los cuatro intentos Tropa y once FAS: las huellas de
cabeceras antiguas, marcas y resultados coinciden antes/después. Para comparar FAS
se excluye únicamente la nueva columna nullable result_snapshot, que permanece
vacía en los intentos anteriores. Hay dos revisiones semilla publicadas, doce
vínculos de preparaciones y cero borradores/fixtures persistidos por el ensayo.

Los asesores de seguridad no añaden errores ni advertencias: aparecen únicamente
dos [INFO RLS-sin-política](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
para las tablas privadas creation_requests y events,
intencionalmente cerradas y sin grants de acceso directo al cliente. Las funciones
privadas validan permiso/AAL2 y exponen solo las operaciones autorizadas.

La copia posterior 42092600721-1 queda verified: restauración aislada del
esquema nuevo a las 19:24:19 UTC, paquete cifrado de 4.280.331 bytes y recibo
a las 19:24:24 UTC; disponibilidad hasta el 12/11 a las 19:24:21 UTC. La recogida
de errores de servicios también pasa.

ADMIN Dev 42091933340 completa validación, publicación y retención. La revisión
f3d8e03e69070de28b1b4eeee4f77b1fbef87575 queda activa en admin.entrenaop.es como
0.7.0+12, con sourceTreeDirty=false y destino sxbxfjqgoddzhtcyhalw. Una consulta
HTTPS independiente comprueba build-info, version.json, base del índice, hash
SHA-256 de main.dart.js, X-Frame-Options DENY y Cache-Control no-store. CI repite
1.872 pruebas raíz y 406 ADMIN, análisis limpios y compilación. Trainer Dev
42091933173 y ensayo de Salud 42091933283 también terminan correctamente.

La aceptación física en iPhone requiere instalar el nuevo cliente; el ensayo web/servidor no acredita instalación nativa en ese dispositivo.


## Regresión al desplegar condiciones · 05/11/2026

La grabación 20261105-1948-14.2996569 y la reproducción autenticada en Chrome
muestran bloques grises al abrir objetivos de Tropa/FAS. La consola y una prueba
local reproducen exactamente bool no es double en ScrollPosition.restoreScrollOffset.
La ficha real tiene un PageStorageKey para recordar el desplazamiento. Los
ExpansionTile sin clave propia escribían su booleano en ese mismo identificador;
los SelectableText interiores lo leían como desplazamiento numérico. Las pruebas
anteriores del panel aislado omitían la clave de la ficha y no ejercitaban ese contexto.

ADMIN 0.7.1+13 separa claves estables de historial, comparación, simulador y cada
objetivo, así como textos seleccionables y campos internos del simulador. Se
conservan diseño, selección/copia del texto, datos introducidos y reglas de negocio.
No cambia servidor, base de datos, baremos, app del deportista ni Trainer.

Las pruebas existentes pasan a utilizar scroll persistente como la ficha real.
Dos regresiones adicionales recorren ambos programas, abren varios objetivos,
pliegan uno sin afectar al otro y vuelven a abrir manteniendo metadatos. Las 16
pruebas focales pasan; batería ADMIN completa: 408 correctas y dos omisiones
previas. Análisis sin incidencias y compilación web release Dev correcta.

La ejecución ADMIN Dev 42099553973 completa validación, despliegue y retención.
HTTPS independiente acredita revisión 7fd496f52ad7c7f0bf4b83ebdada5d9a7e026719,
versión 0.7.1+13, destino Dev, índice y SHA-256 del código correctos. Se repite el
recorrido autenticado en Chrome: Tropa muestra perfil/protocolo sin bloque gris;
FAS permite abrir los tres objetivos, plegar la plancha independientemente y
mantener circuito/flexiones completos. El simulador FAS abre edad y las cuatro
marcas. Capturas antes/después contrastadas y cero errores nuevos de la revisión
publicada en consola. No se guardan intentos ni se cambia ninguna revisión durante
la comprobación visual.
