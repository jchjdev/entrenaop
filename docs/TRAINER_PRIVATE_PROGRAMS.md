# Programas privados y agenda profesional · TRN-017 · 21/10/2026

## Recorrido y reutilización

El preparador crea rutinas o programas por fases con nombre, objetivo,
destinatarios, material y sesiones reutilizadas. Puede crear, editar o duplicar
una sesión dentro del programa mediante el creador de sesiones existente.
El montaje completo de ADMIN pasa a `GuidedProgramEditorPage` en
`workout_editor_ui`: campos, fases, ordenación, lector de recetas, trabajo en
curso y protección de salida. ADMIN conserva publicación/revisión conjunta,
categorías, calentamientos, visibilidad oficial y recuperación de trabajos en
su adaptador. Los contratos/controlador de trabajo y resúmenes se comparten
mediante alias compatibles; no se copia otro creador profesional.

El adaptador profesional ofrece su biblioteca y guardado privado. El
calentamiento y descanso quedan dentro de la receta de la sesión; no aparecen
ajustes oficiales cuyo motor no vaya a aplicar a las citas. Una receta histórica
se puede consultar y reutilizar; editarla desde un programa parte de una copia
si ya no es la versión vigente de la sesión suelta.

Guardar o revisar un programa no lo publica ni lo pauta. Biblioteca y detalle
permiten consultar fases y abrir la receta concreta. Desde la ficha de cualquier
alumno activo se elige un programa y se revisan fechas. Puede pautarse una fase,
todo el programa dentro del máximo de envío, quitar sesiones de ese envío y
repetir la planificación después de la última semana incluida. No cambia el
programa de biblioteca ni avanza fases automáticamente.

La propuesta inicial separa las sesiones dos días y se explica en el formulario:
es una ayuda de entrada, no una recomendación deportiva ni un algoritmo de
periodización. Cada fecha es editable y se confirma antes del envío. Máximo
técnico de 256 citas por envío; programas mayores se pautan por fases. No es una
cuota comercial de biblioteca. Las duraciones de fase son orientativas.

## Servidor y consumo

`trainer_private.programs` conserva dueño, familia, versión y contenido del
modelo común `GuidedProgram`. `program_sessions` fija recetas y posiciones con
FK. `program_writes` conserva operaciones de guardado y `program_deliveries`
registra la tanda inmutable. Las tablas no tienen permisos de cliente; RLS
añade defensa. Las RPC públicas invoker delegan en funciones internas con
identidad, MFA y propiedad. Escribir y asignar requieren acceso profesional.

Se amplía el motor de asignación existente con una entrada interna que admite
versiones fijadas. La sesión suelta sigue admitiendo solo su versión vigente.
Toda la tanda se crea en una transacción: un error no deja una parte asignada.
Cada guardado/envío mantiene su UUID y datos ante respuesta incierta. Los
formularios bloquean cambios hasta confirmar o abandonar ese intento.

Las citas resultantes son `scheduled_workouts` con origen coach y vínculo de
`trainer_assignments`; añaden referencia al envío y llevan programa/fase e
indicaciones en la nota del alumno. Se reutilizan agenda, ejecución, snapshots,
resultados y contratos de baja de TRN-016. Un alumno no obtiene acceso general
a la biblioteca del profesional ni repetición libre por conocer el ID del
programa. No se añade una sección vacía de programas a todos los deportistas.
Los controles nuevos del deportista de TRN-016 aún requieren distribuir su app.
El alumno recibe las sesiones y las etiquetas de programa/fase, no una ficha
completa del programa con todas las indicaciones generales de cada fase. Esa
presentación contextual en Mi plan sigue pendiente; no se atribuye a esta tanda
una biblioteca de programas del alumno que todavía no existe.

## Agenda y navegación

`list_trainer_agenda` devuelve únicamente las pautas propias del servicio, con
nombre de alumno de la cartera, fechas y estado. Acepta como máximo 62 días,
pagina cien filas por fecha/ID y exige MFA. No abre la agenda personal o los
resultados de otros preparadores. Calendario mensual, selección de día y listado
permiten ir a la ficha o al resultado. Si faltan páginas, se avisa de que los
recuentos son parciales. No sustituye el aviso de coincidencias de la app.

Un shell común conecta Alumnos, Agenda, Sesiones y Programas, con URLs visibles
y acceso directo. Los creadores ocupan toda la pantalla. El router consulta el
guard compartido antes de salir de un borrador, también al cambiar de destino.
La identidad descarta router y estado anterior. No hay edición por arrastre,
reprogramación profesional, alertas ni registro persistente de resultados leídos.

## Límites de esta entrega

Ejercicios profesionales propios/medios, recuperación persistente del borrador
profesional al recargar, cobros y contratación por tramos, algoritmos privados,
mensajería, seguimiento agregado y relojes siguen pendientes. El alcance
completo solicitado está en [TRAINER_PLATFORM.md](TRAINER_PLATFORM.md).
La compilación y las pruebas no equivalen a una sesión humana de dos cuentas
en dispositivos ni a publicación en producción.

## Verificación técnica · 21/10/2026

Aplicada a Dev `20261021132641_trainer_private_programs.sql`; 182 migraciones
locales/remotas coincidentes. Trece contratos transaccionales pasan antes de
aplicar con ROLLBACK, incluidos los recorridos anteriores de sesiones, cartera,
MFA, cuotas, ADMIN, ejecución y papelera. El nuevo cubre receta fijada aunque se
revise la sesión, entrega idempotente/atómica, notas, agenda, aislamiento ADMIN,
sin MFA y continuidad después de baja.

45 contenciones reales pasan en PostgreSQL 17.6 local: las 33 anteriores y doce
de programa/baja, ambos órdenes y READ COMMITTED/REPEATABLE READ con reintento.
El fixture local usa RPC reales y tablas mínimas para bloqueos; receta completa,
RLS y ejecución se verifican en Dev. No utiliza producción ni deja alumnos de
ensayo en Dev. Los asesores no añaden WARN en los objetos del bloque; las tablas
privadas sin grants generan INFO de RLS sin políticas y los índices recién
creados pueden aparecer sin uso. No se corrigen avisos ajenos en esta entrega.

Análisis limpio en deportista, ADMIN, portal y paquete común. Baterías: 1144
raíz (una omisión previa), 301 ADMIN (dos previas), 24 portal y 67 compartidas.
Las nueve regresiones nuevas cubren compositor real, receta/fases, operación
incierta, tanda repetida, agenda paginada, 320/1200 px con texto 2× y guard al
cambiar de destino. Diez capturas reales de widgets con datos ficticios están
en `docs/visual-audit/trainer-programs-2026-10-21/`. Web Dev Release compilada.
Seis pruebas del empaquetador verifican origen, aislamiento de host, hash y
dependencias locales: comprueba todos los paquetes resueltos de Trainer y no
incluye paquetes aún no consumidos que se estén creando en otro chat.

## Referencia observada en Harbiz

Se usa la sesión abierta de Javier. Inicio muestra actividad reciente, tareas
por agendar, cumplimiento y eventos. Crear programa ofrece semanas/días y, en
cada día, selección o creación de workout, cardio, vídeo, documentos, formularios
y otras tareas. Se añade una semana solo en el formulario sin guardar. El cuadro
de automatizaciones permite enlazar otro programa o archivar al terminar; se
cancela y se vuelve al inicio. No se activan cobros, no se guarda contenido ni
se envían mensajes. Estas observaciones de interfaz no acreditan la lógica
interna del competidor ni autorizan cambiar nuestras reglas de baja.
