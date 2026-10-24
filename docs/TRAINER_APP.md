# Espacio de entrenadores

## Recuperación contextual · TRN-029 · 24/10/2026

Trainer conecta al creador compartido las sesiones internas de programa y las
adaptaciones individuales recuperables. Contrato aplicado y probado en Dev;
análisis limpio, 199 pruebas Trainer y 48 contenciones locales correctas.
No amplía permisos ni cambia el catálogo de ADMIN. Las etiquetas privadas de
ejercicios se reutilizan en el selector común y están aplicadas en Dev;
[contrato](TRAINER_EDITOR_PREFERENCES.md). Push nativa preparada y servidor
publicado en Dev, desactivado hasta configurar proveedor/Apple y aceptar la
recepción física; [evidencia](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).
La actualización de Trainer web aún queda pendiente.
[Contrato y límites](TRAINER_SESSION_WORK_DRAFTS.md).

## Varios preparadores · TRN-028 · 24/10/2026

El piloto admite dos preparadores activos por alumno. El alumno decide compartir
su calendario y pautas; cada preparador conserva cartera, notas, conversaciones,
resultados y autoría independientes. Trainer añade Calendario compartido en la
ficha, en lectura, sin equipos globales ni edición cruzada.
[Contrato y evidencia](TRAINER_MULTI_COACH_2026_10_24.md).

## Criterio inicial · 22/10/2026 · TRN-026 (concretado por TRN-028)

Javier solicita poder tener dos preparadores activos a la vez, por ejemplo uno
de fuerza y otro de carrera. Sustituye el acuerdo anterior de preparador único;
las referencias siguientes a ese límite describen el comportamiento
histórico. También pide registrar, sin cambios de código, simplificación de
asignaciones, reordenación por arrastre y revisión del creador de carrera.
Aclara que fuerza y carrera se preparan conjuntamente: priorizar el caso de
equipo con planificación compartida autorizada para coordinar las sesiones.
Javier precisa el 24/10 que la colaboración se limita al alumno compartido, sin
abrir el resto de clientes ni exigir un equipo global. Los permisos de edición,
la comunicación y los pagos compartidos están por definir.
[Notas y alcance pendiente](TRAINER_UX_NOTES_2026_10_22.md).

## Actualización · 22/10/2026 · TRN-023

Alumnos incorpora tarjetas pulsables y gestión secundaria con confirmación.
Invitaciones distingue pendientes e historial y muestra la fecha de aceptación
sin anunciar caducidad de códigos ya aceptados. Vídeos ofrece entrada a los
clips compartidos por alumno y sesión, separada de las demostraciones propias.
Las pruebas privadas explican su uso y el límite actual de puntuación oficial.
Cambio exclusivo de Trainer, con favicon de marca, sin alterar ADMIN, el
deportista ni contratos de acceso. [Detalle](TRAINER_CLIENT_NAVIGATION_2026_10_22.md).

## Actualización · 21/10/2026 · TRN-022

El estado vigente incluye sesiones, programas y ejercicios privados asignables,
agenda, seguimiento y recuperación de programas. Se añade recuperación privada
de sesiones de biblioteca/nuevas versiones, selección de demostraciones guardadas
y acceso del alumno desde Inicio a sus recursos y avisos. Reutiliza los creadores
comunes de ADMIN mediante adaptadores independientes. Contratos aplicados solo
en Dev; hijos de programa/adaptación, push y cobros reales siguen pendientes.
[Evidencia y límites de esta entrega](TRAINER_STUDENT_RECOVERY_2026_10_21.md).
Las secciones siguientes conservan instantáneas de los primeros tramos; sus
afirmaciones de funciones pendientes se entienden en la fecha y alcance indicados.

## Estado · 21/10/2026 · TRN-010/011

El primer bloque de acceso y clientes tiene interfaces y contrato verificados:
panel web independiente en `trainer_app/`, entrada con TOTP obligatorio también
en servidor, gestión profesional/cupo y directorio en ADMIN, invitaciones y
aceptación/finalización en Perfil → Mi preparador de la app habitual.

El panel está publicado en `trainer.entrenaop.es`, separado de ADMIN, y
verificado por HTTPS y formulario real en Chrome. La gestión manual está
habilitada solo en Dev, con la cuenta de Javier y cinco plazas auditadas.
La entrada humana con TOTP, el panel con 0/5 plazas y la sesión tras recarga
están comprobados en Chrome. [Estado de publicación](TRAINER_HOSTING_2026_10_21.md).
No se han implementado contenido privado, asignaciones, resultados profesionales
ni cobros. Una identidad puede ser administradora, preparadora y alumna a la vez.

TRN-007 mantiene el creador de sesiones compartido y TRN-008/009 el vínculo y las
cuotas personales independientes. No se modifican los creadores ni el algoritmo
en este bloque. El siguiente recorrido es sesión privada → asignación →
ejecución → resultados autorizados, concretando antes los derechos pendientes.
[Interfaces, contratos, pruebas y límites actuales](TRAINER_PORTAL_2026_10_21.md).

