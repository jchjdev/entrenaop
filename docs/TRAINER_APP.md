# Espacio de entrenadores

## Estado · 19/10/2026

Documento de preparación, basado en la inspección de `main` en `39f24ff`.
No hay aplicación profesional ni relación entrenador-cliente implementadas.
Esta revisión no ejecuta SQL remoto ni modifica aplicaciones o infraestructura.

Javier confirma en TRN-003 que las herramientas existentes deben reutilizarse
sin duplicar ADMIN. Los criterios de TRN-001/004/005 siguen vigentes: preparadores
de oposiciones, contenido privado y clientes en la app actual, con acceso
profesional separado de Pro y de los permisos administrativos.

Javier confirma también crear un panel profesional con un acabado visual
especialmente cuidado y contemplar paquetes según número de clientes. Sus
ejemplos de cantidades y precios son ilustrativos, no tarifas acordadas.
La estructura, secuencia y primera versión descritas a continuación son
recomendaciones revisables. La intervención del algoritmo sigue pendiente en
TRN-002; tarifas, derechos y límites concretos siguen pendientes en TRN-004.

## Base comprobada y dependencias

| Pieza existente | Reutilización y límite observado |
| --- | --- |
| `packages/workout_core/` | Plantillas, borradores, validación y modelos/códecs de programas guiados. Sus recetas pueden compartirse; no acreditan autorización profesional. |
| `packages/workout_editor_ui/` | Campos de series, carrera, formatos, tiempos, ejercicios y composición Compacto. No contiene los creadores completos de ADMIN. |
| `packages/entrena_ui/` | Tema, marca, tarjetas, política de teclado, diálogos y protección de salida. Reutilizable por el panel profesional. |
| `AdminWorkoutEditorPage` | Usa campos compartidos y permite inyectar un guardado, pero depende de `AdminProgram`, `AdminWorkoutRepository`, catálogo administrativo y retorno por rutas. Separar formulario y operaciones antes de consumirlo desde otra app. |
| `admin_guided_pages.dart` y revisión | Mezclan composición de fases, catálogo, recuperación, portadas, categorías globales, visibilidad pública y rutas administrativas. Extraer solo las piezas necesarias, conservando los recorridos actuales. |
| Recuperación de trabajo guiado | El controlador serializa escrituras y conserva peticiones inciertas; su contrato y persistencia actuales son administrativos. Reutilizar el comportamiento requiere separar ese contexto y conservar conflictos/idempotencia. |
| App del deportista | Ya dispone de agenda, vista previa, ejecutor e historial. Ampliar lectura e inicio para asignaciones autorizadas; mantener una sola ejecución y un solo registro de resultados. |

`WorkoutTemplateOrigin.coach` y `ScheduledWorkoutSource.coach` existen, pero
no hay vínculo profesional, asignación ni permiso para leer resultados ajenos.
Estos valores no deben presentarse como un módulo profesional funcional.

## Distribución recomendada

- `trainer_app/`: inicio profesional, clientes, selección de cliente, navegación
  y adaptadores para las operaciones autorizadas al entrenador. Nombre propuesto.
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

La recomendación inicial es contar relaciones aceptadas y activas. Invitaciones
pendientes y relaciones finalizadas no ocuparían plaza. Es una propuesta que
requiere confirmación, junto con el número de entrenadores que puede tener un
cliente. La cuota se comprueba en servidor al activar/reactivar el vínculo,
de forma atómica para que dos aceptaciones simultáneas no consuman la misma
última plaza. La pantalla informa antes, pero no decide la capacidad disponible.

Con el cupo completo, se recomienda impedir nuevas activaciones y ofrecer
gestionar clientes o cambiar de paquete. Bajar de paquete o perder vigencia no
debe borrar vínculos o resultados ni cortar una ejecución en curso; falta
acordar cómo resolver exceso de clientes, nuevas asignaciones, consulta e
historial. La revocación de acceso por fin de una relación conserva su propia
regla y no se sustituye por un simple recuento de plazas.

Para el piloto se propone conceder manualmente un acceso profesional con cupo
explícito y comprobar ya esas reglas. Conectar el cobro posteriormente debe
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
   de invitación y el número de relaciones simultáneas aún requieren decisión.
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

1. Separar las dependencias del editor de sesiones y seguir utilizándolo desde
   ADMIN con sus guardados y pruebas actuales. Cierre técnico localizado.
2. Concretar acceso profesional con cupo, relación aceptada, asignación
   versionada, ámbito de resultados y fin del vínculo. Implementar y comprobar
   sus contratos de servidor antes de conectar datos privados.
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
- Cómo acepta el cliente la relación, si puede tener varios entrenadores y
  cómo termina el vínculo. Conservar resultados históricos no decide por sí solo
  qué acceso conserva cada parte al contenido, a la agenda o a los resultados.
- Qué funciones adicionales recibe el cliente más allá del entrenamiento ya
  incluido sin otra suscripción, cómo convive con Pro individual y qué ocurre
  al caducar el acceso profesional del entrenador o
  reducir el cupo por debajo de las relaciones activas. Confirmar qué estados
  computan antes de implementar el límite.

## Verificación y trabajo desde la nube

El entorno Linux permite implementar Flutter web, componentes compartidos,
pruebas y migraciones versionadas. Instalar migraciones y acreditar SQL requiere
acceso comprobado a Supabase Dev; no se presume por tener el código local.
Las verificaciones físicas de iPhone siguen requiriendo Mac/dispositivo.

La extracción del editor requiere análisis y pruebas de ADMIN, del paquete
compartido y de los consumidores afectados según `AGENTS.md`. El cierre del
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

Esta preparación solo cambia documentación: no acredita ninguna de esas pruebas
futuras ni habilita usuarios, permisos, planes de pago, subdominios o despliegues.
Se reutiliza la infraestructura existente conforme a `COST_CONTROL.md`.
