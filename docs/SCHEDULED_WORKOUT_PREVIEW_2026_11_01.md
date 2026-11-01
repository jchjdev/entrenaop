# Consultar el entrenamiento pautado sin empezarlo · 01/11/2026

## Decisión de Javier

La consulta completa antes de comenzar es parte necesaria del recorrido del
deportista. Javier pide completarla después de la reorganización de navegación.
Tocar la card o Ver entrenamiento debe mostrar el contenido asignado sin crear
ejecución, cambiar el estado de la pauta ni confirmar avisos.

Javier descarta tanto «receta» como «detalle de la sesión» en la interfaz. Los
botones utilizan **Ver entrenamiento**, las cabeceras **Entrenamiento** y las
comparaciones **Pautado / Realizado**. Se actualizan los textos de la app,
Trainer y sus componentes compartidos, conservando identificadores y contratos
técnicos. No se renombran campos SQL, tipos ni claves de serialización.

## Recorrido

- Inicio abre directamente el entrenamiento pendiente del día seleccionado.
- La agenda permite abrirlo tocando la card o Ver entrenamiento. Su acción
  explícita de comenzar existente se conserva.
- La consulta ocupa una tarea de pantalla completa, con el mismo contenido de
  bloques utilizado en Biblioteca y una cabecera de fecha, preparador y notas.
  Incluye las dosis y excepciones por serie, cargas, descansos, ritmos, carrera,
  RPE e instrucciones de prescripción.
- Volver conserva la fecha y la pantalla de origen. Una entrada directa dispone
  de la fecha de origen como alternativa, aunque el preparador reprograme la
  pauta durante la consulta.
- Comenzar entrenamiento es una acción separada. Durante su petición se protege
  la salida para evitar abandonar una escritura en curso. Un fallo permite
  reintentar o volver; la lectura ordinaria no añade confirmaciones de salida.
- Si cambia el contenido o se cierra la pauta, se actualiza y se exige otro gesto
  explícito. Si ya tiene resultado, se ofrece Ver resultado.

## Contrato y arquitectura

`ScheduledWorkoutPreviewRepository` separa consulta e inicio revisado. Sus casos
de uso y el Cubit no dependen de Supabase. El adaptador fija la cuenta y comprueba
identidad antes y después de cada RPC mediante el transporte autenticado común.
El router identifica los controladores de consulta y agenda por cuenta; una
renovación conserva estado y un cambio de usuario descarta respuestas anteriores.

La URL `/plan/week/session/:scheduledId?date=YYYY-MM-DD` conserva los enlaces
existentes de calendario y ejecución. El ejecutor sigue recibiendo el identificador
de ejecución del motor actual; no se inicia desde una plantilla suelta.

### Consulta autorizada

`get_scheduled_workout_preview(p_expected_owner, p_scheduled_id)` devuelve:

- `scheduled_workout`: metadatos autorizados de la pauta.
- `template`: contenido completo del UUID y versión que tiene asignados.
- `planning_revision` y `revision`: referencias para detectar cambios.

La fachada pública es invoker. La implementación privada verifica identidad,
propiedad de la cita, acceso a la asignación y referencias a ejercicios antes de
serializar. Conocer un UUID privado no permite consultar una biblioteca ajena.
No se busca la última versión de una familia ni se conceden permisos nuevos sobre
tablas, programas privados o imágenes. La función de consulta es estable y no
ejecuta escrituras, inicio, limpieza ni confirmación de avisos.

### Inicio explícito de lo revisado

`start_reviewed_scheduled_workout(p_expected_owner, p_scheduled_id,
p_expected_revision)` comprueba la identidad y la revisión antes de delegar en el
inicio existente. También valida una reanudación: otra pantalla no puede sustituir
el contenido que se acaba de revisar por una adaptación posterior ya iniciada.

La revisión incluye el contenido asignado y el contexto de planificación; excluye
estado y vínculo de ejecución para permitir reintentos idempotentes. Un cambio
de contenido o un estado ya cerrado produce `40001`, que el adaptador convierte
en actualización y revisión explícita. Un recurso o identidad no autorizado falla
con `42501`.

Los bloqueos se limitan al inicio confirmado y respetan el orden del catálogo.
Las plantillas personales propias con hijos editables se protegen además frente
a modificaciones concurrentes de bloques, ejercicios y series. Las consultas no
adquieren estos bloqueos de escritura.

## Verificación y entrega

Comprobado el 01/11/2026: análisis Flutter sin incidencias; batería completa de
raíz con **1.600 pruebas correctas y una omisión previa**, Trainer con **428**,
ADMIN con **368 y dos omisiones previas**, y `workout_editor_ui` con **247**.
Se verifican navegación real, cambio de cuenta, consulta sin inicio, versión
asignada, errores, reintentos, cambios concurrentes, reanudación y resultado.

La migración `20261101201440_scheduled_workout_preview_read.sql` está aplicada y
contrastada en el historial de **entrenaop-dev** (`sxbxfjqgoddzhtcyhalw`). La
prueba `supabase/tests/scheduled_workout_preview_read.sql` pasó después del
despliegue, dentro de una transacción terminada en `ROLLBACK`. Los RPC nuevos
exigen autenticación y no conceden ejecución a `anon`. Se aisló este despliegue
para no aplicar migraciones pendientes de otros bloques. No se modifica producción.

Las capturas de widgets reales se generan con
`tools/scheduled_workout_preview_visual_test.dart`, usando datos ficticios y un
repositorio que rechaza comenzar. No acreditan instalación en el iPhone.
Las cuatro combinaciones de 320/390 px y texto 1×/2× pasan y producen doce
capturas: cabecera, series y carrera. El siguiente recorrido de aceptación es
recompilar en Mac y probar Inicio → Ver entrenamiento → volver, calendario →
Ver entrenamiento → Comenzar entrenamiento → resultado, y una pauta real de Ervi.
