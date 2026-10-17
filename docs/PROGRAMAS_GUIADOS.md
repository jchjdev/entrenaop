# Programas guiados oficiales

## Acuerdo e implementación por bloques · 17/10/2026

Javier autoriza implementar PRG-001 conservando Biblioteca, preparaciones
adaptativas y ejecutores actuales. ADMIN elige rutina o recorrido por
fases en el mismo creador. Ambos contienen sesiones para entrenar y registrar
resultados. El autor define duración y condiciones de cada fase; el usuario
confirma el avance, sin consumo automático de etapas por calendario.

ADMIN crea calentamientos reutilizables y los adjunta opcionalmente a cada
sesión. El deportista puede omitirlos. Los descansos configurables conservan
pauta y ajuste personal separados; el ajuste genérico se limita a bloques
convencionales, sin alterar formatos temporizados ni el motor adaptativo.

## Bloque 1 · Autoría en ADMIN

Implementados catálogo y creador común, orden de fases/sesiones, duración,
condiciones, selección de sesiones oficiales generales publicadas, calentamiento
por sesión y límites de descanso entre series. Una guía usa una fase repetible
sin plazo. Publicación y retirada son explícitas; editar una publicación crea
un borrador nuevo. Las sesiones se crean y publican desde el editor existente.

El creador de calentamientos reutiliza campos, ejercicios públicos y series
convencionales del editor. Guarda una versión oficial privada con bloques
`warm_up`; no aparece como sesión suelta. Revisarla conserva las referencias
previas. No se adjunta otro calentamiento a una sesión que ya incluya uno.

### Contrato e integración

- `workout_core/guided_program.dart`: entidades y validación pura.
  `guided_program_codec.dart`: adaptación JSON fuera de las entidades.
- `admin_app/lib/features/guided_programs/`: repositorio, adaptador y pantallas.
  Los widgets no consultan Supabase directamente.
- `guided_programs`: documento editorial versionado. `guided_program_links`
  acredita sesiones/calentamientos con claves foráneas y posiciones.
- `guided_warmups`: familia, versión y plantilla privada.
- `save_guided_program`, `save_guided_warmup`, `set_guided_program_status`:
  transacciones administrativas con `search_path` vacío y grants explícitos.
  Las tablas conceden al cliente solo lectura con RLS.
- No se admite una sesión privada de oposición como contenido libre. Retirar
  una sesión de un programa publicado se rechaza para no romper ese programa.

Migración `20261017101000_guided_program_authoring.sql`, aplicada únicamente
a `entrenaop-dev`. Prueba instalada `guided_program_authoring.sql` con ROLLBACK:
autoría, guía/fases, descansos inválidos, referencias, versiones y permisos.
La prueba no persiste datos. Las demos autorizadas posteriormente se detallan
al final de este documento.

Validación: análisis de raíz y ADMIN limpios; 927 pruebas raíz y 111 ADMIN
correctas, con sus omisiones existentes. Los avisos del asesor para las tres
RPC autenticadas son deliberados: la autorización administrativa se comprueba
dentro y está cubierta por SQL. Los avisos anteriores de Auth y otras funciones
no se corrigen dentro de este alcance.

El punto de guardado del bloque de autoría es `68f8d43`. El siguiente bloque,
descrito debajo, completa el recorrido del deportista sobre este contrato.

## Bloque 2 · Biblioteca, seguimiento y entrenamiento

Biblioteca incorpora Programas, Sesiones y Ejercicios. Conserva Sesiones como
entrada inicial, las colecciones oficiales/propias, sus accesos de creación y
los componentes visuales existentes. Programas ofrece búsqueda, filtro por
rutinas/fases o iniciados y dos resultados por página, sin carga infinita. El
selector admite desplazamiento cuando el texto ampliado no cabe.

La ficha permite seguir una versión, ver información/material, explorar fases,
entrenar sus sesiones y consultar su estado reciente. La guía repite su secuencia.
El recorrido por fases avanza solo mediante confirmación explícita; presenta
duración/condiciones del autor sin evaluarlas como reglas deportivas automáticas.
No permite avanzar con una ejecución en curso. Reenviar la misma confirmación
no consume otra fase. Al completar se puede repetir con un seguimiento nuevo,
conservando el anterior y sus resultados.

`GuidedProgramRepository`, sus Cubit y el adaptador Supabase separan lectura,
persistencia y presentación. Las rutas tienen identidad en la URL y la vista de
sesión y el ejecutor usan el navegador raíz, sin barra de secciones. La vista
previa existente incorpora puntos opcionales para ajustes e inicio guiado. Una
sesión de otra fase o de un programa todavía no seguido se puede consultar,
pero no iniciar como entrenamiento de ese programa.

### Nombres e Inicio · PRG-002 · acuerdo del 18/10/2026

Javier confirma **Rutinas** para el filtro, **Rutina** para la etiqueta de la
tarjeta y **Por fases** para la otra modalidad. ADMIN utiliza los mismos nombres.
Se conservan los identificadores persistidos `guide`/`phased`, las versiones y
las sesiones publicadas. El botón se llama **Iniciar programa** y sigue creando
el seguimiento explícito antes de permitir entrenar; no arranca una sesión.

Inicio/Hoy incorpora **Tus programas**, con acceso a las fichas de los tres
últimos programas iniciados y no completados, mostrando la fase actual cuando
corresponda. La consulta pasa por `GuidedProgramRepository`, filtra propietario
y seguimiento activo en servidor, tiene orden estable y límite de tres, y usa
las RLS existentes. No agenda sesiones ni cambia el calendario o los ejecutores.
Se actualiza al volver a Inicio y al refrescar, incluso si el resumen principal
responde antes del siguiente frame. Un cambio de cuenta descarta respuestas
anteriores y el componente se identifica por usuario. Sin programas se oculta;
un fallo ofrece reintento sin bloquear el resumen de preparaciones.

