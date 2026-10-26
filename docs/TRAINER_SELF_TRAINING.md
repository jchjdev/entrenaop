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

## Nombre editable

«Cambiar nombre» normaliza espacios y exige entre 1 y 100 caracteres, sin controles
ni saltos. El servidor solo actualiza `full_name` propio, su metadata de presentación
y el nombre visible de sus carteras. No acepta correo, rol, derechos ni otro
propietario; conserva el resto de metadata. `profile_private` separa el dominio
del perfil de las capacidades profesionales.

La petición fija propietario y token. Las respuestas tras cambiar de cuenta no
se aplican a otra identidad. El diálogo conserva el borrador tras un error y la
confirmación actualiza AuthCubit sin cerrar sesión ni sustituir permisos.

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

Publicación automática y comprobación HTTPS/Chrome pendientes de registrar. No
se han dejado sesiones ni mensajes de ensayo en cuentas reales. El nombre editable
y las etiquetas del deportista necesitan una nueva build móvil; publicar Trainer
no actualiza el iPhone ni acredita APNs. Las citas nuevas reutilizan el recorrido
profesional ya disponible en las instalaciones anteriores.
