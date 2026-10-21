# Acceso y clientes del panel profesional · 21/10/2026

> Estado posterior: TRN-011 habilita la gestión manual y la primera cuenta de
> cinco plazas solo en Dev; el panel está publicado y verificado por HTTPS.
> La entrada humana con TOTP sigue pendiente. [Publicación actual](TRAINER_HOSTING_2026_10_21.md).

## Alcance comprobado · TRN-010

Primera interfaz del contrato TRN-008/009, dentro de un único producto:
`trainer_app/` es una aplicación Flutter web independiente de ADMIN y del
deportista. Su destino acordado es `trainer.entrenaop.es`; este bloque no publica
ese subdominio. La identidad EntrenaOP y el autenticador son los mismos, pero
cada origen web conserva su sesión. No se entrega al preparador el rol admin.

Una persona puede ser admin, ejercer como preparador y ser alumna de otra
persona a la vez. Acceso administrativo, acceso profesional, Pro individual y
vínculo son dimensiones distintas. Se conserva un único preparador activo por
alumno y se rechaza el vínculo consigo mismo.

## Recorridos implementados

- **ADMIN → Cuentas → ficha:** consulta del acceso profesional, cupo y clientes
  activos; concesión/retirada manual con motivo y revisión del servidor.
  Las peticiones inciertas conservan su orden para reintentar sin duplicación.
  El formulario no ofrece nuevas reglas de caducidad: conserva la vigencia
  existente. El responsable de cuentas es el mismo del contrato administrativo,
  con su protección MFA. Un editor de contenido no puede gestionar estos accesos.
- **ADMIN → Cuentas → Gestionar entrenadores:** directorio paginado de cuentas
  con acceso profesional registrado, también retirado/caducado, y su gestión.
  El estado manual no acredita que se haya pagado una suscripción. No muestra
  alumnos ni prescripciones privadas del preparador.
- **Panel profesional:** entrada con contraseña y TOTP, alta del autenticador
  si no existe y reutilización del factor ya verificado de ADMIN si lo hay.
  Tras verificar, una consulta de servidor confirma el acceso asegurado.
  Si falla esa consulta, el reintento no consume otra vez el OTP confirmado.
- **Clientes:** acceso vigente/inactivo/caducado, ocupación y cupo completo;
  listas paginadas de vínculos activos/finalizados e invitaciones. Crear un
  código, copiarlo y compartirlo mediante el canal habitual es una acción
  explícita del preparador; la aplicación no envía mensajes.
- **Deportista → Perfil → Mi preparador:** pegar código, consultar quién invita,
  aceptar explícitamente, ver vínculo actual/anteriores y finalizarlo con
  confirmación. Aceptar no exige MFA al alumno ni otra compra.
- **Ambas partes:** finalizar conserva el vínculo histórico y libera la plaza;
  volver requiere una invitación nueva. Los diálogos reutilizan la composición
  accesible existente. Perder acceso profesional no impide terminar vínculos,
  aunque quien actúe como profesional sigue necesitando MFA.

Las invitaciones mantienen el contrato de siete días, un único uso y 32 bytes
aleatorios seguros. El código solo vive en memoria hasta cerrar/abandonar la
pantalla; el servidor guarda SHA-256 y no permite recuperarlo. El mismo ID y
secreto se conservan ante una respuesta incierta. Una invitación pendiente no
reserva plaza: la aceptación comprueba el cupo de forma atómica.

`Mi preparador` es la entrada para gestionar el vínculo. Este bloque no añade
secciones vacías de entrenamientos profesionales en inicio, biblioteca o Mi plan.
Las asignaciones futuras deberán integrarse en el recorrido habitual solo cuando
exista contenido autorizado para ese alumno.

## Integración y seguridad

`packages/trainer_access/` comparte modelos, traducción de errores y adaptadores
de acceso/vínculo entre las tres aplicaciones. No contiene permisos concedidos
por Flutter. El repositorio se vincula a una identidad y comprueba que siga siendo
la misma antes y después de cada petición. Los routers descartan la navegación,
los códigos y los datos al cambiar de cuenta.

El QR TOTP pasa a `entrena_ui`, con adaptadores que conservan los nombres usados
por ADMIN. Se traslada la implementación; no se duplica. Se añade a ese paquete
`web: 1.1.1`, versión ya fijada en ADMIN. No se cambia el circuito de seguridad
administrativo ni se tocan los creadores, Compacto o el algoritmo. Las versiones
resueltas del panel profesional se alinean con el lockfile de ADMIN.
El panel incluye también `cupertino_icons: 1.0.9`, ya resuelto en ADMIN, para
las referencias de iconos adaptativos que detecta la compilación web.