El paginador de Biblioteca solo aparece si hay otra página o se está más allá
de la primera. En la última página conserva el acceso de vuelta. No se añade
desplazamiento infinito.

Verificado el 18/10/2026: análisis limpios en raíz y ADMIN, 943 pruebas completas
de la app y 111 de ADMIN correctas, con sus omisiones anteriores. Regresiones
de navegación/actualización, fase, texto 2× a 320 px, paginación y consulta por
propietario con respuesta pendiente al cambiar de cuenta. Sin cambios de SQL,
dependencias o producción; queda la aceptación física de Javier.

### Preparación de la ejecución

`start_guided_program_session` comprueba propietario, fase, sesión y descanso
permitido. Materializa una plantilla privada compatible con el contrato actual:
copia todos los campos de bloques, posiciones y series, antepone el calentamiento
seleccionado y aplica el descanso personal solo a bloques convencionales. La
pauta editorial y sus referencias no cambian. La plantilla usa origen
`algorithm` para la materialización de servidor, sin llamar al motor adaptativo
ni consumir una familia personal de Free.

El inicio usa `start_workout_execution`; omitir el calentamiento utiliza el
registro de omisión existente. Fuerza, EMOM, AMRAP y carrera conservan sus formatos,
relojes y registro. No se ha modificado el código de los ejecutores. Las series,
cierre, abandono, descarte, correcciones, avisos y cola offline siguen sus
recorridos actuales. La preparación de una sesión nueva requiere conexión.

`guided_program_follows` conserva versión y fase propias; `guided_program_runs`
enlaza operación, ajustes y ejecución. Ambas tablas tienen RLS por propietario
y solo conceden lectura al cliente. Las RPC verifican autorización en servidor.
Una operación incierta mantiene identidad y ajustes al reintentar; otra pestaña
retoma la ejecución abierta. Se sincronizan cierres pendientes antes del inicio
y se rechaza un cambio de cuenta durante esa sincronización. Al volver del
ejecutor se comprueba el estado antes de permitir otra operación nueva.

Migraciones `20261017102449_guided_program_follow_through.sql` y
`20261017105005_guided_program_read_indexes.sql`, solo desarrollo. La segunda
indexa el historial por propietario y resuelve la comprobación administrativa
una sola vez por consulta en las políticas de lectura.
La prueba instalada `guided_program_follow_through.sql` termina con ROLLBACK:
permisos, límites, reintentos, calentamiento, series reales, cierre habitual,
confirmaciones, repetición, descarte, EMOM, cierre AMRAP y tramos/ritmos de carrera.
También pasan las regresiones de autoría, sesiones oficiales, clasificación
histórica, descarte y revisión AMRAP. Las pruebas no dejan usuarios o contenido.

### Verificación y límites del recorrido

Análisis de raíz limpio, 937 pruebas completas correctas y la omisión web
existente. ADMIN conserva su análisis limpio y sus 111 pruebas correctas del
bloque 1, con su omisión existente; el bloque 2 no cambia sus archivos. Capturas
de widgets reales revisadas a 390 px, 320 px con texto doble y escritorio.
Compilación web correcta. Los 157 identificadores de migración coinciden entre
Git y desarrollo.
Los avisos de RPC autenticadas del asesor son los accesos de servidor previstos,
con propiedad/permisos comprobados; no hay concesión de ejecución anónima nueva.

El catálogo definitivo se llena desde ADMIN con contenido revisado. Por petición
de Javier se publican dos programas demo solo en desarrollo, descritos más abajo.
No añade progresión automática de cargas,
coordinación con preparaciones adaptativas, generación de agenda ni política
comercial nueva. Retirar un programa conserva seguimiento e historial; retirar
también sus sesiones puede impedir nuevas vistas previas de ese contenido.
La eficacia deportiva y la aceptación en dispositivos no quedan acreditadas
por las pruebas técnicas. Sin cambios en producción.

**Único siguiente bloque recomendado:** aceptación del recorrido en móvil con
las demos y revisión de autoría en ADMIN, incluyendo calentamiento, ajuste de descanso,
retorno/reanudación, cierre y confirmación de fase, antes de ampliar el catálogo.

### Demos publicadas para aceptación · 17/10/2026

Javier solicita dos programas sencillos para probar la app sin acceso a ADMIN.
Solo en `entrenaop-dev` se publican **Demo · Empuje, tirón y pierna**, guía
repetible de tres sesiones, y **Demo · Mejora de dominadas**, tres fases con una
sesión cada una: Base, Progreso y Consolidación. Las duraciones de dos semanas
son orientativas y el usuario confirma el avance. Se reutilizan ejercicios
públicos existentes; no se añaden movimientos ni se prescriben pesos fijos.
Ambos permiten calentamiento opcional y descanso de 60 a 180 segundos.

La carga reproducible e idempotente queda en
`tools/guided_programs_demo/`, fuera de migraciones y seeds globales, con destino
de desarrollo fijo y RPC de autoría/publicación existentes. No cambia el código
de las aplicaciones, sus ejecutores, cuentas, permisos o seguimientos reales.
Los nombres y descripciones identifican el carácter de demostración; no
acreditan revisión deportiva definitiva.

Comprobados autoría con ROLLBACK, publicación, repetición sin duplicados y
catálogo visible como deportista. La batería `verify.sql` inicia y termina las
seis sesiones, alterna calentamiento incluido/omitido, aplica descanso elegido,
conserva las sesiones fuente y confirma las tres fases; termina con ROLLBACK.
157 migraciones coincidentes; sin cambios en producción. La aceptación física
queda a cargo de las pruebas que Javier va a realizar.