Javier prioriza preparadores de oposiciones, reutilización sin duplicar ADMIN,
acabado visual coherente y paquetes según alumnos. Cantidades, precios y límites
de recursos siguen pendientes; no son tarifas acordadas.

## Base comprobada y dependencias

| Pieza existente | Reutilización y límite observado |
| --- | --- |
| `packages/workout_core/` | Plantillas, borradores, validación y modelos/códecs de programas guiados. Sus recetas pueden compartirse; no acreditan autorización profesional. |
| `packages/workout_editor_ui/` | Campos y composición Compacto; desde TRN-007 incluye WorkoutEditorPage, creador completo de sesiones/calentamientos independiente de ADMIN y del router. El editor de programas sigue pendiente. |
| `packages/entrena_ui/` | Tema, marca, tarjetas, política de teclado, diálogos y protección de salida. Reutilizable por el panel profesional. |
| `AdminWorkoutEditorPage` | Adaptador del creador compartido: transforma el catálogo autorizado, conserva creación/revisión/calentamientos, show_in_library y retorno por rutas. AdminProgram y AdminWorkoutRepository no salen de ADMIN. |
| `admin_guided_pages.dart` y revisión | Mezclan composición de fases, catálogo, recuperación, portadas, categorías globales, visibilidad pública y rutas administrativas. Extraer solo las piezas necesarias, conservando los recorridos actuales. |
| Recuperación de trabajo guiado | El controlador serializa escrituras y conserva peticiones inciertas; su contrato y persistencia actuales son administrativos. Reutilizar el comportamiento requiere separar ese contexto y conservar conflictos/idempotencia. |
| App del deportista | Ya dispone de agenda, vista previa, ejecutor e historial. Ampliar lectura e inicio para asignaciones autorizadas; mantener una sola ejecución y un solo registro de resultados. |

`WorkoutTemplateOrigin.coach` y `ScheduledWorkoutSource.coach` ya existían en la
inspección inicial sin circuito profesional. TRN-008 añade el vínculo aceptado
con preparador único; los valores de origen siguen sin acreditar asignaciones
ni permiso para leer resultados ajenos. TRN-010 incorpora el panel de acceso y clientes; las asignaciones siguen pendientes.

## Primer tramo cerrado: creador compartido · TRN-007 · 20/10/2026

`workout_editor_ui/lib/workout_editor_page.dart` contiene la edición completa de
carrera, los siete formatos convencionales y el contexto de calentamiento. El
consumidor aporta catálogo mediante `WorkoutEditorExercise`, guardado asíncrono
de `CreatePersonalWorkoutInput` y recepción del ID confirmado. También aporta
los textos, campos adicionales y su firma de cambios. El creador no importa
ADMIN, Supabase ni go_router; no decide origen, audiencia ni publicación.

ADMIN conserva la API de `AdminWorkoutEditorPage` y sus llamadas actuales para
crear, revisar o guardar calentamientos. El interruptor editorial y su valor
viven en el adaptador; cambiarlo no reconstruye ni pierde la receta. La firma
de campos adicionales participa en la protección de salida del editor común.
Se mantiene el bloqueo durante guardado y la retención ante errores. Los
controles vacíos que heredan valores por serie ya no cuentan como cambios solo
por mostrarlos, evitando un aviso de salida en una receta intacta.

Se añade únicamente la dependencia interna a `entrena_ui`, sin ciclos, para
reutilizar la protección de salida existente. Las resoluciones offline del
paquete y ambas apps son correctas; los lockfiles de ambas apps no cambian y no
se incorporan paquetes externos. El editor personal mantiene su contenedor.

Verificación local:

- Análisis de raíz, ADMIN y `workout_editor_ui` sin incidencias.
- Baterías completas: 1.092 pruebas raíz, 242 ADMIN y 37 del paquete correctas;
  se conservan una omisión raíz y dos ADMIN existentes.
- Cinco regresiones nuevas desde un consumidor sin dependencias administrativas:
  catálogo propio, conservación de objetivos/cargas/RIR históricos, ID confirmado
  sin navegación implícita, validación previa, fallo/reintento, bloqueo de salida
  durante petición y cambios de campos aportados por el consumidor.
- Las 50 regresiones dirigidas de ADMIN conservan creación/revisión, visibilidad,
  siete formatos, carrera, calentamiento y montaje de programas con router real.
- Compilación web release Dev correcta; capturas nuevas de móvil 320 px con
  texto 2× y carrera en escritorio revisadas. [Evidencia visual](visual-audit/shared-workout-editor-2026-10-20/README.md).

