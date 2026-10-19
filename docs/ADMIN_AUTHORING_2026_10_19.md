# Autoría guiada en ADMIN · UI-055 · 19/10/2026

## Recorrido revisado

Javier autoriza revisar y mejorar las ineficiencias del admin, empezando por crear
un programa con cuatro sesiones sin salir a gestionar cada recurso por separado.
Se revisan programa guiado → sesión → revisión/publicación → incorporación a la
fase, calentamientos adjuntos, navegación, errores y conservación del formulario.
Se mantiene UI-054: una sesión general publicada se usa suelta y en varios
programas; la incorporación referencia una versión concreta, sin copiarla.

## Hallazgos y soluciones

| Hallazgo comprobado | Solución |
| --- | --- |
| Crear sesiones estaba al final del formulario y solo devolvía un booleano. | Crear nueva sesión y Elegir del catálogo aparecen en cada fase/rutina. El mismo editor devuelve opcionalmente el ID guardado mediante `returnId=true`; los demás consumidores conservan su resultado booleano. |
| Guardar una sesión no la incorporaba y obligaba a buscarla fuera. | Se abre la revisión existente. Tras publicar explícitamente, se recargan los datos y se añade exactamente esa versión a la fase de origen. |
| Cancelar o fallar podía dejar un borrador guardado sin relación visible con el montaje. | La fase conserva una referencia pendiente en memoria, con Retomar y Quitar referencia pendiente. No se guarda un programa omitiendo silenciosamente estas sesiones. El borrador del catálogo no se elimina al quitar la referencia. |
| El selector solo mostraba publicaciones y carecía de búsqueda. | Búsqueda sin tildes, Publicadas y Borradores. Seleccionar un borrador abre revisión/publicación; no permite enlazar contenido sin publicar. Los retirados no se ofrecen para nuevas incorporaciones. |
| Volver desde Publicar o revisar sesiones no refrescaba el selector. | Recarga al volver, también desde revisión y calentamientos. Las tres lecturas independientes de sesiones, calentamientos y categorías se ejecutan conjuntamente. |
| Una revisión podía devolver otra identidad y se conservaba la anterior. | El ID revisado se propaga hasta el programa, vuelve a revisión si aún es borrador y se incorpora solo tras su publicación. |
| Encadenar dos regresos con `onExit` asíncrono podía cerrar dos veces el editor hijo. | Se espera el frame de retirada de la página hija antes de cerrar la revisión o abrir la siguiente. Se conservan la estructura de rutas y las URLs. |
| La revisión podía abandonarse mientras se publicaba/retiraba. | Usa el guard de operaciones pendientes del router, bloquea acciones simultáneas y deja errores persistentes con reintento. |
| Solo se podía subir una sesión en el orden. | Se añade Bajar sesión, manteniendo los campos y ajustes del elemento movido. |
| Crear un calentamiento quedaba separado de la sesión que lo necesitaba. | Crear y adjuntar calentamiento usa el editor actual y adjunta el ID devuelto al regresar. |
| Se ofrecían calentamientos dobles y descansos incompatibles con el formato. | La lectura de bloques informa si la sesión ya incluye calentamiento o tiene series convencionales. Las opciones se ajustan a esos datos; el guardado vuelve a validarlos. Las referencias retiradas/ausentes mantienen una etiqueta corregible. PostgreSQL conserva su validación definitiva. |
| El selector desbordaba con teclado y texto 2×; el objetivo del editor podía desbordar. | Selector con un único desplazamiento y resultados construidos a demanda; dropdown de objetivo expandido dentro de su ancho. |

## Publicación y referencias

Guardar una sesión sigue creando un borrador. Publicar requiere el diálogo
existente que avisa de su visibilidad en la biblioteca general. Publicar una
sesión no publica el programa, no asigna agendas ni ejecuta entrenamientos.
El programa se guarda después, con sus referencias y configuración, y conserva
su publicación independiente. Una revisión publicada no sustituye versiones
en otros programas automáticamente.