Migraciones nuevas:

- `20261021074426_trainer_portal_summaries.sql`: resumen paginado de relaciones
  propias y consulta de configuración comercial reservada al gestor. Devuelve
  nombre e identidad de la contraparte; no amplía RLS de perfiles ni devuelve
  correos, datos físicos o resultados al preparador.
- `20261021075243_trainer_mfa_and_directory.sql`: TOTP verificado + JWT AAL2
  en servidor para operaciones profesionales y lectura directa por RLS;
  estado de seguridad propio y directorio profesional solo para el gestor.
  Las implementaciones anteriores sin MFA quedan internas sin ejecución para
  `authenticated` o `anon`. Los wrappers expuestos siguen siendo invoker y las
  implementaciones protegidas permanecen en `trainer_private`.

La configuración manual continúa deshabilitada. Lectura posterior en Dev:
cero concesiones profesionales, vínculos, invitaciones, auditorías y usuarios de
ensayo. Las 178 migraciones locales coinciden con Dev. Producción sin consultar
ni modificar. Los asesores no añaden warnings para los objetos profesionales:
permanecen INFO de índices sin uso y configuración cerrada con RLS sin política
ni grants, descritos en el contrato de TRN-008.

## Verificación

- Análisis Flutter de deportista, ADMIN, panel y paquetes afectados.
- Baterías completas de deportista y ADMIN; pruebas del panel, contrato compartido
  y `entrena_ui`. Los recuentos finales y omisiones existentes se registran en Roadmap.
- Rutas reales: Cuentas → Entrenadores → Cuentas, denegación al editor y reto MFA
  antes de consultar; Perfil → Mi preparador → volver. Respuesta tardía de otra
  identidad descartada. Creación/gestión incierta conservan ID/secreto/revisión.
- Configuración inicial TOTP, factor existente, OTP inválido y confirmación
  de servidor fallida sin consumir dos veces el OTP.
- `trainer_access_and_relations.sql` y `trainer_portal_and_mfa.sql` correctas
  contra Dev y terminadas con ROLLBACK. Incluyen aislamiento, MFA/RLS, cuotas
  Free 8/4 con vínculo, directorio, implementaciones internas inaccesibles y
  una cuenta administradora/profesional/alumna simultáneamente.
- `tools/test_trainer_concurrency.py`: PostgreSQL nativo **17.6**, como Dev.
  Ejecuta las tres migraciones reales en un clúster local desechable, con
  contexto Auth mínimo de ensayo. Observa bloqueo entre conexiones antes de
  liberar al ganador: última plaza READ COMMITTED, snapshot REPEATABLE READ y
  reintento, dos preparadores para un alumno, mismo código/alumno y mismo
  código con alumnos distintos. Tres repeticiones por caso: **15 carreras**.
  Necesita COMMIT local para hacer visible al ganador; cada conexión termina
  con ROLLBACK y el clúster propio se detiene y elimina. Nunca conecta a Dev
  ni producción. No equivale a un ensayo concurrente vía GoTrue/HTTP remoto.
- Compilación web release del panel y evidencia de widgets reales en escritorio,
  390 px y 320 px/texto 2×: [capturas](visual-audit/trainer-access-2026-10-21/README.md).

## Límites y siguiente bloque

No se habilita el piloto ni se publica el subdominio. Queda comprobar la entrada
TOTP en navegador con una cuenta profesional de piloto autorizada, incluida la
caducidad de sesión y la recuperación operativa del autenticador perdido.
No se presenta ese recorrido humano como completado mediante pruebas de widgets.

El siguiente bloque profesional es un único recorrido de **sesión privada →
asignación versionada → ejecución en la app existente → resultados autorizados**.
Antes de aplicarlo deben acordarse los derechos tras terminar/caducar el vínculo,
el acceso a contenido ya recibido y la convivencia con el plan automático.
No se presume acceso a todo el historial personal.

La contratación autónoma desde web queda confirmada como objetivo posterior.
Antes de cobrar hay que acordar catálogo y precios, cupo de alumnos activos,
límites de ejercicios/planes privados, tamaño y almacenamiento de archivos y
transferencia de vídeo. Conviene medir esos consumos y limitar recursos caros
sin multiplicar las identidades ni los vínculos. No hay tarifas ni cuotas nuevas
aprobadas; no se añade proveedor de pagos, renovaciones ni cargos automáticos.
La contratación pública necesitará también límites de frecuencia de invitación;
el cupo actual limita relaciones aceptadas, no la cantidad de códigos pendientes.