Este cierre no añade recuperación persistente de sesiones/ejercicios ni promete
idempotencia nueva. Tampoco habilita cuentas, invitaciones, cupos, asignaciones,
cobros, acceso incluido o consulta de resultados. El único siguiente bloque
profesional recomendado es concretar y probar el contrato de acceso profesional
y relación aceptada antes de conectar datos privados al panel.

## Base de acceso y vínculo · TRN-008/009 · 20/10/2026

Javier confirma un único preparador activo por alumno. El contrato base ya está
aplicado y probado en Dev: cupo manual, gestión reservada al responsable de
cuentas, invitación con código secreto y aceptación explícita, relación única
activa y cierre por cualquiera de sus partes. El cupo cuenta vínculos activos
aceptados; las invitaciones pendientes y los vínculos terminados no ocupan plaza.
La aceptación bloquea el acceso del preparador y el contexto del alumno antes
de comprobar capacidad y crear la relación. La reactivación requiere otra
invitación aceptada: un reintento antiguo nunca reabre un vínculo terminado.

El alumno conserva sus cuotas personales: ocho ejercicios propios y cuatro
sesiones propias en Free, o sus derechos Pro individuales si los tiene. Se prueba
expresamente que la vinculación no permite un noveno ejercicio ni una quinta
sesión propia en Free. Consumir asignaciones del preparador sin cuota personal
ni otra compra sigue siendo un requisito pendiente de conectar al recorrido.

El cierre inicial TRN-008 dejó la configuración manual deshabilitada y las
pruebas no dejaron cuentas, concesiones ni relaciones de ensayo. TRN-011 habilita
después la primera cuenta real del piloto exclusivamente en Dev. La bajada manual con acceso habilitado se
rechaza si el nuevo límite es inferior a los vínculos activos; la política
comercial definitiva sigue pendiente. La retirada/caducidad no borra relaciones,
y se permite terminarlas aunque el acceso profesional ya no esté vigente.

[Contrato, permisos, pruebas SQL y límites de verificación](TRAINER_ACCESS_2026_10_20.md).
TRN-010 integra acceso, cupo, invitación y aceptación, y verifica quince carreras
con conexiones reales en PostgreSQL local desechable de la misma versión.
El cierre TRN-010 no publicó el panel ni habilitó cuentas; TRN-011 registra el
alta posterior y su publicación en curso. Las asignaciones siguen pendientes. [Cierre técnico y límites del piloto](TRAINER_PORTAL_2026_10_21.md).

## Distribución implementada para acceso y clientes

- `trainer_app/`: inicio profesional, clientes, selección de cliente, navegación
  y adaptadores para las operaciones autorizadas al entrenador. Destino acordado: trainer.entrenaop.es.
- `admin_app/`: contenido oficial y administración general. Sus herramientas de
  creación consumirían las mismas piezas compartidas que el panel profesional.
- Paquetes existentes: modelos, validación, formularios y componentes comunes,
  con dependencias hacia esos paquetes y sin importar ninguna aplicación.
- Supabase: identidad existente y autorización de datos por recurso, relación y
  derecho profesional. Las aplicaciones no se conceden acceso entre sí.

El formulario común recoge una receta y devuelve su borrador; cada aplicación
resuelve su catálogo, guardado, revisión y navegación. Una comprobación visual de
capacidad ayuda a presentar acciones, pero la autorización vuelve a comprobarse
en el servidor. El control editorial de `show_in_library` pertenece a ADMIN.

La extracción debe trasladar el comportamiento existente y mantener a ADMIN
como consumidor validado antes de añadir el segundo consumidor. No se propone
reescribir todos los editores ni crear otro paquete por cada pantalla. El
editor personal del deportista no se migra por obligación en este bloque.

## Permisos que requieren trabajo nuevo

Las RPC actuales de autoría comprueban `is_admin()`; no se deben utilizar
concediendo ese permiso al entrenador. Las políticas de los programas guiados
actuales permiten leer publicaciones del catálogo general. Introducir contenido
profesional privado exige diseñar explícitamente propietario y audiencia antes
de admitirlo en ese contrato; `published` no puede equivaler por sí solo a acceso
general para un programa profesional.

El guardado y las lecturas deben comprobar entrenador, relación activa y recurso
asignado, incluidas las consultas por ID, bloques, ejercicios y medios. También
deben cumplir TRN-001: gestionar comercialmente entrenadores desde ADMIN no
concede por defecto lectura de sus prescripciones privadas. Revisar las RLS y
RPC efectivas de las tablas reutilizadas, no solo añadir un menú restringido.

El derecho profesional se consulta en servidor y no deriva de Pro. Debe
decidirse cómo se concede para el piloto; la propuesta es acceso manual desde
administración autorizada, sin implementar cobros para probar el recorrido.
No se modifica aquí el contrato de cuotas Free ni se concede Pro a clientes.

## Paquetes profesionales y capacidad de clientes · TRN-004

