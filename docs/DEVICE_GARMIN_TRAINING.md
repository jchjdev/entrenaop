# Envío común de carrera · INT-007 · 22/10/2026

Esta página conserva la primera fase manual y su aceptación. INT-010 amplía
ahora el ciclo con publicación automática, cambios y retirada de citas futuras,
solo en Dev: [contrato y estado actual](DEVICE_GARMIN_AUTOMATIC_SYNC.md).

Javier autoriza implementar y probar una primera carrera en Garmin, solo en
desarrollo, manteniendo Clean Architecture y reutilización por entrenadores.
El recorrido de cuenta de INT-005 está aceptado desde navegador. El equipo
físico elegido es su fēnix 8 ya enlazado a Garmin Connect; el fēnix 6X queda
como posible segundo dispositivo de comprobación, sin cobertura acreditada aún.

## Contrato compartido y límites

El servidor recibe una cita y su revisión, nunca una receta dictada por Flutter.
`device_private.training_source` proyecta la jerarquía publicada existente de
`workout_templates/blocks/items/sets`, fecha, versión y autoridad. Para algoritmo
exige decisión/objetivo propios activos; para entrenador exige asignación propia,
relación y servicio profesional vigentes. Biblioteca, usuario y preparación
genérica quedan fuera de esta primera exportación, conforme a INT-006.

`garmin-training` admite al alumno sobre sí mismo y al preparador sobre sus
propias asignaciones del alumno, con aal2 tanto en JWT verificado como en sesión
persistente. La concesión Garmin pertenece siempre al alumno. El preparador no
obtiene tokens ni identidad Garmin, no puede enviar pautas de otros profesionales
y no sustituye el consentimiento del deportista. El alumno profesional no
necesita contratar Pro adicional.

La primera interfaz de selección/revisión está en Perfil → Conexión con Garmin
→ Enviar una carrera de la app del deportista. Trainer puede consumir el mismo
endpoint mediante su adaptador de presentación y `client_id`; su pantalla todavía
no incorpora ese botón. No se cambia Inicio, Preparador ni el portal profesional.

## Clean Architecture

| Parte | Responsabilidad |
| --- | --- |
| `device_training/prescription.ts` | Modelo puro de carrera y normalización de la receta ya existente; sin HTTP, Garmin, SQL o Flutter. |
| `device_training/delivery.ts` | Servicio de aplicación y puertos de persistencia, proveedor, cuenta y cifrado; revisión, orden de efectos y resultado incierto. |
| `garmin/training.ts` | Traducción a Training API y transporte HTTP del fabricante. |
| `garmin/training_http.ts` | Composición, Auth, cuenta esperada y adaptador RPC; cerrado a Dev por la configuración existente. |
| Dart `features/device_training` | Dominio de presentación sin SDK, repositorio Supabase con aislamiento por sesión y Cubit/vista previa. |

Se reutiliza la receta común, sin copiar el algoritmo o el editor ni introducir
paquetes externos. El endpoint compartido evita otro motor de Garmin para
entrenadores. INT-009 añade la semántica de paso/manual a la receta y su snapshot de
ejecución sin cambiar autoridades de pauta. [Detalle](RUNNING_STEPS_V2.md).

## Compatibilidad de la primera entrega

