# Consulta profesional en la app · TRN-036 · 28/10/2026

TRN-037 incorpora los avisos nativos de mensajes y vídeos desde Resumen, con
consentimiento independiente y categorías. [Reglas y prueba física pendiente](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

## Producto y recorrido

La app del deportista incorpora un espacio de consulta profesional. La misma
cuenta puede entrenar con Ervi, preparar a sus alumnos y usar «Para mí» sin
confundir esas relaciones. El selector superior «Mi entrenamiento / Entrenador»
solo aparece cuando el servidor confirma acceso profesional vigente. Un usuario
normal conserva sus cuatro destinos y el quinto «Preparador» cuando corresponde;
no necesita Pro para que se compruebe su condición profesional.

El modo personal conserva las pilas existentes y «Preparador» sigue siendo el
servicio que recibe el usuario. El profesional incorpora cuatro pilas:
Resumen, Agenda, Alumnos y Mensajes. Cambiar de espacio conserva la pantalla y
el borrador del chat. Perfil mantiene su ruta del navegador raíz. TRN-048 añade
planificación ligera; los creadores y la gestión completa permanecen en Trainer web.

- Resumen consulta hoy, resultados pendientes y vídeos sin primera corrección.
  Muestra una selección breve y permite abrir sus listados paginados.
- Agenda ofrece día/semana y cambio de fecha, sobre las pautas propias del
  preparador, incluida su planificación propia cuando existe.
- Alumnos distingue activos, inactivos y archivados, con búsqueda entre los
  cargados y paginación. La ficha consulta objetivos de oposición y marcas con
  unidades, sesiones/resultados y conversaciones de las etapas del servicio.
- El calendario compartido del alumno reutiliza su consentimiento existente.
  Muestra otras pautas en lectura; no abre resultados ni conversaciones de
  otros preparadores ni expone su cartera.
- Mensajes añade globos por alumno, recibos al presentar la conversación y
  actualización cada quince segundos mientras está visible y en primer plano.
  La bandeja se comprueba cada minuto para cuentas profesionales habilitadas;
  las demás solo al entrar/reanudar. Ocultar el chat no consume su refresco.
- El resultado reutiliza la presentación común de fuerza/carrera y permite
  marcar revisado con nota privada. El vídeo se reproduce bajo demanda y admite
  correcciones vinculadas a un instante. Ambos envíos conservan operación y
  contenido al reintentar un error incierto.

El contador de mensajes es interno a la app; TRN-037 añade después el envío
push nativo al preparador por mensajes y vídeos compartidos, con activación
expresa. La recepción del deportista conserva su agrupación y consentimiento
por teléfono; APNs sigue pendiente de la configuración/aceptación de Apple.

## Arquitectura y seguridad

- `lib/features/coach_workspace/domain/`: puerto de consulta/seguimiento y
  proyecciones móviles. Reutiliza modelos profesionales existentes.
- `data/`: adaptador de las RPC de Trainer, con propietario y JWT fijados por
  `authenticatedTrainerRpc`. La reproducción fija además el token de la función
  de vídeo y descarta respuestas al cambiar la identidad.
- `presentation/`: controlador efímero por cuenta, guardia de acceso/MFA,
  pantallas de consulta y navegación propia. No importa `trainer_app/` ni
  `admin_app/`.
- `core/router/coach_workspace_routes.dart`: sexta rama del shell existente,
  con cuatro ramas profesionales internas. `go_router` conserva los contextos
  independientes. La conversación usa el guardia de salida compartido.
- `trainer_access` conserva acceso, seguridad, relaciones, calendario y mensajes;
  expone un puerto de bandeja/lectura para inyectarlo sin atar la UI al cliente.
- `workout_editor_ui/professional_workout_result.dart` contiene la presentación
  antes alojada en Trainer. El archivo anterior la reexporta y conserva su
  página/adaptador web; no se copian dos lectores de resultados.
- `entrena_ui/ConversationView` respeta también `TickerMode`, necesario para
  detener lecturas y recibos al conservar una rama fuera de pantalla.

La guardia exige estado propio confirmado y MFA antes de montar datos
profesionales. Usa el mismo autenticador de Trainer; si no existe, permite
configurarlo mediante clave manual y verificar su primer código. No concede
acceso, Pro ni plazas. Un error no confirma autorización. Un fallo temporal
oculta el contexto ya autorizado y detiene foco/refrescos,
conservando su borrador hasta revalidar; antes de MFA no se monta. Revocación
confirmada y cambio de cuenta desmontan el contexto. Las respuestas tardías
no restablecen permisos/contadores anteriores. Cada RPC
mantiene además sus comprobaciones de servidor por cuenta, servicio y recurso.

Las composiciones aisladas sin transporte registrado mantienen el deportista y
no montan el espacio profesional; un enlace directo no evita esa guardia.

## Consulta nueva de vídeos

Migración `20261028093038_trainer_mobile_technique_inbox.sql`, aplicada solo en
Supabase Dev `sxbxfjqgoddzhtcyhalw`. Añade una fachada invoker autenticada y su
proyección privada, sin tablas, cambios de RLS ni privilegios administrativos.

`list_trainer_technique_inbox` verifica propietario esperado/MFA, filtra autor,
vídeo compartido/listo y permiso existente de corrección. «Sin corrección»
significa que todavía no hay una respuesta de técnica; no se presenta como
una acreditación de visionado. Devuelve como máximo cincuenta referencias
ordenadas por fecha e ID, con cursor compuesto, sin URLs ni contenidos de vídeo.
Reproducir o responder vuelve a autorizar el recurso por los contratos anteriores.

## Verificación y entrega

El contrato SQL ampliado de vídeos termina con ROLLBACK. Comprueba bandeja
propia/ajena, propietario cambiado, MFA, cursor compuesto, compartición retirada
y exclusión después de corregir. Se revalidan también acceso/vínculos,
operaciones/resultados, varios preparadores/calendario, planificación propia,
bandeja de mensajes, ficha y objetivos: ocho contratos con ROLLBACK sobre Dev.

Las pruebas móviles cubren navegación dual, entrada directa sin MFA, usuario
normal, revocación/error, respuesta tardía, cambio de cuenta, pausa, conservación
del borrador, lectura de mensajes, calendarios compartidos y reintento de revisión.
El reproductor se desmonta al ocultar el espacio para detener vídeo y audio.
Las de transporte comprueban fechas locales, cursores, propiedad/JWT, ausencia
de identidad y payloads de revisión/corrección. Se revisan pantallas a 320/390
píxeles con texto 1×/2× y capturas de consulta con fuentes legibles.

Análisis limpio en raíz, Trainer y ADMIN. Baterías completas: 1.413 pruebas
del deportista (una omisión anterior), 286 de Trainer y 316 de ADMIN (dos omisiones
anteriores). Veinticinco pruebas específicas nuevas de módulo/transporte; paquetes
compartidos: 218 de workout_editor_ui, 31 de entrena_ui y 22 de trainer_access.
Se coteja el historial de migraciones local/Dev sin diferencias y los grants de
la fachada: sin ejecución anónima, autenticada e invoker. Los asesores conservan
las mismas cinco categorías y 243 hallazgos previos, sin incremento por este
cambio; no se presenta ese estado anterior como una auditoría global resuelta.

La entrega principal `0f52eeed28a8cbf0ab566a0febafbd5b698fab9c` pasó las
comprobaciones remotas: Trainer run `40668009962`, ADMIN `40668009669` y
Garmin/consumidor/iOS `40668009785`. Los portales Dev sirvieron esa revisión,
verificada independientemente por HTTPS, identidad de proyecto, SHA-256,
entrada, cabeceras y MIME WASM. El job iOS compiló Release sin firma; no instaló
una app ni validó APNs. Los ajustes posteriores de bloqueo temporal y parada del
reproductor se verifican con las 1.413 pruebas raíz y 25 específicas indicadas;
no modifican el paquete web ni el servidor.

La funcionalidad requiere una nueva compilación e instalación móvil. No se
acredita aquí su instalación física en iPhone, APNs ni publicación en tiendas.
No se cambian tarifas, cobros, algoritmo profesional ni producción.

Siguiente recorrido de aceptación: instalar la app → entrar con la cuenta
profesional → verificar autenticador → alternar ambos espacios → leer/responder
un mensaje de un alumno → revisar resultado/vídeo → volver al entrenamiento
personal y comprobar que «Preparador» sigue mostrando a Ervi.


## Ajuste de consulta móvil · TRN-047 · 30/10/2026

La consulta utiliza su propia densidad, sin cambiar el tema del entrenamiento
personal ni limitar el tamaño de texto elegido en el teléfono. Los segmentos de
cambio de espacio pasan a un menú cuando no caben; conservan el contexto y el
globo profesional. La navegación inferior y el acceso a Perfil permanecen.

- Resumen reúne los mensajes sin leer y las muestras cargadas de resultados y
  vídeos pendientes. Estas dos últimas cifras no son un total de servidor.
  Muestra una selección corta, oculta secciones vacías y conserva el acceso a sus
  listados paginados; las preferencias de avisos son desplegables.
- Alumnos, conversaciones, agenda, resultados y vídeos comparten tarjetas
  pulsables sin alturas rígidas, con títulos que pueden ocupar varias líneas.
- La ficha destaca Mensaje, Calendario, objetivo y marcas; conserva el historial
  del servicio y la lectura autorizada del calendario conjunto.
- El resultado usa una sola lista para la cabecera y la presentación compartida.
  Se puede llegar al final y operar la revisión incluso con texto 2×.
- El estado de preparación del vídeo se presenta en castellano. Reproducir,
  corregir y marcar revisado mantienen sus contratos y reintentos anteriores.

No se modifican modelos, permisos, MFA, refresco de mensajes, acuses, algoritmo,
precios ni servidor. El lector compartido recibe solo una cabecera opcional y
padding estrecho; se verifican sus consumidores de ADMIN y Trainer.

### Evidencia y límites

Nueve pruebas de disposición recorren doce pantallas a 320/390/430 px y texto
1×/1,3×/2×: resumen, agenda, alumnos, mensajes, ficha, resultado, pauta pendiente,
calendario conjunto, técnica, conversación, revisiones y vídeos. Se configura
plataforma iOS y zonas seguras de 47/34 px, se verifica ausencia de desbordamientos,
la operación del control final de resultados y el regreso a la misma ruta al
alternar entrenamiento personal/profesional. Los datos incluyen nombres largos,
marcas, mensajes, resultados y técnica; no hay transporte a cuentas reales.

Batería raíz: 1.455 pruebas correctas y una omisión previa. ADMIN: 364 y dos
omisiones previas. Trainer: 332. Editor común: 223. Análisis de las cuatro unidades
limpios. Se mantienen las regresiones de guardia, revocación, borradores, pausas,
lectura y desmontaje del vídeo al ocultar el contexto.

`tools/coach_mobile_preview.dart` permite compilar las pantallas reales en un
target local aislado con fixtures de `test/support/`; no se usa en entregas de
la app. Las capturas opcionales del test usan fuentes de Windows para que sean
legibles; no acreditan la tipografía exacta ni el comportamiento nativo de iOS.
El control interactivo del navegador se detuvo al no poder determinar su URL.
Javier descarta el Samsung; no se usa ese teléfono, no se prepara APK y no se
acredita aceptación física del iPhone ni APNs. La nueva compilación e instalación
móvil sigue a cargo de Javier.

El siguiente recorrido es aceptar una invitación en iPhone, alternar ambos
espacios y completar planificación, ejecución y revisión con mensaje y vídeo,
comprobando además que el servicio recibido de otro preparador permanece.


Entrega guardada en `e9163d73854ff727050db7e77c2b08916d4a4483`. La publicación
automática termina correctamente en [Trainer 41023331383](https://github.com/jchjdev/entrenaop/actions/runs/41023331383)
y [ADMIN 41023331371](https://github.com/jchjdev/entrenaop/actions/runs/41023331371).
Ambos portales sirven esa revisión: identidad Dev `sxbxfjqgoddzhtcyhalw`, árbol
de construcción limpio, SHA-256 de JavaScript y recursos HTTPS verificados.
La [verificación 41023331336](https://github.com/jchjdev/entrenaop/actions/runs/41023331336)
termina correctamente, incluida compilación iOS Release sin firma. Esta evidencia
no instala la app móvil, no acredita APNs y no cambia producción.


## Planificación ligera · TRN-048 · 30/10/2026

La petición amplía la consulta de TRN-036: el preparador puede operar con contenido
ya creado desde su móvil. Se conserva el espacio personal, la guardia de cuenta/MFA,
las cuatro pestañas y los permisos del servicio. No se importa una aplicación web,
no se añaden roles y no se amplían cuotas ni Pro.

### Recorridos y presentación

- Ficha → Asignar sesión: alumno conocido → biblioteca con búsqueda entre las
  sesiones cargadas → vista previa compartida → fecha/nota → confirmación. Si la
  sesión ya está elegida no se despliega otra vez el catálogo.
- Agenda → +: conserva el día seleccionado; permite asignar sesión o crear cita.
  El destinatario se elige entre alumnos activos paginados, o «Para mí». La ficha
  propia se obtiene con `ensure_trainer_self_client`; conserva la misma identidad
  y su exclusión del cupo, sin crear otra cuenta.
- La agenda muestra semana por defecto, día y mes. La semana evita apartados de
  días vacíos salvo el seleccionado. Las tarjetas indican alumno, sesión/estado
  o cita/hora/duración. El color usa la misma paleta y cálculo estable que web.
  La navegación de días usa fechas civiles, también al cruzar el cambio de hora.
- Los filtros mantienen el alumno elegido. Sesiones y citas cargan sus páginas
  por separado; si faltan filas se indica que la vista es parcial y se permite
  cargar más junto al calendario. Los puntos del mes no se presentan como un
  inventario completo antes de terminar la paginación.
- La pauta permite volver a pautar una versión disponible y mover/retirar una
  sesión pendiente sin ejecución. Repetir crea otra asignación: la anterior y sus
  resultados permanecen. Una versión retirada no se reasigna de forma silenciosa;
  se puede elegir otra de la biblioteca. No hay editor de receta en móvil.
- «Más» en la ficha reúne cita, notas privadas y formularios. Las citas conservan
  fecha/hora civil, zona, revisión, advertencia de solapamiento y avisos existentes.
  Se pueden editar y cancelar. El alumno decide su recordatorio; la sugerencia
  del preparador no lo activa en su nombre.
- Las notas conservan revisión y objetivo interno; no se envían por chat ni
  sustituyen objetivos de oposición. Los formularios envían una versión guardada
  y muestran las respuestas autorizadas, incluidas respuestas `false` y opciones
  con sus etiquetas. No se incorpora autoría de formularios.
- Mis sesiones da acceso a ejercicios propios y oficiales en consulta, con foto,
  descripción y demostración. Las fotos privadas usan enlaces firmados de 15 min;
  se renuevan al actualizar. Se cargan miniaturas al mostrarlas y el vídeo solo
  bajo demanda, desmontándolo al ocultar el espacio. Los enlaces externos se abren
  en su proveedor. El buscador comparte el desplazamiento para admitir teclado.

### Contratos y recuperación

`CoachPlanningRepository` es un puerto del módulo móvil. Su adaptador reutiliza
las RPC de biblioteca, asignación, planificación, notas y formularios; delega
citas en `trainer_access`. La receta completa se restringe a propietario,
origen coach y estado publicado, además de las políticas de servidor. El calendario
solo consulta la presencia de otras planificaciones para advertir coincidencias,
sin descargar nombres o contenido de planes personales ajenos.

Cada envío fija un UUID y sus campos para reintentar. Las notas y movimientos
conservan la revisión leída; las citas mantienen su ID/revisión y confirmación de
solapamiento. Cancelar una cita incierta reintenta cancelar, nunca guardar. Una
retirada incierta consulta el estado autorizado antes de darla por confirmada.
Las rutas de escritura usan el guard compartido para salidas y doble pulsación;
al alternar espacios se conserva el borrador sin enviar automáticamente.

No se alteran el modelo, RLS, grants, funciones SQL, preferencias de avisos,
pagos o dependencias. No se han usado cuentas reales para crear asignaciones
ni se ha generado una APK. Creadores, composición de programas, envíos masivos,
papelera y gestión completa continúan en web.

### Verificación

Se contrastan en Supabase Dev `sxbxfjqgoddzhtcyhalw` las firmas de las operaciones
existentes. Pasan seis ensayos transaccionales con ROLLBACK: sesiones privadas,
planificación propia, operación/revisión, ficha/notas, formularios y citas. No dejan
datos ni modifican producción. La batería completa raíz pasa 1.481 pruebas, con una omisión previa; análisis
limpio. Veintiséis pruebas nuevas cubren transporte,
propiedad, revisión, reintentos, selección/navegación, «Para mí», citas, notas,
formularios, teclado y conservación del borrador. Las nueve pruebas de disposición
recorren veinte pantallas a 320/390/430 px y texto 1×/1,3×/2× con zonas seguras iOS.

Las capturas usan widgets reales y datos simulados; la aceptación física en iPhone
sigue pendiente de instalar su compilación. No acreditan APNs, recepción física de
avisos, envío a relojes ni cobros. El siguiente recorrido es ficha → asignación →
agenda → ejecución en el alumno → revisión/mensaje, comprobando también una cita.