**Modelo confirmado; condiciones concretas pendientes.** Los paquetes deben
tenerse en cuenta desde el diseño inicial, aunque los tramos y precios se
decidan después. El vínculo identifica a entrenador y cliente y conserva su
estado e historial; no se crea una relación diferente para cada tarifa. El
acceso profesional determina por separado las capacidades y el límite vigente.
Cambiar ese límite no exige reconstruir vínculos ni mover resultados.

El contrato del piloto de TRN-008 cuenta relaciones aceptadas y activas.
Invitaciones pendientes y relaciones finalizadas no ocupan plaza. Javier confirma
un único preparador activo por alumno. La cuota se comprueba en servidor al activar el vínculo,
de forma atómica para que dos aceptaciones simultáneas no consuman la misma
última plaza. La pantalla informa antes, pero no decide la capacidad disponible.

Con el cupo completo, se recomienda impedir nuevas activaciones y ofrecer
gestionar clientes o cambiar de paquete. Bajar de paquete o perder vigencia no
debe borrar vínculos o resultados ni cortar una ejecución en curso; falta
acordar cómo resolver exceso de clientes, nuevas asignaciones, consulta e
historial. La revocación de acceso por fin de una relación conserva su propia
regla y no se sustituye por un simple recuento de plazas.

El contrato permite conceder manualmente un acceso profesional con cupo
explícito; la habilitación de esa gestión sigue desactivada. Conectar el cobro posteriormente debe
actualizar el mismo acceso efectivo con autenticación e idempotencia de servidor,
sin permitir al entrenador aumentar su propio límite desde Flutter.

Los paquetes pueden diferenciarse inicialmente por capacidad, manteniendo las
herramientas esenciales comunes; funciones adicionales, periodicidad, impuestos,
derechos del cliente y precios quedan por valorar. El número de clientes no
acota por sí solo el consumo de vídeos, almacenamiento o transferencia: esas
cuotas necesitan medición y condiciones propias según `COST_CONTROL.md`.

### Acceso del cliente incluido en el paquete

**Confirmado por Javier el 19/10/2026:** el entrenador paga por poder prestar
el servicio a sus clientes y el acceso de estos al entrenamiento debe estar
incluido. No se exige al cliente otra suscripción de EntrenaOP para recibir
asignaciones, consultar su contenido y medios, realizarlas en el ejecutor y
registrar/consultar sus resultados. Las cuotas personales Free no deben impedir
ese recorrido ni presentar una compra Pro como condición para completarlo.

Se mantiene la misma cuenta y aplicación del deportista. La recomendación
técnica es derivar un acceso por la relación autorizada y el acceso profesional
vigente del entrenador, separado de la suscripción individual y limitado a los
recursos y operaciones incluidos. No se convierte al cliente en administrador
ni se cambia su suscripción personal para representar el vínculo.

Falta decidir si el paquete incluye todo Pro o únicamente el servicio vinculado
al entrenador y sus herramientas necesarias. También requiere una regla expresa
la convivencia con un Pro individual ya contratado: informar del acceso incluido
y evitar promover otra compra para las mismas funciones; no cancelar ni alterar
suscripciones de tienda sin petición. Si termina el vínculo o el acceso
profesional, se conserva el historial y no se crea un cobro al cliente ni se
activa automáticamente una suscripción individual. Las nuevas asignaciones,
el acceso posterior al contenido y las funciones adicionales siguen pendientes.

## Calidad visual del panel · TRN-006

**Prioridad confirmada por Javier.** El panel profesional debe ser especialmente
cuidado, coherente y agradable. Reutiliza identidad, tema Compacto y componentes
existentes; no se introduce otro sistema visual para distinguirlo de ADMIN.

Se recomienda una primera revisión visual del listado de clientes y su ficha,
con datos de ejemplo, antes de extender el resto de pantallas. Debe permitir
reconocer cliente, situación, siguiente acción y capacidad del paquete sin
saturar de indicadores. La composición ha de contemplar vacío, carga, error,
invitación pendiente y cupo completo, además del estado con datos.

La aceptación incluirá escritorio, móvil, texto ampliado, foco/teclado,
contraste, nombres largos y acciones inequívocas. Las capturas de widgets se
complementarán con el recorrido autenticado cuando exista. Esta propuesta no
afirma que haya pantallas o maquetas implementadas.

## Primera versión recomendada

Cerrar primero un recorrido de asignación manual y resultados:

1. Habilitar el acceso de un entrenador de prueba sin permiso administrativo.
2. Vincular una cuenta de cliente mediante una aceptación explícita. El método
   de invitación es el código secreto; se admite un único preparador activo.
3. Crear una sesión privada mediante el creador compartido y seleccionar una
   versión para un cliente y una fecha.
4. Mostrar esa asignación en la app actual, con su origen profesional, e iniciar
   el ejecutor habitual. Conservar receta y versión usadas en la ejecución.
