# Preparadores por alumno · TRN-028 · 24/10/2026

Javier confirma el caso de Isabel: Javier coordina fuerza y Ervi carrera, sin
abrir las carteras de alumnos de ninguno. No se crea un equipo global ni se
modifican los grupos. Sustituye la exclusividad anterior de un preparador.

## Contrato

- Inicialmente dos preparadores activos por alumno, con máximo configurable
  en servidor. No se admite dos veces la misma pareja activa. Las invitaciones
  siguen requiriendo aceptación del alumno, son caducables e idempotentes.
- Cada vínculo consume una plaza del preparador correspondiente. Pro, cuotas
  personales, acceso profesional y seguimiento siguen separados.
- El alumno habilita explícitamente compartir su calendario desde la gestión
  de vínculos en Preparador. Está desactivado por defecto, también para las
  cuentas existentes. Aceptar otra invitación no activa la compartición.
  Si ya está activada, la vista previa explica que el nuevo preparador también
  podrá consultar la agenda y las pautas. Se puede retirar en cualquier momento.
- La compartición alcanza las citas del alumno seleccionado y sus pautas
  (ejercicios, series, ritmos, descansos), incluidas sesiones personales y de
  EntrenaOP, para cotejar la carga. No incorpora medios privados, resultados,
  conversación, formularios ni notas internas del otro profesional.
- El calendario identifica autor, origen, estado y vínculos finalizados. Cada
  preparador solo escribe sus propias asignaciones. Las sesiones conviven sin
  sustituciones automáticas. No se decide edición cruzada ni chat conjunto.
- Consultar exige identidad fijada, MFA, acceso profesional vigente, vínculo
  activo con ese alumno y compartición habilitada. No amplía las políticas de
  lectura del catálogo, ejercicios, asignaciones ni relaciones de otras cuentas.
  Terminar un vínculo revoca su lectura; el último vínculo desactiva la
  compartición para que una futura etapa no herede ese consentimiento.

## Implementación

Las migraciones `20261024175746` y `20261024183546` cierran el contrato. La
primera sustituye el índice de exclusividad por pareja
activa y protege el máximo mediante trigger y serialización por alumno. El
contador de calendario fuerza reintentos de snapshots obsoletos también entre
preparadores distintos. La aceptación conserva los bloqueos y versiones de cupo
profesional. El consentimiento tiene revisión optimista e idempotencia. La segunda
serializa también habilitación y baja del último vínculo: REPEATABLE READ no
puede reactivar la compartición desde una relación ya finalizada.

Las funciones públicas son invoker; los internos definer tienen `search_path`
vacío, controles explícitos y privilegios restringidos. El detalle de una pauta
se obtiene por cita y alumno, con campos permitidos expresos; no concede acceso
genérico a la plantilla del otro profesional. La paginación usa fecha e ID.

`trainer_access/trainer_calendar.dart` aporta contratos y adaptadores con token
fijado e invalidación al cambiar de cuenta. Trainer añade Calendario compartido
en la ficha, con semanas y detalle de pauta en lectura, reutilizando
`WorkoutTemplateContent`. La agenda operativa propia no cambia. La app del
deportista permite otro vínculo, conserva historial y ofrece conversaciones
identificadas por preparador. Su agenda e Inicio identifican al autor.

## Verificación

Preflight de migración y contrato sobre Dev en transacción con ROLLBACK:
aceptación doble, duplicado, máximo, cupos independientes, consentimiento,
revocación, baja parcial/total, MFA, acceso profesional y aislamiento entre
alumnos/catálogos. El contrato previo de acceso también pasa con las nuevas
reglas. No se crean vínculos ni consentimiento de personas reales en las pruebas.

`tools/test_trainer_multi_coach_concurrency.py` pasa 42 contenciones reales en
PostgreSQL17 local desechable: dos preparadores, última plaza de alumno y de
preparador, pareja duplicada, idempotencia y habilitación simultánea con baja
del último vínculo, con READ COMMITTED y REPEATABLE READ.

Ambas migraciones están aplicadas en Dev y el historial coincide con la copia local.
Sobre el esquema aplicado pasan de nuevo acceso, sesiones privadas, avisos y el
contrato de varios preparadores, todos con ROLLBACK. Los advisors no introducen
avisos públicos nuevos de esta entrega; calendar_sharing queda intencionadamente
sin políticas ni grants, accesible solo por funciones internas autorizadas.

Pruebas Flutter cubren vínculos y consentimiento, destinos independientes de
conversación, identidad fijada, lectura sin edición y descarte de datos tras
revocación/cambio de alumno. Análisis limpio en raíz, ADMIN y Trainer;
baterías completas de 1.336, 315 y 190 pruebas respectivamente, con una omisión previa en raíz y dos
en ADMIN. Los cinco tests del contenedor flotante también pasan. Calendario
comprobado a 320 px y texto 2×. Compilar Flutter no acredita instalación física
en iPhone. La publicación web se verifica separadamente.

## Límites y siguiente recorrido

No crea cuentas ni enlaza a Isabel automáticamente: ella acepta ambas
invitaciones y decide compartir. No incorpora pagos compartidos, escritura de
pautas ajenas, valoración automática de interferencias ni organización global.
El siguiente recorrido es la aceptación de Javier y Ervi sobre un alumno de
prueba compartido, incluida revocación desde la app actualizada.

## Publicación profesional Dev

Fuentes de interfaz `c0933f54aceccb348ed439615d408dd70ddcf4d2` guardadas y subidas
a main. Trainer publica la release
`c0933f54aceccb348ed439615d408dd70ddcf4d2-20261024-1`, paquete ZIP SHA-256
`e70339e2f1cea84456f199d6d30da244b9f7e9054056d9ff7cca19c561954239` y JavaScript
`f9ff10ae73208b96890cbccca1cb56239067a91fe0a7cc742433622f9aa2b96c`.
Carga en trainer-releases fuera de public_html; extracción exclusivamente en
public_html/trainer, conservando versiones anteriores. Verificador HTTPS correcto
para revisión, proyecto Dev, hash, entrada, cabeceras y WebAssembly.

Chrome contrasta la sesión profesional existente, Calendario compartido desde
la ficha y la ausencia de sesiones sin consentimiento. No se activa la
compartición de una persona real para probar. Se comprueba desplazamiento de
480 px horizontal y 30 vertical de la calculadora, navegación conservando el
contenido, minimizado/restaurado y 400 m a 4:15/km = 1:42, sin errores de consola.
Evidencia local: .dart_tool/garmin-strength/trainer-multi-coach-c0933f54.png.

La aplicación del deportista también compila en Web Release Dev. Esto no instala
una nueva build en el iPhone: la gestión de dos vínculos y el consentimiento
requieren actualizar esa aplicación. No hay cambios en producción ni pagos.

ADMIN también publica las fuentes `c0933f54`, release `c0933f54aceccb348ed439615d408dd70ddcf4d2-40120588497-1`.
El workflow Publicar ADMIN Dev #66 termina correctamente (validación, despliegue
y retención), con revisión Dev y hash de JavaScript contrastados por HTTPS.
La corrección del arrastre compartido llega a ambos portales.
