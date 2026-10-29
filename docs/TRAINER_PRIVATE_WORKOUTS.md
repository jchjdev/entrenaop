# Sesiones privadas, pautas y resultados · TRN-016 · 21/10/2026

## Búsqueda en el contenido · 29/10/2026

TRN-044 añade modalidad fuerza/carrera y «Contiene formato» (series,
superserie, circuito, intervalos, AMRAP, EMOM, Tabata, carrera, calentamiento y
vuelta a la calma). Una sesión puede coincidir con varios formatos según sus
bloques reales; nombrarla «Tabata» no basta para pasar ese filtro. La búsqueda
textual normalizada incluye título, descripción, nombres de bloques y ejercicios,
modalidad y etiquetas de formato. Las tarjetas muestran los formatos internos.

Se reutiliza el filtro en biblioteca principal, bibliotecas laterales de agenda
y planificación del alumno, y selector de sesión al asignar. Conserva arrastre,
receta fijada, confirmación y selección inicial sin desplegar otra vez el catálogo.
La lista canónica sigue viniendo de `list_trainer_workouts` y cada página añade
una consulta de metadatos, limitada a sus IDs, dueño y origen profesional, bajo
RLS. No hay lecturas por sesión, series descargadas ni permisos adicionales.
Una lectura incompleta falla y permite reintentar, sin presentar los formatos
ausentes como conocidos. Búsqueda y filtros se aplican a lo cargado; las páginas
restantes se incorporan con «Cargar más». No es búsqueda global de servidor.
Análisis de Trainer limpio y 306 pruebas correctas. Incluyen formato real frente
a título engañoso, búsqueda normalizada de ejercicios, una lectura por lote,
restricción por dueño/IDs, asignación y bibliotecas con texto ampliado. Los filtros
laterales usan un menú compacto para no desplazar fuera de pantalla las sesiones.

## Resultados compactos · UI-065 · 23/10/2026

La vista de resultado profesional presenta una cabecera por bloque con nombre
y formato, y una tarjeta plegable por posición de ejercicio de fuerza. Los
colores mantienen las familias usadas en el creador; nombre y estado escritos
evitan depender del color. La tarjeta cerrada resume completadas, omitidas y
pendientes. Solo resume una dosis uniforme observada; si las marcas varían,
lo indica sin promediarlas. Al desplegar, cada serie conserva su pauta y su
resultado, con tiempos originales del reloj y valores ausentes intactos.
En escritorio se comparan en columnas; en móvil o con texto ampliado se apilan.

La agrupación es local a presentación y recorre el orden recibido del servidor.
Exige posiciones consecutivas con el mismo `block_order`, `item_order` y
`exercise_id`; no agrupa por nombre ni mezcla posiciones de bloques diferentes.
Si falta identidad suficiente, conserva tarjetas separadas. Carrera mantiene
sus tramos individuales y AMRAP no convierte su receta en series realizadas.
La consulta, las marcas, las revisiones, la asignación y el cierre no cambian.

Análisis Trainer correcto y 179 pruebas aprobadas, incluidas diez series en una
tarjeta, separación por posición/bloque/identidad, resultados variables,
omisiones, carga ausente, tramos de carrera y superserie a 320/1200 px con
texto ampliado al doble. Publicación web autorizada después por Javier.
Compilación Release local y comprobación en Chrome sin errores de consola:
una sesión de ejemplo con dieciséis series ocupa tres tarjetas cerradas;
desplegar conserva las dosis variables y la comparación por serie. La vista
previa utiliza el mismo widget con datos ficticios, sin consultas ni escrituras
de alumnos. Esa vista previa se complementa con la comprobación publicada.
Fuentes funcionales guardadas en `3c7ff9a1`. Compilación completa de Trainer
Release Dev correcta; release preparada
`3c7ff9a1e10d982ac5544f4cef5f712be01ea87a-20261023-1`, ZIP SHA-256
`efc21dd919d67389cf30ab25d64d24dc23b26746223f11e3e6bf76d259799c6f`.
Paquete publicado con autorización expresa en `public_html/trainer`, conservando
las releases anteriores. Verificador HTTPS correcto: revisión, JavaScript,
arranque, cabeceras y WebAssembly. Chrome acredita la sesión profesional y el
resultado existente de fuerza: sus tres series ocupan una tarjeta plegable,
con pauta y mediciones originales por serie al abrirla. No hay errores ni
avisos de consola en esa comprobación ni escrituras de resultados/revisiones.
La captura real queda privada fuera de Git. No se despliega ADMIN o producción.

