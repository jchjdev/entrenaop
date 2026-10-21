# Formularios profesionales versionados · 21/10/2026

**Integración Dev · 21/10/2026:** migración aplicada dentro del conjunto profesional
de diez; 195 migraciones locales/remotas coinciden. Los 24 contratos relacionados
vuelven a pasar con ROLLBACK sobre el esquema aplicado, sin datos de ensayo
persistentes. La publicación web/móvil se acredita por separado.

## Alcance implementado

Biblioteca privada de formularios, creación y revisión mediante versiones nuevas,
asignación a una etapa activa de un alumno propio, respuesta completa en la app y
consulta posterior por ambas partes. No añade adjuntos, pagos, diagnósticos,
notificaciones externas ni acceso al historial personal general.

La receta recibida queda fijada al ID de versión. Revisar la biblioteca no cambia
preguntas, opciones ni respuestas de entregas anteriores. Una entrega admite una
respuesta completa e inmutable; la operación de envío y la de respuesta se
conservan al reintentar. Reutilizarlas con otros parámetros se rechaza.

El preparador requiere identidad propia, TOTP/AAL2 y acceso profesional activo
para crear o asignar. El alumno no necesita otra compra Pro para responder. Los
participantes se derivan de la relación/asignación, nunca de un campo enviado por
el cliente. Otro preparador y ADMIN ajeno no reciben permisos de consulta.

Terminar el vínculo o desactivar/caducar el acceso profesional bloquea nuevas
asignaciones y respuestas. Ambas partes conservan consulta de lo ya respondido;
los pendientes se muestran como servicio inactivo. Un reintento idéntico de una
respuesta ya confirmada sigue devolviendo su entrega después de la baja.

## Contrato técnico inicial

- 100 versiones por preparador por defecto, en `trainer_private.form_limits`;
  configurable por servidor, sin conceder edición al cliente ni definir precios.
  Las versiones antiguas cuentan. Crear/revisar usa el mismo bloqueo de acceso
  del resto de autoría; modifica `membership_version` para invalidar snapshots
  anteriores a otra creación concurrente en REPEATABLE READ.
- Hasta 40 preguntas y 20 opciones por pregunta. Tipos: `shortText`, `longText`,
  `number`, `singleChoice`, `multipleChoice`, `scale`, `yesNo`.
- Título 120 caracteres; descripción 1.000; pregunta 200; ayuda 500; etiqueta de
  opción 100. Respuestas de texto: 240 o 2.000. Payloads de receta y respuesta
  limitados también en PostgreSQL a 128 KiB.
- IDs estables de 1..64 caracteres ASCII alfanuméricos/guion/guion bajo,
  comenzando por alfanumérico. Posiciones únicas consecutivas desde cero.
- Números finitos con magnitud máxima de mil millones. El texto numérico admite
  coma o punto inequívocos y hasta seis decimales, sin redondeo. `1,234`/`1.234`
  se rechazan como ambiguos; `0,125` o `1,2340` son explícitos. Al servidor llega
  un número JSON, nunca una cadena numérica. No interpreta separadores de miles.
- Escalas enteras, por defecto 1..5, con hasta 21 posiciones. Opciones ajenas,
  duplicadas y selecciones que exceden el máximo se rechazan.
- Ausente no equivale a cero ni a falso. Flutter omite opcionales vacíos; SQL
  valida obligatorias y tipos. No infiere respuestas ni valores deportivos.

Estos límites son constantes técnicas iniciales; no constituyen planes o tarifas.
La validación Flutter sirve a la experiencia; los permisos y límites efectivos
están en PostgreSQL. Todas las tablas nuevas viven en `trainer_private`, con RLS
como defensa adicional y sin acceso directo de `anon` o `authenticated`.

## RPC

Todas las fachadas públicas son SECURITY INVOKER y delegan en funciones privadas
que comprueban identidad y propiedad. Las funciones auxiliares no tienen EXECUTE
para el cliente.

| RPC | Parámetros | Resultado |
| --- | --- | --- |
| `save_trainer_form` | `p_operation_id uuid, p_payload jsonb, p_previous_id uuid=null` | ID de versión |
| `get_trainer_form` | `p_id uuid` | Versión propia con contenido |
| `list_trainer_forms` | ninguno | Versiones actuales propias |
| `assign_trainer_form` | `p_operation_id uuid, p_relation_id uuid, p_form_id uuid, p_due_date date` | ID de entrega |
| `list_trainer_form_assignments` | `p_client_id uuid, p_before_at timestamptz=null, p_before_id uuid=null` | 50 entregas propias por página |
| `list_my_trainer_forms` | `p_before_at timestamptz=null, p_before_id uuid=null` | 50 entregas del alumno por página |
| `get_trainer_form_submission` | `p_assignment_id uuid` | Entrega, versión y respuesta autorizadas |
| `submit_trainer_form` | `p_operation_id uuid, p_assignment_id uuid, p_answers jsonb` | ID de entrega |

El contenido usa claves `title`, `description`, `questions`. Cada pregunta usa
`id`, `position`, `prompt`, `type`, `required`, `help`, `options`, `minimum`,
`maximum`, `maximum_selections`. Las opciones usan `id`, `label`; las respuestas
son un objeto por ID de pregunta. La versión efectiva se deriva de la entrega.

## Consumidores y navegación

El dominio y codec viven en `packages/trainer_access`. El portal consume
`TrainerFormRepository`; la app, `TrainerStudentFormRepository` mediante su
adaptador de datos. Ninguna pantalla instancia Supabase.

- Portal: `TrainerFormsPage`, `TrainerFormEditorPage` y
  `TrainerClientFormsPage`. La integración de sus rutas corresponde al router
  profesional. El editor necesita su `WorkflowExitScope` y `onExit`, además del
  guard de borrador interno.
- App: se conserva `/profile/trainer`; se añaden `/my-trainer/forms` y
  `/my-trainer/forms/:id`, esta última mediante `_workflowRoute`. Todas exigen
  autenticación y cambian su identidad de widget con la cuenta.
- Mi preparador muestra el acceso a formularios únicamente si existen entregas
  reales, también históricas. No crea una sección vacía para todos los usuarios.
- Los errores conservan los campos. Después de enviar una operación incierta,
  el contenido se fija y el reintento confirma el mismo payload. Una respuesta
  confirmada no se vuelve editable si falla la recarga posterior.

## Evidencia y límites del cierre

La migración `20261021151928_trainer_followup_forms.sql` se comprobó temporalmente
contra Dev junto con `supabase/tests/trainer_followup_forms.sql`, terminando todo
con ROLLBACK; esta comprobación no publica ni deja DDL persistido. El contrato
cubre revisiones, reintentos, respuestas obligatorias cero/falso, opciones ajenas,
MFA, ADMIN ajeno, cuota, desactivación del acceso, baja y consulta retenida.

Dominio y codec tienen pruebas de versión, inmutabilidad, orden, decimales y
ausencias. Las pantallas tienen regresiones de validación, guardado con error,
reintento, respuesta, consulta y presencia contextual. El cierre global del
esfuerzo debe acreditar integración del portal, ejecución completa de las
baterías, migraciones persistidas y recorrido humano con dos cuentas. Este
documento no acredita instalación física, publicación web ni producción.
