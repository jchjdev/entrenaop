# Autoría del programa y series · UI-062 · 20/10/2026

Javier concentra creadores y Compacto en este chat. Solicita corregir los
solapamientos de personalización de series y evitar saltar entre páginas para
crear un programa. Confirma expresamente el guardado y publicación conjunta.

## Presentación elegida: la ventana existente · 20/10/2026

Tras comparar ambas presentaciones, Javier elige la ventana para focalizar la
edición de una sesión. Aclara expresamente que se reutilice la ventana que ya ha
probado, sin otro rediseño ni selector de modos. Esta decisión sustituye la
prueba anterior de edición desplegada en la página.

Se recuperan el Dialog existente, su cabecera con cierre y el programa detrás.
El contenido comparte un desplazamiento dentro de la ventana y reutiliza el
creador y lector actuales. Se conservan todas las correcciones de formatos,
series, protección del trabajo, reintento del enlace y publicación conjunta.
La ruta del programa permanece estable; abrir no crea sesiones y guardar
incorpora el borrador mediante el mismo contrato existente.

El guard local consulta los cambios pendientes antes de cerrar; PopScope permite
salir por atrás usando esa comprobación. El fondo no cierra por pulsación y el
programa bloquea navegación/edición mientras la ventana está abierta. La cabecera
de cierre permanece fuera del desplazamiento. No se cambia el diseño móvil de
la ventana existente, ni se añaden nuevos accesos o atajos.

Solo cambian la composición de ADMIN y sus pruebas. Sin cambios en los paquetes
compartidos, datos, RPC, permisos, algoritmos ni migraciones. No se recarga la
pestaña de trabajo del usuario.

### Verificación de la ventana elegida

Análisis de ADMIN sin incidencias y batería completa con 255 pruebas correctas
y dos omisiones previas. Las 27 pruebas dirigidas de autoría y editor comprueban
cuatro sesiones, cierre protegido, borrador conservado al desplazar, recuperación
del enlace sin duplicados y apertura sin crear versiones. Las comprobaciones de
ventana cubren 1300/390 px y 320 px con texto 2×; revisada la captura de escritorio.
Compilación web release local para Dev correcta, con CSP y sin mapas de fuentes
ni recursos CDN. No se repite raíz ni paquetes porque no cambian sus fuentes.

### Publicación comprobada de la ventana elegida