5. Consultar desde el panel el estado y los resultados de esa asignación. No
   conceder acceso general a todo el historial personal del cliente.

Empezar con ejercicios públicos evita abrir inmediatamente la subida de medios
profesionales. Ejercicios privados, programas completos por fases y participación
del algoritmo se integrarían después utilizando sus herramientas compartidas.
Este orden es una recomendación, no una renuncia a esas capacidades.

Las asignaciones profesionales deben convivir con la agenda y con el algoritmo
actual. La primera versión no sustituye ni regenera automáticamente el programa
adaptativo ni afirma coordinar todas las cargas. Antes de activar asignaciones
hay que fijar qué se permite cuando el cliente ya sigue un plan automático.

## Secuencia de implementación propuesta

1. **Completado en TRN-007:** separar las dependencias del editor de sesiones y
   seguir utilizándolo desde ADMIN con sus guardados y pruebas actuales.
2. **Base en Dev en TRN-008:** acceso manual con cupo y relación aceptada/terminada.
   Faltan integración visual y ensayo concurrente, asignación versionada,
   ámbito de resultados y derechos sobre contenido tras terminar el vínculo.
3. Revisar visualmente clientes y ficha usando el diseño existente; crear el
   cliente web profesional y conectar el recorrido completo de una sesión hasta
   sus resultados en la app del deportista.
4. Ampliar por recorridos completos: programas privados y creación de ejercicios;
   después, uso del algoritmo conforme a TRN-002 y condiciones comerciales.

No es necesario esperar al historial editorial futuro de ADMIN para preparar
estas piezas. La publicación del panel profesional es un paso propio: el flujo
de ADMIN no publica `trainer_app/` automáticamente.

## Decisiones abiertas para el primer recorrido

- Si el algoritmo debe intervenir desde la primera versión o después del
  recorrido manual; qué significa revisar o sustituir su pauta.
- El piloto usa código secreto, aceptación explícita y un único preparador activo;
  ambas partes pueden terminar el vínculo. Conservar resultados no decide por sí solo
  qué acceso conserva cada parte al contenido, a la agenda o a los resultados.
- Qué funciones adicionales recibe el cliente más allá del entrenamiento ya
  incluido sin otra suscripción, cómo convive con Pro individual y qué ocurre
  al caducar el acceso profesional del entrenador o
  reducir el cupo por debajo de las relaciones activas. El piloto cuenta solo
  aceptados activos y rechaza esa reducción manual mientras siga habilitado.

## Verificación y trabajo desde la nube

El entorno Linux permite implementar Flutter web, componentes compartidos,
pruebas y migraciones versionadas. Instalar migraciones y acreditar SQL requiere
acceso comprobado a Supabase Dev; no se presume por tener el código local.
Las verificaciones físicas de iPhone siguen requiriendo Mac/dispositivo.

La extracción de TRN-007 se verifica según la matriz de `AGENTS.md`, como se
detalla arriba. Los siguientes cambios compartidos conservan esa matriz. El cierre del
recorrido profesional necesita pruebas SQL transaccionales con ROLLBACK y casos
de entrenador A/B, cliente sin relación, relación terminada, referencias ajenas,
reintentos de asignación y cambio de cuenta. El cupo requiere probar su última
plaza con aceptaciones concurrentes, reactivación, exceso tras cambio de paquete
y vigencia del acceso. Comprobar también que los recorridos oficiales y
personales conservan sus contratos.

El acceso incluido necesita además un cliente Free sin suscripción individual
que complete el recorrido con sus cuotas personales agotadas, sin compra
obligatoria; un cliente con Pro previo; y revocación/caducidad sin cobro ni
suscripción individual automáticos. Son verificaciones futuras, no ejecutadas
en esta preparación documental.

La preparación del 19/10/2026 era documental; TRN-007 acredita únicamente las
pruebas del creador compartido descritas arriba. TRN-010 acredita acceso/clientes; las verificaciones de asignación y resultados
siguen pendientes. No se conceden accesos profesionales reales ni se habilitan planes de pago o
subdominios. Se reutiliza la infraestructura existente según `COST_CONTROL.md`.

## Decisiones confirmadas el 21/10/2026 · TRN-010

Panel profesional web independiente en trainer.entrenaop.es, con el mismo correo, contraseña y autenticador TOTP de la identidad EntrenaOP. La sesión web pertenece a su origen y no se comparte con ADMIN. El doble factor es obligatorio en servidor para las operaciones profesionales; no se concede permiso administrativo. El subdominio no está publicado por este bloque.

Una cuenta puede ser administradora, disponer de acceso profesional y ser alumna de otro preparador a la vez. Cada dimensión mantiene sus permisos y derechos. Un único preparador activo por alumno; queda prohibido el vínculo consigo mismo.