## Revisión y comparación · 24/10/2026

Deportista y preparador disponen de «Solo diferencias con la pauta», desactivado
al entrar y reversible sin escrituras. Mantiene omisiones, pendientes y datos
insuficientes, además de las diferencias numéricas. Las tarjetas conservan el
orden y numeración originales. Fuerza compara los objetivos declarados;
carrera respeta los márgenes existentes de tiempo (2 %), distancia (1 %) y
recuperación (5 %), con límites de ritmo y precisión original del dispositivo.
No es la puntuación de Garmin ni una calificación deportiva. AMRAP conserva su
resultado por bloque, sin deducir series ejecutadas de la receta.

«Comparar con otra sesión» abre una consulta de lectura bajo demanda. Se elige
una ejecución anterior cerrada de la misma plantilla y versión. Se empareja
cada serie por bloque, posición, ejercicio, formato y, en las prescripciones
especializadas, protocolo/montaje/medición. Una identidad incompleta o duplicada
no produce una correspondencia arbitraria. Se muestran las marcas anterior y
actual y su diferencia numérica, junto al esfuerzo global declarado; los cambios
de pauta/contexto se advierten y los valores ausentes permanecen como «—».
Los resultados AMRAP se comparan como vueltas y parciales de cada bloque.

`workout_core/workout_result_review.dart` contiene las instantáneas y reglas
puras; `workout_editor_ui/workout_result_review_panel.dart` comparte controles,
selección y comparación. La app del deportista adapta su entidad de ejecución
y carga páginas desde un caso de uso a través de `WorkoutRepository`. Trainer
consulta exclusivamente las pautas del mismo alumno y sus resultados mediante
los RPC profesionales ya autorizados, con MFA e identidad del repositorio.
No incorpora credenciales, consultas privilegiadas, tablas, migraciones,
permisos ni endpoints nuevos. La comparación no altera resultados o revisiones.

El historial del deportista se consulta de treinta en treinta ejecuciones;
Trainer, de cincuenta en cincuenta pautas, cargando resultados solo de candidatas
cerradas de la misma versión. Una página sin coincidencias permite continuar,
y los errores conservan la consulta para reintentar. La selección ordena las
sesiones consultadas por fecha de ejecución; no presume haber leído páginas
posteriores. No compara automáticamente revisiones o copias distintas de una
plantilla ni detecta tendencias de mejora/regresión: eso sigue siendo una
interpretación contextual, no una conclusión de dos marcas aisladas.

Verificación local del bloque: análisis raíz, Trainer y ADMIN sin incidencias;
1.330 pruebas raíz con una omisión previa, 182 Trainer y 314 ADMIN con dos
omisiones previas. Las nuevas regresiones cubren filtro reversible y numeración,
precisión del reloj, RIR y cargas ausentes, variantes/protocolos distintos,
identidades ambiguas, límites de versión, paginación y reintentos, AMRAP y
comparación a 320 px con texto doble. La vista web del componente compartido
se contrasta también con datos de ejemplo, sin escrituras de alumnos.