Se contrasta Training API V2 2.0, páginas 4–9 y 18–20, descargada desde el
[portal oficial](https://developerportal.garmin.com/developer-programs/programs-docs).
El archivo completo y sus anexos permanecen locales e ignorados por Git.

- Carrera de un deporte, secuencia plana de hasta cien pasos contando
  recuperaciones. No representa circuitos/rondas o modalidades mixtas.
- Duración en segundos, distancia en metros o avance manual OPEN; nunca se
  mezclan medidas ni se inventa duración para Lap. Se conserva recuperación
  final prescrita. Los metadatos V2 ya distinguen calentamiento y enfriamiento.
- Ritmo opcional en segundos/km convertido a PACE en m/s, invirtiendo extremos:
  mínimo de velocidad = 1000 / ritmo lento. No se inventan zonas o pulso.
- Recuperación pasiva, andando o trotando en su medida original. Andar/trotar y
  RPE se conservan como instrucciones visibles; no se simula una alerta de
  marcha o de RPE que el reloj no ofrece como objetivo.
- Instrucciones de sesión y de cada paso conservadas dentro de los límites del
  fabricante; si exceden capacidad o hay campos no representables se bloquea,
  sin truncar ni omitir instrucciones. Límite inicial de nombre: ochenta caracteres.

La vista previa muestra fecha, instrucciones, todos los pasos y ritmos. El
usuario confirma que los ha revisado antes de enviar. La versión se vuelve a
comprobar en servidor justo antes de cada escritura externa.

## Orden persistente y concurrencia

`20261022132601_garmin_running_training_delivery.sql` añade recibos privados por
propietario/cita/proveedor y un lease de uso de la conexión de tres minutos.
Solo la fachada RPC de servidor tiene EXECUTE para `service_role`; no hay acceso
directo de clientes ni de `service_role` a la tabla. RLS queda activado como
defensa adicional. El recibo conserva snapshot, revisión, versión del adaptador,
generación de conexión y referencias remotas.

El UUID histórico de cita se conserva sin FK que bloquee un reset de agenda o
elimine la evidencia remota por CASCADE. Antes de cada nuevo efecto se vuelve
a resolver su existencia/autoridad. Una cita eliminada no autoriza otro envío.

1. Reclamar una única orden y verificar cuenta, sesión, derecho, prescriptor y
   revisión. Una segunda petición concurrente no recibe las credenciales.
2. Si hace falta renovar OAuth, registrar previamente el estado de rotación y
   persistir el refresh token nuevo antes de cualquier otra operación. Una
   rotación incierta detiene el envío y deja la conexión pendiente de retirada.
3. Verificar identidad Garmin y permisos actuales. No basta el permiso almacenado.
4. Registrar `creating` antes de POST del entrenamiento; guardar su workout ID
   antes de registrar `scheduling` y enviar su fecha.
5. Consultar el calendario por fecha y comprobar una referencia única al workout;
   solo entonces guardar `sent`. Un 204 aislado no acredita el calendario.
6. Liberar lease y completar una retirada que hubiera coincidido con el envío.

La desconexión impide nuevos pasos externos; la revocación espera mientras se
usa la concesión. Un refresh ya devuelto o un efecto externo ya aceptado se
pueden persistir/limpiar aunque el usuario cierre sesión o termine el vínculo.
Eso no permite nuevas escrituras en Garmin tras perder autoridad.

Un POST sin respuesta fiable nunca se repite automáticamente. Se conserva como
incierto y se pide comprobar Garmin. Si el workout quedó confirmado en base de
datos, un rechazo conocido al agendar reutiliza ese ID. Una respuesta perdida
del guardado no borra un recibo final ya confirmado. Hay treinta segundos mínimos
entre reintentos de una orden fallida.

Cambiar receta/fecha o cambiar de conexión tras un posible efecto remoto exige
revisión, sin crear otra copia silenciosamente. Reconectar tras un fallo conocido
sin workout creado sí puede continuar la misma orden. No hay actualización,
retirada de una sesión ya enviada o conciliador de resultados inciertos en esta
primera fase. Desconectar la cuenta no elimina entrenamientos que ya están en Garmin.

## Aceptación y operación Dev

Activado exclusivamente en `entrenaop-dev` (`sxbxfjqgoddzhtcyhalw`): migración
`20261022132601` aplicada y sincronizada con el historial; `garmin-training`
ACTIVE v1 y handlers de cuenta/callback ACTIVE v5. Las credenciales de INT-005
se reutilizan sin reenviarlas ni regenerar la clave de cifrado. Después se
instala la app en iPhone y se acredita el primer envío/recepción nominal.

Validación: 109 pruebas Node, tipos estrictos, ocho pruebas Flutter nuevas y
batería raíz completa 1.278 correctas/una omisión previa; análisis limpio.
SQL transaccional completo contra Dev con ROLLBACK antes y después de aplicar,
sin usuarios sintéticos ni entregas restantes; concurrencia real en PostgreSQL
local. También pasan las regresiones transaccionales existentes de agenda y
revisión de asignaciones del preparador. El asesor solo añade la información
esperada de RLS sin políticas en la tabla privada sin acceso directo.

[CI 39791868190](https://github.com/jchjdev/entrenaop/actions/runs/39791868190)
correcta para `7c05f8cd2edf015ed4062ca3bcd46250bdaf5fd8`. Petición al endpoint
nuevo sin sesión: 401. Esta evidencia automática no acredita por sí sola una
entrega. La comprobación física posterior se describe debajo.

La API crea el workout y después su cita de calendario. En la especificación
consultada, creación usa `/workoutportal/workout/v2` y agenda/consulta usan
`/training-api/schedule/` y `/training-api/schedule?startDate=…&endDate=…`.
Solo se permiten destinos oficiales fijos, sin redirecciones; timeout por petición
de diez segundos y respuestas limitadas. Logs de errores: operación/estado/código
cerrados, nunca cuerpos, fechas, nombres, tokens o URLs de retorno.

La prueba utiliza una cita de entrenador autorizada y revisada por el alumno.
Javier pide probar desde el iPhone al no tener el PC disponible: el preparador
`bash tools/prepare_iphone_dev.sh` deja Release Dev listo para instalar desde
el esquema existente Runner iPhone en el Mac, sin copiar secretos. El recorrido
de instalación y autorización móvil está en [la guía iOS](IOS_DEVELOPMENT.md).
La [CI 39796122054](https://github.com/jchjdev/entrenaop/actions/runs/39796122054)
de `87f63de69a5f0fbeb804e347cc82cd663520cac6` termina correctamente en backend,
consumidor Flutter e iOS Release sin firma.

### Primera recepción física y diagnóstico · 22/10/2026

Javier confirma la instalación en iPhone. Las capturas muestran la sesión de
EntrenaOP en Garmin Connect y el vídeo muestra su carga, listado de pasos,
inicio y avance en fēnix 8 durante una prueba de banco. Dev acredita `sent`,
sin error, con referencias de workout y calendario persistidas. Es evidencia
del recorrido nominal de nube y reloj, no de completar la carrera o de validar
todos los rangos, avisos y recuperaciones durante su ejecución.

Javier señala que los pasos necesitan perfeccionamiento. La comparación del
vídeo con la receta persistida permite separar tres cuestiones:

- Garmin Connect muestra origen y notas, pero oculta el desglose de la sesión
  externa. Garmin lo describe también para sesiones de TrainingPeaks en su
  [soporte oficial](https://support.garmin.com/en-HK/?faq=jnm4aY5LM880wNP6LWm1n8&searchType=noProduct).
  Esa pantalla no demuestra por sí sola pérdida de pasos.
- El listado del reloj muestra ritmos únicos compatibles con valores centrales
  de los rangos prescritos. El adaptador conserva ambos extremos en m/s; el
  vídeo no demuestra todavía que las alertas respeten ambos límites. No se
  reemplaza el rango por una media para imitar el resumen del reloj.
- La receta agrupa los tramos bajo una etiqueta genérica y Garmin presenta
  recuperación andando/trotando bajo su intensidad común RECOVERY. Las
  instrucciones distintivas se envían como descripción. No inventar objetivos
  de ritmo o cambiar la prescripción para obtener otro rótulo del fabricante.

Al contrastar el formato se elimina `durationValueType=METER`: la especificación
V2 2.0 reserva ese modificador a HR/POWER (`PERCENT`); TIME ya expresa segundos
y DISTANCE metros. Una regresión comprueba unidades nativas y conversión
inversa de ambos límites de ritmo. No hay evidencia de que ese campo causase
la presentación observada; la corrección no se presenta como solución probada
de las etiquetas ni modifica o duplica la sesión ya entregada.

El ajuste pasa las 110 pruebas de servidor y tipos estrictos y se publica solo
en Dev como `garmin-training` ACTIVE v2. Petición sin sesión: 401. El recibo
anterior conserva `sent`, referencias confirmadas y lease liberado; no se
reescribe ni se vuelve a enviar. Este cambio de servidor no exige reinstalar iOS.

Siguiente tramo único tras INT-009: comparar la nueva receta con calentamiento
y enfriamiento hasta Lap, cinco series y recuperación en EntrenaOP y fēnix;
verificar transiciones y ambos límites de ritmo antes de ampliar objetivos.
[Implementación y pruebas](RUNNING_STEPS_V2.md). Las capturas, el vídeo y las
métricas exactas se conservan fuera de Git; solo se registra el resumen técnico.

Sigue pendiente antes de producción la limpieza de la cuenta externa al borrar
Auth, conciliación de permisos fuera de la app, rotación operativa de clave y
recuperación de efectos inciertos ya señaladas en INT-005. No se modifica producción.

## Carrera física completa · 23/10/2026

Javier realiza una carrera con la pauta creada en Trainer, asignada a su cuenta
de alumno y entregada al fēnix 8. Confirma expresamente que funcionaron los pasos,
recuperaciones, avance con Lap y avisos de ritmo. La actividad en Garmin Connect,
consultada en navegador y contrastada con sus capturas, contiene las cinco
repeticiones esperadas. Es aceptación de una ejecución real, además del ensayo
de recepción del día anterior.

La consulta de solo lectura a Supabase Dev comprueba origen profesional,
entrega `sent`, referencias de entrenamiento y calendario presentes y snapshot
V2 con calentamiento manual, cinco trabajos con recuperación por tiempo y
enfriamiento por tiempo. No se vuelve a enviar ni se altera la pauta. La
pregunta de aceptación mencionaba enfriamiento hasta Lap; el snapshot acredita
enfriamiento temporizado, por lo que ese caso sigue pendiente. Tampoco se han
medido separadamente ambos umbrales de alerta.

La cita continúa planificada: esta comprobación no importa la actividad ni
confirma resultados del alumno. El ciclo de cambios/cancelaciones automático,
la omisión de última recuperación, nuevos objetivos y otras marcas conservan
su aceptación pendiente. No se guardan en Git correo, identificadores de
cuenta/asignación/actividad, recorrido, capturas ni métricas exactas.


## Retorno de esa carrera · actualización del 23/10/2026

La comprobación anterior era de solo lectura. INT-012 implementa después el
retorno: reenvío oficial del FIT, recepción privada y confirmación desde la app
web Dev con el esfuerzo declarado por el alumno. La cita ahora figura
completada, con una única ejecución sobre la versión original, parciales del
reloj y un recibo. Auto Lap se agrupa por evidencia nativa; no se atribuyen los
totales a las series ni se envía otra pauta al reloj. El nuevo menú del iPhone
requiere actualizar desde main. [Contrato y aceptación](DEVICE_GARMIN_ACTIVITY_RETURN.md).

## Fuerza · recorrido solicitado INT-013

Javier solicita y autoriza implementar el mismo recorrido para fuerza el
23/10/2026, solo en desarrollo. El creador común ya existe en deportista,
ADMIN y Trainer y conserva su receta. La primera entrega amplía el adaptador
de envío y el lector FIT; no añade un editor paralelo.

El recorrido deseado es crear una única receta propia, asignarla a la semana,
enviarla al reloj con cambios y cancelaciones, recibir lo realizado y completar
la misma cita con sus datos y esfuerzo declarado. Se reutilizarán las fronteras
de cuenta, permisos, entrega e historial, manteniendo los detalles de Garmin
en sus adaptadores; no se creará un segundo editor o resultado para Trainer.

La especificación oficial Training API V2 2.0 consultada (páginas 4–9 y anexos
A/B locales) contempla `STRENGTH_TRAINING`, ejercicios de catálogo, duración
por repeticiones y carga en kilogramos. Esto no acredita equivalencia completa
de superseries, Tabata ni los demás formatos del creador. Antes de modificar
el contrato se contrastarán esas capacidades y los campos realmente devueltos
en FIT con el catálogo propio y los resultados existentes.

Primera cobertura implementada: `straight_sets`, una ronda, trabajo por
repeticiones o tiempo, carga opcional y descansos individuales explícitos.
Equivalencias de catálogo versión 1: `bench_press_barbell`, `push_up_standard`
y `pull_up_pronated`. Se contrastan con los anexos oficiales A/B y con categorías
y subtipos del perfil FIT. No se asocian por nombre traducido ni semejanza muscular.
La primera fuente exportable de fuerza es una asignación profesional vigente;
la política comercial y las autoridades de prescripción existentes se conservan.
Superseries, circuitos, Tabata, otros ejercicios, calentamientos de fuerza y las
prescripciones especializadas de rendimiento del algoritmo siguen sin soporte.
Se bloquean; no se aplanan ni se convierten en carrera.

El dominio puro `device_training/strength.ts` normaliza la receta propia; el
adaptador `garmin/strength.ts` traduce a `STRENGTH_TRAINING`, `REPS`/`TIME`,
ejercicio de catálogo y kilogramos. Entrega, renovación, exclusión mutua,
actualización y cancelación reutilizan los servicios existentes. El snapshot
de fuerza añade deporte y código propio de ejercicio; los snapshots y hashes
anteriores de carrera permanecen iguales. Los datos del fabricante siguen
fuera del creador, de los motores y de los modelos compartidos de autoría.

El lector reconoce FIT de una sesión `training/strengthTraining`. Guarda una
observación V2 con series activas y descansos, tiempo, repeticiones y carga
medida; distancia ausente se conserva como NULL. No guarda GPS ni FIT completo.
Una propuesta automática exige índice nativo y ejercicio inequívocos; si falta
evidencia se elige la serie explícitamente. Solo una serie activa por resultado;
no se reutilizan series ni se mezclan deportes. El backend obtiene todas las
marcas de la evidencia privada, nunca de campos aportados por Flutter.

La prescripción no rellena repeticiones o cargas ausentes del reloj. Una serie
por repeticiones exige ese dato para confirmarse; un peso ausente sigue ausente.
El esfuerzo global continúa siendo declarado por el alumno. Confirmar reutiliza
el cierre deportivo, completa la cita y expone el mismo resultado profesional;
no crea otra ejecución para Trainer ni completa por recibir una notificación.

Migración `20261023123635_garmin_strength_roundtrip.sql` y funciones
`garmin-training`, `garmin-training-sync`, `garmin-activities` y
`garmin-activity-ingest` activas exclusivamente en Dev. Verificados fixtures
SDK oficiales, tipos estrictos, 151 pruebas de servidor, 1.308 pruebas raíz
(una omisión previa), 172 Trainer y compilación web Release Dev. Contratos
SQL de carrera y fuerza pasan con ROLLBACK: precisión, carga ausente,
repeticiones distintas de la pauta, duplicación, descanso usado como trabajo,
mezcla de deporte, atomicidad y lectura profesional MFA. Avisos globales del
asesor de seguridad previos al bloque se conservan; las tablas privadas siguen
cerradas por RLS/grants y RPC específicas.

Punto de guardado funcional `9c5c9a27`, verificado el 23/10/2026:
[CI completa](https://github.com/jchjdev/entrenaop/actions/runs/39968612833)
correcta en backend, aplicación e iOS Release. El compilado web de Trainer
`6f15d325ed6d0fc64a451cc526b1172821dbba47-20261023-1` se publica tras la
autorización expresa de Javier; los cambios posteriores no afectan a sus fuentes
consumidas. Verificación HTTPS correcta y Chrome muestra el resultado existente
con tiempo total `m:ss` y tiempos originales por serie, sin errores de consola
en ese recorrido. La actualización del iPhone sigue el flujo habitual
Fetch/Pull de main y Xcode, conservando la configuración de desarrollo.

Primera salida real comprobada: sesión convencional creada y asignada mediante
Trainer Dev, revisada y enviada desde EntrenaOP Dev. Garmin acepta la creación
y se comprueba el identificador de calendario: recibo `sent`, sin errores.
La cuenta tenía desactivada la sincronización automática; no se altera esa
preferencia ni se envían otras citas. Las referencias, la cuenta y las capturas
quedan privadas fuera de Git. La infraestructura admite cambios/cancelaciones
de recetas compatibles; fuerza automática y retirada en proveedor conservan
aceptación externa pendiente. Los formatos incompatibles requieren revisión,
sin publicarse como otra receta.

El ensayo técnico con fēnix 8 se completa después con una actividad simulada,
no con una sesión física de fuerza realizada. La actualización
de menús y tiempos requiere instalar main en iPhone; la revisión existente de
Trainer ya muestra repeticiones, kilos y reloj `m:ss`. El paquete web de Trainer
se actualiza con la autorización posterior; ADMIN no se despliega en esta entrega.

Aceptación técnica con dispositivo real · 23/10/2026: el vídeo acredita la
receta de banca y sus instrucciones en el fēnix; Garmin Connect conserva las
series y la actividad FIT entra automáticamente en Dev (`done/stored`, sin
error). Se contrastan sus repeticiones, cargas y tiempos con la vista Garmin.
El archivo no resuelve el código propio de ejercicio de forma inequívoca;
la revisión exige seleccionar explícitamente cada serie activa, como establece
el contrato, conservando descansos separados y sin reutilizar registros.

Desde la app se revisan las tres correspondencias y se completa exclusivamente
la cita de prueba, conservando como esfuerzo la autoevaluación declarada en
Garmin. SQL acredita una confirmación, la misma cita/ejecución completadas y
resultados de fuente `device` con los tiempos originales. Trainer muestra ese
mismo resultado sin errores ni avisos de consola; no se marca la revisión
profesional como realizada. Identificadores, métricas exactas, vídeo y capturas
permanecen privados fuera de Git. Es aceptación de transporte, revisión y cierre
con actividad simulada, no de ejercicio físico, carga efectiva ni detección
automática de repeticiones. No acredita otros ejercicios, formatos, cambios o
cancelaciones automáticos de fuerza. Siguiente ensayo: sesión convencional
real con marcas distintas de la pauta, sin ampliar todavía las equivalencias.

Compatibilidad de lectura: el cliente nuevo pide `activity_schema_version: 2`.
Sin esa petición el receptor de usuario devuelve solo observaciones/candidatas
de carrera V1, conservando la fuerza privada para cuando se actualice la app.
Una vista previa V2 se rechaza en un cliente V1. El indicador de protocolo se
retira antes de llamar al RPC, por lo que no altera el hash ni los reintentos
de una confirmación anterior. No cambia permisos, recepción automática o cierre.

## Tiempos, comparación y perfil del reloj · INT-014

El detalle de historial muestra tiempos de objetivo, realizado, recuperación
y totales como reloj `m:ss`; no recorta los segundos de los totales. Trainer
ya utiliza ese formato en sus resultados y su informe de evolución también
lo aplica a mínimos/máximos; el CSV mantiene números y unidades explícitas.
No se modifica ninguna medición.
La comparación conserva sus tolerancias y explica tiempo, distancia, ritmo o
recuperación diferentes por tramo. El rótulo pasa a «Diferencias con la pauta»
y aclara que no es una nota deportiva ni la puntuación de Garmin.

La migración `20261023132658_garmin_activity_native_timing.sql` añade
`observed_duration_seconds` y `observed_recovery_duration_seconds` numéricos
en cada resultado, manteniendo intactos los enteros anteriores. Mostrar tiempo
original y calcular el ritmo desde él evita que redondear primero cambie la marca.
Solo RPC internas los escriben; el cliente conserva SELECT con su RLS vigente.
Una corrección manual o un cambio de tiempo entero elimina la precisión previa.
El enriquecimiento histórico usa exclusivamente el recibo y observación privados,
cuando fuente, estado y marcas actuales coinciden con lo medido; no toca marcas
corregidas ni atribuye totales a series. El dominio, su codec y proyección de
consulta conservan esa precisión y retrocompatibilidad; Trainer puede leerla
en el mismo resultado. SQL prueba descarte manual y prohibición de escritura
directa; Dart prueba cálculo de ritmo y conservación del dato en copias.

El envío de carrera sigue con deporte genérico `RUNNING`; la implementación
no selecciona Pista o Trail ni ha cambiado ahora ese comportamiento. El manual
del fēnix 8 permite elegir primero la actividad y después Biblioteca/Calendario
de entrenamiento, mostrando solo sesiones compatibles. Sin repetir el recorrido
del usuario no se atribuye a un fallo o a una elección suya el perfil observado.
Su puntuación Garmin pondera sobre todo los pasos activos y no puntúa el
enfriamiento; los promedios de las series no permiten reconstruir esa nota.
[Puntuación del fēnix 8](https://www8.garmin.com/manuals/webhelp/GUID-EECCAC99-90D6-4AB1-9A3A-EC433D3365E2/EN-US/GUID-FD71D73A-C744-4779-A6C3-2FA9AB89B228.html).

## Ejercicios privados de fuerza · INT-015 · 26/10/2026

La restricción a tres ejercicios era el alcance de nuestro primer adaptador,
no una prueba de que Garmin impida cualquier otro ejercicio. Javier solicita
ampliarlo y probar una sesión profesional propia, reutilizando «Para mí».

`strength_snapshot` conserva la autoridad resuelta por `training_source` y
acepta ejercicios públicos o privados del autor de la plantilla profesional.
Un ejercicio privado ajeno sigue rechazado. No cambia cuentas, MFA, relaciones,
RLS ni acceso directo: las proyecciones permanecen internas y sin EXECUTE para
clientes o service_role. Las recetas anteriores de carrera no cambian.

Las equivalencias explícitas de banca, flexiones y dominadas se conservan.
Los demás ejercicios llevan `exercise_code: null`, con nombre y notas propios.
El adaptador omite `exerciseCategory` y `exerciseName` en esos pasos y conserva
nombre/notas en `description`, con repeticiones o tiempo, peso si estaba pautado
y descansos explícitos. Training API V2 2.0, páginas 7–9, documenta las
instrucciones del paso y sus campos de catálogo; el ensayo real debe comprobar
la aceptación de su omisión y cómo los presenta cada reloj. No se envían nombres
inventados del catálogo ni se sustituye calistenia por otros movimientos.

Continúa el límite de cien pasos, sin truncar instrucciones ni admitir medidas
no traducidas. Superseries, circuitos y otros formatos pendientes siguen
bloqueados, aunque sus ejercicios individuales sean compatibles. Esta entrega
no convierte una sesión de carrera técnica mixta en carrera estructurada.

Al volver una actividad, dos códigos NULL no prueban identidad de ejercicio.
Incluso con índice de paso, la correspondencia de ejercicios genéricos requiere
selección explícita. No se completan resultados ni se copian dosis como marcas.
Se conserva el cierre existente de la misma cita y su revisión por el alumno.

Validación en Dev: migración `20261026080243` aplicada; contrato nuevo de
privacidad/dosis/permisos y regresiones SQL de fuerza, carrera, sincronización
y progreso terminan con ROLLBACK. Pasan 156 pruebas de servidor, tipos estrictos,
30 pruebas Flutter de envío/recepción y `flutter analyze`. Se publican solo
`garmin-training`, `garmin-training-sync`, `garmin-activities` y
`garmin-activity-ingest`, sin nueva compilación de los portales o de iPhone.

Primer envío real comprobado el mismo día: una sesión privada de dieciséis
ejercicios y treinta y nueve series queda `sent`, con referencias de workout y
calendario confirmadas, sin error ni duplicar su cita. Garmin Connect muestra
el nombre, la fecha y las notas. Su diálogo remite al proveedor para editar;
esa presentación no expone el listado de pasos de la sesión externa.

Una lectura autenticada de la receta mediante el GET oficial de Training API
verifica treinta y nueve pasos en STRENGTH_TRAINING. Nombre de sesión y, en cada
paso, descripción con nombre/notas originales, intensidad, medida, dosis y
objetivo coinciden con lo enviado. Confirma que Garmin acepta estos pasos sin
campos de catálogo. Después Javier confirma la recepción física: ve los pasos
en el fēnix y puede leer las notas, pero el título de los ejercicios genéricos
aparece repetidamente como «Ir». Es aceptación del transporte y detección de
una limitación de presentación; no se da por resuelta la experiencia del reloj.
El anexo oficial A/B enumera nombres nativos (por ejemplo, curl martillo o
subida de cuerda), pero no una equivalencia exacta para todos los movimientos
de calistenia de esta rutina. Una futura equivalencia debe ser explícita y
contrastada por ejercicio, sin inferirla de etiquetas ni sustituir un front lever
completo por el MODIFIED_FRONT_LEVER del catálogo. El JSON de Training API
consultado no ofrece un título de paso libre separado de description; los
campos de título de FIT pertenecen a otro formato, cuya existencia no acredita
su transmisión mediante esta API. No se modifica la pauta enviada durante
la prueba. Ejecución y retorno de una sesión privada realizada siguen pendientes.
Los identificadores, credenciales,
datos de usuario y la rutina personal permanecen fuera de Git.

Durante la conexión de esa cuenta, un intento chocó con la identidad ya ligada
a otra cuenta de la app; tras desconectarla, otro canje obtuvo un 403 al leer
permisos de Garmin y quedó en `revocation_pending`. Se reintentó exclusivamente
la retirada con el servicio existente: identidad comprobada (200), retirada
aceptada (204) y limpieza persistida de la concesión. Javier volvió a autorizar
desde la app y la conexión quedó `connected`, con ambos permisos confirmados.
No se activó por escritura directa ni se trasladaron concesiones entre cuentas.
No hay evidencia suficiente para atribuir el 403 transitorio a una causa del
proveedor. No fue necesario modificar el protocolo de conexión.

### Títulos propios: comprobación directa del 26/10/2026

Javier solicita corregir los títulos «Ir» y señala después que no puede conectar
el fēnix por USB en ese momento. No se presenta la recepción anterior como
solución completa de los nombres. Dos comprobaciones aisladas contra Training
API V2 envían un nombre libre en `exerciseName`, con categoría UNKNOWN y sin
categoría. Garmin acepta ambos entrenamientos, pero el GET devuelve ese nombre
como NULL en los dos casos. El paso de control con CURL/DUMBBELL_HAMMER_CURL
conserva la equivalencia nativa. Son pruebas sin fecha ni modificación de la cita
del alumno; no justifican inventar equivalencias para sus variantes.

Se prepara localmente un archivo FIT de la receta original usando el SDK oficial
ya fijado en el proyecto: treinta y nueve pasos, dieciséis títulos propios,
WORKOUT_STEP y EXERCISE_TITLE (mensaje 264) con categoría UNKNOWN, claves únicas
y coincidentes, y títulos después de los pasos. Lectura posterior con el SDK
comprueba CRC, nombres, notas y dosis. TIME se codifica en milisegundos en
durationValue y se verifica como duración en segundos; REPS conserva el entero.
El archivo y la rutina son privados y no se versionan en Git. No se incorpora
otro editor, una equivalencia ficticia ni un endpoint de exportación sin uso.

El SDK confirma el contenido del FIT, no su presentación física. La aceptación
posterior en el fēnix se registra en la comprobación de copia directa, debajo.
No hay una solución inalámbrica acreditada de títulos arbitrarios por la API
JSON consultada; no se ofrece la carga manual de un archivo como si corrigiera
el envío automático de la plataforma. Para producto quedan dos tareas distintas:
asociaciones explícitas de catálogo cuando exista equivalencia exacta y una vía
verificada para títulos propios que no obligue al alumno a cambiar sus ejercicios.

### Copia directa al fēnix · 26/10/2026

Javier conecta después el fēnix 8 al Windows y autoriza continuar la prueba.
El equipo lo detecta como dispositivo portátil MTP. Se genera otra copia FIT
desde la revisión privada con descansos: treinta y nueve series de trabajo,
treinta y ocho pasos de recuperación y dieciséis títulos propios. El nombre
de la copia permite distinguirla del entrenamiento recibido por Connect.
La decodificación con el SDK verifica CRC, referencias de título, notas, dosis
y setenta y siete pasos totales, dentro del límite de cien pasos.

La copia se deposita en Internal Storage/GARMIN/NewFiles, con nombre de archivo
nuevo. La relectura desde el dispositivo contiene 7.050 bytes y coincide por
SHA-256 con el archivo preparado. Javier desconecta el USB, abre la copia de
fuerza y confirma expresamente que los nombres de los ejercicios y los descansos
aparecen correctamente. Quedan comprobados el procesamiento del archivo y su
presentación en el fēnix 8, además de la recepción por MTP. No acredita todavía
la realización de la sesión ni el retorno de sus resultados. Este ensayo no
acredita que Training API JSON pueda transportar los títulos propios mediante
sincronización inalámbrica: esa integración sigue pendiente.


### Preparación de FIT reutilizable y vía Connect IQ · 26/10/2026

El generador probado por USB se extrae a
`supabase/functions/_shared/garmin/strength_fit.ts`. Consume una instantánea
validada con el mismo contrato de series convencionales; no consulta usuarios,
no decide permisos y no abre un endpoint. Conserva nombres originales por
posición de ejercicio, notas, descripción de sesión, repeticiones, tiempo,
cargas y todos los descansos explícitos. Dos ejercicios homónimos tienen
referencias distintas. La identidad y fecha de creación del archivo las aporta
el llamador para producir los mismos bytes en un reintento.

FIT limita cada campo de texto a 254 bytes UTF-8 más terminador. El generador
rechaza una pauta que no quepa; no la recorta. El peso se escribe con la escala
100 del SDK oficial y rechaza más de 655,34 kg o precisión no representable;
conserva cero y distingue carga ausente. La categoría UNKNOWN y la tabla
EXERCISE_TITLE no declaran equivalencias con el catálogo Garmin. Se mantiene
el límite de cien pasos y el rechazo de formatos no traducidos. No se modifica
el envío JSON, la cita iniciada, su historial ni el retorno de resultados.

La documentación oficial de Connect IQ describe `makeWebRequest` con
`HTTP_RESPONSE_CONTENT_TYPE_FIT`: el sistema descarga, procesa y guarda el
contenido compatible en el reloj. `PersistedContent` permite obtener el
entrenamiento instalado y abrirlo en una aplicación nativa. Es una vía candidata
para transmitir el FIT sin USB, no una comprobación física de que conserve
EXERCISE_TITLE. Requeriría una aplicación complementaria en el reloj y un
circuito de autorización de descargas, caducidad y revocación; no se implementa
un enlace público a rutinas privadas ni se reemplaza Garmin OAuth.

Antes de adoptar esa aplicación como requisito del producto quedan pendientes:
ensayo inalámbrico en el fēnix, decisión explícita de experiencia/distribución,
vinculación segura con EntrenaOP y prueba de retorno de la actividad. La app
complementaria recibiría entrenamientos para el ejecutor nativo, no duplicaría
el registro de entrenamientos de Garmin. El SDK Connect IQ se ha descargado
solo a tooling local ignorado; no hay aplicación instalada o publicada.

Fuentes oficiales:
[descargas FIT](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html#makeWebRequest-instance_function),
[contenido persistido](https://developer.garmin.com/connect-iq/api-docs/Toybox/PersistedContent.html).

Validación del generador: siete pruebas nuevas de roundtrip con el SDK oficial,
CRC, títulos UTF-8, referencias homónimas, dosis, kilos, notas, descansos,
estabilidad e invalidaciones. La batería de servidor pasa 163 pruebas. La
comprobación estricta de tipos y la CI incluyen el generador. No se publican
funciones ni nuevas versiones móviles por esta preparación aislada.

## Puente Connect IQ · INT-016 · 26/10/2026

Javier autoriza implementar y probar el puente FIT al ejecutor nativo, primero
con una muestra sintética y después con vinculación segura de cuenta. El primer
tramo queda aceptado físicamente el 26/10/2026 en su fēnix 8 de 47 mm: con USB
desconectado, EntrenaOP Dev 0.2 recibe «Entrenamiento instalado» y abre Fuerza
mediante el intent nativo. Javier elige «Solo una vez» en el selector de apertura.
Confirma Dominada con pausa, 6 repeticiones a 7,5 kg, descanso 1:30, otra serie de
5 repeticiones, descanso 1:00 y Front lever isométrico de 0:07; también las notas
«Prueba de título propio» y «Prueba de tiempo». Esta comprobación acredita la
presentación inalámbrica de nombres, notas, dosis y descansos de esta muestra.
No acredita una actividad física realizada ni el retorno de sus resultados.

### Implementación y servidor Dev

`connect_iq/` contiene una app Monkey C de ensayo exclusivamente para el fēnix 8
AMOLED de 47/51 mm (`fenix847mm`), con permisos Communications y PersistedContent.
No registra actividades: usa `HTTP_RESPONSE_CONTENT_TYPE_FIT` y abre el contenido
instalado con `Content.toIntent()`. Confirma nombre e identidad contra
`getAppWorkouts()`, que restringe la búsqueda a entrenamientos de esta app.
Un HTTP 200, un iterador vacío o contenido sin esa correspondencia nunca son éxito.
No elimina ni consulta entrenamientos ajenos.

`garmin-ciq-probe/workout.fit` sirve una única receta pública inventada:
**EntrenaOP IQ prueba 01**, cinco pasos y dos títulos propios, 713 bytes. Usa el
generador de `dc48764e`, sin modificarlo. No publica la sesión privada probada por
USB ni datos de cuenta. Identidad y fecha FIT constantes para los reintentos.
El endpoint no consulta SQL, Auth o Garmin ni recibe recetas, identificadores o
rutas de archivos. Solo GET a la ruta fija sin parámetros; POST devuelve 405 y
selección por parámetros 404. La muestra es anónima, pero el handler exige
`GARMIN_ENVIRONMENT=DEVELOPMENT` y la URL exacta de `entrenaop-dev`; cualquier otro
destino queda cerrado con 503. La futura entrega privada necesita otro contrato
autorizado; no se ampliará este endpoint con identificadores de usuario.

Desplegado y releído en Dev con versión `ciq-probe-1`, tipo
`application/vnd.ant.fit`, `Cache-Control: no-store` e igualdad de bytes con el
generador local. SHA-256:
`c31d5f0cca195936912e160358dc812dcdea25492694a01d3d426de7994c6201`.
El verificador reproducible es `connect_iq/verify-dev.ts`. No se modifican
concesiones, sesiones, citas, permisos, RLS, resultados ni el envío JSON habitual.

### Diagnóstico y artefacto aceptado

El primer intento 0.1 muestra «Contenido no reconocido». Una prueba Monkey C
reproduce un error de comparación del nombre: `==` rechaza cadenas con el mismo
texto; `equals()` hace pasar la prueba. La revisión 0.2 corrige esa comparación
y usa el contrato `PersistedContent.Content`, sin exigir una subclase concreta.
No se atribuye la causa física a esa comprobación de clase sin evidencia adicional.
El simulador 6.0.3 devuelve HTTP 200, Iterator no nulo y primer elemento nulo;
ese resultado queda separado de la aceptación física posterior del fēnix.

La descarga física tarda más de sesenta segundos. Javier sale/reabre al aparecer
el aviso, y después recibe la confirmación de instalación. El límite de espera
es un aviso de falta de callback, no prueba de cancelación ni fracaso nativo.
La app permite salir y bloquea nuevas solicitudes en esa instancia mientras
conserva la posibilidad de aceptar una respuesta tardía. El texto actual invita
a reabrir y debe pulirse en el siguiente tramo para evitar reintentos innecesarios.
No se conoce todavía la causa de la latencia ni del giro persistente de sincronía
en Garmin Connect. No se promete entrega inmediata.

SDK Connect IQ 9.3.0 y perfil oficial `fenix847mm` 6.0.3 descargados mediante el
gestor oficial tras autenticación de Javier. `build-dev.ps1` usa Java de Android
Studio si está disponible, tipos estrictos y clave local de firma fuera de Git.
Binarios, claves, SDK y logs permanecen ignorados. El PRG aceptado de la revisión
0.2 se copia a `GARMIN/APPS/entrenaop-dev-fenix847mm.prg`, sin copiar el FIT por
USB. Relectura MTP: 105.852 bytes y SHA-256 idéntico al compilado:
`40c92969006f91a0a421dffa53ebc21a33565a540d9aa41fb2d903d121c84e48`.
El PRG pendiente que MTP no reemplazaba se conserva en respaldo local antes de
copiar el definitivo. Se habilita un TXT exclusivo de esta app para diagnóstico;
no se leen logs de otras aplicaciones. Procedimiento: `connect_iq/README.md`.

### Verificación del tramo

- Tres pruebas nuevas de servidor: cierre fuera de Dev, contrato HTTP sin
  selección de datos y roundtrip FIT con CRC, títulos y dosis. Batería completa
  de servidor: 166 pruebas correctas; tipos estrictos correctos. La CI incluye
  el endpoint y sus tipos.
- Compilación Monkey C estricta sin avisos. Dos pruebas de regresión en el
  simulador: identificación por interfaz/nombre/ID y rechazo de otro nombre o ID.
  `test-dev.ps1` valida el resumen explícito del runner, que en Windows devuelve
  código 1 incluso cuando informa PASSED con cero fallos y errores.
- Versión publicada, cabeceras, bytes y rechazo de POST/parámetros releídos en
  Dev. Historial de migraciones cotejado contra Dev; sin cambios SQL ni nuevo
  contrato de base de datos. Flutter y sus paquetes no cambian en este tramo.
- Aceptación humana física de instalación inalámbrica, apertura nativa,
  nombres/notas, repeticiones, carga, tiempo y ambos descansos. No se cambia la
  cita real iniciada ni sus resultados para realizar el ensayo.

### Límites y único siguiente tramo

El recorrido cerrado es **muestra sintética → descarga inalámbrica → contenido
propio instalado → Fuerza nativa con títulos y descansos correctos**, solo en el
fēnix probado. No cierra publicación en Connect IQ Store, otros relojes,
duplicados tras descargas/reinicios repetidos, cambios/retirada, importación en
background, entrega privada ni retorno de la actividad por esta vía.

El único siguiente tramo es vinculación segura con la cuenta y entrega de
instantáneas autorizadas por servidor y revisión vigente, con caducidad y
revocación, recuperación tras interrupciones y control de duplicados. Sin tokens
Garmin ni credenciales administrativas en el reloj; se conserva el OAuth actual
de Training API y retorno. Debe mejorar la espera observada antes de ampliar el
piloto a sesiones personales.

La experiencia objetivo es vincular una vez y mantener sesiones actualizadas,
con Actualizar como recuperación manual. Background o Mobile SDK no acreditan
por sí solos importación FIT en segundo plano: quedan por comprobar app cerrada,
móvil en segundo plano, límites de ejecución, interrupciones, cambios y retirada.
No convertir el mínimo temporal de cinco minutos en sondeo permanente ni prometer
recepción inmediata sin conectividad. El puente no es aún requisito general del
producto ni se anuncia en Flutter como una integración personal disponible.

## Cuenta y entrega privada · INT-017 · 26/10/2026

Javier aprueba expresamente este diseño en Dev. La app del reloj obtiene un
código aleatorio de ocho caracteres válido diez minutos. En **Perfil → Garmin →
Vincular app EntrenaOP del reloj**, el usuario introduce el código, revisa el
dispositivo y la cuenta y confirma. Introducir el código no autoriza por sí solo.
La concesión dura 90 días, se puede revocar y admite cinco relojes activos.
El reloj conserva su credencial aleatoria de 256 bits; PostgreSQL solo su hash.
No recibe contraseña de EntrenaOP, JWT de usuario, tokens Garmin o claves de servidor.

### Autorización y datos

`garmin-ciq` es un endpoint distinto del ensayo anónimo. Solo funciona con URL
exacta Dev y `GARMIN_ENVIRONMENT=DEVELOPMENT`. `/account` verifica el JWT, su
sesión y la cuenta esperada; `/watch` y `/fit/<uuid>` verifican la credencial del
reloj. No se admiten credenciales en URL ni recetas del cliente. Las tablas
`device_private.ciq_links`, `ciq_limits` y `ciq_exports` no conceden acceso directo
a clientes o `service_role`. La fachada invoker solo es ejecutable por el servidor.
RLS sin políticas en estas tablas es intencional; la autoridad reside en comandos
privados con `search_path` vacío, comprobación de propietario y límites de intentos.

El permiso sigue siendo **Pro o servicio de entrenador activo**. Javier reafirma
que, sin ambos, se impiden vinculación, nuevas descargas y sincronización; solo se
conserva la consulta y retirada de los permisos propios. La credencial de 90 días
no sustituye esta comprobación. El servidor verifica el permiso y la revisión en
cada descarga; el reloj vuelve a pedir un manifiesto autorizado antes de abrir
una copia desde EntrenaOP. No abre versiones retiradas o revisiones anteriores.
Los FIT ya importados pueden seguir disponibles en la biblioteca nativa fuera de
EntrenaOP; no se promete bloqueo remoto ni se borran automáticamente.

Se consultan citas propias pendientes de ayer a los próximos 14 días, con límite
de 30 candidatas y manifiesto completo. Se reutiliza `training_source` y la
instantánea de fuerza autorizada, incluida la biblioteca privada del entrenador.
Solo se exporta lo compatible con el generador FIT. Las revisiones tienen
identidad inmutable y un número de serie estable: repetir la misma revisión
reutiliza exportación y nombre nativo. Otra cuenta, cancelación, cambio de fuente,
revisión obsoleta o pérdida de acceso invalidan su descarga. La fuerza propia del
entrenador sigue los permisos de la fuente existente, sin crear otra excepción.

### Reloj y alcance de actualización

EntrenaOP Dev 1.0 actualiza al abrir y desde **Actualizar**, consulta únicamente
sus propios `getAppWorkouts()` y recupera importaciones terminadas antes de una
interrupción por el nombre único de exportación. Un manifiesto parcial, HTTP 200
sin copia confirmada o error de red no habilitan la apertura. El aviso tras 60 s
permite esperar o salir y conserva la respuesta tardía, sin invitar a repetir.

La comprobación cada 15 minutos está desactivada por defecto; solo se registra
si el usuario la activa en el menú del reloj. Consulta una huella y cantidades,
sin nombres ni recetas, y marca cambios pendientes. No descarga FIT en segundo
plano, no borra contenido y no acredita recepción inmediata. Ante 401/403 deja de
consultar por red. El sistema puede terminar el servicio y limita cada ejecución
a 30 s; `Timer` no está disponible en ese ámbito. Referencia oficial:
[servicios en segundo plano de Garmin](https://developer.garmin.com/connect-iq/articles/core-topics/Backgrounding.html).

### Evidencia y pendientes de aceptación

- Migración `20261026123737` aplicada en Dev y cotejada con el historial.
  Contrato SQL transaccional correcto con ROLLBACK: consentimiento, cuenta/sesión,
  propietario, revisiones, retirada, cinco relojes, pérdida de servicio sin Pro,
  caducidad y revocación. Regresión de `garmin_strength_roundtrip` correcta.
- 173 pruebas de servidor correctas y tipos estrictos. HTTPS Dev confirma versión
  `ciq-private-1`, FIT sin credencial 401, reloj pendiente sin entrega 403 y retirada
  de la concesión de ensayo. Ningún aviso de seguridad nuevo; los tres INFO nuevos
  corresponden a las tablas privadas cerradas sin políticas públicas.
- `flutter analyze` limpio; batería completa raíz: 1.379 correctas y una omisión
  existente. Tras la aclaración comercial, 14 pruebas de conexiones correctas.
  Compilador Monkey C estricto sin avisos y ocho regresiones en simulador.
- PRG 1.0 de 122.508 bytes copiado al fēnix de Javier y releído por MTP con SHA-256
  `982073011a5d9e6db2caebf1b8031c9826b3c3e619d968b81cbab9438dfadbb2`.
  Esta copia no acredita todavía la vinculación ni la presentación física privada.

La vinculación física con cuenta real queda comprobada: Javier confirma en el
reloj «Sin fuerza compatible» y Dev registra la concesión aprobada con consultas
posteriores. El calendario solo tenía una fuerza iniciada, excluida correctamente
de la entrega de pendientes. Desde la sesión autenticada de Trainer → Para mí se
programa para el 27/10 **Prueba Garmin · Fuerza 3x5**, con indicación expresa de
prueba técnica sin necesidad de ejercicio. Su estado pendiente y la generación
FIT compatible se verifican; queda preparada para que Javier pruebe fuera del PC.
Javier permite usar datos prescindibles en esta prueba Dev; no se reinicia la
ejecución existente porque no es necesario para producir la nueva cita de prueba.

La aceptación pendiente es **sesión privada vigente → Fuerza nativa**, repetición
sin duplicar y bloqueo después de cambio/retirada/revocación. Los entrenamientos
se descargan desde Dev sin PC; cambiar el binario del reloj sigue requiriendo USB
hasta disponer de distribución Store. La ejecución en background, otros modelos y Connect
IQ Store siguen pendientes; la distribución actual es sideload Dev por USB una
vez, y después FIT inalámbrico. El retorno continúa por el contrato Garmin existente.

### Repetición privada preparada · 27/10/2026

Javier muestra EntrenaOP Dev 1.0 con «0 sesiones listas». Dev confirma que la
primera **Prueba Garmin · Fuerza 3x5** ya está `in_progress`, por lo que queda
fuera del manifiesto de pendientes. La versión instalada sigue siendo 1.0.0;
esta pantalla no acredita por sí sola un fallo ni una importación anterior.

Javier pide nuevas sesiones de prueba. Desde su sesión autenticada de Trainer →
Para mí se crea otra cita para el 27/10 y se adapta su título a **CIQ prueba 2 -
27 octubre**, para distinguirla en el reloj. Sigue `planned`, sin ejecución:
press banca con barra, tres series de cinco repeticiones a 20 kg y descanso de
1:00. Indicaciones de ensayo técnico sin necesidad de ejercicio y apertura desde
el reloj, evitando iniciar antes la cita desde la app del deportista.

Se comprueban la cita y su fuente vigente en Dev, generación/decodificación FIT
sin errores y seis pasos. Una consulta del comando real de manifiesto dentro de
una transacción con ROLLBACK devuelve lista completa, una entrada con el título
nuevo y cero bloqueadas; no se extrae la credencial original del reloj. Esta
verificación de servidor no acredita descarga o apertura física. Javier debe
actualizar EntrenaOP del reloj y confirmar la nueva sesión en Fuerza nativa.

### Ajuste de identidad nativa · 27/10/2026

La nueva prueba devuelve físicamente **FIT no confirmado: 200** en 1.0. La cita
sigue pendiente y su revisión exportada es vigente. El cliente comprueba nombre
exacto en `getAppWorkouts()` y la versión inicial usa 38 caracteres para esta
copia (título + serie). El HTTP 200 no acredita importación; tampoco permite
afirmar, sin leer el nombre devuelto por el dispositivo, que el reloj lo truncó.

Se despliega `ciq-private-2` solo en Dev: el nombre nativo pasa a `EOP<serial>`,
ASCII y máximo 13 bytes, único por exportación. La lista de EntrenaOP conserva el
título completo, al igual que ejercicios, notas, dosis y descansos. Producto FIT
2 distingue este formato del anterior para no confundir una copia ya importada;
serial y fecha siguen siendo estables entre reintentos. La huella de manifiesto
incluye el alias nativo para detectar este cambio de representación. El generador
compartido conserva producto 1 por defecto y no cambia el ensayo USB/sintético.

175 pruebas de servidor y tipos estrictos correctos. Se decodifican archivos con
alias ASCII corto, títulos largos/acentuados, seriales límite e identidad de
formato distinta, preservando ejercicios/dosis. Se relee `ciq-private-2` en HTTPS
Dev, con FIT anónimo 401, y el ensayo sintético sigue con hash y bytes idénticos.
No cambian SQL, permisos, RLS, Flutter ni el PRG 1.0 del reloj.

Tras pulsar START para actualizar sin USB, Javier comunica **sesiones listas /
actualizado ahora**. Esto acredita que el cliente encuentra la copia instalada
con la nueva identidad. No prueba por sí solo el mecanismo interno del fallo
anterior. Javier pulsa START, elige «Solo una vez» y confirma la apertura en
Fuerza con `EOP1000000026`, press banca con barra, tres series, cinco repeticiones
a 20 kg y descanso de 1:00. Indica que ha iniciado la actividad accidentalmente;
se le explica cómo detenerla y descartarla, sin dar por hecho que la haya guardado
o descartado. No se acredita retorno ni resultado deportivo.

Queda aceptado físicamente el 27/10 el recorrido **cuenta vinculada → manifiesto
autorizado → FIT privado inalámbrico → copia propia confirmada → Fuerza nativa
con receta correcta**, manteniendo el PRG 1.0 y sin otra instalación USB. El único
siguiente ensayo de este recorrido es reabrir/actualizar sin duplicados y comprobar
cambio/retirada/revocación físicos; no se declara completada la sincronización
general, background, Store ni otros modelos por esta aceptación.

### Calendario y retirada de la prueba anterior · 27/10/2026

Javier señala que abrir el FIT no equivale a verlo como entrenamiento de hoy y
muestra dos citas en Mi semana. Se confirma que la nueva está `planned` para el
27/10 y tiene recibo `sent` de Training API con fecha/título correctos. Ese envío
al calendario es una vía distinta del FIT Connect IQ abierto como `EOP1000000026`;
la aceptación del transporte privado no acredita el aviso nativo del día ni que
la entrada de calendario reproduzca esa misma copia FIT con títulos propios.

Para aislar la prueba, Javier pide quitar la primera **Prueba Garmin · Fuerza
3x5**. Desde su sesión autenticada de deportista se descarta su ejecución de ensayo
(cero series confirmadas) y desde Trainer se retira la cita ya pendiente. Dev
confirma ejecución eliminada, cita `cancelled`, recibo Garmin `cancelled`, cola
`done` y ausencia de error. Mi semana se vuelve a cargar y muestra **una sola
sesión hoy: CIQ prueba 2 - 27 octubre**, pendiente. No se alteran otras citas.

El destino de Trainer se contrasta con su recurso JavaScript público versionado:
solo incorpora la URL de `entrenaop-dev`. El calendario Garmin del PC pide nuevo
inicio de sesión, por lo que no se acredita su apariencia visual desde esa pestaña.
Javier sincroniza desde el iPhone y confirma que Garmin Connect muestra solo
**CIQ prueba 2 - 27 octubre**. Después de comprobar el reloj desde la esfera,
START → Entrenamientos, confirma «ahora sale correcto, solo el ciq prueba 2».
Queda acreditada una única sesión de hoy en EntrenaOP, Garmin Connect y el reloj,
con retirada de la prueba antigua. No se atribuye el resultado exclusivamente a
tener dos citas: también se ha sincronizado el dispositivo.

Esta confirmación corresponde al calendario y la lista nativa de entrenamientos;
no demuestra un aviso automático al entrar en Fuerza ni que la entrada de Training
API use el mismo FIT de Connect IQ. El único siguiente ensayo es reabrir/actualizar
sin duplicados y después cambios/revocación físicos. Sincronización general,
background, Store y los demás límites siguen abiertos.

### Actualización de receta y avisos preparados · 27/10/2026

Javier pide repetir la actualización, modificar la sesión, evitar duplicados y
automatizar el recorrido; comunica «1 sesiones listas / actualizado ahora» antes
del cambio. Se modifica desde Trainer autenticado la misma cita de ensayo a
**CIQ prueba 2 - actualizada**, tres series de seis repeticiones a **22,5 kg** con
descanso **1:15**. Dev confirma revisión de planificación 4, estado pendiente y
recibo `sent`, conservando `workout_id=1743167688` y `schedule_id=1822173388`.
Trainer muestra la receta nueva. Un ensayo transaccional con ROLLBACK comprueba
rechazo `40001` de la exportación antigua y dos manifiestos idénticos con una sola
exportación vigente. No se extrae la credencial original ni se modifica otra cita.
La apertura física de esta revisión y la repetición tras reabrir siguen pendientes.

Se prepara **1.1.0**, aún sin instalar: sustituye el icono provisional por el PNG
oficial OP existente, escalado por el compilador a 65 px, y corrige «1 sesión lista».
**Activar avisos de cambios** es opcional e inicialmente está apagado, sin heredar
el consentimiento de la consulta silenciosa anterior. Activa consulta cada 15 min
y usa `Background.requestApplicationWake`: solo una huella válida, distinta de la
instalada y de la última avisada, puede pedir abrir EntrenaOP. Aceptar abre la app
y ejecuta la descarga habitual en primer plano; rechazar no repite el mismo aviso.
Apagar la consulta apaga los avisos. HTTP fallido, permiso perdido o respuesta
incompleta no producen aviso. El servicio continúa sin importar ni borrar FIT.

Compilación estricta sin avisos y diez pruebas Monkey C correctas, incluidas
respuesta malformada, consentimiento, revisión instalada y supresión de avisos
repetidos. No cambian SQL, servidor ni Flutter. Instalación, apariencia de la OP
y diálogo de cambios físicos pendientes; el reloj conserva 1.0. La biblioteca
nativa puede conservar alias de revisiones antiguas: la lista vigente y la
actualización sin duplicar el calendario no acreditan limpieza de esas copias.
Garmin limita el servicio a 30 s y puede terminarlo antes; no se promete recepción
inmediata ni importación fiable con la app cerrada. Referencias oficiales:
[servicios](https://developer.garmin.com/connect-iq/articles/core-topics/Backgrounding.html)
y [diálogo de apertura](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#requestApplicationWake-instance_function).

Javier conecta después el fēnix por USB. Tras una primera lectura sin dispositivo,
Windows lo detecta y se copia únicamente `entrenaop-dev-fenix847mm.prg` en
`Internal Storage/GARMIN/APPS`, con el mismo identificador y clave de desarrollo.
La relectura MTP confirma **124.556 bytes**, SHA-256
`92af65d8ed3c04695771734f453f61434e5eefc03eddf09f9a8c9967ff1c4bf0`,
idéntico al paquete 1.1.0 compilado. No se alteran otros archivos del reloj ni se
extraen credenciales. Queda copiada y verificada la actualización; Javier debe
desconectar USB y confirmar inicio en 1.1, OP, receta actualizada y avisos.

Tras desconectar, Javier confirma que aparece 1.1 y el icono OP naranja. Señala
que el entrenamiento nativo sigue mostrando un nombre `EOP…`: corresponde al alias
corto definido en `ciq-private-2`, mientras la lista de EntrenaOP conserva el
título de la cita. No se toma el identificador comunicado de memoria como prueba
de su serial exacto ni de la dosis. Quedan pendientes la confirmación de 3×6 a
22,5 kg con 1:15, repetir sin duplicar y los avisos físicos.

Javier confirma después expresamente que ve las tres series de seis repeticiones
a 22,5 kg y descansos de 1:15 dentro de ese entrenamiento. Queda aceptado el
cambio de receta de la misma cita hasta Fuerza nativa con 1.1. Se solicita ahora
repetir Actualizar dos veces y reabrir para comprobar una sola entrada vigente
en EntrenaOP; ese ensayo y los avisos siguen pendientes. No se deduce ausencia
de copias antiguas en la biblioteca nativa a partir de esta confirmación de dosis.

Javier realiza el ensayo de dos actualizaciones consecutivas, esperando entre
ambas, y reapertura: confirma «solo una» en la lista de EntrenaOP, sin comunicar
errores. Queda aceptada la repetición con una entrada vigente después del cambio
de receta. El alcance es esa lista; no se ha inspeccionado ni limpiado la biblioteca
nativa. Se pide activar **Avisos de cambios**, salir a la esfera y confirmar la
activación antes de modificar de nuevo el título de la misma cita. La detección,
el diálogo y la actualización al aceptarlo siguen pendientes.

Javier comunica **Activado**. Desde Trainer autenticado se cambia únicamente el
título de la misma cita a **CIQ prueba 2 - aviso automático**. Dev confirma revisión
5, `planned`, tres series de seis repeticiones a 22,5 kg y descansos de 75 s; recibo
`sent` y los mismos `workout_id=1743167688` y `schedule_id=1822173388`.
La interfaz muestra título y dosis correctos. El comando real de manifiesto,
ejecutado con ROLLBACK y sin extraer la credencial, devuelve lista completa con
una entrada nueva y cero bloqueadas. Esto prepara un cambio detectable; no
acredita todavía ejecución del servicio ni aparición del diálogo en el reloj.

Se aclara el recorrido ante la duda de Javier: permanecer en la esfera, con la
app cerrada y el iPhone conectado; esperar el diálogo y aceptar solo cuando
aparezca. Abrir EntrenaOP o actualizar manualmente durante la espera no prueba
ese aviso. La consulta está programada cada 15 min, su ejecución puede demorarse;
se pide comunicar si pasan unos 20 min sin aviso. Resultado físico pendiente.

### Diagnóstico del aviso pendiente · 27/10/2026

Javier confirma que No molestar ya estaba apagado y después recibe una notificación
de Codex procedente del iPhone. Ese canal no prueba el diálogo de nuestra app.
La concesión Dev registra contacto reciente y los logs de `garmin-ciq/watch` del
intervalo revisado muestran cinco respuestas 200. No distinguen por sí solos
consulta manual y segundo plano ni acreditan callback o diálogo en el dispositivo.

Se prepara **1.2.0**, sin nuevas dependencias, permisos, SQL, backend ni cambios
en Flutter. **MENU → Estado de avisos** muestra activación de consulta y avisos,
último paso, antigüedad y código HTTP. El servicio conserva solo estado acotado y
tiempos locales: inicio/espera, respuesta inválida, avisos apagados, revisión ya
instalada/avisada, app en primer plano, solicitud del diálogo o error. No almacena
credenciales adicionales, contenido de recetas ni mensajes de excepción. La API
puede aceptar una solicitud sin acreditar que el usuario vea el diálogo.

Se captura también un fallo de procesamiento para registrar el paso y salir del
servicio; un error al pedir el diálogo no marca la revisión como avisada. Cinco
regresiones nuevas ejecutan el callback real con sustitutos de contexto, diálogo
y salida: aviso único y salida, rechazo recuperable, primer plano/consentimiento,
respuesta inválida, permiso perdido y excepción al consultar contexto. Pasan las
quince pruebas Monkey C y compila
sin avisos. No se atribuye todavía la ausencia del aviso a una causa concreta.
Se pide USB para instalar esta versión; el reloj conserva 1.1 hasta verificar copia
y aceptación física. No se amplía el ensayo a una segunda cita ni se cambia su dosis.

Javier conecta después el reloj. Tras esperar a que Windows exponga MTP, se copia
solo el paquete **1.2.0** y se relee: **127.260 bytes**, SHA-256
`db075169135d2e66536067eaa8c45388c4155dee896e112cba15b97a05916cb4`,
idéntico al compilado validado. Mismo identificador y clave de desarrollo; no se
leen credenciales ni se modifica otra app. La copia está verificada, sin acreditar
todavía el arranque ni un servicio en segundo plano de esta versión. Se pide
desconectar, abrir 1.2, terminar la sincronización y salir a la esfera antes de
cambiar de nuevo el título: así se ensaya una revisión nueva con el diagnóstico
activo, sin confundir una actualización al abrir con el aviso automático.

Javier responde **listo** al recorrido de inicio 1.2, sincronización terminada y
salida a la esfera. Se cambia desde Trainer únicamente el título de la misma cita
a **CIQ prueba 2 - aviso 1.2**. Dev confirma a las 13:07 UTC revisión 6 y `sent`,
conservando IDs de entrenamiento/calendario y las tres series de seis repeticiones
a 22,5 kg con 75 s de descanso. La interfaz muestra título y dosis nuevos.
La prueba queda preparada con la app cerrada: esperar el diálogo, aceptar si llega
y comprobar una sola entrada nueva. Si no aparece en unos 20 min desde el cambio,
abrir entonces **Estado de avisos** y comunicar Último estado y HTTP. La detección
y el diálogo siguen sin aceptación física; no se atribuye una causa al fallo previo.

Javier comunica ausencia de aviso y después **«Ya está actualizado» / HTTP 200**
en el diagnóstico. Esto acredita callback válido y revisión local coincidente en
la última comprobación, no el resultado del primer cambio. Los logs entre 13:00
y 15:17 UTC muestran primera consulta de la revisión a las 13:19, descarga FIT a
las 13:21 (recorrido de primer plano) y consultas periódicas posteriores con 200.
El estado único puede quedar sustituido después de la actualización; no permite
atribuir la ausencia del aviso a una causa concreta.

Javier vuelve a confirmar salida a la esfera. Se renombra solo la misma cita a
**CIQ prueba 2 - aviso final**, revisión 7, `sent` y mismos IDs Garmin; Trainer
conserva 3×6 a 22,5 kg y 1:15. «Final» es solo el título de ensayo, no cierre del
bloque. Dev registra exportación de ese título a las **15:19:14 UTC**. Se pide
leer Último estado, HTTP y Hace tras unos tres minutos desde el cambio si no hay
diálogo, antes de que otra consulta periódica sustituya la información. Continúa
1.2 sin reinstalar; recepción y aceptación del aviso siguen pendientes.

Javier comunica inmediatamente **«App en primer plano», hace 2 min, HTTP 200**
tras haber salido a la esfera. En ese punto del callback ya hay respuesta válida,
avisos activados y revisión nueva sin avisar; es `AppBase.isActive()` el que devuelve
verdadero y suprime `requestApplicationWake()`. Ese filtro no acredita que la app
esté visible para el usuario en este contexto; se localiza un defecto de nuestro
código, sin atribuirlo a No molestar o a notificaciones del iPhone.

Se prepara **1.3.0** siguiendo el patrón del ejemplo oficial **BackgroundTimer** del
SDK 9.3.0: cancelar el evento temporal en `getInitialView()` y reprogramarlo en
`onStop()` de la instancia de primer plano. La instancia del servicio no reprograma
al terminar. El menú conserva los indicadores de consentimiento, pero no registra
el temporizador mientras se está dentro: la primera consulta queda a 15 min desde
la salida. Solo programar si consulta activada, credencial presente y vinculación
sin código pendiente; apagar la consulta sigue cancelando el evento y los avisos.
Se elimina el filtro `isActive()`, conservando revisión instalada, aviso único,
validación de respuesta y permisos del servidor. No cambian SQL, backend ni Flutter.

Compilación estricta sin avisos y **16 pruebas Monkey C correctas**. La prueba del
método eliminado se sustituye por regresiones con el registro real del simulador:
cancelación al abrir y programación al salir condicionada a consentimiento/vínculo;
se mantienen aviso único, rechazo recuperable, respuesta inválida y permiso perdido.
Esto valida la corrección de código y la política de registro, sin acreditar todavía
que el diálogo corregido aparezca en el fēnix. PRG 1.3 preparado; se solicita USB.

Javier conecta USB y se copia/relee **1.3.0**, **127.932 bytes**, SHA-256
`ad2109c4c7fd2f0a5ca36a303fc9964d9c481489cce947661da4e1dc6697a4a5`,
idéntico al paquete compilado y validado. Mismo identificador y clave; no se
alteran otras apps ni se extraen credenciales. Pendientes inicio físico, revisión
de consulta/avisos activados y salida a la esfera antes de cambiar otra vez el
título de la misma cita para comprobar el diálogo con el filtro corregido.

Javier responde **listo** al recorrido de inicio 1.3, sincronización terminada,
consulta/avisos activados y salida a la esfera. Las dos adaptaciones desde Trainer
registran revisiones 8 y 9, pero conservan el título **CIQ prueba 2 - aviso final**;
no se da por aplicado el nombre introducido en el control del editor. Se evita
seguir retocando la cita: el manifiesto real con ROLLBACK ya acredita una identidad
nueva respecto de la exportación instalada 94, con una sola entrada y cero bloqueadas.
Esa revisión distinta permite probar el aviso aunque el nombre se conserve.

Dev confirma revisión 9, `sent`, mismos IDs de calendario/entrenamiento y tres
series de seis repeticiones a 22,5 kg con 75 s. Se mantienen app cerrada e iPhone
conectado hasta la consulta programada al salir; se pide aceptar el diálogo si llega
y, si no aparece hacia las 17:06 Europe/Madrid, leer Último estado, HTTP y Hace.
El nuevo diálogo sigue pendiente de aceptación física; no se afirma corrección
completa del recorrido por la compilación o por el manifiesto de servidor.

### Aceptación de aviso y actualización asistida · 27/10/2026

Javier comunica **«AHORA HA SALIDO»** con el reloj en la esfera y EntrenaOP cerrada.
Después confirma expresamente que acepta el aviso, la app se actualiza **sin
errores** y sigue mostrando **una sola sesión**. Queda aceptado físicamente en
fēnix 8 con **1.3.0** el recorrido **consulta en segundo plano → cambio detectado
→ diálogo del reloj → aceptar → actualización FIT en primer plano → lista vigente
de una entrada**. La descarga exige la confirmación de contenido instalado del
cliente; el éxito no se deduce solo del HTTP 200.

La traza Dev del ensayo registra POST 200 a las 15:55:25 UTC, otro POST 200 a las
15:55:35 y GET FIT 200 a las 15:55:36. El FIT corresponde a la exportación propia
98 de esta cita y título. Es coherente con consulta, apertura y descarga comunicadas
por Javier; los logs no sustituyen su aceptación visual. La prueba anterior ya
acreditaba cambio de dosis a 3×6 a 22,5 kg con 1:15 y dos actualizaciones/reapertura
con una sola entrada. No se exige otra actividad ni se crean más citas de ensayo.

El automático acreditado detecta cambios y pide abrir la app; **aceptar inicia la
descarga en primer plano**. Garmin decide cuándo ejecutar el servicio, sin SLA de
15 minutos exactos ni promesa de importación con la app cerrada. Se necesita el
móvil/Connect y conectividad disponibles. No se han comprobado físicamente rechazo
del diálogo, otra revisión notificada después de este éxito, pérdida de red,
retirada/revocación ni otros modelos. La lista única no acredita limpieza de FIT
antiguos de la biblioteca nativa. Training API/calendario y sus IDs conservados
siguen siendo una vía distinta, sin asociación demostrada con el FIT privado.

El tramo de aviso y actualización asistida queda aceptado en Dev; el bloque de
sincronización general sigue abierto. **Único siguiente ensayo recomendado:**
revocar el vínculo propio desde Perfil → Garmin y comprobar bloqueo en el reloj.
Store, distribución sin USB, retirada de citas y limpieza nativa siguen pendientes.

### Revocación real y preparación de beta privada · 27/10/2026

Javier autoriza probar la revocación y continuar con Store. Desde su sesión
autenticada, Perfil → Garmin → Retirar acceso confirma **Acceso retirado** sobre
el único vínculo activo. Dev registra la revocación a las 16:11:41 UTC. Un ensayo
transaccional con ROLLBACK usa internamente el hash del vínculo real y comprueba
rechazo `link_revoked` en estado, manifiesto y descarga de la última exportación.
No se imprime ni extrae la credencial del reloj. La pantalla física esperada al
abrir EntrenaOP es **Vinculación caducada o retirada**; Javier todavía debe
confirmarla. Los FIT ya importados siguen bajo control de la biblioteca Garmin.

Javier prefiere que Store sea solo para nosotros. Se prepara la variante
**EntrenaOP Beta 1.3.0**, con UUID independiente, recursos propios para el nombre
y la misma OP oficial, código compartido y endpoint fijo exclusivamente Dev.
La documentación oficial del SDK precisa que la beta solo se ve desde la cuenta
Garmin que la sube; no es distribución privada por enlace para varias cuentas.
Usar esa misma cuenta en Connect IQ para instalarla. Tendrá almacenamiento
separado y pedirá un código de vinculación nuevo.

Exportación release sin avisos y 16 pruebas Monkey C correctas en cada variante.
Paquete IQ de 34.966 bytes, SHA-256
`ec2ab6403eeebee86e035deeae6550d91822c27611165a4c03cf3359e27e5f7f`.
Se inspeccionan manifiesto, dos referencias del perfil `fenix847mm` y contenido
del paquete; no incluye la clave privada. El build rechaza exportar Dev para
Store y no genera otra clave de firma para Beta si falta la existente.

Todavía **sin subir**: formulario detenido antes de crear el nombre de
desarrollador y aceptar el acuerdo de Garmin. Ficha propuesta, limitaciones y
secuencia en [connect_iq/store/BETA.md](../connect_iq/store/BETA.md). Capturas y
requisitos de privacidad de la ficha deberán contrastarse en el siguiente paso
del formulario; la política pública actual no describe esta integración. No se
acreditan instalación Store, actualización de la beta ni publicación pública.
