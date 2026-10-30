# Planificación propia y nombre de perfil · 26/10/2026

## Decisión acordada

Javier pide «Para mí»: usar la misma cuenta profesional y de deportista para
asignarse sesiones y programas, realizarlos y revisar resultados, sin consumir
plaza ni alternar identidades. También confirma editar el nombre desde Perfil.

## Contrato

- Entrada propia en Trainer y acceso desde Alumnos. Reutiliza creadores,
  planificación, objetivos, notas, versiones, ejecutor, resultados e historial.
- La relación interna tiene `trainer_id=client_id`. Solo la crea
  `ensure_trainer_self_client` para `auth.uid()`, con propietario esperado, MFA
  y acceso profesional vigente. Es idempotente. Con acceso inactivo se recupera
  la identidad existente/historial, pero no se admiten asignaciones nuevas.
- No necesita invitación, no consume cupo comercial ni uno de los dos
  preparadores externos del deportista. No concede Pro ni cuotas personales.
- No se mezcla en la cartera comercial ni se termina/archiva como un cliente.
  Aparece como destino «Para mí» en asignaciones después de abrirla por primera vez.
- La cita sigue siendo `scheduled_workouts`, origen `coach`, con receta fijada
  y cuenta propia como deportista. Las dos agendas usan el mismo registro;
  la app actualizada distingue la autoasignación en Inicio/agenda.
- El calendario propio completo no exige compartirse consigo mismo. Otros
  preparadores siguen necesitando vínculo, MFA, acceso y consentimiento; no
  reciben resultados, conversaciones ni medios ajenos por consultar la agenda.
- No hay conversación ni avisos de autoplanificación. Los recordatorios optativos
  conservan su política. Formularios, pruebas y técnica son recursos reales de
  la misma cuenta: «Para mí» no simula los permisos de un segundo usuario.
- Conserva protecciones de retirada/archivo/borrado y consentimiento/sincronizador
  Garmin. Abrir la ficha no envía entrenamientos al fabricante.

## Consulta de otras semanas · 30/10/2026

«Para mí» muestra tanto las autoasignaciones como las pautas recibidas de otros
preparadores, con el autor y estado de cada una. Se reutiliza
`get_trainer_shared_calendar` con la identidad propia; no exige compartir el
calendario consigo mismo. Las pautas ajenas permiten consultar su receta y
conservan la protección frente a cambios o retirada desde Trainer.

La navegación de semanas queda fija sobre el calendario, incluso al desplazar
objetivos o tarjetas: anterior, siguiente, Hoy y selector de fecha. El calendario
consulta la semana civil elegida y conserva sus avisos de carga parcial y
paginación. La mejora se aplica también a la planificación de un alumno.

Análisis de Trainer limpio y sus 335 pruebas correctas. Tres regresiones cubren
la sesión futura de otro preparador en la ficha propia, la barra fija y el salto
de fecha. El contrato `supabase/tests/trainer_self_training.sql` añade lectura de
una pauta ajena en otra semana, consulta de su receta y rechazo de su retirada;
comprobado en Dev con ROLLBACK, sin nuevas migraciones ni datos persistentes.
La publicación web se acredita después de terminar el publicador automático.

## Nombre editable

«Cambiar nombre» normaliza espacios y exige entre 1 y 100 caracteres, sin controles
ni saltos. El servidor solo actualiza `full_name` propio, su metadata de presentación
y el nombre visible de sus carteras. No acepta correo, rol, derechos ni otro
propietario; conserva el resto de metadata. `profile_private` separa el dominio
del perfil de las capacidades profesionales.

La petición fija propietario y token. Las respuestas tras cambiar de cuenta no
se aplican a otra identidad. El diálogo conserva el borrador tras un error y la
confirmación actualiza AuthCubit sin cerrar sesión ni sustituir permisos.

## Recorrido de prueba

1. Recargar Trainer y abrir «Para mí» en la barra lateral o en Alumnos. En una
   pantalla estrecha también está en Más. La primera apertura confirma la ficha
   propia; las siguientes recuperan la misma identidad y planificación.
2. Pautar una sesión desde la biblioteca o un programa con sus fechas. La ficha
   y la agenda general de Trainer muestran las mismas citas. El contador comercial
   mantiene las plazas ocupadas por alumnos externos.