Fuentes funcionales `b2bf067b` subidas a main. Compilaciones Release Dev de
ambos consumidores correctas. Trainer publicado como
`b2bf067bc287c17a0f84131b891e9394181eeee0-20261024-1`, ZIP SHA-256
`dab79400e97034628b2cad2787f3fb0feb1f232627423ef71947f14a06d4cd5f`.
Verificación HTTPS correcta de revisión, JavaScript, entrada, cabeceras y WASM.
La consulta autenticada acredita filtro reversible sobre resultados existentes
en ambas apps y el estado sin otra ejecución anterior de la misma versión.
No se crean sesiones ficticias en el historial ni se guardan correcciones,
marcas o revisiones. Las capturas de comprobación quedan privadas fuera de Git.
La comparación con marcas distintas está cubierta por pruebas y vista previa
con datos de ejemplo; falta la aceptación con dos ejecuciones reales comparables.
La web local necesitó una entrada generada con ruta versionada para sortear
el service worker previo, manteniendo intacto el JavaScript de aplicación.
Se observó un aviso de fallback de fuentes Noto en la consola local, sin glifos
ilegibles en las capturas contrastadas; no se declara una consola sin avisos.
La [CI de Garmin e iOS Release](https://github.com/jchjdev/entrenaop/actions/runs/40068355597)
terminó correcta sobre estas fuentes, igual que la publicación automática y
retención de paquetes de [ADMIN Dev](https://github.com/jchjdev/entrenaop/actions/runs/40068355464).
La instalación física del iPhone sigue el flujo habitual de Pull de main y Xcode.

## Informe general compacto · 24/10/2026

El informe de progreso del alumno comienza con cada ejercicio plegado y permite
abrir/cerrar sus mediciones de forma independiente. AMRAP conserva sus resultados
por bloque en otra tarjeta plegable. Las filas de repeticiones, tiempo, distancia,
carga, RPE y RIR aparecen solo si existe alguna observación registrada. Un cero
real sigue siendo un dato; si faltan otras observaciones de esa misma métrica,
se mantiene el recuento de ausentes. Si un ejercicio no tiene ninguna medición,
no se presenta una tabla vacía. Los registros deportivos conservan protocolo,
unidad y declaraciones disponibles sin rellenar valores ausentes.

La comparación común de sesiones aplica el mismo criterio: no muestra esfuerzo
global si no está declarado en ninguna fecha, ni filas de medidas sin registro
en ambas sesiones. Si una fecha tiene medición y la otra no, se mantiene la marca
y la ausencia explícita para no sugerir que ambas fueron realizadas. Es una
mejora de presentación; no cambia agregaciones, CSV, contratos, permisos o datos.

Validación del ajuste aislado sobre main: análisis correcto de los tres
consumidores, 1.331 pruebas raíz (una omisión previa), 184 Trainer y 314 ADMIN
(dos omisiones previas). En el árbol compartido, después del punto de guardado
de las herramientas paralelas, pasan también las 186 pruebas Trainer y las
315 ADMIN. Las regresiones cubren ceros, ausencia total y parcial, apertura y
cierre repetidos, tiempos legibles, AMRAP y móvil a 320 px con texto doble.
La captura de los widgets reales con datos de ejemplo se contrasta fuera de Git.
La publicación se retrasa inicialmente por un fallo del proceso de control del
navegador y se completa tras el reinicio de Codex, con comprobación del hosting.

Fuentes funcionales `793adbf84d1ccc0fd8b62053ce293e1bc4332400` guardadas en main.
Las compilaciones Release Dev de deportista y Trainer terminan correctamente,
igual que la [CI de Garmin e iOS](https://github.com/jchjdev/entrenaop/actions/runs/40071871325).
Paquete publicado en `trainer.entrenaop.es`, proyecto `sxbxfjqgoddzhtcyhalw`,
release `793adbf84d1ccc0fd8b62053ce293e1bc4332400-20261024-1`, ZIP SHA-256
`b727205435bd5a9cad0c7e0e8ba74e3996345dedfe128c0931c9f1cf11a41a7c`.
Se compila y empaqueta en salidas separadas del otro trabajo compartido.

Con autorización expresa de Javier se coordina la publicación con el chat de
entrenadores, evitando cargas simultáneas. Tras el reinicio, el navegador vuelve
a responder: se carga el ZIP en `trainer-releases` y se extrae únicamente en
`public_html/trainer`, conservando las releases anteriores. El verificador HTTPS
acredita la revisión exacta, JavaScript, entrada, cabeceras y WebAssembly.
La ficha autenticada existente confirma ejercicios plegados al entrar; banca
muestra solo repeticiones, tiempo y carga al abrirse, sin distancia, RPE o RIR
ausentes. Carrera permanece plegada y separada. La comprobación no guarda notas,
resultados ni revisiones; la captura real permanece privada fuera de Git.
No se modifica producción ni se utilizan las credenciales FTP confinadas de
ADMIN para otro destino.

## Recorrido implementado

La agrupación de UI-065 se extiende el 24/10/2026 al historial del deportista
mediante su modelo de ejecución existente. Fuerza comienza plegada, con el
mismo criterio de bloque/posición/ejercicio y paleta por formato. Ofrece
«Desplegar todo / Plegar todo» y conserva los controles de corrección dentro
del detalle; plegar no escribe datos ni modifica las series. La vista profesional
publicada conserva su paquete y sus permisos. Esta extensión no despliega Trainer.
Verificación de la extensión: 1.314 pruebas raíz correctas, una omisión previa
y análisis completo sin incidencias. Trece pruebas del historial cubren además
el plegado conjunto, los tiempos originales, identidades separadas, datos
variables/ausentes, la corrección con RIR heredado y móvil a 320 px con texto
doble. AMRAP conserva sus vueltas y parciales; carrera no se convierte en series
de fuerza ni se ocultan sus tramos con este control.
Código funcional `bad6d08c` subido a main. Web Release Dev compilada desde
fuentes limpias; la vista local autenticada acredita el resultado de fuerza
existente en una tarjeta cerrada, apertura de sus tres series, correcciones
visibles y plegado conjunto. No hay errores ni avisos de consola en ese
recorrido. Capturas privadas fuera de Git; ninguna corrección o marca se guarda
durante la comprobación. La aceptación física del menú en iPhone requiere Pull
de main y la instalación habitual con Xcode.
La [CI 40036880351](https://github.com/jchjdev/entrenaop/actions/runs/40036880351)
termina correcta en servidor, consumidor e iOS Release sobre `bad6d08c`.

Javier pide aprovechar Harbiz e implementar el recorrido con nuestros creadores.
El preparador entra en Mis sesiones privadas, crea una receta con el editor
compartido y abre Planificación y resultados de un alumno. Selecciona sesión y
fecha, consulta la receta concreta, añade indicaciones y confirma. El alumno
recibe la pauta en su agenda, ejecuta y registra resultados mediante el motor
existente. El preparador consulta el resultado desde esa pauta, sin corregirlo
en nombre del alumno.

La biblioteca y las pautas tienen paginación. Revisar crea otra versión y archiva
la anterior: no actualiza las pautas existentes. Crear no asigna ni publica en
el catálogo oficial. Se utilizan ejercicios públicos; las subidas profesionales
y sus cuotas no se implementan aquí.

## Reutilización y datos

`trainer_workout_repository.dart` aporta catálogo, guardado, identidad y RPC al
`WorkoutEditorPage` de `workout_editor_ui`. Se reutilizan modelos, validación y
codec de `workout_core`, formatos convencionales y carrera. No hay otro editor.

El lector existente de ADMIN se traslada como `WorkoutTemplateContent` al mismo
paquete. `AdminWorkoutContent` conserva su API como adaptador. Biblioteca y
confirmación profesional utilizan ese lector, no una maqueta ilustrativa.
Sus dependencias transitivas se fijan a las versiones verificadas en ADMIN.

`workout_templates` conserva origen `coach`, dueño preparador, visibilidad
privada, familia y versión. Los constructores/validaciones SQL existentes se
reutilizan mediante contexto interno autorizado, siguiendo el patrón oficial
previo: la receta nace fuera de la cuota personal. `trainer_assignments` fija
etapa aceptada, participantes e indicaciones y enlaza con `scheduled_workouts`.
La cita conserva versión, estado y ejecución; no se crea otro historial.

La app carga solo sus propias citas incluso si la identidad también es ADMIN.
Mi semana muestra las indicaciones y el origen ENTRENADOR y no ofrece la pauta
como cita personal reprogramable. Inicio/agenda conservan TRN-014. Sin pautas no
se añade una sección profesional nueva en Inicio. El historial y la corrección
de resultados del alumno siguen siendo los existentes.

## Permisos, reintentos y baja

Autoría/asignación exigen MFA y acceso profesional vigente en servidor. Consultar
biblioteca, cartera y resultados propios exige MFA; no se inventan reglas
comerciales de pérdida del historial. El consumo asignado no exige Pro y el
vínculo no amplía las cuotas personales Free de 8 ejercicios y 4 sesiones.

Las RPC públicas nuevas son invoker; las operaciones privilegiadas viven en
`trainer_private`. El cliente no escribe recetas coach ni sus hijos directamente.
ADMIN ajeno tampoco obtiene lectura de recetas, citas ni ejecuciones coach por
su permiso general. El resultado profesional se entrega desde su asignación,
sin abrir el historial global del alumno. El motor interno de inicio no tiene
EXECUTE para authenticated.

El alumno inicia desde su cita activa, nunca pasando el ID a inicio suelto,
duplicación o programación personal. Solo ve recetas asignadas o realizadas.
La baja retira pendientes, permite terminar lo iniciado y conserva consulta de
lo realizado y el historial propio del preparador. Descartar después de la baja
no reabre una pauta. Volver requiere la aceptación prevista en TRN-015.

Cada guardado/asignación conserva su UUID de orden al reintentar; reenviar otros
datos con ese UUID se rechaza. El formulario bloquea datos tras una respuesta
incierta. No hay recuperación persistente del borrador profesional al recargar.

Asignación e inicio respetan el bloqueo por alumno existente. Asignar incrementa
la versión interna de membresía: una baja REPEATABLE READ con snapshot anterior
debe reintentar y ver la pauta antes de retirar pendientes. No cambia cupos ni
la revisión administrativa del acceso.

## Verificación · 21/10/2026

Aplicadas solo a Dev `20261021122051_trainer_private_workouts_and_assignments.sql`
y `20261021124130_trainer_workout_read_policy_and_write_index.sql`. Coinciden
181 migraciones locales/remotas. Doce contratos SQL pasan con ROLLBACK: recorrido
nuevo, acceso/cartera/MFA, cuotas, autoría ADMIN, visibilidad, papelera, tipo
histórico, descarte, AMRAP e instrucciones. El contrato nuevo vuelve a pasar
después de aplicar. Cero usuarios, pautas y recetas coach de ensayo restantes.

El runner local acredita 33 contenciones reales en PostgreSQL 17.6: 21 anteriores
y 12 asignación/baja, ambos órdenes y READ COMMITTED/REPEATABLE READ. Para estas
últimas utiliza las RPC reales y catálogo/citas mínimos; recetas, RLS y resultados
completos se verifican en Dev. No equivale a dos móviles por HTTP.

Análisis limpio; 1144 pruebas deportista (una omisión previa), 301 ADMIN (dos
previas), 15 panel y 67 paquete común correctas. Seis regresiones nuevas cubren
reintento, vista previa concreta, receta al revisar, espera de confirmación,
consulta inactiva, resultado AMRAP y 320/1200 px con texto 2×. Agenda prueba indicaciones/acciones.
Ocho capturas reales de widgets cubren biblioteca, ficha, asignación y resultados.
[Ficha de ensayo](visual-audit/trainer-private-workouts-2026-10-21/client-desktop.png).

Los asesores no señalan WARN nuevos. Se corrige la FK nueva sin índice y se
consolida la lectura de plantillas conservando el catálogo anónimo. Quedan INFO
esperados de [índices recientes sin uso](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
y [RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
en el registro privado sin grants. Los avisos anteriores ajenos a este cambio
permanecen fuera de alcance.

Panel publicado en `trainer.entrenaop.es`, conectado solo a Dev. Publicación
`efff7227653cea6b37e26f6c362a6b7c0e4e03e8-20261021-4`, ZIP SHA-256
`a3be588ea2d7fe916021090160ee54505fc27490b82860176791c831546ef867`.
El verificador HTTPS acredita manifiesto, hash, entrada, cabeceras y WebAssembly.
Chrome conserva la sesión MFA de Javier, carga la biblioteca y abre el creador
con catálogo autorizado; no se guardan recetas ni pautas reales. Se conservan
miniaturas de Storage y la ficha técnica de carrera no aparece en el selector
de fuerza, igual que en ADMIN.
[Biblioteca publicada](visual-audit/trainer-private-workouts-2026-10-21/published-library.png)
y [creador publicado](visual-audit/trainer-private-workouts-2026-10-21/published-editor.png).

Los cambios del deportista todavía no están distribuidos; no hay aceptación
humana con dos cuentas ni ejecución en dispositivos. No se declara desplegado
en producción. El recorrido de resultados se acredita con SQL y widgets reales
con fixtures, no con el guardado de entrenamientos en la cuenta de Javier.

No incluye programas privados, recurrencia, calendario mensual del preparador,
mensajería, edición de pautas empezadas, purga definitiva, subidas privadas,
algoritmo profesional ni cobros. El único siguiente recorrido recomendado es
programas privados con composición reutilizada y asignación versionada.