El entrenamiento asignado debe aparecer en el recorrido habitual del alumno únicamente cuando haya contenido autorizado: no se mostrarán secciones profesionales vacías a todos los usuarios. Mi preparador gestiona el vínculo; la integración concreta en inicio, agenda, biblioteca o Mi plan se resolverá al implementar asignaciones.

ADMIN necesita un directorio de accesos profesionales y control manual del cupo. Javier quiere también contratación autónoma desde web en un bloque posterior. Tarifas y límites por alumnos, ejercicios, planes, almacenamiento y transferencia siguen pendientes de medición y acuerdo; no se habilitan cobros en este bloque.

## Cobro del servicio del preparador · TRN-012 · 21/10/2026

El alumno paga al preparador por su servicio; el preparador paga a EntrenaOP
por herramientas y plazas. El acceso incluido evita otra suscripción obligatoria
de EntrenaOP al alumno y no convierte en gratuito el trabajo del entrenador.
Javier pide facilitar el pago al preparador desde la web. Pasarela, proveedor y
condiciones quedan pendientes en un bloque propio; no se activan cobros aquí.
[Contrato pendiente de pagos](TRAINER_PAYMENTS.md).


## Entrega integrada con objetivo 30/10/2026 · TRN-013

Javier pide trabajar todo el alcance de forma conjunta y fija nueve días desde
el 21/10/2026. El objetivo es 30/10/2026. Se desarrollan superficies y contratos
en paralelo cuando no dependan de decisiones pendientes; se mantienen guardados
validados en main y pruebas de integración. La fecha no permite afirmar que la
pasarela, la app publicada o el algoritmo profesional estén acabados.

La app del deportista forma parte de la entrega, no una aplicación secundaria:

| Superficie | Trabajo necesario y criterio de utilidad |
| --- | --- |
| Inicio | Sesión pautada con origen y fecha; acceso a todas las del día y aviso de coincidencia. No mostrar módulos profesionales vacíos. |
| Mi semana | Asignaciones profesionales junto a las existentes, sin sustituciones automáticas, con estados de realización y cambios autorizados. |
| Mi plan y biblioteca | Consultar programas/material asignados; diferenciar catálogo oficial, personal y del preparador sin convertir contenido privado en público. La ubicación definitiva se valida con el recorrido. |
| Detalle y ejecutor | Receta/versiones e indicaciones autorizadas; ejecutar mediante el motor actual, conservando vínculo, estado y reanudación. |
| Historial | Resultados de lo realizado conservados, con origen profesional y sin convertirlos en sesiones propias ni gastar cuota personal. |
| Perfil → Mi preparador | Invitación y vínculo ya conectados; ampliar ficha y explicar qué información se comparte. |
| Seguimiento y avisos | Entrega de resultados autorizados, comentarios y notificaciones vinculadas a asignaciones; preferencias de aviso y estados claros. |
| Derechos | Servicio asignado sin otra compra EntrenaOP, sin elevar Pro ni las cuotas Free personales. Fin de vínculo/caducidad pendientes de concretar. |

En el portal se desarrollan catálogo/ejercicios privados, adaptador del creador
compartido, composición reutilizable de programas, agenda/ficha del alumno,
asignación versionada, resultados/comentarios y resumen de trabajo pendiente.
Los medios requieren límites y autorización por recurso. La propuesta de
preparaciones privadas y asistencia del algoritmo debe respetar pruebas,
baremos oficiales y revisión manual; no se presume ya implementada.

Dos circuitos de contratación: preparador → EntrenaOP y alumno → preparador.
Precios, proveedor, recepción de fondos, comisiones y efectos de impago siguen
pendientes. Javier decide después posponerlos hasta cerrar la infraestructura;
no bloquean el desarrollo que no depende de esas condiciones. No se abren
cuentas financieras ni se activan cargos por la petición de acelerar.
[Pagos](TRAINER_PAYMENTS.md).

Puntos de control propuestos para la fecha objetivo, sujetos a los contratos y
verificación, no estimaciones cerradas ni habilitaciones de producción:

- 21–24/10: conectar autoría privada, permisos, asignación y recepción en la app.
- 25–27/10: programas, ficha/seguimiento y resultados; contratación/recursos
  avanzan en cuanto existan sus condiciones concretas.
- 28/10: revisar el alcance real y cerrar incorporaciones que impidan validar.
- 29–30/10: recorridos con entrenador sin ADMIN y alumno Free, recuperación,
  regresiones y prueba en dispositivos; preparar la distribución de la versión
  validada. La publicación de producción conserva su autorización propia.

No se declara cumplida la entrega por completar pantallas: debe poder crearse,
asignarse, ejecutarse y revisarse una prescripción, con aislamiento entre
entrenadores y sin una compra adicional obligatoria al alumno. La distribución
real de la app, configuración productiva y pagos requieren comprobación propia.

## Convivencia confirmada · TRN-014 · 21/10/2026

