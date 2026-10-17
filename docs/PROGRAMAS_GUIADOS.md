# Programas guiados oficiales

## Acuerdo e implementación por bloques · 17/10/2026

Javier autoriza implementar PRG-001 conservando Biblioteca, preparaciones
adaptativas y ejecutores actuales. ADMIN elige guía repetible o recorrido por
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
Sin contenido de prueba persistido ni ejemplos publicados.

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
guía/fases o seguidos y dos resultados por página, sin carga infinita. El
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

No se han publicado programas deportivos de ejemplo: el catálogo se llena desde
ADMIN con contenido revisado. No añade progresión automática de cargas,
coordinación con preparaciones adaptativas, generación de agenda ni política
comercial nueva. Retirar un programa conserva seguimiento e historial; retirar
también sus sesiones puede impedir nuevas vistas previas de ese contenido.
La eficacia deportiva y la aceptación en dispositivos no quedan acreditadas
por las pruebas técnicas. Sin cambios en producción.

**Único siguiente bloque recomendado:** aceptación del recorrido con un programa
editorial real en móvil y ADMIN, incluyendo calentamiento, ajuste de descanso,
retorno/reanudación, cierre y confirmación de fase, antes de ampliar el catálogo.