3. Abrir la app del deportista con ese mismo usuario y consultar Inicio/agenda.
   Realizar la cita y cerrar su resultado; consultar Resultados en «Para mí».
   Es una planificación real: si la cuenta tiene activada sincronización automática
   de Garmin, las recetas compatibles siguen ese mismo circuito autorizado.
4. En la app actualizada, Perfil → Cambiar nombre → Guardar nombre. La cabecera
   refleja la confirmación y el nombre se conserva al volver a iniciar sesión.

La autoasignación permite probar contenido y ejecución sin otra cuenta. Para
ensayar invitaciones, conversación y aislamiento entre personas hacen falta
identidades distintas; esos límites se verifican también con los contratos SQL.

## Verificación y distribución

Migraciones `20261026060150` y `20261026060153` aplicadas en Supabase Dev;
231 versiones local/Dev coincidentes. Fachadas públicas invoker, sin privilegios
anónimos ni escritura directa de vínculos. Cero usuarios de ensayo persistentes.

- Análisis limpio en raíz, Trainer y ADMIN. Baterías completas: 1.369 pruebas
  raíz (una omisión previa), 247 Trainer y 316 ADMIN (dos omisiones previas).
- Trece contratos SQL sobre el esquema aplicado, todos con ROLLBACK: alta propia,
  nombre, acceso, varios preparadores/calendario, sesiones, programas, ejercicios
  privados, ficha, objetivos, avisos, política de notificaciones y las dos pruebas
  de archivo/borrado. Incluye ejercicio privado propio en el ejecutor sin MFA,
  resultado real cerrado y propiedad de la misma cita en las dos agendas.
- Dieciocho contenciones RC/RR reales en PostgreSQL17 local desechable: dos altas
  propias y alta propia frente a la última plaza comercial, en ambos órdenes.
- Seguridad: mismos 239 hallazgos de asesores antes/después, sin avisos nuevos.
- UI: reintento sin navegar antes de confirmar, borrador de nombre conservado,
  respuesta tardía tras cerrar sesión descartada y menú compacto sin desplazar
  los accesos habituales. «Para mí» no es una simulación de aislamiento externo.

La primera validación de publicación detectó que faltaba `profile_private` en
`BACKUP_SCHEMAS`; se incorpora a la copia/restauración existente y se conserva
la prueba que exige cubrir todos los esquemas declarados. Trainer sigue también
esa dependencia en su disparo de CI. No cambia cifrado, permisos ni destino.

Trainer Dev publicado automáticamente desde `b0392f8eef7333587ce29dfbb0b886df110769b9`,
run `40282825639` con validación y deploy correctos. Verificados por HTTPS revisión,
SHA-256 del JavaScript, entrada, cabeceras y WASM. Chrome acredita la entrada con
la cuenta solicitada, creación/recuperación de su ficha, biblioteca y calendario,
sin conversación propia, y **2/5 plazas antes y después**. No se han creado pautas
reales de ensayo ni se han tocado los creadores abiertos en otras pestañas.

ADMIN también publicado/verificado por HTTPS desde esa revisión. Su run
`40282825568` pasó pruebas y deploy, pero falló una lectura HTTP del job posterior
de retención; repetir solo los jobs fallidos terminó correctamente. Se añaden
reintentos limitados solo de lectura y diagnóstico cerrado, conservando los
controles de borrado y todos los avisos persistentes: 46 pruebas de herramientas
ADMIN y 17 Trainer correctas. El refuerzo queda comprobado en el run `40284404188`
desde `b438d42da089f578c4f33dc48e918bf7405d7ac7`: validación, deploy y retención
correctos, con revisión servida contrastada de nuevo por HTTPS. Trainer conserva
la versión funcional `b0392f8e`; los últimos cambios afectan a mantenimiento/docs.

El nombre editable y las etiquetas del deportista necesitan una nueva build
móvil; publicar Trainer no actualiza el iPhone ni acredita APNs. Las citas nuevas
reutilizan el recorrido profesional disponible en las instalaciones anteriores.
Queda pendiente la aceptación humana de autoasignación → ejecución física en la
app → consulta del resultado y del nombre en la nueva build móvil.