Si se cancela el editor antes de guardar, no se crea contenido. Si se cancela la
revisión, el borrador guardado permanece en el catálogo y visible como pendiente
en el montaje actual. Los errores de publicación permiten reintentar el mismo
ID; no vuelven a crear la sesión. Quitar una sesión/fase del montaje conserva el
contenido del catálogo.

## Referencias de experiencia de uso

[Trainerize](https://help.trainerize.com/hc/en-us/articles/45565151151508-Using-the-AI-Workout-Builder)
documenta el acceso al creador desde biblioteca y desde una fase, con contexto de
destino visible. Se toma ese patrón de creación contextual, reutilizando nuestro
editor; no se añade generación por IA.
[TrainingPeaks](https://help.trainingpeaks.com/hc/en-us/articles/204072434-Workout-Libraries)
documenta bibliotecas reutilizables para facilitar la planificación. Se conserva
nuestro catálogo común y se reduce el cambio manual entre catálogo y programa.
No se trasladan sus reglas de copia, permisos, prescripción ni negocio.

## Límites comprobados al cerrar UI-055

La conservación de programas incompletos y el guardado final se amplían después
en [UI-056](ADMIN_DRAFT_RECOVERY_2026_10_19.md). La lista siguiente describe el
estado previo de este bloque, no sus pendientes actuales.

- Los campos de programa y las referencias pendientes sin guardar viven en la
  pantalla. No se añade recuperación persistente tras cerrar/recargar el navegador.
  El guard protege las salidas de navegación de la aplicación; las sesiones y
  calentamientos que sí se guardaron permanecen en el catálogo.
- El contrato actual exige fases con sesiones publicadas para guardar el programa.
  Admitir borradores incompletos persistentes requiere ampliar ese contrato y sus
  validaciones; no se disfraza como un cambio de botones.
- No se añade idempotencia de creación ante una respuesta de red ambigua: esta
  revisión evita recrear al reintentar publicación, no acredita exactamente una
  creación tras perder la respuesta de guardado.
- No se modifican migraciones, permisos, producción, motor deportivo, paquetes
  compartidos ni aplicación del deportista. Esto revisa el recorrido de autoría
  descrito; no constituye una auditoría de todas las funciones del producto.

Antes de preparar el subdominio, el siguiente bloque recomendado de este
recorrido es concretar la recuperación persistente de programas incompletos y
la idempotencia de guardado, conservando la separación de borrador y publicación.

## Verificación · 19/10/2026

- `flutter analyze` de ADMIN sin incidencias. Batería completa: 162 pruebas
  correctas y las dos capturas optativas existentes omitidas.
- Siete regresiones nuevas: seis recorridos de widgets con router/editores reales
  y repositorios de prueba, más una prueba de metadatos del adaptador. Comprueban
  cuatro creaciones/publicaciones y guardado del programa, cancelación con
  pendiente visible, rechazo de guardado que omitiría pendientes, recuperación
  desde el selector, fallo/reintento sin nueva creación, identidad revisada,
  bloqueo durante publicación, calentamiento creado/adjuntado, fase correcta y
  selector a 320 px, texto 2× y espacio de teclado. La prueba del adaptador
  contrasta las opciones con los formatos de bloque recibidos.
- Compilación web de desarrollo en modo release. Las comprobaciones afectan solo
  a ADMIN: no se cambian paquetes compartidos ni contratos de PostgreSQL y no
  corresponde ampliar a la batería del deportista ni aplicar SQL de mutaciones.
- Chrome autenticado contra Dev: Crear nueva sesión abre el editor existente y
  volver conserva el programa; búsqueda de Empuje filtra el catálogo real.
  No se guarda ni publica contenido remoto durante esta comprobación. Las
  escrituras del caso de cuatro sesiones se verifican con repositorios de prueba,
  no se presentan como cuatro publicaciones nuevas en Supabase.
- [Capturas reales y procedencia](visual-audit/admin-authoring-2026-10-19/README.md).