El alumno puede mantener el plan automático y la pauta del preparador. Ninguna
pauta sustituye, pausa o regenera la otra automáticamente por el vínculo.
Inicio y Mi semana avisan si una fecha tiene sesiones `coach` y `algorithm`
pendientes o en curso. Es coincidencia de día, no un diagnóstico de sobrecarga ni
un cálculo de intervalos horarios. Sesiones completadas, abandonadas u omitidas
no disparan el aviso; sesiones personales o de biblioteca no se confunden con
el plan automático. El aviso no realiza escrituras ni reordena la agenda.

Inicio identifica la sesión como pautada por el preparador y no la oculta por
la tarjeta de revisión del plan automático. Conserva el acceso a la cita y su
ID; no inicia una copia suelta. El cambio Flutter está conectado, pero todavía
no hay autoría/asignación privada ni recepción remota profesional implementadas.
No se presenta como recorrido de alumno real cerrado.

TRN-015 concreta después la baja: el alumno conserva consulta/resultados de lo
realizado y no nuevas repeticiones; el preparador conserva el historial de sus
propias etapas con la ficha inactiva. La autorización de asignaciones/resultados
todavía debe implementar ese contrato. [Cartera y derechos](TRAINER_CLIENT_LIFECYCLE.md).


Verificación de esta integración Flutter (21/10/2026): análisis raíz limpio;
41 pruebas dirigidas de convivencia/Inicio/agenda y batería completa raíz con
1144 aprobadas y una omisión preexistente, salida 0. Once regresiones nuevas
cubren fechas, orígenes, estados, conservación de pautas, navegación a la cita,
revisión automática coexistente y 320 px con texto 2×. No se modifican SQL,
políticas de acceso, cuotas ni la publicación del deportista en este cambio.


## Cartera y prioridades actualizadas · TRN-015

Javier pide centrarse en avanzar con la infraestructura y dejar las fechas en
segundo plano. El calendario anterior fue una propuesta y no gobierna recortes
ni compromisos de publicación. También confirma posponer precios y proveedor de
pagos; la captura aportada de Harbiz sirve como referencia, no como tarifa de
EntrenaOP ni autorización para contratar una prueba.

La cartera separa activos, inactivos y archivados, conserva etapas y recupera la
misma ficha al volver mediante aceptación nueva. El historial mostrado hoy es el
del vínculo, no resultados deportivos aún sin conectar. La política acordada
conserva el trabajo propio del preparador tras la baja y el historial del alumno.
[Contrato e implementación comprobada](TRAINER_CLIENT_LIFECYCLE.md).

## Referencia visual de Harbiz aportada por Javier · 21/10/2026

Se revisan las pantallas del vídeo de aproximadamente 96 segundos aportado por
Javier, que ha accedido gratis por su cuenta. Es evidencia visual de ese acceso,
no una comprobación de las condiciones comerciales, permisos o arquitectura de
Harbiz. No se contrata nada. El vídeo y sus fotogramas de trabajo no se añaden al
repositorio porque incluyen datos de la cuenta.

| Observado en el vídeo | Aplicación propuesta a EntrenaOP | Base y límite actuales |
| --- | --- | --- |
| Clientes con activos, invitaciones y archivados; columnas de actividad, cumplimiento y pagos | Cartera con indicadores útiles para detectar quién necesita revisión | Activos/inactivos/archivados e invitaciones ya existen. Cumplimiento, resultados y pagos profesionales aún no están conectados. |
| Ficha del cliente con calendario y accesos a información, evolución y archivos | Un lugar principal por alumno para pautar y consultar su servicio | Se conserva la ficha y las etapas; todavía no hay espacio de planificación/resultados por alumno. |
| Biblioteca de ejercicios, workouts y programas reutilizables | Contenido privado del preparador que se puede asignar a varios alumnos | Reutilizar `workout_editor_ui` y `workout_core` mediante adaptadores. No se copia el creador de ADMIN ni se publica el contenido privado en el catálogo oficial. |
| Elección Normal/Sencillo y tabla comparativa de series, objetivos, descansos, marcas y superseries | Mantener una receta estructurada y su lectura sencilla para el alumno | Es una referencia de presentación; no se decide crear dos editores ni dos modelos. El creador compartido ya ofrece formatos propios. |
| Botón «Así lo verá tu cliente» en el alta de workout | Vista previa con el lector del deportista antes de asignar | Se ha visto el botón; el vídeo no muestra con detalle su resultado ni todo el editor de la receta. |
| Añadir tarea al calendario con fecha, repetición y tipos como workout o programa | Asignar una sesión/programa de biblioteca desde la ficha del alumno y después consultar su ejecución | Reutilizar agenda, ejecutor e historial del deportista; asignaciones remotas privadas y resultados autorizados siguen pendientes. |

