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