- Commit de presentación: `e9114c735d0bb944be841a858b1f8b43bedd35d7`.
- [CI 39462194081](https://github.com/jchjdev/entrenaop/actions/runs/39462194081):
  validación, compilación y publicación automática en ADMIN Dev.
- Comprobación HTTPS independiente el 20/10/2026, 17:03 UTC: revisión exacta,
  entorno `development` y proyecto `sxbxfjqgoddzhtcyhalw`, entrada activa,
  manifiesto, cabeceras de caché y protección de marco y MIME WebAssembly correctos.
- Versión: `e9114c735d0bb944be841a858b1f8b43bedd35d7-39462194081-1`.
- JavaScript SHA-256:
  `134d0b6fcdf75453523347e0f4979ac6589a9aa98072f4b244144a9e94927551`.
- No se recarga el trabajo abierto de Javier. Aceptación manual con su contenido
  y teclado físico pendientes; producción sin cambios.

## Prueba anterior: editor dentro de la página · sustituida por ventana

Javier prueba el panel superpuesto y confirma reemplazarlo por creación, edición
y revisión desplegadas en la propia página del programa. Una sesión abierta a
la vez, sin diálogo, ruta adicional, Scaffold ni scroll interno del creador.
El programa comparte un único desplazamiento y conserva montados los campos
fuera del área visible para no perder el borrador al desplazarse.

Mientras está abierta se bloquean los controles de estructura y metadatos del
programa, también para el foco de teclado; se mantienen visibles. **Recoger
sesión** consulta el guard del editor y pide confirmar si hay cambios sin guardar.
Salir por navegación consulta primero ese guard y después el del programa;
`WorkflowDraftGuard.beforeExit` compone ambas comprobaciones sin sustituirlas.
El guard del lector conserva el bloqueo de operaciones en curso. Un error de
enlace permite reintentar o recoger la sesión: el padre conserva el ID pendiente.

Se reutilizan creador y lector, ofreciendo contenido sin scroll propio en modo
`embedded`; sus rutas independientes conservan Scaffold y desplazamiento. No se
modifican RPC, esquema, publicación conjunta, dosis, ejecutor ni algoritmo.
Javier confirma conservar repeticiones y RIR con kg opcionales; vacío no implica
cero y no se incorpora prescripción por RM. El cambio de interfaz se guarda en
un commit separado para poder recuperar el panel anterior mediante una reversión
selectiva de presentación, conservando datos y publicación conjunta.

La evidencia del panel más abajo corresponde a la primera implementación. La
integración directa tiene sus propias pruebas y capturas; su aceptación manual
por Javier queda pendiente.

### Verificación del editor integrado

Análisis limpios en raíz, ADMIN, `workout_editor_ui` y `entrena_ui`. Batería raíz:
1.128 correctas, una omisión previa; ADMIN: 253 correctas y dos omisiones previas;
editor compartido: 43; componentes UI: 15.
Las regresiones de autoría verifican cuatro sesiones, fase correcta, reintentos,
recoger un enlace fallido y retomarlo sin duplicar, borrador conservado al salir
del área visible y protección al navegar fuera. Vista previa y creación no añaden
Dialog, Scaffold ni ListView interno. Revisadas capturas de widgets reales a
1300/390 px y 320 px con texto 2×; la publicación sigue usando el contrato Dev ya
validado, sin migraciones nuevas. CI y la comprobación HTTPS constan debajo.

### Publicación comprobada del editor integrado

- Commit de interfaz: `6f1b2fe1b86410f35d4d461273eaaabdd403750f`.
- [CI 39449386565](https://github.com/jchjdev/entrenaop/actions/runs/39449386565):
  validación, compilación y despliegue correctos.
- Comprobación HTTPS independiente el 20/10/2026, 15:41 UTC: revisión exacta,
  configuración `development` y proyecto Dev `sxbxfjqgoddzhtcyhalw`, JavaScript
  SHA-256 `3a2d029e59b0c87d5e42cc38c9f49731383bbcb6f02b9947d6ab97571b73d259`,
  entrada activa, `Cache-Control: no-store`, `X-Frame-Options: DENY` y MIME de
  WebAssembly correctos.
- Versión: `6f1b2fe1b86410f35d4d461273eaaabdd403750f-39449386565-1`.
- No se recargan pestañas de trabajo del usuario ni se modifican sus sesiones
  para esta comprobación. Aceptación manual del editor integrado y teclado en
  dispositivo físico pendientes; las capturas anteriores son tests de widgets.
- Para recuperar el panel anterior basta revertir la presentación introducida
  por este commit; no hay migraciones ni datos que deshacer y la publicación
  conjunta de UI-062 permanece.

## Cambio de formato y comparación de presentaciones · 20/10/2026

Javier detecta que pasar a Tabata crea ocho posiciones y que, al volver a series,
permanecen las posiciones vacías y bloquean Intervalos de trabajo. El creador
compartido distingue ahora los huecos añadidos automáticamente para completar
un formato de los ejercicios elegidos o posiciones añadidas manualmente. Al
cambiar de formato retira solo huecos automáticos intactos; elegir un ejercicio,
escribir un valor, cambiar el objetivo o personalizar series los conserva.

El selector cuenta las posiciones que se conservarían: los huecos automáticos
no bloquean Intervalos (un ejercicio) ni Superserie (dos), pero el contenido
existente no se recorta para forzar esos formatos. El selector explica el límite
cuando hay más ejercicios. Se mantienen los ocho intervalos 20/10 de Tabata y
la validación deportiva, serialización y publicación existentes.

Javier continúa comparando ventana y edición dentro de la página; no ha elegido
una definitiva. Pide abrir la anterior aquí, sin añadir selector ni modificar la
presentación publicada. La comparación local conserva ventana; la web mantiene
la integración en página. La copia local se compila en `.dart_tool/` con el
contenedor anterior y el creador compartido corregido, sin cambiar main a ese
contenedor ni recargar su pestaña de trabajo. El lector y creador `embedded` se
alojan en un desplazamiento del diálogo local. No es una segunda implementación
de la receta ni una versión publicable del producto.

El cambio de nombre a «Guardar borrador y salir» se propuso y aceptó inicialmente;
Javier interrumpió la implementación pidiendo no añadir nada y abrir la versión
anterior para comparar. No se ha cambiado ese texto ni añadido el selector.

Verificación de esta corrección: análisis limpios en raíz, ADMIN y
`workout_editor_ui`; 1.128 pruebas raíz (una omisión previa), 253 ADMIN (dos
omisiones previas) y 47 del paquete compartido correctas. Cuatro regresiones
nuevas cubren volver de Tabata a series varias veces sin alterar la receta,
pasar directamente a Intervalos, conservar ejercicios elegidos y conservar
valores escritos en posiciones automáticas. La disponibilidad se actualiza al
empezar a escribir, sin reconstruir por cada dígito una receta ya configurada.
La compilación local de comparación termina correctamente. En navegador local
se verifica Tabata → Intervalos: opción habilitada, una sola posición y consola
sin errores; no se guarda contenido ni se recarga la pestaña del programa.
La corrección no añade migraciones ni cambia permisos o algoritmos.

Publicación de la corrección de Tabata: commit
`a2c672d6ca26370e0acc951ed13c974178641365`,
[CI 39456371391](https://github.com/jchjdev/entrenaop/actions/runs/39456371391)
con validación, build y despliegue correctos. Comprobación HTTPS independiente:
revisión exacta, entorno `development`, proyecto Dev `sxbxfjqgoddzhtcyhalw`,
entrada activa, cabeceras y MIME de WebAssembly correctos; SHA-256 del JavaScript
`fde8e652151e768d93f22337e777b2de737e78db6b6b07c265b0393b7721584d`.
La copia local con ventana se actualiza sin recargar el trabajo del usuario.

## Revisión de superserie, circuito, EMOM y AMRAP · 20/10/2026

Javier pide comprobar todos los cambios de formato, sin restos del formato
anterior ni pérdida del trabajo escrito. Se conservan las reglas deportivas y
la serialización existentes: rondas/descanso en superserie y circuito, estaciones
de un minuto en EMOM, límite global y objetivo común por repeticiones en AMRAP,
y ocho intervalos fijos de 20/10 en Tabata.

Se corrigen dos fronteras del creador compartido:

- Las excepciones por serie ocultas no se envían en AMRAP ni Tabata. En AMRAP se
  usa el objetivo común; Tabata mantiene 20 segundos sin kg ni RIR heredados.
  Las excepciones quedan disponibles si se vuelve a un formato compatible
  durante la misma edición, y la pantalla lo explica. Al guardar y salir se
  conserva la receta del formato elegido, no una copia oculta de otros formatos.
- Al entrar en AMRAP desde duración o distancia no se interpretan segundos o
  metros como repeticiones ni se reutiliza esfuerzo histórico incompatible.
  Se exige completar un objetivo de repeticiones explícito; las cantidades y el
  RIR de esa modalidad se mantienen separados mientras se edita. Volver al
  formato anterior recupera su objetivo y regresar a AMRAP recupera el nuevo.

La comparación local con ventana recibe el mismo creador corregido, sin recargar
el trabajo abierto. La web conserva la edición integrada. No se cambian datos,
permisos, algoritmo, guardado conjunto ni publicación; no hay migraciones nuevas.

### Botones de edición y versiones

Javier pregunta por «Crear nueva versión en borrador» frente a «Editar borrador».
El texto depende del estado de la sesión, no del modo ventana/página. Pulsarlo
solo abre el editor y no hace RPC de guardado. Guardar desde una sesión publicada
crea otra versión de su familia y conserva la publicación anterior; guardar un
borrador actualiza el mismo ID según el contrato Dev ya validado de UI-062.
En un programa, el ID devuelto se enlaza al montaje para su revisión/publicación
conjunta. Dos nuevas regresiones comprueban que abrir/cerrar el editor desde
ambos estados no crea ni guarda sesiones.

### Verificación

Análisis limpios en raíz, ADMIN y paquete compartido. La batería raíz conserva
1.128 pruebas correctas y una omisión previa; ADMIN, 255 y dos omisiones previas.
Las 67 pruebas del paquete compartido son correctas. Su cobertura incluye doce recorridos entre los cuatro formatos con
vuelta a series, cuatro guardados de rondas/descansos/límite, dos regresiones de
excepciones ocultas y dos de objetivos AMRAP desde segundos/metros. La compilación
local con ventana termina correctamente; no se recarga ninguna pestaña de trabajo.
La comprobación de CI y HTTPS se registra al terminar la publicación.

Comprobación adicional en navegador local: un objetivo real de `00:45` pasa a
AMRAP con repeticiones vacías y sin RIR inventado; al volver a series se recuperan
visualmente los `00:45`. Consola sin errores, sin guardar contenido de prueba.
Durante esta tarea Javier confirma que los programas de desarrollo son datos de
prueba prescindibles y autoriza modificarlos o rehacerlos si hace falta para las
comprobaciones. Este permiso no incluye producción ni otros datos ajenos a las
pruebas de programas. No se borra ni modifica ningún programa por esta aclaración.

Publicación de la revisión completa de formatos: commit
`be1101b203e8411d5cba3f74b4d512cccb42c1c7`,
[CI 39459395615](https://github.com/jchjdev/entrenaop/actions/runs/39459395615)
con validación, compilación y despliegue correctos. HTTPS independiente acredita
revisión exacta, entorno `development` y proyecto Dev `sxbxfjqgoddzhtcyhalw`,
entrada activa, cabeceras y MIME de WebAssembly correctos. SHA-256 del JavaScript:
`8a7af2293afc1f14e1e62e7013822f0b511541c984b023906aad9a444703caca`.
La comparación local permanece en ventana y la web integrada, sin selector nuevo.

## Contrato acordado

- El programa mantiene su contexto mientras se crean, editan y revisan sesiones
  con el creador compartido; no se copia otro editor.
- Guardar una sesión contextual crea un borrador reutilizable y lo incorpora al
  montaje. No publica contenido ni exige una confirmación de publicación aparte.
- El programa puede guardarse en borrador con sesiones oficiales generales en
  borrador o publicadas. Las retiradas o ajenas al catálogo siguen rechazadas.
- La revisión final reúne todas las sesiones. Una confirmación publica el programa
  y los borradores que utiliza en una transacción del servidor. Un fallo revierte
  el conjunto. Las versiones publicadas reutilizadas se conservan.
- Mostrar como sesión suelta sigue siendo opcional y comienza desactivado al
  crear desde un programa. No es un requisito para utilizarla dentro de él.
- Sesiones conserva su recorrido independiente. No cambian cuotas comerciales,
  planes activos, resultados, propiedad ni permisos profesionales.

Este acuerdo sustituye la obligación anterior de publicar cada sesión antes de
enlazarla. Implementado y validado en Flutter y Supabase Dev. La aceptación manual
del editor integrado por Javier continúa pendiente; no se atribuye a capturas de tests.

## Series

Las etiquetas reservan espacio en su grupo compartido, también al envolver filas
y ampliar texto. Valores comunes y ajustes por serie se distinguen. Un campo
vacío de una excepción hereda el valor común: se muestra «Común», no un cero
aparente. Se conserva el cálculo existente de dosis, descansos, carga y RIR.

## Guardado y recuperación

Se guarda el trabajo antes de desplegar el editor. Tras recibir el ID de la sesión,
primero se conserva como pendiente, después se lee su resumen y se confirma el
enlace. Un fallo permite reintentar con ese ID, sin volver a crear la sesión ni
duplicar su posición. Recuperar una revisión pendiente conserva cuál era su
posición original. Los snapshots antiguos siguen siendo legibles; la información
de reemplazo es opcional dentro del JSON de trabajo existente.

Editar un borrador conserva su ID y sustituye la receta validada en una sola
transacción. Editar una publicación crea otra versión. Los borradores compartidos
por varios montajes siguen siendo una sola versión; publicar uno deja la sesión
publicada también como referencia de los otros, pero no publica esos programas.
Quitar una referencia del programa no borra la receta reutilizable.

## Servidor y límites

Migraciones `20261020142135` y `20261020144306`, aplicadas solo a Dev. La RPC
existente de publicación publica cada identidad una vez, valida contenido y
calentamientos y conserva una única transacción. La activación vuelve a comprobar
calentamiento propio/adjunto y compatibilidad del descanso genérico: guardar un
programa no congela la receta de sus sesiones en borrador.

No se crean tablas ni permisos de lectura/escritura nuevos. Las operaciones de
autoría mantienen `is_admin()` y el MFA vigente; el trigger no es ejecutable por
anon ni authenticated. El asesor de seguridad identifica las RPC administrativas
autenticadas existentes: sus comprobaciones internas y el rechazo del deportista
se verifican en SQL. [Criterio del asesor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
Los avisos ajenos al cambio no se consideran corregidos por este bloque.

El reintento del enlace presupone haber recibido el ID. No se añade idempotencia
a la creación de una sesión cuando se pierde completamente su respuesta. La
relectura de la revisión y los bloqueos de publicación conservan sus límites:
no constituyen una firma editorial de todas las recetas entre pestañas. No hay
ensayo de edición realmente simultánea ni aceptación de teclado en móvil físico.

## Verificación del 20/10/2026

- Análisis limpios en raíz, ADMIN y `workout_editor_ui`.
- Baterías completas: **1.128 raíz**, **250 ADMIN** y **43 del paquete** correctas;
  se conservan una omisión raíz y dos ADMIN preexistentes.
- Compilación web release de ADMIN con configuración explícita de Dev correcta.
- Cuatro pruebas SQL con `ROLLBACK`: publicación conjunta, autoría guiada,
  borradores/revisiones de sesiones y visibilidad editorial. Cubren reversión de
  una publicación parcial, referencias repetidas, edición enlazada, historial,
  incompatibilidad de formato después de guardar y permisos.
- `supabase migration list --linked`: **171 versiones coincidentes**, sin pendientes.
- Seis configuraciones de separación de títulos/etiquetas (320, 390 y 1100 px,
  texto 1×/2×); panel sobre el programa a 1300/390/320 px, incluyendo texto 2×.
  Se mantienen las regresiones de todos los formatos, carrera y calentamientos.
- [Capturas de widgets reales y sus límites](visual-audit/program-authoring-workspace-2026-10-20/README.md).

Único siguiente paso de este recorrido: aceptación manual del montaje y sus
series en el admin actualizado, con el contenido que Javier esté creando.
No se abre aquí otro rediseño ni la implementación del portal profesional.

## Publicación comprobada

Publicado en `https://admin.entrenaop.es` mediante la
[ejecución automática 39443585025](https://github.com/jchjdev/entrenaop/actions/runs/39443585025),
validación y despliegue correctos. Revisión servida:
`cdeb1ec318ec25265509b6397835ca3df60e19bf`.
Release: `cdeb1ec318ec25265509b6397835ca3df60e19bf-39443585025-1`.

Comprobación HTTPS independiente con `verify_public`: proyecto Dev, SHA-256 del
JavaScript `d52035e9170a55f71b301a7dfd8dbaa1021cf166201a1d377eedee007ae1a160`,
índice que activa la versión, cabeceras administrativas y MIME Wasm correctos.
Nueva pestaña de Chrome: catálogo autenticado cargado, sin errores de consola.
La pestaña de creación que Javier tenía abierta se conserva intacta. No se crea
contenido remoto para esta comprobación ni se atribuye aceptación manual del
panel a la mera lectura del catálogo.