El calendario visible reúne tareas de varias clases y ofrece contadores de
completadas/incompletas. En EntrenaOP la coincidencia con el plan automático se
trata conforme a TRN-014, sin deducir del vídeo cómo lo resuelve Harbiz. Del mismo
modo, la columna de pago y el estado del cliente se observan por separado, pero
no se infieren sus reglas de cupo, archivo ni conservación de datos.

El recorrido principal recomendado sigue siendo biblioteca privada → ficha del
alumno/calendario → ejecución en su app → revisión por el preparador. Para
oposiciones deberá permitir entender las pruebas y marcas pertinentes; la
asistencia del algoritmo y las preparaciones privadas conservan su contrato
pendiente. Nutrición, marketing y equipos de profesionales aparecen en Harbiz,
pero observarlos no amplía automáticamente el alcance de esta entrega.

### Revisión directa con la sesión de Javier · 21/10/2026

Javier autoriza usar su pestaña abierta de Harbiz para investigar estos flujos,
sin pedirle vídeos de pantallas que ya son accesibles. Se utiliza el alumno de
demostración y se vuelve a su planificación sin guardar sesiones ni asignaciones.

Se abre una sesión pautada desde el calendario y su editor Normal. La receta
reúne bloque de calentamiento, series, objetivos, descansos, instrucciones y una
superserie; la biblioteca de ejercicios ocupa un lateral con búsqueda y filtros.
«Ver histórico» permite consultar al alumno y ejercicio sin salir del editor;
en el mes consultado no hay registros, por lo que no acredita resultados reales.

En Tarea → Workout se selecciona una sesión de biblioteca y aparecen Guardar,
Modificar y añadir y Vista previa de cliente. «Modificar y añadir» abre Crear
nuevo workout con la receta precargada; se cancela antes de guardar. Se observa
el recorrido de adaptación, pero no se presupone cómo persiste versiones Harbiz
ni qué efecto tendría editar después el contenido de biblioteca.

Las vistas del cliente abiertas desde editor y asignación son carruseles con
capturas explicativas del tipo de workout. No se comprueba una representación
dinámica de la receta seleccionada. Para EntrenaOP se recomienda previsualizar
la receta concreta con el lector compartido, pendiente de implementar.

Evolución → Panel de progreso ofrece periodo, RPE medio, récord personal,
volumen por ejercicio/grupo y desglose de series, repeticiones, récord y tonelaje.
Actividad muestra indicadores de dispositivos. El ejemplo consultado tiene cero
tareas completadas e histórico vacío: se ha revisado la interfaz de seguimiento,
no un registro deportivo completado. No se inventan ejecuciones para rellenarla.

Estas observaciones orientan la ficha y la revisión de pautas de EntrenaOP, sin
cambiar los contratos de permisos ni convertir propuestas en funciones ya
implementadas. No hace falta resolver precios ni pagar una prueba para avanzar.

## Recorrido implementado de sesiones privadas · TRN-016 · 21/10/2026

Mis sesiones privadas y Planificación y resultados conectan autoría común,
revisión versionada, vista previa real de receta, asignación con indicaciones y
consulta del resultado propio del servicio. El deportista usa agenda, ejecución
e historial existentes; no recibe una biblioteca repetible al acabar el vínculo.
ADMIN y portal comparten el lector de recetas, manteniendo permisos separados.
[Implementación, pruebas y límites actuales](TRAINER_PRIVATE_WORKOUTS.md).

## Programas, agenda y alcance ampliado · TRN-017/018 · 21/10/2026

El montaje completo de programas se comparte con ADMIN mediante adaptadores.
El portal incorpora biblioteca privada versionada, sesiones creadas dentro,
asignación por fase/fecha y agenda conjunta con navegación. El alumno sigue
consumiendo citas profesionales mediante su app; no se abre el catálogo privado.
[Contrato y verificación](TRAINER_PRIVATE_PROGRAMS.md).

Javier concreta ejercicios propios y contenido reutilizable para cualquier
alumno, seguimiento y ambos circuitos de pago con cupos configurables. No son
capacidades ya implementadas por estar acordadas. El alcance, límites técnicos
concretados en TRN-019 y la separación respecto al trabajo de relojes se registran en
[TRAINER_PLATFORM.md](TRAINER_PLATFORM.md).

## Ejercicios profesionales · TRN-019 · 21/10/2026

El portal reutiliza el formulario de ADMIN para su catálogo privado, revisiones
inmutables e imágenes. Los ejercicios se incorporan a sesiones/programas y el
alumno los consulta dentro de lo asignado; su biblioteca personal no cambia.
Javier confirma límites piloto de 500 ejercicios/versiones y 1.000 reservas de
imagen de hasta 500 KB, configurables en servidor. El código del deportista se
actualiza en este tramo, sin acreditar instalación en su teléfono.
[Contrato, pruebas y distribución](TRAINER_PRIVATE_EXERCISES.md).
