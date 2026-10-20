# Autoría del programa y series · UI-062 · 20/10/2026

Javier concentra creadores y Compacto en este chat. Solicita corregir los
solapamientos de personalización de series y evitar saltar entre páginas para
crear un programa. Confirma expresamente el guardado y publicación conjunta.

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
del nuevo panel por Javier continúa pendiente; no se atribuye a capturas de tests.

## Series

Las etiquetas reservan espacio en su grupo compartido, también al envolver filas
y ampliar texto. Valores comunes y ajustes por serie se distinguen. Un campo
vacío de una excepción hereda el valor común: se muestra «Común», no un cero
aparente. Se conserva el cálculo existente de dosis, descansos, carga y RIR.

## Guardado y recuperación

Se guarda el trabajo antes de abrir el panel. Tras recibir el ID de la sesión,
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
