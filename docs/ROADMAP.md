# Roadmap de EntrenaOP

**INT-023 · 28/10/2026 · Apple Watch en validación:** primer recorrido de carrera
exterior desde el iPhone con WorkoutKit; receta y editor comunes, autorización
explícita, referencia estable para cambios/retirada, acceso comercial en servidor
y protección de borrado profesional. Solo Dev. La preparación y el ACK local no
cierran el bloque ni acreditan recepción física. Aún no hay envío automático ni
asociación automática de los resultados Apple con la semana.
**Siguiente recorrido único de Apple:** autorizar y comprobar alta, cambio,
retirada y devolución por Salud en el Ultra y su iPhone emparejado.
[Contrato, validación y límites](DEVICE_APPLE_WATCH.md).

**COM-022 · 28/10/2026 · contratación profesional web en curso:** Javier retoma
los dos circuitos de pago profesional y propone Pro personal en las tiendas.
Stripe sandbox configurado y complemento conectado, todavía sin conexión al
servidor de Trainer. Connect guarda cobro directo del entrenador a sus alumnos;
la cuenta/pago de demostración del asistente no acredita nuestro recorrido.
Adaptador sandbox HTTP con
precio/cuenta/comprador fijados, reintentos y HMAC preparado; 43 pruebas locales
incluyendo núcleo y push, tipos Deno correctos. Sin pasarela pública, nuevos
cobros, derechos automáticos ni modificación de la web pública.
**Reglas iniciales aprobadas:** pago confirmado, cancelación a fin del periodo,
regalos/ADMIN independientes y reducción de cupo sin expulsión automática.
**Siguiente bloque:** conectar el servidor a Stripe sandbox, concretar catálogo y persistencia
para integrar pedido → Checkout → conciliación → acceso profesional.
[Dependencias y límites](TRAINER_COMMERCIAL_CONTRACT.md#preparacion-stripe--com-022--28102026).

**TRN-039 · 28/10/2026 · chat al reactivar:** la etapa activa recupera los
mensajes anteriores de la misma pareja; las etapas cerradas conservan su vista
de consulta y no admiten envíos. Solo cambia la lectura del servidor, compatible
con app y Trainer instalados; sin APK ni publicación web nueva. Se conservan
origen de mensajes, acuses, push, MFA y páginas de 50. Cuatro contratos SQL con
ROLLBACK correctos; 242 migraciones coincidentes solo en Dev y sin nuevas alertas
del asesor de seguridad.
**Aceptación física del 28/10:** Javier confirma que el chat reactivado recupera
los mensajes anteriores y funciona bien. Queda aceptada esta corrección de
continuidad. Los avisos profesionales conservan su aceptación física pendiente
en el recorrido separado TRN-037.
[Contrato y pruebas](TRAINER_MESSAGES_2026_10_27.md#continuidad-al-reactivar--trn-039--28102026).

**TRN-038 · 28/10/2026 · invitaciones por enlace:** implementadas creación
vinculada al correo confirmado, copia/WhatsApp/correo, página pública y recepción
nativa con sesión/vista previa/aceptación explícita. Código manual y legado
conservados; MFA, cuotas y calendario sin cambios. Análisis sin incidencias en
raíz, Trainer y ADMIN; 1.428/291/316 pruebas, 25 del paquete y cuatro contratos
SQL con ROLLBACK correctos; 241 migraciones coincidentes solo en Dev.
Publicación automática y HTTPS comprobados: Trainer `b8ee9987` (ayuda final),
ADMIN `74474506`. Compilación iOS de la app sin firma correcta en CI.
Sin APK nueva ni producción.
**Único siguiente recorrido recomendado:** actualizar la app por el flujo habitual
→ enviar enlace a un alumno → abrir desde WhatsApp/correo → entrar con el correo
invitado → aceptar → comprobar el vínculo. Contrastar cuenta equivocada y
cancelación. Tiendas, enlaces HTTPS verificados y recuperación automática tras
instalar siguen pendientes; no se presenta el recorrido físico como aceptado.
[Contrato y comprobaciones](TRAINER_ACCESS_2026_10_20.md#invitacion-por-enlace--trn-038--28102026).

**TRN-037 · 28/10/2026 · push profesionales implementadas y servidor Dev publicado:**
mensajes/vídeos agrupados entre alumnos, preferencias separadas, descanso,
lecturas y comprobación de permisos antes de enviar. 1.421 pruebas raíz,
286 Trainer, 316 ADMIN, 12 Node y siete contratos SQL con ROLLBACK; 240
migraciones coincidentes. Worker v9 con JWT y rechazo público 401. Trainer y
ADMIN publicados automáticamente en `dd1c4ffe`, con HTTPS/recursos comprobados.
APK Dev firmada 1.0.0-beta.2+3 preparada; iOS sin firma compila en CI. Nadie recibe
el alta de avisos automáticamente. La entrega física profesional sigue abierta:
**único siguiente recorrido recomendado:** actualizar Android → activar Avisos
de mis alumnos → enviar mensajes y técnica desde alumno → comprobar agrupación,
apertura con MFA y lectura previa desde web. No hay Android conectado hoy;
Apple/APNs, cobros reales y la oferta militar siguen pendientes. COM-021 fija
la referencia anual general en 39,99 €; catálogo Test Store EUR actualizado
y releído el 28/10 (mensual 3,99 €).
[Recorrido, límites y comprobaciones](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

**TRN-036 · 28/10/2026 · consulta profesional móvil preparada:** selector
por acceso confirmado y dos espacios independientes en la app; Resumen, Agenda,
Alumnos y Mensajes reutilizan permisos/MFA y componentes comunes. Consulta
objetivos, calendario compartido y resultados; responde conversaciones y vídeos
con reintento protegido. La consulta de vídeos sin primera corrección está
aplicada solo en Dev y ocho contratos terminan con ROLLBACK. Análisis limpios,
1.413 pruebas raíz, 286 Trainer, 316 ADMIN y 271 de los paquetes compartidos
correctas; capturas revisadas a 320/390 píxeles con texto ampliado.
**Siguiente recorrido de este bloque:** nueva instalación móvil → entrar con
MFA → atender a un alumno → comprobar resultado/corrección → volver al espacio
personal y al preparador propio. Pendiente aceptación física; la push nativa al
preparador se implementa después en TRN-037; no se amplían creadores móviles, cobros, algoritmo ni producción.
[Alcance y verificaciones](TRAINER_MOBILE_WORKSPACE.md).

**INT-021 · 27/10/2026 · Beta CIQ 1.6 instalada; ensayo automático en curso:** recuperación por alias exacto
en biblioteca general para descargas previamente solicitadas, sin borrar ni
atribuir propiedad. Modo automático cada 15 min tras primera lista autorizada,
un FIT por evento, diario acotado, reintentos limitados y sin aceptar avisos.
54 pruebas por variante, nueve HTTP, contrato SQL con ROLLBACK y privacidad Dev
verificados. Javier confirma instalación de 1.6 desde la misma beta privada,
una sesión y app cerrada. Tras recuperar su acceso a Trainer se aplica
**Automática 1** (3×5 a 20 kg, descanso 0:30) a las 22:41:38 UTC sobre la misma cita.
**Único siguiente recorrido CIQ:** contrastar la descarga nativa con app cerrada,
su reconocimiento posterior sin volver a descargar y otro cambio sin duplicados
en la lista. Primer ciclo: exportación 155 y GET FIT 200 a las 22:50:07 UTC,
sin petición de FIT/manifiesto desde el PC. Javier confirma revisión 155 con
receta correcta en Fuerza antes de abrir EntrenaOP: importación aceptada.
Javier confirma además una sola sesión lista y apertura correcta; logs hasta
23:03:32 UTC conservan solo el GET de fondo. Primer ciclo completo aceptado sin
redescarga. **Pendiente inmediato:** corregir el diagnóstico que sigue solicitado
y oculta campos, luego aplicar otro cambio; Automática 2 todavía no se ha aplicado
y Javier necesita descansar. Recuperación con móvil
desconectado y denegación también pendientes. Las copias nativas antiguas no se
eliminan. Instalación y lista inicial no acreditan estos pasos.
[Contrato](DEVICE_GARMIN_TRAINING.md#reconocimiento-y-descarga-automatica--int-021).

**Beta Android privada · 27/10/2026 · APK preparada y verificada:** firma
estable externa a Git, compilación release Dev con push y verificación de
identidad/recursos, versión 1.0.0-beta.1+3. Análisis raíz limpio, 1.381 pruebas
correctas con una omisión existente y nueve comprobaciones de firma. Acceso
profesional, ficha propia y permiso Garmin del compañero
comprobados en Dev sin modificar su cuenta. **Siguiente recorrido de este piloto:**
instalar la APK → pautarse desde Para mí → ejecutar/consultar resultado → conectar
Garmin y comprobar llegada al fēnix 7 Solar; avisos reales entre dos cuentas y
recordatorios conservan su prueba propia. Connect IQ para ese reloj/distribución
entre cuentas sigue fuera de la entrega Android; no se cierra la integración
general ni se habilitan cobros/producción. [Circuito y límites](ANDROID_BETA.md).

**INT-020 · 27/10/2026 · ensayo de descarga silenciosa:** Javier prioriza probar
un FIT con app cerrada y sin aceptar avisos. Beta 1.5 incorpora un modo acotado
con biblioteca de partida, cita elegida, autorización actual y un solo GET FIT.
La inspección posterior no descarga en primer plano; HTTP 200 no demuestra
importación. 38 pruebas por variante, contrato SQL con ROLLBACK y privacidad Dev
verificados. Javier confirma **EOP1000000144** en Fuerza nativa antes de abrir
EntrenaOP, con 3×5 a 20 kg y descansos de 1:15: descarga e importación en fondo
aceptadas en su fēnix 8 de 47 mm. Javier confirma después salida del ensayo y una
sola sesión en la lista habitual. Durante la inspección previa sigue **FIT
solicitado en fondo**,
incluso tras START: la app no confirma la copia en su biblioteca propia ni la
respuesta FIT final. Esa discrepancia originó INT-021, que prepara reconocimiento
en biblioteca general y descarga continua. El ensayo 1.5 no acreditaba esos
comportamientos; la aceptación vigente se registra en INT-021 arriba.
[Protocolo](DEVICE_GARMIN_TRAINING.md#ensayo-silencioso-en-segundo-plano--int-020).


**TRN-030/031 · 27/10/2026 · calendario con eventos publicado en Dev:**
mes con tiras de alumno/sesión, colores estables por alumno, estados accesibles,
excedente por día, detalle y arrastre revisado; semana comparte las tiras.
Programas conservan la selección recibida y muestran confirmación fija. Análisis
Trainer limpio y 256 pruebas correctas, incluida conservación de citas iniciadas,
filtros, paginación y fechas. Fuentes `553b373e`, run `40541898947` con validación
y despliegue correctos; revisión y recursos contrastados por HTTPS en Trainer Dev.
Aceptación humana del recorrido visual pendiente. **Único siguiente tramo de
Trainer:** revisar ficha del alumno → resultados → técnica/conversación y continuar
el pulido del espacio Preparador del deportista. Avisos agrupados requieren su
prueba física propia y los cobros siguen pospuestos. Este cambio no cierra los
16 puntos ni el bloque independiente de Connect IQ.
[Presentación y evidencia](TRAINER_DESKTOP_2026_10_25.md#agenda-mensual-con-eventos--27102026).


**INT-018 · 27/10/2026 · beta privada Connect IQ instalada:** variante
EntrenaOP Beta 1.3.0 con identidad independiente y servidor Dev, paquete release
generado, 16 pruebas Beta y 16 Dev correctas. Solo la cuenta Garmin que suba la
beta podrá verla; ficha creada con distintivo BETA. Tras Pending Scan, descarga
habilitada y solicitud de instalación confirmada por Garmin para el fēnix 8
de 47 mm en la próxima sincronización. Javier confirma después **Beta 1.3**
abierta en el reloj con código nuevo: instalación e inicio desde Store aceptados.
Vinculación posterior confirmada en la cuenta secundaria, cuya única cita era
una carrera y daba lista vacía de fuerza. Se pauta allí una muestra técnica de
press banca 3×5 a 20 kg y 60 s; manifiesto de una entrada y FIT generado correctos.
Javier confirma después una sesión y receta correcta en Fuerza; queda aceptado
Store → vínculo → FIT privado → Fuerza nativa. Alias fotografiado y contrastado
con la exportación propia 104. Se retira el vínculo Beta para comprobar bloqueo;
estado, manifiesto y descarga rechazados por servidor con ROLLBACK.
Javier confirma **Vinculación caducada o retirada** al reabrir Beta: prueba de
revocación aceptada físicamente. El vínculo nuevo se confirma y recupera la lista,
pero falla inicialmente la reapertura local con **No se pudo abrir en Fuerza**.
Un reinicio normal la recupera y Javier confirma otra apertura sin reiniciar;
causa concreta sin identificar. Beta operativa, vínculo nuevo y avisos de cambios
activados por Javier. No se ha repetido aún un aviso físico nuevo en Store.
Javier autoriza nombre EntrenaOP y acuerdo Garmin. Firma verificada por SDK;
texto de error anterior oculto, estado visible Verified. Aviso estático de
privacidad desplegado en Dev, con 176 pruebas servidor, tipos estrictos y contrato
SQL con ROLLBACK correctos. No se publica al público ni se habilita producción.
Revocación del vínculo Dev aplicada desde
Perfil y bloqueo de estado/manifiesto/descarga acreditado en servidor con ROLLBACK;
la prueba física se completa después sobre Beta. INT-019 implementa en Beta 1.4
la vista de apertura, bloqueo de intent repetido, descarte tras salir y diagnóstico
local, conservando permisos. Veinticinco pruebas por variante y firma correctas;
Store registra 1.4.0 (Internal: 2) en la misma beta privada. **Siguiente paso de este
recorrido:** aceptar físicamente actualización, apertura repetida y cancelación
de 1.4 en el fēnix. Javier confirma después recuperación de timeout -300 y
apertura con contenido. Publicada 1.4.1 en la misma beta privada (Internal: 3),
con reintento manual/autorización nueva
y ajuste circular, 30 pruebas por variante y vista de timeout revisada en
simulador. Javier confirma **TODO EN ORDEN** al comprobar instalación, textos y
apertura de 1.4.1; aceptados físicamente. **Única comprobación siguiente del piloto:**
cancelación y reapertura repetida de esta versión, incluyendo recuperación ante
otro timeout si aparece. Piloto actualizado y operativo; integración general abierta.
[Preparación y requisitos pendientes](../connect_iq/store/BETA.md).

**INT-017 · 27/10/2026 · transporte privado aceptado en Dev:** diseño aprobado,
contrato SQL aplicado y endpoint privado desplegado/verificado. Perfil → Garmin
permite revisar/confirmar código y revocar; perder Pro y servicio bloquea uso,
conservando solo gestión de permisos. App 1.0 copiada/releída en fēnix, con espera
corregida y apertura condicionada a manifiesto actual. Verificación del 26/10:
análisis limpio, 1.379 pruebas raíz y una omisión existente, ocho Monkey C y
contratos SQL con ROLLBACK correctos, sin avisos nuevos. El 27/10 se ajusta identidad
nativa desde servidor (`ciq-private-2`), con 175 pruebas y tipos correctos. Javier
confirma **cuenta vinculada → FIT privado inalámbrico → Fuerza nativa**, press
banca 3×5 a 20 kg y descanso 1:00, sin reinstalar por USB. Se descarta y retira la
primera prueba: Garmin confirma cancelación y Mi semana muestra una sola cita hoy.
Tras sincronizar, Javier confirma solo «CIQ prueba 2» en el calendario Garmin del
iPhone y en Entrenamientos del reloj. **Único siguiente ensayo:** revocar el vínculo
propio y comprobar bloqueo físico en el reloj. El aviso automático al entrar
en Fuerza y la asociación del FIT propio con Training API no quedan acreditados. El bloque
de sincronización general sigue abierto. Store, otros relojes y revocación física
siguen pendientes; no se borran ni bloquean remotamente copias nativas antiguas.
Ensayo de cambio preparado sobre la misma cita: 3×6 a 22,5 kg, descanso 1:15 y
título «CIQ prueba 2 - actualizada», con recibo `sent` y los mismos IDs Garmin.
Servidor rechaza la exportación vieja y conserva una entrada al repetir manifiesto;
Javier confirma la receta nueva en Fuerza nativa y una sola entrada en EntrenaOP
tras dos actualizaciones y reapertura, sin errores.
PRG 1.1 preparado con
OP oficial y aviso opcional por cambio, compilación limpia y diez pruebas Monkey C;
PRG copiado/releído por USB con hash idéntico; Javier confirma inicio en 1.1 y OP
naranja y dosis 3×6 a 22,5 kg con 1:15. Los avisos se aceptan con 1.3 más abajo; la lista
única no acredita limpieza de la biblioteca nativa.
Javier activa avisos; misma cita renombrada «CIQ prueba 2 - aviso automático»,
revisión 5, dosis conservada, `sent` con los mismos IDs y manifiesto de una entrada.
Esa prueba inicial no consigue todavía el aviso con la app cerrada.
Sin aviso acreditado: No molestar apagado y notificaciones del iPhone recibidas;
logs Dev con respuestas 200. Versión 1.2 preparada con diagnóstico local de pasos,
HTTP y antigüedad, compilación limpia y quince pruebas Monkey C. Paquete 1.2
copiado/releído por USB con hash idéntico; arranque y sincronización confirmados
por Javier. Misma cita «CIQ prueba 2 - aviso 1.2», revisión 6 y mismos IDs Garmin,
dosis conservada. La prueba 1.2 no consigue el aviso y se lee el diagnóstico.
Javier comunica «Ya está actualizado» y 200, sin aviso. Se repite con revisión 7,
«CIQ prueba 2 - aviso final»: Dev registra la consulta y se pide el primer estado,
HTTP y antigüedad antes de otra comprobación. Sigue la 1.2 sin reinstalar.
Javier comunica el primer resultado «App en primer plano», hace 2 min, HTTP 200
estando en la esfera: localizado el filtro incorrecto `isActive()`. Versión 1.3
preparada: suspende evento al abrir y programa cada 15 min al salir, con consulta
activada y vínculo sin código pendiente, según BackgroundTimer del SDK. Compilación
limpia y 16 pruebas Monkey C correctas; paquete 1.3 copiado/releído por USB con hash
idéntico. Javier confirma inicio 1.3, sincronización y consulta/avisos activados
antes de salir. Ensayo con revisión 9 de la misma «CIQ prueba 2 - aviso final»,
nombre y dosis conservados, manifiesto completo con identidad nueva y mismos IDs
Garmin. **Aceptación física del 27/10:** Javier confirma aviso con la app cerrada,
aceptación, actualización sin errores y una sola sesión en EntrenaOP. Traza Dev
coherente: consulta 200 y descarga FIT 200 de la exportación propia nueva. Tramo
de aviso/actualización asistida aceptado en 1.3; descarga en primer plano al aceptar.
Rechazo/repetición de avisos, pérdida de red, retirada/revocación, limpieza nativa
y distribución general siguen pendientes. No se cierra el bloque general.
No equivale a importar FIT con la app cerrada.
[Contrato y evidencia](DEVICE_GARMIN_TRAINING.md#cuenta-y-entrega-privada--int-017--26102026).

**INT-016 · 26/10/2026 · primer tramo Connect IQ cerrado en Dev:** muestra
sintética → descarga inalámbrica → instalación propia → apertura en Fuerza nativa
con nombres/notas, repeticiones, carga, isométrico y descansos correctos, aceptado
por Javier en fēnix 8 sin USB. Endpoint Dev releído, compilación estricta y dos
pruebas Monkey C correctas; 166 pruebas servidor y tipos correctos. La respuesta
llega después de 60 s; latencia/espera pendientes de pulir. Sin entrega privada,
background, otros relojes ni retorno acreditados; duplicados tras reinicios y
cambios/retirada siguen pendientes. **Único siguiente bloque de este recorrido:**
vinculación segura de cuenta y entrega de instantáneas autorizadas por revisión,
caducidad/revocación y recuperación de reintentos, conservando OAuth actual.
[Contrato y evidencia](DEVICE_GARMIN_TRAINING.md#puente-connect-iq--int-016--26102026).

**TRN-033 · 26/10/2026 · «Para mí» y nombre editable:** implementado y aplicado
en Dev, 231 migraciones coincidentes. Reutiliza planificación/ejecución/historial
sin cupo; nombre propio editable desde Perfil. Análisis limpio y baterías completas
1.369 raíz, 247 Trainer, 316 ADMIN; 13 contratos SQL con ROLLBACK, 18 contenciones
RC/RR y seguridad sin avisos nuevos. Trainer publicado automáticamente desde
`b0392f8e`, run `40282825639`, y verificado por HTTPS/Chrome: ficha propia operativa
con 2/5 plazas antes y después. ADMIN publicado/verificado; retención correcta al
reintentar una lectura HTTP y refuerzo acotado de lecturas con 46+17 pruebas de
herramientas. El refuerzo queda verificado en CI `40284404188`, con validación,
deploy y retención correctos. Instalación móvil pendiente. **Siguiente recorrido único:** asignarse
desde «Para mí», realizarlo con la misma cuenta y consultar el resultado; después
comprobar el nombre desde la nueva build del deportista.
[Contrato](TRAINER_SELF_TRAINING.md).

**TRN-031 · 25/10/2026 · borrado tras retirada Garmin confirmada:** ajuste
implementado y aplicado en Dev. Permite quitar la cita de prueba sin resultados
cuando la retirada remota está confirmada y la cola terminada, sin leases vigentes; conserva
recibos y versiones. Scan/take ignoran las identidades borradas. Análisis limpio,
245 pruebas Trainer, 84 carreras RC/RR y cinco contratos SQL con ROLLBACK correctos;
asesores sin avisos nuevos. Trainer Dev publicado automáticamente desde `605a3020`
y verificado por HTTPS; run 40240963267 correcto.
**Siguiente recorrido único:** probar en Trainer publicado una retirada de Garmin
confirmada y comprobar permiso de borrado, frente a otra pendiente que sigue
bloqueada; las notificaciones mantienen su prueba humana prevista.
[Contrato y evidencia](TRAINER_CLIENT_PLANNING.md#ajuste-retirada-de-garmin-confirmada--25102026).

**TRN-031 · 25/10/2026 · archivo y borrado de citas:** recorrido implementado,
aplicado, publicado y verificado en Trainer Dev desde `2b9ea1b8` (run 40238901174). Ficha, Agenda y pautas comparten filtros Habitual/Retiradas/
Archivadas/Todas y acciones recuperables. Borrado propio, retirado y protegido
por servidor ante resultados, conversaciones, vídeos y operaciones Garmin no cerradas.
No elimina plantillas ni referencias externas; no reactiva sesiones ni push.
Análisis Trainer limpio, 244 pruebas, 60 carreras RC/RR y cinco contratos SQL
con ROLLBACK correctos. Actions y verificación HTTPS correctos; Chrome acredita
filtros y bloqueo explicado por resultados/Garmin. Aceptación humana pendiente. **Siguiente recorrido único:** revisar en Trainer publicado una
retirada → archivo → filtro → restauración y la explicación de borrado bloqueado;
los avisos se prueban mañana siguiendo el guion ya guardado.
[Contrato y verificación](TRAINER_CLIENT_PLANNING.md#archivo-y-borrado-de-asignaciones--25102026).

**TRN-029 · 25/10/2026 · agrupación y preferencias implementadas en Dev:**
planificación/conversación agrupadas por preparador, contador por grupos y lectura
con generación; historial íntegro. Cola con esperas y pausas, descanso editable
22:00–08:00 y zona IANA. Recordatorios apagados, mismo día/anterior y hora elegible,
uno por fecha/dispositivo para todo el alumno. Revalida lectura, cuenta, servicio,
preferencias y sesiones canceladas/completadas antes de enviar. Migración aplicada,
worker Dev v8 con JWT, horario activo cada minuto y APK instalada en el Samsung.
Análisis limpio, 1.365 pruebas raíz y una omisión previa, 10 Node, tipos estrictos,
42 carreras RC/RR y cuatro contratos SQL con ROLLBACK correctos. Sin paquetes nuevos.
**Siguiente recorrido único de avisos:** probar físicamente un lote real de Trainer,
mensajes y recordatorio elegido → apertura del recurso correcto, respetando descanso.
No se acredita recepción física de la nueva política por instalar la APK.
Apple/APNs, badge nativo y producción pendientes; cobros fuera de este bloque.
[Política, evidencia y límites](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md#agrupación-y-recordatorios--25102026).

**Garmin · 25/10/2026 · circuito profesional aceptado y publicado en Dev:**
Javier confirma en fēnix alta automática, cambio de día sin duplicados y retirada
tras sincronizar. Se conservan las referencias del proveedor. Estado por cita
plegable común a deportista/Trainer; errores permanentes y transitorios separados,
confirmación de calendario tras cambios y consulta profesional READ ONLY corregida.
Dos migraciones Dev cotejadas; contratos SQL con ROLLBACK y autoridad real,
análisis limpios, 1.358 pruebas raíz, 238 Trainer, 316 ADMIN y 154 de servidor.
CI Garmin/iOS correcta y Trainer Dev `a4bfb355` publicado/verificado por HTTPS.
La carrera nueva recibida queda pendiente de asociación, sin cierre supuesto.
**Siguiente recorrido único:** aceptar una pauta real del algoritmo y su actividad
de vuelta, revisando asociación y cierre. El algoritmo comparte orquestación y tiene
cobertura de publicación/reset; no se presenta como aceptación física nueva.
Las demás marcas se posponen y el editor conserva su receta independiente.
[Estado, validación y límites](DEVICE_GARMIN_AUTOMATIC_SYNC.md#revisión-del-ciclo-completo--25102026).

**TRN-029 · 25/10/2026 · Firebase y primera push Android:** creado
`entrenaop-dev` en Spark, sin Analytics/facturación. Configuración pública y
lanzamiento Android versionados; APK instalada conservando datos en el Samsung
SM-A326B. Javier activa los avisos y confirma recepción de la prueba aceptada
por FCM HTTP 200. Worker Dev v7 y horario cada minuto activos, con JWT obligatorio,
credenciales manuales separadas de la clave interna y tickets de un uso/55 s para
no depositar secretos permanentes en pg_net. Primera ejecución automática 200,
con descarte correcto por no haber avisos recientes pendientes. Análisis limpio,
1.353 pruebas raíz (una omisión), ocho Node, tipos estrictos y dos contratos SQL
con ROLLBACK correctos. Migración de tickets aplicada selectivamente en Dev;
no se integra ni se aplica trabajo Garmin ajeno.
**Siguiente recorrido único:** comprobar un evento real de Trainer → alerta en
segundo plano → apertura en la cuenta del alumno, y después permisos/cambio de
cuenta. Apple/APNs, badges nativos y producción quedan pendientes.
[Configuración, aceptación y límites](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

**TRN-032 · 25/10/2026 · publicación automática Trainer · operativa en Dev:**
motor FTPS común con ADMIN, adaptadores, cuentas y entornos separados. 59 pruebas
Python correctas; Trainer valida, compila, conserva artefacto y publica en el run
`40225422916`. ADMIN conserva su publicación tras la extracción: run `40225423177`
con validación, deploy y retención correctos. Entorno Trainer limitado a main,
cuenta confinada y secretos configurados por Javier para la contraseña. Ambos
portales confirman por HTTPS fuente `3188c701` y sus hashes. Sin producción.
**Siguiente recorrido único:** siguiente cambio funcional de Trainer → push a
main → publicación automática y verificación de la versión servida.
[Contrato y evidencia](TRAINER_DEPLOYMENT_2026_10_25.md).

**TRN-031 · 25/10/2026 · planificación desde el alumno · publicada en Dev:**
la ficha reúne biblioteca propia, semana conjunta y detalle, con retorno de los
creadores existentes al mismo alumno/día. Arrastrar prepara la confirmación;
pautas ajenas solo permiten lectura y desaparecen si se revoca la compartición.
Objetivo de oposición por servicio: convocatoria, fecha y metas de protocolos
propios, con última evaluación, anterior y mejor marca separadas. Dos migraciones
aplicadas solo en Dev, contrato transaccional correcto antes/después y sin datos
de ensayo persistentes. Análisis limpios y baterías completas: 1.353 pruebas raíz,
316 ADMIN y 236 Trainer. Trainer Dev publicado desde `04a1f87c`, verificado por HTTPS y
en Chrome: ficha, semana, objetivos, biblioteca y confirmación sin crear pautas.
**Siguiente recorrido único:** aceptación con Javier de alumno → objetivo →
crear/arrastrar → confirmar pauta → consultar calendario junto al otro preparador.
No incluye cambios de Inicio del deportista, puntuación oficial, cobros o push.
[Contrato y evidencia](TRAINER_CLIENT_PLANNING.md).

**TRN-030 · 25/10/2026 · escritorio profesional · revisión final publicada en Dev:**
completada la pasada de las pantallas actuales y sus creadores compartidos.
Fuerza/carrera usan lienzo y propiedades de la selección; el creador de programas
mantiene fases/recetas resumidas, clasificación desplegable y guardado fijo. El
creador de ejercicios se organiza en dos columnas. Catálogos, formularios, pruebas y conversación comparten
el acabado. Fuente final en ambos portales: `6fe1d35c`.
Análisis limpios; 1.349 pruebas raíz, 316 ADMIN, 207 Trainer, 218 editor y 28
interfaz común, con las omisiones anteriores de raíz/ADMIN. Release, HTTPS y
recorridos reales comprobados; 21 capturas finales optativas.
ADMIN tuvo un fallo FTPS en el run `40196467093` y se recuperó con su artefacto
original. El transporte automático ya quedó reparado y acreditado en el run
`40217442803`, con TLS/SNI conservados y publicación HTTPS verificada.
[Corrección comprobada](ADMIN_DEPLOYMENT_2026_10_19.md). Trainer se publica en su directorio.
Sin cambios de permisos, datos, cuotas, dependencias ni producción.
Siguiente recorrido único: aceptación con Javier de creación, programa, agenda
y seguimiento en el escritorio publicado. Cobros, Firebase/Apple y recepción
push quedan pospuestos. [Evidencia y límites](TRAINER_DESKTOP_2026_10_25.md).

**TRN-029 · 24/10/2026 · recuperación, etiquetas y push preparada:** cerrado el recorrido de
persistir/retomar sesiones de programa y adaptaciones sin aplicar borradores ni
duplicar resultados. Contrato aplicado solo en Dev y tres pruebas SQL con
`ROLLBACK`; 199 pruebas Trainer, análisis limpio y 48 contenciones locales
RC/RR correctas. Web publicada en Trainer Dev desde `95c0e8c8`, verificada por
HTTPS; aceptación humana de pérdida de respuesta pendiente.
El selector compartido incorpora etiquetas privadas de ejercicios, con 54
contenciones locales y aislamiento por cuenta/contexto. La app del deportista
prepara consentimiento y transporte FCM opcional; cola/RPC y función de envío
publicadas en Dev, con JWT y credenciales de worker, envío desactivado. Análisis
limpio, 1.349 pruebas raíz, APK debug, cinco pruebas de servidor y 66 carreras de
push correctas. Chrome acredita acceso y lectura de etiquetas sin modificar
datos en la web actualizada. ADMIN incorpora las etiquetas y verifica publicación
desde `46351527` (run `40133604371`); los ensayos de transporte y restauración pasan en CI.
CI de iOS Release/simulador correcta con Xcode 26.2 y envío apagado; el primer
registro APNs tiene regresiones Dart, sin afirmar recepción física.
El límite conservado también se aplica al cambiar de cuenta, acreditado por
regresión SQL en Dev y las 66 carreras repetidas.
Siguiente recorrido único: configurar Firebase/APNs de Dev y aceptar una entrega
física completa cuando Javier disponga de Apple/configuración. No se acredita
recepción física ni se incluyen cobros o etiquetas de programas/sesiones.
[Evidencia y fronteras](TRAINER_SESSION_WORK_DRAFTS.md).
[Push preparada y pasos de activación](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

**TRN-028 · 24/10/2026 · varios preparadores:** Recorrido: alumno acepta dos
invitaciones, habilita la compartición, cada preparador consulta agenda/pauta de ese
alumno y mantiene aislada su cartera. La revocación y la baja parcial/total se
comprueban en servidor. El arrastre de herramientas conserva todos los movimientos entre
fotogramas. Siguiente recorrido único de este bloque: aceptación con dos preparadores y
un alumno de prueba en la app actualizada. No incluye edición cruzada ni pagos
compartidos.
[Contrato y evidencia](TRAINER_MULTI_COACH_2026_10_24.md).

**Revisión y comparación histórica · 24/10/2026:** implementados filtro
opcional de diferencias y comparación por fecha para deportista y Trainer,
con dominio y controles compartidos. La lectura mantiene permisos actuales,
paginación, datos ausentes, tiempos nativos y contexto; exige la misma plantilla
y versión y una posición/variante inequívoca. AMRAP mantiene vueltas y parciales.
Validación: análisis limpio en las tres apps, 1.330 pruebas raíz (una omisión
previa), 182 Trainer y 314 ADMIN (dos omisiones previas). Componente web comprobado
con datos de ejemplo. No modifica el cierre o envío Garmin ni interpreta dos
marcas como tendencia deportiva. Fuentes `b2bf067b` subidas a main; Trainer Dev
publicado y verificado por HTTPS. Filtro y consulta autenticada contrastados en
ambas apps sin escrituras; sus pruebas actuales aún no tienen otra ejecución de
la misma versión. CI de servidor/consumidor/iOS Release y ADMIN Dev correctas.
**Siguiente recorrido único:** aceptación con dos ejecuciones reales de la misma
sesión/versión, comprobando filtro y comparación en móvil y en la revisión del
preparador. [Contrato](TRAINER_PRIVATE_WORKOUTS.md#revisión-y-comparación--24102026).

**UI-065 · resultados profesionales compactos · 23/10/2026:** cabecera por
bloque y tarjeta plegable por posición de ejercicio de fuerza, con colores
por formato, resumen de cumplimiento y detalle de pauta/resultado por serie.
No mezcla nombres repetidos, posiciones, bloques o tramos de carrera, ni
promedia excepciones. Análisis limpio y 179 pruebas Trainer correctas,
incluidas pantallas estrechas con texto doble. Release local comprobada en
Chrome con dieciséis series en tres tarjetas; captura con datos ficticios,
sin escrituras de resultados. Publicado después en Trainer Dev con autorización
expresa: verificador HTTPS correcto y Chrome acredita tres series reales
agrupadas, con detalle original al desplegar y sin errores de consola.
**Siguiente paso único de UI-065:** aceptación de Javier en su revisión habitual
de una sesión larga; no amplía la cobertura de fuerza Garmin.
[Contrato de presentación](TRAINER_PRIVATE_WORKOUTS.md#resultados-compactos--ui-065--23102026).
**Extensión al deportista · 24/10/2026:** el historial incorpora tarjetas de
fuerza plegables por posición, colores por formato, resumen fiel y control
conjunto de apertura/cierre, conservando correcciones, tiempos del reloj y
separación entre bloques. No cambia datos, recepción, cierre o permisos.
Análisis limpio y batería raíz completa: 1.314 pruebas y una omisión previa.
Distribuir en iPhone requiere actualizar main; no se publica otra web de Trainer.
Web Release local y apertura/plegado del resultado existente comprobados sin
errores de consola, conservando controles de corrección y mediciones originales.

**INT-013 · primera entrega de fuerza en Dev · 23/10/2026:** reutilizar el creador
común y el ciclo de cuenta, asignación, envío/cambios/cancelaciones y retorno
para cerrar la misma cita con mediciones reales. Implementada la vía profesional
por series para banca con barra, flexiones estándar y dominadas pronadas; otros
formatos y las prescripciones especializadas del algoritmo siguen fuera.
Dos migraciones y cuatro funciones actualizadas solo en Dev. Raíz 1.308 pruebas y
una omisión previa, Trainer 172, servidor 151, tipos y análisis correctos;
contratos SQL de carrera y fuerza correctos con ROLLBACK, incluida lectura MFA
del mismo resultado desde Trainer. Los tiempos de detalle conservan segundos
legibles y el ritmo usa el tiempo decimal original de cada serie. Una corrección
manual descarta esa precisión de dispositivo. Primera sesión creada/asignada
desde Trainer y envío real desde EntrenaOP confirmados en calendario Garmin.
La sincronización automática de esa cuenta estaba desactivada; esta aceptación
es de un envío explícito, sin modificar su preferencia ni enviar otras citas.
La app anterior sigue recibiendo solo carreras V1; el cliente nuevo solicita
V2 para mostrar fuerza, sin cambiar los reintentos de confirmación previos.
Punto de guardado funcional `9c5c9a27`, con CI completa correcta el 23/10/2026
(backend, aplicación e iOS Release). Javier autoriza después publicar el paquete
web de Trainer `6f15d325`: desplegado y contrastado por HTTPS y Chrome, con
tiempos originales del reloj en la misma ejecución y sin escrituras de resultados.
Aceptación técnica posterior con fēnix 8 y actividad simulada: recepción
automática correcta, tres series activas revisadas sin reutilización, cierre
de la misma cita desde la app y resultado visible en Trainer sin errores.
No acredita haber realizado físicamente esas series ni otras variantes.
**Siguiente recorrido único:** ensayar una sesión convencional real con marcas
distintas de la pauta para contrastar la fidelidad del resultado. Actualizar el
iPhone desde main antes de probar el menú ampliado. No habilita cierres sin revisión.
[Alcance solicitado](DEVICE_GARMIN_TRAINING.md#fuerza--recorrido-solicitado-int-013).

**INT-012 · retorno de carrera aceptado en Dev · 23/10/2026:** observación FIT
privada por cuenta, revisión de vueltas/cita y confirmación atómica que completa
la semana mediante el cierre existente. Servidor activo solo en Dev, contrato
SQL transaccional y concurrencia local correctos; app con recorrido de revisión
y totales medidos. Reenvío oficial del FIT real, revisión y cierre desde la app
web comprobados: semana completada, siete resultados, cinco series y un recibo.
Auto Lap conserva vueltas originales y la versión archivada exige entrega exacta
y autoridad vigente. Raíz 1.302 pruebas y una omisión previa, Trainer 171,
servidor 145, tipos y análisis correctos. Tres migraciones aplicadas solo en Dev.
Código `4160082f` en GitHub; CI 39942562157 correcta con servidor, consumidor
y compilación iOS Release sin firma ni publicación.
**Siguiente recorrido único:** actualizar iPhone desde main y comprobar el nuevo
menú y el mismo resultado ya cerrado, sin volver a enviar la sesión al reloj.
Fuerza Garmin, otros proveedores y producción permanecen fuera de este cierre.
[Contrato y comprobaciones](DEVICE_GARMIN_ACTIVITY_RETURN.md).

**UI-061 · fuerza compacta común · 23/10/2026:** bloques con color y nombre
por formato, resumen plegable, un bloque abierto y arrastre de bloques y de
ejercicios dentro de su bloque. Conserva las siete prescripciones, campos
incompletos, ajustes por serie, schema 1 y permisos de las tres apps. Sin
dependencias ni cambios de servidor. Las regresiones conservan duplicación,
cambio de formato, dosis, teclado y guardado, y añaden cancelación sin escritura
y revisión móvil/escritorio con texto grande. Verificación local: análisis de
las tres apps limpios; raíz 1.294 (una omisión previa), ADMIN 314 (dos previas),
Trainer 170 y paquete común 212 pruebas correctas. Código `e2294d73`;
Trainer Dev publicado con autorización expresa y verificado por HTTPS y Chrome.
ADMIN Dev publicado y verificado por HTTPS; CI ADMIN 39926567729 y Garmin
39926567864 completamente correctas, incluida compilación iOS Release sin firma.
**Siguiente recorrido único:** aceptar el creador de fuerza publicado con una
sesión de varios formatos, moviendo bloques y comprobando su receta guardada.
[Alcance, límites y distribución](WORKOUT_EDITOR_SHARED_2026_10_22.md#fuerza-compacta--ui-061).

**INT-009 · primera carrera física · 23/10/2026:** se contrasta en solo lectura
la pauta profesional entregada con la actividad realizada en fēnix 8. Javier
confirma pasos, recuperaciones, Lap y avisos; Garmin registra las cinco
repeticiones. El enfriamiento era temporizado, por lo que no acredita el caso
de enfriamiento manual ni los dos umbrales medidos por separado. No se altera
la cita, que continúa planificada; importar y asociar la actividad es un
recorrido distinto. Cambios/cancelaciones automáticos y omisión de última
recuperación conservan aceptación pendiente. Evidencia privada fuera de Git.
[Prueba física y límites](DEVICE_GARMIN_TRAINING.md#carrera-física-completa--23102026).

**INT-011 · arrastre de carrera · 23/10/2026:** el creador común añade asa
para reordenar con ratón y tacto, indicador de inserción y desplazamiento del
formulario. La serie conserva colores, repeticiones, recuperación/omisión y
texto incompleto; cancelar no guarda. Mantiene Subir/Bajar, contrato V2,
snapshot y permisos. Análisis de las tres apps limpios; raíz 1.294, ADMIN 314,
Trainer 170 y creador común 196 pruebas correctas, con las omisiones previas.
Código funcional `f050b422`, CI Garmin 39906487372 correcta incluida iOS;
CI ADMIN 39906487330 correcta incluida publicación y retención. ADMIN y Trainer
Dev publicados y verificados por HTTPS el 23/10/2026, con autorización expresa
para esta ampliación de Trainer. **Siguiente recorrido único:** continuar la
aceptación física de la receta en el fēnix.
[Arrastre y verificación](WORKOUT_EDITOR_SHARED_2026_10_22.md#reordenación-por-arrastre--23102026).

**INT-011 · 22/10/2026 · creador común de carrera compacto:** resúmenes
plegables, series iguales agrupadas, edición individual de excepciones y
recuperación con objetivo propio dentro de la serie. Libre oculta y retira
ritmos. Conserva receta plana V2, schema 1, omisión y límite de cuarenta; no
cambia SQL ni permisos profesionales. Capturas reales sintéticas en móvil y
escritorio, también texto 2×. Análisis de las tres apps limpios; raíz 1.294
(una omisión previa), ADMIN 314 (dos previas), Trainer 170 y creador común 189. Distribución
anotada en su documento responsable. **Siguiente recorrido
único:** actualizar el creador y contrastar en fēnix una pauta nueva con Lap,
ritmo rápido/suave y última recuperación omitida, dentro del ciclo automático
Dev. Pulso/cadencia/potencia y fuerza Garmin siguen pendientes.
Código funcional `9deb71a4`: CI Garmin correcta incluida iOS. Distribución
comprobada el 23/10/2026: ADMIN y Trainer Dev publicados y verificados por HTTPS.
Javier autoriza publicación y reintento de retención; el job auxiliar conserva
cinco compilados incluida la versión publicada y retira un compilado antiguo.
CI ADMIN completamente correcta tras ese reintento. Distribución Dev cerrada;
la siguiente aceptación sigue siendo física en el fēnix.
[Interfaz y aceptación](WORKOUT_EDITOR_SHARED_2026_10_22.md#creador-de-carrera-compacto--int-011).

**INT-010 · 22/10/2026 · ciclo automático implementado y activo solo en Dev:**
preferencia por cuenta/generación, cola durable, creación compartida, cambios
con PUT y retirada con DELETE; historial de versiones y guardas de autoridad,
sin modificar el flujo profesional. Tres migraciones aplicadas; cron acredita
200 con cero cuentas activadas. Análisis limpio, raíz 1.294 y una omisión
previa, servidor 128 y tipos estrictos; contratos transaccionales Dev del
entrenador y del algoritmo/reset, regresiones de cuenta/envío y competencia real
manual/automática en PostgreSQL aislado.
Código funcional `37a32d83`; CI Garmin 39847659243 correcta en backend,
consumidor e iOS Release sin firma. **Siguiente recorrido único:** actualizar
iPhone, activar la opción Dev y acreditar crear → cambiar → cancelar en
Connect/fēnix. La prueba física Lap/fartlek sigue pendiente y forma parte de
esa comprobación. No se abre otro bloque de objetivos o fabricantes todavía.
[Contrato y operación](DEVICE_GARMIN_AUTOMATIC_SYNC.md).

**INT-009 · 22/10/2026 · pasos de carrera V2 implementados:** tipos de paso,
finalización por tiempo/distancia/manual y objetivos libre/ritmo en el creador
común, borradores, guardado, vistas y ejecución. Metadatos versionados aditivos,
huellas V1 conservadas, revisión antigua bloqueada y capacidades por proveedor
comprobadas antes de reservar el envío. Dos migraciones aplicadas solo en Dev;
servidor 114 pruebas y tipos estrictos, raíz 1.292, ADMIN 314, Trainer 170 y
paquete 161; omisiones previas conservadas. Código funcional `a3018544`, CI
Garmin 39822294290 correcta incluida compilación iOS Release sin firma; función
de envío ACTIVE v5 solo en Dev. Trainer publicado en `a3018544` y ADMIN en
`6924e967`, con CI 39823651874 correcta; ambos verificados por HTTPS. Javier
aplaza la prueba física. **Siguiente recorrido único:**
comprobar en fēnix una pauta nueva con Lap → 5 × (400 m + 90 s) → Lap y ambos
límites de ritmo. Pulso/cadencia/potencia y fuerza Garmin siguen pendientes.
[Implementación y límites](RUNNING_STEPS_V2.md).

**INT-009 · aceptación del creador y fartlek · 22/10/2026:** Javier confirma las
fases visibles y solicita ritmo suave, repetir combinaciones y omitir la última
recuperación. El creador común añade conversión de recuperación en paso editable,
expansión ordenada de grupos y omisión explícita desactivada por defecto; los
selectores dicen «Tiempo». No cambia SQL ni el contrato V2: se conservan pasos
individuales al guardar/reabrir, con un máximo de 40. Análisis de las tres apps
limpios; raíz 1.292, ADMIN 314, Trainer 170, creador 171 y servidor 115 pruebas
correctas, con las omisiones previas conservadas.
Código `8998d25c`, CI Garmin 39837977581 correcta incluida iOS; Trainer y ADMIN
Dev publicados en esa revisión y verificados por HTTPS, CI ADMIN 39837977717
correcta. El diálogo se abre/cancela en Chrome sin aplicar cambios a la sesión
real. Javier ya tiene instalada la app V2: puede enviar esta receta sin
reinstalar; solo las acciones nuevas del creador móvil requieren actualización.
**Único siguiente recorrido:**
comprobar la pauta nueva en fēnix con Lap, ritmo propio rápido/suave y última
recuperación omitida. El envío automático sigue pendiente de su ciclo completo
de actualización/cancelación; no se activa por este ajuste del editor.
[Receta y comprobaciones](RUNNING_STEPS_V2.md).

**INT-008 · 22/10/2026 · creador común en las tres apps:** las entradas personales
de carrera y fuerza montan el mismo formulario que ADMIN/Trainer. Se conservan
catálogos, Pro, cuotas, rutas, versiones y borradores por cuenta; mejora común de
autoguardado de excepciones, valores opcionales por serie y límite expandido.
El contrato SQL se conservó en INT-008 y se amplía después con INT-009 para
los pasos de carrera; fuerza Garmin sigue pendiente. La interfaz nueva requiere reinstalar en iPhone.
Análisis de las tres apps limpios; raíz 1.279, ADMIN 314, Trainer 170 y paquete
común 155 pruebas correctas, con las omisiones previas conservadas.
Trainer y ADMIN Dev publicados y verificados por HTTPS en `f12df112`; CI Garmin
correcta, incluida compilación iOS. ADMIN supera validación y su reintento de
publicación resuelve el error inicial de transporte con Hostinger.
[Alcance y verificaciones](WORKOUT_EDITOR_SHARED_2026_10_22.md).

**INT-007 · 22/10/2026 · primer envío Garmin común activo solo en Dev:** contrato de cita
autorizada/versionada, normalización pura de carrera, servicio de entrega y
adaptador Training API; servidor común para alumno y entrenador con MFA, sin
modificar el portal de Trainer. Perfil del deportista incorpora selección,
fecha/pasos y revisión explícita. SQL con ROLLBACK y concurrencia local pasan;
raíz 1.278 pruebas correctas/una omisión previa, 110 de servidor y tipos limpios
tras corregir el modificador de unidades sin reenviar la sesión anterior.
Migración aplicada, función de envío ACTIVE v2, cuenta/callback v5 y CI 39791868190
correcta; regresiones SQL de agenda/revisión profesional con ROLLBACK correctas.
Javier instala en iPhone y aporta capturas/vídeo de la sesión en Garmin Connect
y fēnix 8; Dev confirma workout/calendario, el vídeo acredita inicio y avance
en banco. CI 39796122054 también compila iOS Release sin firma correctamente.
**Siguiente recorrido único:** verificar fidelidad de receta/pasos e instrucciones
y rangos de ritmo en el reloj; no se cierra todavía una carrera completa o sus alertas.
[Contrato y límites](DEVICE_GARMIN_TRAINING.md).

**TRN-025 · 22/10/2026 · navegación del alumno implementada:** Preparador ocupa
una pestaña condicional y Perfil pasa arriba. Inicio muestra solo el resumen de
novedades; la campana desaparece con cero avisos sin leer. Avisos e historial
siguen accesibles y se preservan enlaces, tareas sin barra y retorno al origen.
Batería completa de raíz: 1.270 correctas y una omisión previa; análisis limpio y cinco capturas
de widgets reales a 390/320 px, incluido texto 2×. No cambia ADMIN, SQL ni la
web publicada de Trainer. **Siguiente paso de este tramo:** instalar la nueva
compilación en el iPhone y aceptar el recorrido desde la pestaña, la campana y
Perfil con la cuenta vinculada. No cierra los dieciséis puntos profesionales.
[Evidencia](ATHLETE_TRAINER_NAVIGATION_2026_10_22.md).

**INT-005 · 22/10/2026 · servidor Garmin publicado solo en Dev:**
Activity y Training Enabled/Approved; servicio por cuenta, PKCE, tokens cifrados,
consumo único y desconexión implementados con handlers Edge. Perfil incorpora
una entrada y ruta interna conservando TRN-025. Análisis limpio, 1.270 pruebas
raíz correctas/una omisión previa, 91 de backend y tipos estrictos comprobados.
Contrato SQL y concurrencia local RC/RR correctos; DDL/contrato también pasan en
Dev con ROLLBACK. Tras autorización de Javier, migración aplicada y dos funciones
ACTIVE v1 en `entrenaop-dev`; contrato repetido sin usuarios sintéticos restantes.
CI de servidor y consumidor correcta. Cuatro secretos cargados directamente
desde el helper local; petición sin sesión 401 y callback inválido 400.
Javier aporta capturas de autorización completada y cuenta conectada; Dev
confirma generación 2, ambos permisos, grant cifrado e intento consumido.
Después confirma desconexión; Dev acredita permisos desactivados, grant,
identidad e intentos/leases eliminados tras retirada satisfactoria en Garmin.
**Recorrido nominal conectar/autorizar/desconectar aceptado en navegador el
22/10/2026. Único siguiente bloque recomendado:** primera prescripción de carrera
autorizada/versionada → Training API → calendario Garmin → comprobación en reloj.
No hay recepción o envío de entrenamientos; producción y Trainer no cambian.
El primer retorno real falla: se corrige la presentación a texto UTF-8 y se
añade diagnóstico sin datos privados (handlers Dev v4, 93 pruebas de servidor).
El segundo intento completa la conexión real; la causa inicial no se reproduce.
CI 39780738347 correcta. Denegación/cancelación/pérdida de acceso probadas de
forma automatizada; instalación móvil y esas variantes manuales no acreditadas.
El bloque funcional de dispositivos permanece abierto.
[Contrato y límites](DEVICE_GARMIN_CONNECT.md).

**TRN-022 · 21/10/2026 · integración de continuidad y seguimiento:** recuperación
privada de sesiones de biblioteca/nuevas versiones conectada al binding común;
Inicio del alumno y bandeja profesional hacen visibles formularios, conversación,
pruebas y técnica sin crear secciones vacías. Selector de demostraciones ya
preparadas conectado al creador único. Las dos migraciones están aplicadas solo
en Dev y ambos contratos se han repetido con ROLLBACK; 200 migraciones coinciden.
Validación y aceptación de vídeo/publicación móvil constan por separado en
[la evidencia del tramo](TRAINER_STUDENT_RECOVERY_2026_10_21.md).
Los dieciséis puntos siguen abiertos: este cierre técnico no acredita cobros,
push, recuperación de hijos de programa/adaptación ni aceptación física completa.
**Único siguiente tramo recomendado:** probar con preparador y alumno el recorrido
asignación → ejecución → técnica/formulario/conversación → revisión, incluyendo
recarga y reintento, antes de ampliar el alcance.

**ADM-008 · 21/10/2026 · recuperación de sesiones y portada publicadas en ADMIN Dev:**
puerto opcional y checkpoint compartido conservan entradas incompletas y ramas
ocultas; confirmación idempotente y enlace por fase/posición mantienen publicación
conjunta. Inicio reúne trabajo, calidad y copias/errores sin duplicar servicios.
Localización oficial española, sin rediseñar el editor. Portal `ac45df0a` verificado
por HTTPS y Chrome: sesión incompleta, reapertura/recarga, cambio de nombre y
regreso desde URL directa con el catálogo actualizado. Dos migraciones ADMIN
aplicadas y contrato con ROLLBACK pasado; 201 migraciones Dev coincidentes al
cierre. El recibo pendiente de enlace protege su receta hasta confirmarse el
padre. Matriz y límites en [la entrega](ADMIN_SESSION_RECOVERY_2026_10_21.md).
**Único siguiente paso ADMIN:** aceptación con Javier de recuperación y pendientes.
Cualquier otra función del acopio o rediseño se propone antes; el servidor
privado profesional mantiene su entrega independiente.

**TRN-021 / INT-004 · 21/10/2026 · código y Dev verificados; Trainer publicado:**
programas incompletos de Trainer reutilizan puerto, controlador y editor comunes;
la sesión de las RPC queda vinculada a la cuenta. Nueva URL estable, recuperación,
descarte y finalización atómica, sin copiar ADMIN. Servidor aplicado en Dev:
197 migraciones coincidentes y cero pendientes; 26 contratos juntos con ROLLBACK,
incluido historial personal de Salud. Los trabajos verifican 108 contenciones
locales RC/RR. Matriz final: raíz 1220 correctas/una omisión previa, Trainer 137,
ADMIN 306/dos omisiones previas, UI compartida 124 y acceso compartido 20.
Análisis raíz/Trainer/ADMIN/UI limpios; formato de 42 fuentes Dart sin cambios.
La corrección común conserva posiciones repetidas, normaliza el orden de claves
y confirma un enlace incierto sin volver a introducirlo como pendiente. Catorce
regresiones nuevas cubren recuperación y guardado en ambos contextos. El portal
web está publicado desde `37dcd14`, release terminada en `-20261021-9`. Javier autoriza
expresamente acceso a Hostinger/gestor y se extrae solo en `public_html/trainer`;
queda resuelto el bloqueo anterior. HTTPS verifica identidad, archivos y
cabeceras; Chrome conserva MFA/cinco plazas y comprueba biblioteca y editor sin
crear contenido de prueba.
[Identidad, matriz y estado de la entrega](TRAINER_RECOVERY_RELEASE_2026_10_21.md).
Salud incorpora ruta, configuración iOS aditiva, pruebas de feature y APK de
desarrollo compilado. La CI `39649281298` de `37dcd14` termina correctamente,
incluida la compilación principal iOS Simulator sin firma. ADMIN pasa validación
y publicación Dev en la CI `39649281484`. No acredita instalación física
principal ni Health Connect en la app habitual. **No abrir otro bloque grande
hasta este punto de guardado.**
Después continúa la recuperación de sesiones, sin duplicar el creador.
[Programas](TRAINER_PROGRAM_WORK_DRAFTS.md), [cuenta](TRAINER_ACCOUNT_REQUESTS.md),
[Salud](DEVICE_RUNNING_HISTORY.md).

**TRN-020 · 21/10/2026 · ampliación coordinada de los dieciséis puntos en curso:**
Javier autoriza avanzar en paralelo con agentes, manteniendo creadores comunes y
portales independientes. Ya hay implementación local integrada de inicio,
agenda editable, adaptación individual, grupos/copia/recurrencia finita,
revisión, formularios, conversación, vídeos privados/técnica y ficha/informes.
Diez migraciones nuevas y veinticuatro contratos juntos pasaron en Dev con ROLLBACK;
después se han aplicado en Dev y repetido los 24 contratos. Las 195 migraciones
locales/remotas coinciden y `exercise-video` se ha desplegado solo en Dev.
Portal Dev publicado desde `a2c467f`, HTTPS/Chrome correctos y sesión MFA de
cinco plazas conservada; doce destinos y selector común comprobados.
No acredita distribución móvil ni aceptación física con dos cuentas.
[Evidencia de publicación](TRAINER_PROFESSIONAL_RELEASE_2026_10_21.md).
Pruebas/simulacros tipados integrados en código con protocolos versionados y
captura propia; 36 carreras locales verifican inicio/baja, guardado/cierre y
reintentos. Reutilizar el motor profesional requiere un contrato de paridad
independiente. Cobros: núcleo de ensayo con 21 pruebas, sin proveedor/políticas
elegidos ni dinero real. Favoritos/recientes y cambios individuales revisados
están conectados a los creadores comunes. Matriz final: raíz 1204 correctas/una
omisión previa, ADMIN 306/dos previas, Trainer 101 y editor compartido 110;
análisis raíz/ADMIN/Trainer/UI limpios, compilaciones web ADMIN/Trainer Dev
correctas. La planificación acredita 306 contenciones/solapes locales y los
vídeos, evaluaciones y preferencias 36 cada uno, con sus límites de fixtures.
**Tramo operativo técnico verificado; ampliación de los dieciséis puntos abierta.**
**Único siguiente tramo técnico recomendado tras guardado y publicación Dev:**
recuperación persistente de los creadores, reutilizando `GuidedWorkRepository`
y un puerto opcional para sesiones; concretar cuotas/retención/acceso antes de
añadir su persistencia. Motor, cobros reales y aceptación física mantienen sus
dependencias de contexto, decisiones comerciales y dispositivos.
La aceptación física con dos cuentas sigue pendiente y no bloquea por sí sola
el desarrollo autorizado de los dieciséis puntos.
[Contrato operativo y estado](TRAINER_OPERATIONAL_WORKFLOW.md),
[responsables y mapa completo](PROFESSIONAL_DELIVERY_COORDINATION.md).

**INT-003 · 21/10/2026 · primera lectura física iPhone, aceptación parcial:**
app independiente `labs/health_read_probe` con puentes HealthKit/Health Connect,
sin persistencia ni integración con las tres apps. Análisis local limpio,
Plugin iOS extraído con 16 pruebas y ensayo consumidor con 30; compilación
Android e iOS Simulator acreditadas en CI de `124fa76`. Javier confirma lectura
física con el lector previo: contraste de distancia/duración a precisión de
pantalla, ritmo derivado compatible, descarte al volver de Garmin, relectura sin
duplicados y revocar/restaurar lectura de Salud. Resumen técnico autorizado,
sin métricas personales ni capturas en Git. Reinstalación del plugin extraído,
conexión/persistencia en la app principal y Android real siguen pendientes.
El ensayo no modifica Trainer ni SQL. Huawei requiere comprobar primero que
su actividad llegue a Health Connect. **La fase móvil sigue abierta.**
[Protocolo, capacidades y límites](DEVICE_HEALTH_READ_PROBE.md).

**TRN-019 · 21/10/2026 · ejercicios profesionales implementados y verificados en Dev:**
formulario compartido con ADMIN, catálogo privado y revisiones inmutables,
imágenes privadas y selección de versiones en sesiones/programas. El deportista
reconoce origen profesional y firma la técnica recibida sin añadirla a su
biblioteca personal. Límites confirmados: 500 ejercicios/versiones y 1.000
reservas de imagen de hasta 500 KB; cuotas e idempotencia en servidor.
Catorce contratos SQL con ROLLBACK, 69 contenciones PostgreSQL locales, 1145
pruebas raíz (una omisión previa), 301 ADMIN (dos previas), 33 portal y seis
pruebas del publicador; seis capturas de widgets revisadas. Análisis del alcance,
ADMIN y global final limpios. El primer análisis global detectó trabajo ajeno en
curso de `labs/health_read_probe`; se conservó aparte y el análisis final ya pasa.
Compilación Dev del deportista preparada; no instalada en teléfono. No hay
subida de vídeos profesionales, compras ni aceptación humana con dos cuentas.
Portal publicado desde `cb435e2` y verificado por HTTPS y sesión de Chrome;
185 migraciones coincidentes en Dev. Biblioteca/formulario y cinco destinos
comprobados, sin datos de ensayo guardados. No se declara cerrado el recorrido
físico completo.
**Aceptación física pendiente de TRN-019:** recorrido con dos cuentas
y app instalada: crear ejercicio con foto → sesión/programa → pauta → ejecución
del alumno → resultado del preparador. TRN-020 amplía en paralelo seguimiento y
contratos comerciales por instrucción posterior de Javier.
[Contrato y límites](TRAINER_PRIVATE_EXERCISES.md).

**INT-002 · 21/10/2026 · dominio de carrera aislado y verificado:** paquete
`device_activity_core`, sin dependencias de ejecución ni cambios de Trainer,
creadores, agenda, aplicaciones o SQL. Modela identidad/procedencia, tiempos,
validación/cuarentena, páginas idempotentes con checkpoint, candidatos de
duplicados y revisión/asociación uno a uno con alias elegidos por el titular.
Asociar no crea ejecuciones ni confirma resultados deportivos. Dart analyze
limpio y 56 pruebas puras correctas; Flutter analyze limpio y 1144 pruebas raíz
correctas con una omisión previa. CI incorpora resolución/análisis/pruebas del
paquete y evita publicar ADMIN por cambios exclusivos de este dominio y docs/CI;
ocho escenarios del detector real de alcance pasan con Bash.
No se acreditan transacciones concurrentes, RLS, conectores ni dispositivos.
**Tramo de dominio cerrado; bloque funcional de dispositivos abierto.**
**Único siguiente tramo de INT-001/002:** ensayo aislado de lectura de carrera
desde Salud de Apple y Health Connect, verificando SDK/permisos/dispositivo
antes de conectar persistencia o las tres apps; mantener el trabajo profesional
independiente. [Alcance y evidencia](DEVICE_INTEGRATIONS.md) y
[API y límites](../packages/device_activity_core/README.md).

**TRN-017 · 21/10/2026 · programas privados y agenda implementados en Dev:**
composición de programas extraída íntegra de ADMIN al paquete común, biblioteca
versionada, creación de sesiones dentro, selección de fases/fechas y envío
atómico al alumno. Agenda mensual y navegación común. Análisis limpio, 1144
pruebas raíz (una omisión previa), 301 ADMIN (dos previas), 25 portal y 67 del
paquete; trece contratos SQL con ROLLBACK y 45 contenciones nativas locales.
Diez capturas de widgets revisadas, incluida navegación móvil/texto 2×.
Migración aplicada solo a Dev, 182 coincidentes. Web publicada desde `834e3b6`,
verificada por HTTPS y sesión existente en Chrome, con los cuatro destinos
accesibles y biblioteca/creador. Aceptación humana con alumno pendiente.
No cambia la app móvil distribuida.
El siguiente bloque de ejercicios propios se implementa en TRN-019. El alcance completo, con
seguimiento agregado y ambos circuitos de pago, queda en
[TRAINER_PLATFORM.md](TRAINER_PLATFORM.md). [Contrato de programas](TRAINER_PRIVATE_PROGRAMS.md).

**INT-001 · 21/10/2026 · bloque común de dispositivos: definición inicial:** Javier
aprueba alcance para deportista, ADMIN y entrenadores, empezando por carrera,
contrato y acceso a proveedores. Se definen prescripción/actividad/resultado,
capacidades, identidad, duplicados, revisión y fronteras de permisos. Revisadas
las vías públicas de Apple, Android, Garmin, COROS, Suunto y Huawei; no se
acreditan altas, credenciales operativas ni dispositivos probados. Objetivo de
cobertura de marcas, sin prometer compatibilidad universal. La API Garmin sigue
pendiente y no bloquea la entrada indirecta de salud que se probará en móvil.
**Tramo documental delimitado; bloque funcional abierto.** No cambia Trainer,
sus asignaciones/creadores, SQL o producción; no se ejecuta Flutter/SQL por ser
documentación. No desplaza el siguiente bloque profesional ya en curso.
El siguiente tramo indicado entonces se implementa en INT-002. La implementación
transversal se ordenará con los bloques abiertos antes de conectar las apps.
[Bloque y fases](DEVICE_INTEGRATIONS.md),
[contrato V1](DEVICE_RUNNING_CONTRACT_V1.md) y
[acceso a proveedores](DEVICE_PROVIDER_ACCESS_2026_10_21.md).

**TRN-016 · 21/10/2026 · sesión privada implementada en Dev:** crear/revisar con
el editor común, previsualizar receta, asignar desde la ficha y consultar
resultados propios. Agenda/ejecutor/historial se reutilizan; indicaciones y
controles nuevos del deportista aún no distribuidos. 181 migraciones coinciden;
doce contratos transaccionales, 33 contenciones locales y baterías correctos.
Panel publicado desde `efff722`, HTTPS y biblioteca/creador verificados en Chrome;
aceptación humana con dos cuentas pendiente.
El siguiente bloque indicado entonces se implementa en TRN-017.
[Contrato y límites](TRAINER_PRIVATE_WORKOUTS.md).

**TRN-015 · 21/10/2026 · cartera duradera implementada en Dev:** activos,
inactivos y archivados, una ficha por alumno/preparador, historial paginado de
etapas y vuelta con aceptación nueva sin perder la ficha. Tres SQL con ROLLBACK
y 21 contenciones reales locales correctas; análisis y baterías del deportista,
ADMIN, panel y contrato compartido pasan. Historial deportivo privado,
asignaciones, purga definitiva y pagos siguen pendientes. Javier deja las fechas
en segundo plano y pospone precios/proveedor hasta cerrar la infraestructura.
Publicado en Trainer Dev desde `029a46c`, verificado por HTTPS y en Chrome con
la sesión existente y las tres listas. La referencia visual de Harbiz aportada
por Javier orienta el siguiente recorrido de ficha, biblioteca y calendario;
no acredita funciones nuevas ni cambia los contratos de permisos.
[Contrato, alcance y pruebas](TRAINER_CLIENT_LIFECYCLE.md).

**TRN-013/014 · 21/10/2026 · entrega integrada en curso, objetivo 30/10:** Javier
pide desarrollar portal y deportista conjuntamente. Confirma convivencia de
pauta profesional y automática sin sustitución: aviso de coincidencia por día
conectado en Inicio y agenda, con regresión de acceso profesional en Inicio.
Autoría/asignaciones privadas, recepción real, programas y resultados siguen
pendientes. Derechos tras el vínculo y condiciones de pago se están concretando.
Análisis raíz limpio, 41 pruebas dirigidas y 1144 raíz correctas (una omisión
preexistente). No hay cambios SQL ni publicación del deportista en esta entrega.
La fecha no acredita publicación de producción ni permite omitir verificaciones.
[Alcance, estado y puntos de control](TRAINER_APP.md#entrega-integrada-con-objetivo-30102026--trn-013).

**TRN-011 · 21/10/2026 · publicación y primera entrada cerradas:** publicación del panel Dev y habilitación de
la cuenta de Javier para probar TOTP antes de las asignaciones. Paquete separado
y corrección del contexto de dependencias de trainer_app en GitHub; la creación
del subdominio está confirmada por Javier y acreditada en Hostinger.
Cuenta habilitada en Dev con cinco plazas y auditoría operativa. Panel publicado,
verificado por HTTPS (revisión, hash, cabeceras y WebAssembly) y acceso visible en
Chrome. Javier completa contraseña y TOTP: panel con 0/5 plazas, actualización,
consulta de finalizados y sesión tras recarga verificados. Límites: sin ensayo
humano de caducidad/recuperación del factor ni recorrido con alumno real.
Único siguiente bloque: derechos tras fin de vínculo y convivencia con el plan,
y sesión privada → asignación versionada → ejecución → resultados autorizados.
[Preparación y estado](TRAINER_HOSTING_2026_10_21.md).

**TRN-010 · 21/10/2026 · acceso y clientes: cierre técnico en Dev:** panel
`trainer_app/` independiente para trainer.entrenaop.es, TOTP obligatorio en
RPC/RLS, acceso/cupo y directorio profesional en Cuentas, e invitación/aceptación/
finalización desde Perfil → Mi preparador. Una identidad puede ser admin,
preparador y alumno simultáneamente. No se tocan creadores ni algoritmo.
Análisis limpio en las tres apps y paquetes afectados; 1.133 pruebas raíz
(una omisión previa), 301 ADMIN (dos previas), siete panel, tres contrato de
acceso y quince entrena_ui correctas. Las pruebas dirigidas acreditan las rutas
reales y los reintentos; compilación web del panel y capturas 1200/390/320 px
con texto 2× revisadas. Dos SQL contra Dev terminan con ROLLBACK, y quince
carreras reales en PostgreSQL 17.6 local desechable verifican cupo, preparador
único e idempotencia. 178 migraciones coinciden; cero cuentas/vínculos de ensayo.
**Límites:** subdominio sin publicar, configuración manual deshabilitada y
ninguna cuenta habilitada. Entrada TOTP humana en navegador, recuperación del
factor, cobros y asignaciones no acreditados por este cierre técnico.
**Único siguiente bloque funcional profesional:** sesión privada → asignación
versionada → ejecución existente → resultados autorizados, acordando antes los
derechos tras finalizar/caducar y la convivencia con el plan automático.
Publicar y probar una cuenta de piloto queda como preparación operativa previa
a habilitar ese piloto, sin afirmar que ya se haya realizado.
[Contrato y evidencia](TRAINER_PORTAL_2026_10_21.md).

**ADM-004 · 21/10/2026 · papelera de sesiones y purga manual cerrada:** implementación
verificada en ADMIN/Dev: confirmación explícita, sesiones compartidas preservadas,
seguimientos/ejecuciones/referencias bloquean el borrado, recuperación sin republicar
y URLs purgadas cerradas. 296 ADMIN/dos omisiones previas, 30 Python, trece SQL con
ROLLBACK y 176 migraciones coincidentes. Publicación `4b2759d` y HTTPS correctos;
Chrome acredita retirada/recuperación real y cancelación de ambas confirmaciones
definitivas. La sesión técnica aparece purgada en la consulta final de Dev.
Límites: sin vaciado automático ni limpieza de archivos o copias antiguas. **Único
siguiente paso recomendado:** aceptación de ambas papeleras con el catálogo de
prueba de Javier. [Contrato y pruebas](ADMIN_TRASH_DELETION_2026_10_21.md).

**ADM-003 · 21/10/2026 · papelera de programas cerrada:** implementación y contratos
Dev verificados: retirada por familia, recuperación de trabajos incompletos,
identidad y sesiones reutilizadas conservadas; recuperar no publica. Análisis
limpio, 289 pruebas ADMIN (dos omisiones previas), nueve SQL con ROLLBACK y
175 migraciones coincidentes. Capturas de escritorio y 320 px/texto 2× revisadas.
Publicación `b124fee` y HTTPS correctos; Chrome acredita retirada/recuperación
de trabajo y programa con una sesión compartida, sin alterar receta ni enlaces.
Límites originales, ampliados por ADM-004: sin vaciado automático, continuidad de seguimientos
existentes conservada; no afecta preparaciones ni producción. **Único siguiente
paso recomendado:** aceptación de Javier retirando/recuperando un borrador y un
programa que reutilice sesiones. [Contrato y pruebas](ADMIN_PROGRAM_TRASH_2026_10_21.md).

**ADM-002 · 21/10/2026 · recuperación de Dev cerrada:** copia cifrada real
almacenada y recibo `verified` contrastado en Dev. La ejecución `39551387164`
restaura SQL y 11 objetos de Storage en contenedor aislado, comprueba cifrado y
descifrado, sube el artefacto y registra su caducidad de siete días. Registro real
de errores conectado y recogida programada observada. Cinco SQL correctas,
174 migraciones coincidentes, 280 pruebas ADMIN (dos omisiones previas), 30 Python,
análisis/build/despliegue limpios. Retención autorizada de compilados aplicada:
cinco paquetes recientes y protección de la revisión publicada, sin tocar copias
de datos. Límites: no incluye Bunny ni secretos/clave raíz de servicios; no hay
restauración remota automática; primera copia diaria programada aún no observada.
**Único siguiente bloque recomendado:** papelera recuperable de programas,
acordando borradores, versiones y sesiones compartidas antes de implementarla.
[Contrato, pruebas y recuperación](DEV_RECOVERY_2026_10_20.md).

**ADM-001 y UI-063 · 20/10/2026 · eficiencia y operaciones de ADMIN:** se cierra
la implementación de copia independiente, resumen plegado, deshacer y estado
editorial explícito, conservando el creador y publicación conjunta. Gestión añade
historial/comparación/recuperación como borrador y calidad con avisos accionables;
Cuentas incorpora diagnóstico para su responsable y Herramientas el estado
comprobable del despliegue y conexión. Se revisan código, permisos y fronteras
de guardado/publicación, con pruebas Flutter y SQL transaccionales en Dev.
Análisis limpio, 276 pruebas ADMIN y seis SQL correctas con ROLLBACK; 173
migraciones coincidentes. Publicación final `395e78c` comprobada por HTTPS.
Límites: historial desde activación, recuperación de sesiones/programas sujeta
al guardado vigente, sin copiar recetas personales ni auditar archivos externos;
aceptación manual de estas nuevas pantallas pendiente. Copias y errores generales
de servicios aún sin integrar. **Único siguiente bloque recomendado de operaciones:**
conectar esas evidencias con alcance y costes acordados.
[Contrato, pruebas y despliegue](ADMIN_OPERATIONS_2026_10_20.md).

**UI-062 · 20/10/2026 · creadores y Compacto:** tras comparar ventana y edición
en página, Javier elige la ventana existente para focalizar la sesión y pide
reutilizarla sin otro rediseño ni selector. Confirma leer la sesión escrita en las
tarjetas del programa y editar con un clic directo a la ventana. El lector se
reutiliza, los ajustes se pliegan y el programa conserva su contexto.
Guardar en programa incorpora borradores y la revisión/publicación final activa
el conjunto en una transacción. Se conservan reutilización, versiones, visibilidad
suelta opcional, recuperación y todas las correcciones de formatos/series.
La elección cambia únicamente composición y pruebas de ADMIN, sin nuevos cambios
de servidor o paquetes compartidos. La revalidación de ADMIN y su despliegue se
registran en el contrato; las verificaciones anteriores de raíz, paquetes y SQL
siguen referidas a sus respectivos cambios.
Límites: aceptación física y ensayo realmente concurrente pendientes; producción
sin cambios. **Único siguiente paso de este recorrido:** aceptación manual de la
ventana elegida con el contenido de Javier, sin abrir otro rediseño.
[Contrato, evidencia y límites](PROGRAM_AUTHORING_WORKSPACE_2026_10_20.md).

**Revisión del estado Free/Pro · 20/10/2026:** Javier pide contrastar el proyecto
actual en vez de seguir proponiendo comprobaciones genéricas. Cuotas 8/4/1,
regalos administrativos, programas y pérdida de Pro ya están implementados;
Javier ha aceptado la elección de una plaza y la continuidad visual. Dev tiene
169 migraciones coincidentes y ambas funciones de RevenueCat activas. Se
repiten 18 pruebas de funciones, todas correctas; la batería raíz de 1.128
conserva su evidencia porque el código no ha cambiado.
**Huecos reales del código para vender:** configuración del cliente limitada a
Test Store debug, gestión de suscripción de tienda ausente, botones de documentos
deshabilitados y conciliación disponible bajo demanda sin recuperación automática
al volver a la app. No son equivalentes a las pruebas ya implementadas de cuotas,
eventos duplicados o aislamiento de cuentas.
**Siguiente trabajo recomendado:** preparar e integrar ese contrato de compras
nativas y recuperación; después comprobar el ciclo de tienda en sus sandboxes.
Sin cambios de código, cuentas, despliegues ni producción en esta revisión.
[Evidencia y alcance](PRO_LAUNCH.md).

**UI-061 · 20/10/2026 · confirmaciones de programas coherentes:** se corrigen
los botones pegados que Javier muestra en iPhone. Dejar, pausar, elegir plaza
Free, avanzar y completar reutilizan los diálogos comunes, con acciones
verticales, ancho compartido y separación de 10 px. Cancelar es prioritario
frente a Dejar programa, que usa el estilo de peligro existente. Sin cambios
de negocio, SQL, tema global ni ADMIN. Veinte casos de distribución y 76
pruebas relacionadas correctos; 1.128 pruebas raíz correctas con una omisión
previa. Capturas de widgets reales revisadas en móvil, texto ampliado,
horizontal y escritorio. Análisis limpio.
Javier confirma el 20/10 que el resultado visual se ve bien y tiene continuidad
con otros botones; queda aceptada esta corrección visual. Esta confirmación
no acredita las cuotas, pérdida de Pro ni compras en el móvil actualizado.
La aceptación posterior de COM-020 y la revisión inicial de este documento
actualizan los siguientes pasos; no repetir la elección aceptada como pendiente.
El [estado consolidado](PRO_LAUNCH.md) conserva los pendientes de cierre.
[Criterio visual](VISUAL_DESIGN.md).

**COM-020 · 20/10/2026 · pérdida de Pro y elección de una plaza Free:** Javier
rechaza conservar varios programas utilizables al perder Pro. Se corrige para
cualquier cantidad superior a uno, sin excepción para programas previos: antes
de nuevos entrenamientos o avances debe elegir uno desde su ficha. La elección
pausa los demás conservando fase e historial. Se pueden terminar sesiones ya
iniciadas; no se pausa otro programa con ejecución abierta. Cancelar renovación
mantiene Pro hasta vencer; la elección no modifica facturación.
**Validación del 20/10/2026:** análisis limpio y 1.106 pruebas raíz correctas
con una omisión previa. Seis SQL con ROLLBACK correctos después de aplicar
solo en Dev la migración; 169 migraciones local/remoto coincidentes. Casos de
dos y tres programas, rechazo de URL directa, avance, reintento de sesión ya
aceptada, selección, renovación durante el diálogo y permisos cubiertos. La
interfaz se prueba a 320 px con texto 1×/2×. Asesor revisado: RPC del propio
usuario intencionadamente ejecutable por autenticados, sin acceso
anónimo. Javier confirma después el 20/10 que funciona Pro con dos programas →
retirar Pro → elegir uno → otro pausado: esa aceptación manual queda completa.
El ensayo realmente concurrente sigue pendiente; producción sin cambios.
La revisión actual de código y Dev al inicio de este documento concreta el
trabajo de integración restante. No repetir como pendiente la elección aceptada.
Compras y sandboxes nativos continúan pendientes. [Contrato](PROGRAMAS_GUIADOS.md).

**COM-019 · 20/10/2026 · una plaza Free y pausa de programas guiados:** se
implementan cuota de servidor, contador, invitación a Pro y pausa/reanudación
conservando fase e historial. Pro permite varios; Free alterna pausando el
actual sin penalización. COM-020 sustituye posteriormente la excepción de
continuidad de varios al caducar Pro. Catálogo, sesiones oficiales sueltas, cuotas personales 8/4,
motor adaptativo y facturación conservan sus contratos.
**Validación del 20/10/2026:** análisis limpio y 1.101 pruebas raíz correctas,
con una omisión preexistente. Migración aplicada solo en Dev: 168 migraciones
local/remoto coincidentes. Seis pruebas SQL con ROLLBACK correctas sobre el
servidor actualizado: cuota/pausa, seguimiento/ejecutor, abandono, portadas,
visibilidad editorial y cuotas personales. Revisados los permisos de las RPC
nuevas y los avisos esperados del asesor. Los fixtures no dejan datos.
No hay dispositivo móvil conectado; instalación y aceptación física de esta
interfaz pendientes. No se acredita ensayo de dos activaciones realmente
concurrentes; se revisa su bloqueo transaccional común. Producción sin cambios.
**Siguiente recorrido de este bloque:** actualizar el móvil y comprobar
Free → iniciar → pausar → otro programa → retomar con plaza ocupada → Pro.
La compra/restauración física y los sandboxes de las tiendas siguen pendientes;
no se da por cerrado Free/Pro. [Contrato](PROGRAMAS_GUIADOS.md).

**TRN-008/009 · 20/10/2026 · contrato base profesional en Dev:** Javier confirma
un preparador activo por alumno y rechaza creación personal ilimitada por el
vínculo. Acceso manual con cupo y auditoría, invitaciones y relación
aceptada/terminada implementados. Prueba SQL con ROLLBACK correcta, también
Free 8/4 con alumno vinculado; regresiones de cuotas y directorio correctas.
167 migraciones local/Dev coincidentes; no quedan usuarios ni concesiones de
prueba. Configuración manual deshabilitada, sin cambios en producción o Flutter.
Este punto de partida se amplía en TRN-010: interfaces de acceso/clientes y
ensayo concurrente local completados, manteniendo el piloto deshabilitado.
Asignaciones, acceso incluido y resultados siguen pendientes.
[Contrato y límites originales](TRAINER_ACCESS_2026_10_20.md).

**TRN-007 · 20/10/2026 · creador compartido para el espacio profesional:**
se recuperan e integran los tres commits documentales de la nube y se completa
la primera extracción acordada. Sesiones, carrera y calentamientos pasan a
`WorkoutEditorPage` en el paquete existente. ADMIN aporta catálogo, guardado,
visibilidad y rutas; no se duplica el editor ni se amplían sus permisos.
Análisis limpio en raíz, ADMIN y paquete; 1.092/242/37 pruebas correctas con las
tres omisiones previas, compilación web Dev y capturas actuales revisadas.
**Primer tramo técnico cerrado:** sin cambios SQL ni acceso profesional activo;
programas privados, recuperación adicional y algoritmo profesional pendientes.
**Único siguiente bloque profesional recomendado:** concretar acceso con cupo y
relación aceptada, y verificar sus contratos de servidor antes de conectar
clientes y contenido privado. El número de preparadores simultáneos por alumno
y las condiciones pendientes se detallan en [Espacio de entrenadores](TRAINER_APP.md).

**UI-059 · 19/10/2026 · Compacto implementado en ambas apps:** Javier aprueba
la propuesta ampliada y autoriza el lenguaje común de campos/controles en
deportista y ADMIN. Se reutilizan tema y componentes existentes, sin otro
creador. Se mantienen siete formatos, carrera, calentamientos, personalización,
valores históricos, borradores y guardado. Análisis limpio en cuatro proyectos;
1.084 pruebas de app, 220 de ADMIN, 32 del editor y 13 del tema correctas,
con las tres omisiones previas. Se revisan capturas de widgets reales a distintos
anchos y texto normal/doble, más pruebas de cierre de teclado y errores.
**Punto de guardado validado en Flutter:** sin cambios deportivos, de datos,
servidor, permisos ni dependencias. No acredita aceptación nativa del teclado.
**Único siguiente paso de este tramo:** repetir toque exterior, desplazamiento,
paso entre campos y selectores en iPhone y Android físicos con esta versión.
[Cobertura y capturas](COMPACT_FORMS_2026_10_19.md).

**UI-058 · 19/10/2026 · revisión editorial ADMIN publicada y comprobada:** vista
previa recargable, Guardar y revisar, fases/sesiones/calentamientos desplegables,
comprobaciones y confirmación previa a publicar. Mantiene versiones, catálogo
común y RPC. Favicon e iconos web de EntrenaOP incorporados. Análisis limpio,
193 pruebas correctas (dos capturas optativas omitidas), revisión visual y
publicación del código por WEB-006 verificadas. HTTPS confirma revisión/hash y
favicon; Chrome carga contenido real con la sesión administrativa conservada.
**Bloque cerrado:** sin cambios de servidor, contenido, producción ni promesa de
bloqueo transaccional de la revisión; límites documentados.
**Único siguiente bloque recomendado para ADMIN:** historial editorial propio,
con qué cambió y cuándo, conservando permisos y versiones.
[Contrato y evidencia](ADMIN_PUBLICATION_REVIEW_2026_10_19.md).

**WEB-006 · 19/10/2026 · publicación automática ADMIN activada y comprobada:**
GitHub Actions valida, compila Dev y publica por FTPS con cuenta confinada al
admin, recursos por versión y comprobación HTTPS. Javier guarda directamente
la contraseña y autoriza el acceso persistente; solo `main` usa el entorno.
Primera ejecución completa correcta, con ambas apps verificadas, nueve pruebas
del publicador, transferencia y comprobación independiente de hash/cabeceras/MIME.
Chrome conserva sesión, dos programas publicados y trabajo privado recuperable.
**Bloque técnico cerrado:** no incluye migraciones, producción ni limpieza de
versiones antiguas; los avisos de runtime de acciones quedan documentados.
**Único siguiente bloque recomendado para ADMIN:** vista previa y revisión
editorial antes de publicar contenido, conservando acceso y despliegue remotos.
[Estado y configuración](ADMIN_DEPLOYMENT_2026_10_19.md).

**UI-057 · 19/10/2026 · revisión general de teclado y formularios:** se atiende
la petición expresa de Javier de ampliar UI-053 a toda la app. Política común
de interacción, filas adaptables, etiquetas/opciones completas y composición
corregida en acceso, disponibilidad, editores, resultados y evaluación. Se
conservan Inicio/Mi plan, tarjetas, dominio, datos y permisos. La verificación
incluye pruebas de los dos paquetes visuales y sus aplicaciones consumidoras.
Análisis limpio en los cuatro proyectos, 1.038 pruebas de app, 176 de ADMIN,
32 del editor y 13 del sistema visual correctas, con las tres omisiones
existentes. Revisión de 157 capturas generadas y muestras conservadas.
**Siguiente paso único de este tramo:** aceptación en iPhone y Android físicos
del toque exterior, cambio de campo, diálogos/paneles y formularios corregidos.
La revisión automatizada y las capturas no acreditan todavía ese recorrido nativo.
[Inventario, evidencia y límites](UI_POLISH_2026_10_19.md).

**WEB-005 · 19/10/2026 · publicado en Dev; entrada remota comprobada:** Javier autoriza
`admin.entrenaop.es` conectado a Dev y confirma la identidad compartida con su
cuenta de deportista. Subdominio/carpeta/HTTPS publicados en Hostinger; contraseña
cambiada por Javier y Microsoft Authenticator activado, con requisito de servidor
comprobado. Análisis limpio, 176 pruebas ADMIN correctas y dos capturas optativas
omitidas, compilación release endurecida y pruebas SQL transaccionales correctas.
Manifiesto/JavaScript Dev coincidentes, MIME WebAssembly corregido y acceso
anónimo mostrado en Chrome y navegador integrado.
Javier confirma la entrada con Microsoft Authenticator; se contrastan las cuatro
preparaciones y los dos programas guiados desde el subdominio. El código publicado
es el build validado, sin incorporar los cambios simultáneos de otro chat.
**Cierre técnico verificado; remate de seguridad pendiente:** Javier indica que
desactiva el permiso temporal de archivos de la extensión; falta su confirmación.
No se modifica Supabase de producción ni la web principal. Tras ese remate, el
único siguiente bloque recomendado es vista previa y revisión editorial previa
a publicar, manteniendo el acceso remoto ya disponible.
[Estado y contrato](ADMIN_HOSTING_2026_10_19.md).

**UI-056, 19/10/2026 · recuperación del trabajo de ADMIN:** programas guiados
con guardado automático/manual de campos incompletos, referencias pendientes y
URL recuperable. Catálogo con Continuar trabajando, permisos por administrador,
conflictos del mismo trabajo y finalización transaccional que permite reintentar
sin duplicar versiones. Publicación y validación editorial conservadas.
Análisis limpio, 167 pruebas correctas (dos capturas optativas omitidas), web
compilada y SQL/Chrome comprobados contra Dev; no cambia producción ni deportista.
**Único siguiente bloque tras la aceptación de Javier · WEB-005:** preparar el
acceso administrativo por subdominio, verificando alojamiento, entorno y acceso
con su cuenta antes de publicar. La vista previa y la revisión previa a publicar
quedan como mejoras posteriores, sin bloquear este acceso.
[Límites y evidencia](ADMIN_DRAFT_RECOVERY_2026_10_19.md).

**UI-055, 19/10/2026 · autoría contextual de ADMIN:** desde cada fase/rutina se
puede crear una sesión con el editor existente, revisarla, publicarla
explícitamente e incorporar su versión. Selector con búsqueda y borradores,
pendientes visibles y retomables, calentamientos creados/adjuntados desde la
sesión, opciones según el formato real, movimiento en ambos sentidos y salida
bloqueada durante publicación. Corregido el doble cierre al encadenar regresos
con guards asíncronos. Análisis limpio, 162 pruebas correctas y dos capturas
optativas existentes omitidas; compilación web de desarrollo correcta. Navegación
y selector comprobados en Chrome autenticado con catálogo Dev; el recorrido de
cuatro sesiones y sus fallos se prueba con repositorios de prueba. Sin nuevas
mutaciones remotas, migraciones, dependencias, cambios compartidos ni deportista.
**Siguiente bloque recomendado al cerrar UI-055, completado después en UI-056:** concretar recuperación
persistente de programas incompletos e idempotencia de guardado antes de preparar
el subdominio. El montaje sin guardar vive en la pantalla y sigue exigiendo
sesiones publicadas para persistir el programa.
Este requisito queda sustituido por UI-062 (20/10/2026), que permite guardar
sesiones en borrador y publicar el conjunto desde el programa.
[Auditoría, referencias y límites](ADMIN_AUTHORING_2026_10_19.md).

**UI-054, 19/10/2026 · catálogos ADMIN de sesiones y programas guiados:** Javier
confirma las sesiones generales reutilizables. Se muestran sus programas de uso,
versiones y estados, con enlace al editor. Programas guiados separa resumen,
categorías y acciones e incorpora búsqueda sin tildes y filtros de modalidad y
estado. Análisis limpio, 155 pruebas correctas y las dos capturas optativas
existentes omitidas; compilación web correcta. Comprobación autenticada en ADMIN
contra Dev: seis sesiones demo enlazadas a sus dos programas, acceso al editor y
catálogo actualizado en la pestaña del navegador integrado. Sin mutaciones
remotas, migraciones, dependencias, cambios del deportista ni producción.
**Único siguiente tramo recomendado de este recorrido:** preparar el acceso
administrativo desde el subdominio, concretando alojamiento, entorno y
autenticación antes de desplegar.
[Detalle y límites](ADMIN_NAVIGATION_2026_10_19.md#claridad-de-catálogos--ui-054--19102026).

**UI-052, 19/10/2026 · organización local de ADMIN comprobada:** navegación
lateral agrupada y adaptable, Preparaciones separada de Programas guiados y
acceso recuperado al laboratorio de flexiones junto al de rendimiento. Se
conservan rutas, autoría, publicación, permisos comerciales y guards de salida.
Inventario de contratos y recuentos contrastado con Supabase Dev en solo lectura.
Análisis limpio, 147 pruebas ADMIN correctas con dos capturas optativas omitidas,
captura específica adicional ejecutada y revisada en escritorio/móvil/texto 2×,
y compilación web de desarrollo correcta. No cambia deportista, paquetes,
servidor, web pública ni producción. En la prueba posterior se corrige la
convivencia de un servidor antiguo en IPv6 y el build nuevo en IPv4; ambos
loopbacks sirven ahora el build correcto. Chrome conserva la sesión de Javier
y se comprueba crear, guardar, reabrir y publicar «Prueba ADMIN 19-10-2026»
solo en Dev. Tras el acceso de Javier a la app, se comprueba que aparece en
Biblioteca y que su vista conserva versión 1, 400 m y 6:00/km. Sin asignar ni
registrar resultados. No acredita todos los guardados ni cierra toda la autoría
o el futuro portal profesional.
**Único siguiente tramo recomendado de este recorrido:** preparar el acceso
administrativo desde el subdominio, concretando alojamiento, entorno y
autenticación antes de desplegar.
[Detalle](ADMIN_NAVIGATION_2026_10_19.md).

**PRG-009, 19/10/2026 · selección editorial de sesiones:** Mostrar en Sesiones de
EntrenaOP separa publicación y escaparate, preservando reutilización de la misma
versión en varios programas. Creación contextual inicialmente desmarcada; suelta
marcada. La ficha permite cambiar visibilidad sin nueva receta ni pérdida de
referencias/registros. Búsqueda por ejercicios y chips únicamente de categorías
con programas publicados vigentes. Migración solo Dev y cinco pruebas SQL con
ROLLBACK correctas y 166 migraciones coincidentes. Análisis limpios de ambas apps,
1.092 pruebas raíz y 225 ADMIN correctas, con sus omisiones preexistentes. Capturas
reales de ADMIN a 390 px y 320 px con texto 2× revisadas. Sin cambios de producción.
**Único siguiente paso de este recorrido:** aceptación física del creador/listado
y elección editorial de Javier para las sesiones existentes antes de ampliar
el catálogo. [Contrato](SESSION_LIBRARY_EDITORIAL_2026_10_19.md).

**PRG-008, 19/10/2026 · catálogo directo de programas:** Javier elige la maqueta
directa y confirma categorías pequeñas deslizables. Se retiran números/flechas
de página y no se incorpora Ver más. Búsqueda/Filtros comparten fila; Mostrar
queda plegado y las categorías administrativas son chips horizontales combinados
con texto y modalidad. El Cubit reúne las tandas hasta el final, protege frente
a respuestas antiguas y conserva tarjetas al actualizar desde una ficha. Se
mantienen tarjetas, anchos, pestañas corregidas y estilo Compacto. Análisis,
pruebas raíz/específicas y capturas reales comprobados. Sin cambios de ADMIN,
paquetes compartidos, servidor, datos o ejecutores.
**Único siguiente paso de este recorrido:** aceptación de Javier en móvil del
catálogo directo y los filtros antes de ampliar la navegación por colecciones.
Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-007, 18/10/2026 · Biblioteca adaptable, categorías y búsqueda:** se
conserva Inicio y Biblioteca ocupa el ancho móvil, con dos columnas en escritorio.
Categorías múltiples, una principal visible, gestión y creación desde ADMIN;
identificadores estables, nombres únicos normalizados, desactivación sin perder
asignaciones y edición con revisión. Guardado atómico y búsqueda con/sin tildes
en nombre, descripción y todas las categorías antes de paginar. Demos de
desarrollo clasificadas mediante herramienta idempotente, sin cambiar historial.
Análisis limpios; 965 pruebas raíz, 130 ADMIN y seis del paquete visual correctas
con las omisiones existentes. Cinco baterías SQL con ROLLBACK, 163 migraciones
coincidentes y capturas revisadas en móvil, texto 2× y escritorio. Solo desarrollo.
**Único siguiente bloque recomendado de este recorrido:** aceptación autenticada
de Javier en móvil y ADMIN de anchuras, clasificación, búsqueda y las dos demos
antes de ampliar catálogo. Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**VID-003 · Bunny conectado y recorrido web comprobado; bloque abierto:** subida
desde ADMIN, verificación de MP4/duración en servidor, referencias históricas
estables, firma de reproducción y caché móvil acotada. Migración y función solo
en Dev; 162 migraciones coincidentes, SQL con ROLLBACK, análisis de ambas apps
limpios y baterías completas (959 raíz, 123 ADMIN, con sus omisiones previas),
doce pruebas del editor compartido y compilaciones web de ambas apps.
Máximo ampliado a diez segundos el 18/10/2026: catorce pruebas HTTP y SQL de
límites correctos, análisis ADMIN limpio y ocho pruebas de ejercicios correctas.
Biblioteca y cinco secretos conectados el 18/10/2026. Clip de Javier subido y
publicado desde ADMIN; reproducción completa en ADMIN y app web (3.008 s,
MP4 360p de 249464 bytes). URL sin firma: 403. Corregida consulta del catálogo
del deportista con cuenta admin; análisis limpio y 967 pruebas raíz correctas
con la omisión previa.
VID-004: foto y vídeo comparten un único bloque superior, con inicio desde la
portada y audio conservado sin controles de silencio. Comprobado con el clip real
en web a 390 px; análisis limpio y 970 pruebas raíz correctas con la omisión previa.
VID-005: portada automática del vídeo oficial sin pisar fotos elegidas; guardado
real de JPEG de 42154 bytes sin otro vídeo. Campo personal aclarado como enlace
externo, con subidas de Bunny cerradas a deportistas. Análisis limpios, 970 raíz,
135 ADMIN (omisiones previas), catorce del editor y dieciséis HTTP correctas;
SQL con ROLLBACK y 163 migraciones coincidentes, sin cambiar esquema.
VID-006: selector de fotograma en ADMIN web con búsqueda temporal y captura
del vídeo pausado. Portada de las flexiones a 1,51 s guardada y confirmada al
reabrir; análisis raíz/ADMIN limpios y 139 pruebas ADMIN correctas con la
omisión previa. Sin cambios de servidor ni esquema; otros navegadores pendientes.
**Siguiente paso de este recorrido:** aceptación física en Android/iPhone y
contraste de clips reales de cinco/diez segundos, fracciones y consumo antes de
cargar catálogo o implementar entrenadores. No se da por cerrado ni se modifica
producción. Configuración y límites en [VIDEOS.md](VIDEOS.md).

**PRG-006, 18/10/2026 · proporciones de tarjetas corregidas:** la captura de
Javier acredita que la variante cuadrada seguía diferenciando Programas de
Preparaciones. Eliminada del componente compartido y del editor ADMIN; un único
formato compacto, sin hueco expansible bajo el título. Inicio y Biblioteca
mantienen ancho de 250 px, carrusel y portadas. Análisis limpios de ambas apps;
955 pruebas raíz, 118 ADMIN y seis del paquete visual correctas, con las
omisiones existentes. Regresiones comprueban la composición real y capturas
revisadas a 390 px, 320 px con texto 2× y escritorio. Sin SQL ni cambios de
datos, sesiones, ejecutores o producción.
**Único siguiente bloque recomendado de este recorrido:** aceptación de Javier
en móvil del formato compacto y las demos antes de ampliar catálogo.
Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-005, 18/10/2026 · dejar programas:** la ficha permite abandonar con
confirmación y conserva seguimiento, fase y resultados. Inicio y Programas
iniciados muestran seguimientos activos; reiniciar una publicación crea otro
desde la primera fase. Sesiones abiertas se resuelven en el ejecutor habitual,
con control de propiedad, bloqueo compartido y reintentos seguros en servidor.
Corregida la selección del seguimiento al repetir o reiniciar con historial.
Análisis limpio, 955 pruebas raíz correctas con la omisión existente, cuatro
baterías SQL con ROLLBACK y 160 migraciones coincidentes solo en desarrollo.
Diálogo y reinicio comprobados a 320 px con texto 1×/2×; errores conservan el
estado. Sin cambios de ADMIN, paquetes compartidos, ejecutores o producción.
**Único siguiente bloque recomendado de este recorrido:** aceptación de Javier
en móvil de dejar/reiniciar las demos y de sus portadas compartidas antes de
ampliar catálogo. Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-004, 18/10/2026 · tarjeta y portadas compartidas:** Preparaciones y Programas
usan `EntrenaProgramCard`; Inicio y Biblioteca reutilizan el mismo adaptador de
programa. Retiradas las composiciones duplicadas, conservando las tarjetas de
sesiones. ADMIN usa el editor común en `features/editorial_covers/`, con Portada
desde el catálogo y sin revisión deportiva por cambiar foto. Portadas por familia,
encuadres independientes, bucket existente, rutas inmutables, revisión y RLS;
limpieza que conserva imágenes vigentes de ambos recursos. Solo desarrollo.
Análisis limpios, 949 pruebas raíz y 118 ADMIN correctas con sus omisiones,
cinco baterías SQL con ROLLBACK y 158 migraciones coincidentes. Capturas de
widgets reales con fotografía a 390 px, 320 px con texto 2× y escritorio;
Biblioteca revisada. No se asignan fotos a las demos sin selección editorial.
**Único siguiente bloque recomendado de este recorrido:** aceptación de Javier
en ADMIN y móvil de selección/encuadres, actualización en Inicio/Biblioteca y
las dos demos, antes de ampliar catálogo. Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-003, 18/10/2026 · carrusel de programas en Inicio:** tarjetas cuadradas
de 250 × 250 con el acabado de Preparaciones, desplazamiento horizontal y
sección situada debajo de Preparaciones. Sin seguimientos activos se muestra
Añadir programa; este acceso y Añadir en la cabecera abren Biblioteca en
Programas, conservando la entrada habitual en Sesiones. Capturas revisadas a
390 px, 320 px con texto 2× y escritorio; regresiones de tamaño, líneas completas,
desplazamiento, orden y navegación. Análisis limpio y 947 pruebas raíz correctas
con la omisión web existente. Sin cambios de ADMIN, SQL, dependencias o ejecutores.
**Único siguiente bloque recomendado de este recorrido:** aceptación de Javier
en móvil del carrusel y de las dos demos, antes de ampliar el catálogo.
Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-002, 18/10/2026 · nombres y acceso desde Inicio:** Biblioteca y ADMIN
utilizan Rutinas/Rutina y Por fases. Iniciar programa conserva el seguimiento
explícito. Inicio/Hoy muestra los tres últimos programas propios iniciados sin
completar con acceso a su ficha y fase actual; se refrescan al volver. El paginador
se oculta si solo hay una página y conserva el regreso desde la última. Análisis
limpios, 943 pruebas raíz y 111 ADMIN correctas con sus omisiones anteriores.
Sin cambios de SQL, dependencias, agenda, ejecutores o producción.
**Único siguiente bloque recomendado de este recorrido:** aceptación de Javier
en móvil de las dos demos, incluyendo entrada desde Inicio y retorno de sesión,
antes de ampliar el catálogo. Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-001, 17/10/2026 · contenido demo solicitado por Javier:** publicados solo
en desarrollo «Demo · Empuje, tirón y pierna» (guía, tres sesiones) y «Demo ·
Mejora de dominadas» (tres fases, una sesión por fase), con ejercicios existentes,
calentamientos opcionales y descansos configurables. Carga atómica, idempotente
y separada de migraciones/producción. Comprobados catálogo como deportista,
inicio, registro y cierre de las seis sesiones y confirmación de fases con
ROLLBACK; 157 migraciones coincidentes. Sin cambios de Flutter ni historiales
reales. Contenido para aceptación, pendiente de revisión deportiva definitiva.
**Único siguiente bloque recomendado de este recorrido:** pruebas de Javier
en móvil con estas demos y revisión del creador en ADMIN antes de ampliar catálogo.
Detalle en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-001, 17/10/2026 · programas guiados, bloque 2:** Biblioteca incorpora
catálogo paginado y conserva estilo, sesiones y ejercicios. Seguimiento propio
versionado, confirmación de fases, repetición con historial y preparación de
sesiones con calentamiento/descanso sobre los ejecutores existentes. Análisis
limpio, 937 pruebas raíz correctas con la omisión existente, capturas revisadas
y seis baterías SQL relacionadas con ROLLBACK; web compilada y 157 migraciones
coincidentes en desarrollo. ADMIN queda validado en el bloque anterior. Sin contenido deportivo
ficticio publicado ni cambios de producción.
**Único siguiente bloque recomendado de este recorrido:** aceptación móvil y
ADMIN con un programa editorial real, antes de ampliar catálogo o adaptación.
Detalle y límites en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PRG-001, 17/10/2026 · programas guiados, bloque 1:** autorizados creador común
de guías/fases, calentamientos reutilizables y descansos configurables, conservando
Biblioteca y ejecutores. Autoría ADMIN implementada y comprobada: análisis limpios,
927 pruebas raíz y 111 ADMIN correctas con sus omisiones existentes, SQL instalado
con ROLLBACK y migración aplicada solo en desarrollo. No cierra el uso del deportista.
**Único siguiente bloque de este recorrido:** Biblioteca y seguimiento, preparación
de sesiones y confirmación de fases sobre el ejecutor actual. Detalle y límites en
[PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

**PLAN-026, 16/10/2026 · selección y progresión de carrera:** v6 conserva los
datos compatibles ante una referencia nueva, prioriza dosis antes del bonus de
velocidad por meta, evita que más días o una pareja inviable bloqueen calidad
conocida y comprueba huecos posteriores antes de bajar de formato. Se mantienen
el catálogo, los constructores, v5 reproducible, semanas publicadas y contratos
de fuerza/controles. Las regresiones y la repetición instalada del mismo caso
FAS se detallan en [MOTOR_CARRERA_2K_V6.md](MOTOR_CARRERA_2K_V6.md).
Verificado en desarrollo: análisis limpio, 923 pruebas de raíz y una omisión
web, 29 baterías SQL, 154 migraciones coincidentes y 25 cuerpos instalados
cotejados. El mismo FAS completa 26 semanas, 101 sesiones y 689 registros con
doce controles automáticos, sin forzar formatos/resultados ni exceder tiempo.
La aceptación física y los ensayos conjuntos anual/concurrencia siguen abiertos.
**Único siguiente bloque recomendado:** aceptación del recorrido combinado en
móvil, contrastando la pauta y sus explicaciones con la transcripción real,
antes de ampliar el catálogo candidato.

**STR-041, 16/10/2026 · controles automáticos:** recorrido incorporado en
desarrollo para flexiones, plancha, circuito de 16 m y carrera de 2 km. Selección
por necesidad, respuesta y fase; sustitución de trabajo y recuperación común;
resultados válidos reutilizados con procedencia, sin duplicar ni crear una
evaluación oficial. El caso FAS completa seis meses sin controles manuales
aportados por la fixture: 26 semanas, 102 sesiones, 679 registros y doce controles
de protocolo. No demuestra eficacia fisiológica ni consecución de metas.
Análisis limpio, 923 pruebas de raíz y una omisión web, 25 baterías SQL,
152 migraciones coincidentes y 22 cuerpos instalados cotejados.
La aceptación en móvil, anualidad conjunta y estrés de concurrencia siguen
pendientes. El diagnóstico de variedad de carrera conserva los formatos y
progresiones ordinarios, sin ejecutar una corrección no autorizada.
La revisión de formatos recomendada en este cierre se ejecuta después en
PLAN-026, por autorización de Javier. Contrato y ensayos en
[CONTROLES_ADAPTATIVOS.md](CONTROLES_ADAPTATIVOS.md) y
[VARIEDAD_CARRERA_2026_10_16.md](audits/VARIEDAD_CARRERA_2026_10_16.md).

**STR-040, 16/10/2026 · continuidad, metas y catálogo:** correcciones aplicadas
y verificadas en desarrollo. Se elimina el bloqueo regional de flexiones,
plancha conserva trabajo compatible al cambiar de fase y el adaptador de carrera
aprovecha dos rodajes fáciles observados para un ensayo acotado. Núcleo carrera
v5 intacto. Dead bug sale del selector y plancha alta tiene primera práctica
propia, por duración/RPE. Metas y marcas compatibles se distinguen y orientan el
desempate; no se infieren máximos desde series.
Análisis limpio, 917 pruebas de raíz y una omisión web, 23 baterías SQL,
149 migraciones coincidentes y veinte definiciones instaladas cotejadas.
El mismo FAS de seis meses completa 26 semanas, 102 sesiones y 788 registros sin
forzar marcas finales, exceder disponibilidad ni dejar datos. La transcripción
anterior se conserva y se compara con la nueva. La simulación verifica software,
no eficacia fisiológica. La programación de tests máximos se completa después
en STR-041; la aceptación física y los límites previos anual/concurrencia siguen
abiertos.
**Único siguiente bloque recomendado:** aceptación en móvil del programa
combinado, revisando selección/función de los ejercicios, primera práctica,
registro y transición/adaptación con el repertorio actual, antes de ampliarlo.
Detalle en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md) y
[CATALOGO_ACTIVO_RENDIMIENTO.md](CATALOGO_ACTIVO_RENDIMIENTO.md).

**STR-039, 16/10/2026 · entrada autónoma de accesorios:** recorrido implementado
y verificado en desarrollo. El motor elige apoyos revisados, reutiliza datos
propios y propone una práctica guiada opcional cuando faltan. Publicación,
origen del registro, incertidumbre, material, retirada y tiempo quedan cubiertos.
Análisis limpio, 914 pruebas de raíz, 22 baterías SQL, 148 migraciones
coincidentes y trece cuerpos instalados contrastados, incluida carrera v5
original. FAS combinado pasa nueve semanas con respuestas completas,
incompletas y omisiones; un programa independiente creado desde ADMIN pasa
26 semanas de carrera/flexiones con apoyo automático. El ensayo de seis meses
con todos los bloques FAS supera el límite HTTP y no se declara validado; se
conservan los demás límites de seguridad, anualidad y concurrencia del contrato.
El único siguiente bloque recomendado es la aceptación física en móvil de
selección, primera práctica, registro y adaptación del apoyo dentro del programa.
Detalle en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-038, 16/10/2026 · frecuencia por estímulo y apoyos reales:** bloque
cerrado en código y Supabase de desarrollo. Sin techo universal dos: la dosis
practicable, respuesta, fase, recuperación y calendario delimitan el reparto.
Cada exposición conserva su dosis; se corrigen el alta y selección de apoyos y
se permite declarar una frecuencia habitual mayor. Carrera v5 conserva su cuerpo.
Análisis limpio, 912 pruebas correctas con una omisión web, 21 baterías SQL,
146 migraciones coincidentes y trayectorias conjuntas de 26 semanas y nueve
semanas con accesorio calibrado. Las simulaciones verifican reglas y continuidad,
no resultados fisiológicos. Persisten los límites anual/seguridad/concurrencia
indicados en el contrato. El único siguiente bloque recomendado es la aceptación
móvil del programa combinado con accesorio: entrada, pauta, registro y adaptación.
Detalle en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-037, 16/10/2026 · frecuencia autónoma y disponibilidad:** bloque cerrado
en código y Supabase de desarrollo. Rendimiento puede pasar de una a dos
exposiciones desde respuestas comparables, repartiendo el volumen conocido;
el coordinador conserva una exposición completa cuando no caben dos y guarda
la frecuencia entregada. Carrera v5 conserva su cuerpo. La carga registrada
precarga las semanas recientes, sin renovar salud ni inventar inactividad.
Máximo de días, duración habitual y calendario con excepciones usan el mismo
contexto. Análisis limpio, 912 pruebas de raíz correctas y una omisión web
existente; veinte baterías SQL instaladas, 145 migraciones coincidentes y
trayectorias combinadas de cinco y 26 semanas. Desde frecuencia uno se observan
dos exposiciones por movimiento y hasta tres días físicos de fuerza en el caso
simulado. No acredita mejoras fisiológicas ni cierra el ensayo anual conjunto.
El único siguiente bloque recomendado es la aceptación móvil del programa
combinado: disponibilidad, precarga contextual y adaptación tras cierres reales.
Contrato y límites en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-036, 16/10/2026 · evidencia de carrera/fuerza y encaje conjunto:**
reparación de los seis defectos confirmados por Astra, aplicada solo en
desarrollo sin reescribir sesiones/resultados. Caso real 5×60/5×90 reproducido:
dos carreras y una exposición de rendimiento compartida, coherentes con sus
datos iniciales; se comprueba también una frecuencia mayor con carga reciente.
Fechas observadas y cola offline, abandonos por bloque, falta de tiempo,
RIR dinámico temporal, capacidad baja con carga y coste compartido exacto.
Análisis limpios, 909 pruebas de raíz y 109 de admin correctas, con sus omisiones
existentes; 18 baterías SQL instaladas y ciclo conjunto de 26 semanas correctos.
144 migraciones coincidentes. El ensayo anual conjunto supera el límite HTTP;
los horizontes anuales por motor pasan y ese límite queda explícito, junto con
los avisos previos de seguridad y la concurrencia no sometida a estrés.
El único siguiente bloque recomendado es la aceptación del programa combinado
en móvil: cierre offline, reanudación y revisión contextual cuando corresponda.
Detalle reproducible en [la auditoría](AUDITORIA_ADAPTATIVA_2026_10_16.md).

**UI-047 / STR-034, 16/10/2026 · RPE entero y repetición de sesiones:** se
reutiliza el selector de esfuerzo en entrenamiento, rendimiento y corrección;
nuevas elecciones RPE del 1 al 10, sin redondear históricos/borradores ni cambiar
RIR o motores. El cierre aceptado no depende de otra lectura o de limpieza, y
el inicio sincroniza primero los cierres pendientes. Análisis limpio, 85 pruebas
relacionadas y 896 completas correctas, con una omisión existente. Dos fallos
técnicos relacionados están reproducidos y corregidos; el episodio intermitente
de EMOM no tiene una causa física confirmada. El siguiente recorrido es probar
RPE entero y finalizar/repetir un EMOM en móvil. Detalle en `VISUAL_DESIGN.md`.

**UI-046, 16/10/2026 · circuito AMRAP y guardado:** código y verificación técnica
completados; repetición física pendiente. Circuito con tarjetas compactas y ficha
de consulta, contador opcional, reloj protagonista y revisión recuperable.
Se conecta Supabase y se aplican las dos migraciones a entrenaop-dev: fuente
manual obligatoria, parcial entre movimientos y reintentos sin duplicados.
Las 143 migraciones coinciden con Git, conservando los identificadores generados
por el servidor. La prueba SQL transaccional pasa, incluidos 13/30 y cuatro
vueltas sin parcial; no deja datos ficticios. Análisis limpio, 64 pruebas
específicas y 886 completas correctas, con una omisión existente.
El siguiente recorrido es reintentar el borrador del iPhone y revisar el balance
reloj/cierre en móvil; sin cambios en producción. Detalle en `VISUAL_DESIGN.md`.

**Integración en main, 16/10/2026:** el entrenamiento UI-040 se combina con
Biblioteca, botones y ritmos de main sin sustituir los cambios de otros equipos.
Análisis limpio, 41 pruebas de sesión y 847 completas correctas, con la omisión
web existente. Main sigue siendo el único punto de actualización; aceptación
del entrenamiento en iPhone pendiente tras traer y reinstalar la versión.
Cotejo en `docs/audits/branches-2026-10-15.md`.

**UI-040, 15/10/2026 · pantalla de entrenamiento:** recorrido cerrado en código
y verificación técnica, con aceptación física pendiente. La distribución
compacta conserva el reinicio del reloj, muestra las fotos existentes y abre la
ficha de técnica compartida como consulta. Acciones fijas, descanso con siguiente
paso y registros agrupados. Las series ordinarias pueden terminar y descansar
con datos pendientes recuperables del dispositivo; confirmar utiliza el registro
existente y los retoques posteriores se consolidan al cerrar con auditoría.
Dominio, puertos de persistencia, modelo/almacenamiento de datos y componentes
visuales permanecen separados; no hay preferencias ni Supabase en los widgets.

Comprobación: análisis limpio, 811 pruebas completas correctas y una omisión
preexistente, compilación web correcta y cuatro escenarios de capturas reales
de widgets revisados. Incluyen móvil de 390 px, 320 px con texto al doble,
teclado simulado y escritorio. La imagen de referencia solo se usa en capturas;
no se publica en el catálogo. Sin cambios admin, compartidos, dependencias, SQL,
motores ni producción.

Límites: los datos sin confirmar y los retoques aún no sincronizados pertenecen
al dispositivo; las correcciones de registros enviados requieren conexión y
mantienen 24 horas/tres cambios. Vídeo pendiente de su gestión de contenido;
AMRAP y rendimiento conservan sus contratos específicos. El único siguiente
recorrido recomendado de este bloque es instalar la versión en móvil y probar
una sesión autenticada con fotos propias/oficiales, reinicio, descanso,
corrección, salida y retorno. Detalle en `VISUAL_DESIGN.md`, UI-040.

**DEV-003, 14/10/2026 · entorno cloud de preparación:** EntrenaOP Dev queda
privado, limitado a `jchjdev/entrenaop` y publicado, con Flutter 3.47.5 stable
y Dart 3.13.4. Se comprueba `7b2ebb2`, que incluye la integración y los arreglos
posteriores de FAS/iPhone. Tres análisis limpios, 799 pruebas de raíz, 109 de
admin y nueve del editor compartido correctas, con las dos omisiones existentes.
Los seis comandos y la repetición completa del instalador terminan con código 0.
Lockfiles y archivos versionados intactos en el checkout cloud; sin acceso ni
operaciones contra Supabase, RevenueCat o producción.

La publicación está acreditada por la interfaz. El único siguiente recorrido
cloud recomendado es abrir el primer trabajo en EntrenaOP Dev y comprobar la
restauración/activación del SDK antes de un cambio pequeño. Esta preparación
no cierra Free/Pro ni sustituye las pruebas físicas de Android/iPhone o SQL de
la matriz. DEV-002 conserva su alcance y no se da por migrado todo el desarrollo.
[Configuración, resultados y límites](CLOUD_DEVELOPMENT.md).

**Integración Windows/macOS, 14/10/2026:** Javier autoriza reunir los cuatro
commits que habían divergido desde `d5016de`. Se conservan `c6dd045` (tiempos)
y `c1e97cb` (fotos y acción fija), junto con `9aedb1f` (arranque de compras
en macOS) y `a24ac6d` (instalación Release Dev y sincronización). La integración
entra sin conflictos y conserva la historia de ambas líneas.

Comprobación de la combinación: `flutter analyze --no-pub` sin incidencias en
raíz, admin y `workout_editor_ui`; baterías completas correctas con 791 pruebas
de raíz, 109 de admin y nueve del editor compartido. Se mantienen las dos
omisiones web optativas preexistentes. Las regresiones cubren autoformato,
fracciones, conversión a segundos/milisegundos, regalos Pro indefinidos,
confirmación tardía sin recomprar, cambio de cuenta y retorno a Mi plan.
Se conserva fuera del commit el archivo local previo `devtools_options.yaml`.
No cambia el código de Pro, las dependencias, SQL ni las funciones del servidor.

Límite: esta integración no actualiza las apps ya instaladas ni acredita una
compra física nueva o el cierre de Free/Pro. El siguiente recorrido recomendado
es sincronizar el Mac con el commit integrado, reinstalar el iPhone y comprobar
los tiempos; las compras Test Store requieren el lanzamiento móvil debug Dev,
mientras Release Dev permite abrir desde el icono y consultar el acceso Pro.
La elección de trabajo en la nube queda para después de este punto de guardado.
[Sincronización e instalación](IOS_DEVELOPMENT.md).

**UI-030, 14/10/2026 · fotos y acción fija en la vista de sesión:** recorrido
cerrado en código. La vista previa resuelve fotos por ejercicio con el caso
de uso existente, sin retrasar la sesión; mantiene orden y usa fallback ante
fallo. La acción principal queda fija en una franja que reserva espacio, con
estado ocupado y reintento. Se protege la navegación de fotos tardías y el
listado admite pantalla estrecha/texto ampliado sin desbordar sus etiquetas.

Comprobación: análisis limpio, 791 pruebas de raíz correctas con la omisión
web existente y compilación web. Capturas actuales de inicio/final a 390 px,
320 px con texto al doble y escritorio a 1000 px. Regresiones de Cubit y
widgets incluyen doble inicio, fallo, cierre, recarga y retorno sin duplicar
el ejecutor. No cambia admin, paquetes compartidos, datos, algoritmo ni
producción; se conserva fuera del bloque `devtools_options.yaml` previo.

Límites: las capturas de distribución usan una sesión ficticia sin fotos;
URL/fallback se comprueban en pruebas, no mediante imágenes autenticadas en
móvil. El único siguiente recorrido UX recomendado es biblioteca → vista
con fotos oficiales/propias → empezar → volver, en dispositivo actualizado.
Este tramo no cierra Free/Pro ni sustituye las verificaciones deportivas o
de entrada de tiempos pendientes. Detalle en `VISUAL_DESIGN.md`.

**UI-029, 14/10/2026 · entrada de tiempos uniforme:** se revisan los campos
de segundos/ritmos del deportista, admin y controles compartidos. Se muestra
`00:00` y se añaden separadores al teclear dígitos, con fracciones en mediciones
precisas. Valores precargados y callbacks conservan segundos/milisegundos;
no cambian datos anteriores, restricciones, algoritmos, SQL ni producción.
Alcance detallado e inventario por recorrido en `VISUAL_DESIGN.md`.

Comprobación: análisis de ambas apps sin incidencias, 781 pruebas de raíz,
109 del admin y nueve de `workout_editor_ui` correctas, con las omisiones
optativas existentes. Ambas webs compiladas. El teclado numérico se prueba
mediante widgets/formatter, no mediante instalación en Android/iOS físico.
Se conserva sin incluir el archivo previo `devtools_options.yaml`.

Este recorrido de entrada queda cerrado en código. El único siguiente paso
UX recomendado es comprobar Tropa → FAS → sesión → corrección de resultado
en los dispositivos actualizados. No sustituye los siguientes tramos de
negocio o entrenamiento definidos en sus documentos responsables.

**COM-018, 13/10/2026 · anual y confirmación tardía:** compra anual Test Store
acreditada en Dev; Javier observa oferta persistente y Pro al restaurar. El
repositorio añade confirmación automática limitada, sin recomprar y sin conceder
derechos locales, y explica fecha/hora y periodos acelerados de prueba. Análisis
limpio, 45 pruebas Pro y 776 raíz correctas con la omisión existente; capturas
revisadas y APK debug Dev instalada por reemplazo a las 23:11 en Samsung.
Sin cambios SQL, admin, dependencias o producción. El siguiente tramo recomendado
es repetir Free → compra → Pro → Mi plan en la versión actual; restauración de
historial de tienda requiere sandboxes nativos y no queda acreditada por Test
Store. No se retira ni reinicia la anual activa. Free/Pro sigue abierto.
[Alcance y límites](PRO_LAUNCH.md).

**Aceptación manual, 13/10/2026 · fechas administrativas:** Javier confirma que
cambiar fechas parece funcionar bien. Aclara que el error posterior al retirar
Pro se observó en un iPhone sin actualizar; la consulta propia de servidor tras
retirar devuelve Free y cuotas 8/4. No se considera una regresión confirmada
del Android actualizado ni una aceptación completa de compras. Free/Pro sigue
abierto: cuotas/continuidad, compra mensual/anual, moneda, cancelación/error,
restauración/cambio de cuenta e iOS actualizado pendientes de aceptación móvil.
Ventas reales mantienen su configuración y validación pendientes. El único
siguiente recorrido recomendado sigue siendo Android debug desde Free sin
regalo, compra → Pro → Mi plan → restauración/caducidad. [Detalle](PRO_LAUNCH.md).

**COM-017, 13/10/2026 · listado de cuentas y responsable único:** Cuentas y Pro
lista correos, Free/Pro y fuentes, con búsqueda parcial y páginas de 25; pulsar
una fila conserva la ficha de gestión. Javier es el único responsable configurado
en Dev; editar contenido no concede consulta ni gestión de cuentas. Se protegen
las RPC actuales y antiguas y las rutas directas. Análisis limpio, 108 pruebas
admin y 770 raíz correctas con sus omisiones existentes, compilación web y
capturas revisadas. SQL con ROLLBACK antes/después, consulta real como Javier
y 141 migraciones coincidentes. Producción no cambia. Free/Pro sigue abierto;
el siguiente tramo recomendado continúa siendo la aceptación móvil de compras,
cancelación/error y restauración, verificando moneda e importes del proveedor.
[Detalle](PRO_LAUNCH.md).

**COM-016, 13/10/2026 · Pro gratuito desde el admin:** Cuentas y Pro busca por
correo y distingue regalo y suscripción. Concesión temporal o indefinida,
modificación y retirada con confirmación, actor y motivo, autorizadas en servidor.
Retirar el regalo conserva una compra vigente. Dev habilitado, 140 migraciones
coincidentes y pruebas SQL de regalos/cuotas/conciliación correctas con ROLLBACK.
Análisis limpio, 770 pruebas raíz y 98 admin correctas, con las omisiones web
existentes, y capturas revisadas. Las betas anteriores necesitan actualizarse
para regalos indefinidos. Producción no cambia. Este tramo está verificado;
Free/Pro sigue abierto. El único siguiente tramo recomendado es la aceptación
móvil de compra, cancelación/error y restauración, comprobando los importes del
proveedor antes de preparar tiendas reales. [Alcance](PRO_LAUNCH.md).

**COM-015, 13/10/2026 · compra física y retorno a Mi plan:** Javier prueba Test
Store en Android físico; compra mensual y Pro RevenueCat se acreditan en
servidor. El reinicio confirma Pro y se identifica una aserción de Navigator
al pulsar «Ir a Mi plan» desde Mi suscripción. Se reproduce en pruebas y se
corrige: `go` regresa a la navegación principal sin apilar otro shell. Análisis
limpio, 37 pruebas Pro y 768 de raíz correctas con la omisión web existente.
Incluye compra confirmada → «Ya tienes Pro» → Mi plan. El único siguiente
tramo continúa siendo la aceptación móvil: repetir retorno con el arreglo,
comprobar respuestas de cancelación/error y restaurar. Free/Pro sigue abierto.
[Estado y límites](PRO_LAUNCH.md).

**COM-013, 13/10/2026 · primera integración de compras preparada:** SDK oficial
10.15.2, precios del catálogo, compra/restauración y confirmación de servidor
implementados para Test Store móvil debug. Se descartan respuestas de otra
cuenta y se evita repetir una compra pendiente. Las funciones y la migración
se comprueban con pruebas de contrato; el SQL se ejecuta en Dev con ROLLBACK.
Javier autoriza después el despliegue Dev: migración aplicada, dos funciones y
webhook sandbox conectados, secretos solo en Supabase. TEST responde 200 y
sin autorización ambas funciones responden 401. Una compra mensual simulada
del proveedor verifica el evento INITIAL_PURCHASE y Pro canónico en servidor;
se conservan los accesos manuales y, en ese primer ensayo, la segunda cuenta Free.
La prueba posterior de Javier en Android físico genera INITIAL_PURCHASE para
la secundaria a las 21:08 (Madrid), con Pro RevenueCat confirmado en servidor.
También se comprueban RENEWAL y EXPIRATION de la compra inicial del CLI,
conservando el Pro manual. El diálogo inglés corresponde al SDK Test Store.
139 migraciones
coincidentes y pruebas SQL de conciliación/cuotas correctas tras desplegar.
Análisis limpio, 766 pruebas de raíz correctas y la omisión web
existente; 18 pruebas de funciones correctas. Free/Pro sigue abierto. El único
siguiente tramo es comprobar una compra/restauración desde la interfaz móvil
debug, incluidas respuesta visible de cancelación/error y restauración, antes
de preparar las tiendas reales. El Android ya está conectado y se acredita
la compra mensual en servidor; la beta profile no utiliza Test Store.
El CLI oficial ya está autorizado y conectado únicamente a este proyecto;
oferta y acceso `pro` están enlazados a mensual/anual. Precios EUR 3,99/29,99
configurados y devueltos por el catálogo del SDK con configuración española.
[Configuración y límites](../tools/payments_dev/README.md).

**COM-012, 13/10/2026 · proveedor elegido:** Javier acepta stores + RevenueCat
para las suscripciones y conservar Supabase/PostgreSQL para datos y autorización.
Se mantiene el inicio con pruebas gratuitas y se dimensionará el servidor con
mediciones antes de vender. Supabase Pro es una previsión de lanzamiento;
no se contrata ahora. COM-013 concreta la implementación y la configuración
posterior del proyecto externo y su backend Dev.
[Elección, coste y preparación](PRO_LAUNCH.md).

**COM-010/011, aclaración y preparación al 13/10/2026 · bloque abierto:** Javier
rechaza el cierre provisional de Free/Pro: este chat incluye conectar los pagos
a los derechos de servidor. El producto para entrenadores se estudia aparte.
Confirma Apple Developer con membresía caducada; se propone comenzar con un
proyecto RevenueCat de desarrollo y Test Store, y después validar las tiendas
reales. COM-013 añade el SDK, el backend preparado y el catálogo externo
verificado; la compra y su conciliación completa siguen pendientes. Las
comprobaciones anteriores conservan sus fechas y límites; no se declaran pruebas
de compras realizadas. [Preparación y alcance](PRO_LAUNCH.md).

**COM-009 y MAIL-002, 10/10/2026 · correcciones de Pro y confirmación:** `/pro`
consulta acceso real y una cuenta Pro ve «Ya tienes Pro», vigencia y continuidad,
sin «Seguir con Free» ni oferta de compra. Mi suscripción anuncia Pro solo a
Free; carga/error conservan el reintento. Confirmación de alta traducida y
aplicada en Dev, con recuperación intacta y sin cambios ajenos en Auth.
La cuenta indicada ya estaba confirmada: se aclara que un error de canje en otro
navegador puede permitir entrar con contraseña y que reenvío aceptado no asegura
envío. PKCE se conserva. Análisis limpio, 742 pruebas de raíz correctas y la
omisión web existente; siete pruebas del verificador correctas. Captura Pro
revisada; recepción del nuevo HTML y acceso real de la segunda cuenta pendientes.
Sin cambios en admin, SQL, derechos, cuotas, dependencias ni producción. El
siguiente bloque Pro sigue siendo conectar tiendas a los derechos, antes de
habilitar cobros. Detalles en [Pro](PRO_LAUNCH.md) y
[Cuenta](REFRESH_ACCOUNT_2026_10_08.md).

**COM-008, 10/10/2026 · derechos y cuotas en desarrollo:** Javier pide cuentas
reales para probar Free/Pro y retoma la propuesta 8 ejercicios/4 sesiones. La
app consulta derechos de Supabase, presenta contadores y conserva borradores al
alcanzar una cuota. Pro autoriza cálculo/adaptación; al perderlo se conservan
sesiones, edición, uso e historial. Admin Dev concede/retira Pro temporal, con
permiso y habilitación de servidor; administración y suscripción siguen separadas.
Los contratos de propiedad y el contenido oficial se mantienen. Verificación:
análisis de ambas apps limpio, 737 pruebas del deportista y 94 del admin correctas,
con una omisión web existente en cada batería; 16 SQL transaccionales con
ROLLBACK y 138 migraciones coincidentes en Dev. Capturas de Free/Pro revisadas.
La cuenta indicada por Javier recibe 30 días de Pro de prueba, hasta el 09/11/2026.
No hay compras, SDK, producción ni dispositivos físicos verificados.
El único siguiente bloque de Pro es conectar productos/eventos de tienda a estos
derechos, antes de habilitar cobros. [Recorrido de prueba](PRO_LAUNCH.md).

**COM-006, 10/10/2026 · interfaz inicial Pro verificada:** Javier aprueba el
recorrido y pide primero código, después conectar pagos. Mi plan sin programa
y las fichas Tropa/FAS ofrecen descubrimiento con candado; ejemplo didáctico,
oferta mensual/anual y Mi suscripción en Perfil. Tarjetas/fotos, agenda,
resultados y accesos de desarrollo conservados. Contratación/restauración
deshabilitadas y explicadas, sin cobro simulado ni derechos locales.
Análisis limpio; 53 pruebas relacionadas y 726 completas correctas con la
omisión web existente; capturas de widgets y recorrido a 320 px con texto doble.
No modifica Supabase, producción, admin, paquetes o dependencias. No acredita
compras, derechos, bloqueo comercial ni dispositivos físicos.
[Alcance y requisitos](PRO_LAUNCH.md). El único siguiente bloque recomendado
para Pro es conectar tiendas/proveedor y derechos verificables de servidor
antes de habilitar el cobro. La revisión deportiva de Javier continúa aparte.

**UI-026, 10/10/2026 · accesos y mensajes depurados:** una única entrada
Ver preparación desde sus tarjetas, conservando fotos, estados y detalle de
programa/fecha/marcas/resultados. Favoritos personales sin destinos duplicados,
con migración del antiguo Crear ejercicio a Mis ejercicios y orden por cuenta.
Herramientas sin Ver todas repetido; Biblioteca conserva su pestaña y retira
Perfil duplicado. Errores de autenticación en castellano sin mensajes técnicos,
con los estados de confirmación/recuperación existentes. Análisis limpio,
153 pruebas relacionadas y 717 pruebas completas correctas con la omisión web
existente. [Recorrido y límites](UX_REVIEW_2026_10_09.md).
Sin cambios de datos, motores, negocio, admin o producción. No acredita un
nuevo recorrido autenticado ni físico. El único siguiente bloque recomendado
sigue siendo la revisión de Javier de preparación → Mi plan → Hoy.

**UI-024, 09/10/2026 · gesto de volver verificado:** páginas explícitas de Flutter
y gesto desde el borde en Android/iOS/web, manteniendo flecha, scroll y pestañas. Sesiones
y formularios consultan sus protecciones antes de salir; cancelar permite repetir
el gesto y mantiene los datos. Javier precisa que Android debe ofrecerlo también
con navegación de tres botones, además de atrás del sistema: implementado.
Análisis limpio, 706 pruebas completas correctas con la omisión web existente;
51 regresiones relacionadas incluyen ambos móviles. La primera verificación
acreditó además nueve regresiones en Chrome. El banco web necesitó normalizar en memoria
dos rutas generadas por Flutter en Windows; no se modificó el SDK. Requiere hot
restart. Javier confirma que el gesto va muy fluido en Android físico con la
configuración profile el 09/10/2026; sin medición de fotogramas.
[Implementación y límites](VISUAL_DESIGN.md). iPhone físico y un nuevo recorrido
autenticado completo siguen pendientes. El único siguiente bloque recomendado
continúa siendo la revisión de Javier de preparación → Mi plan → Hoy.

**UI-022, 09/10/2026 · ajustes cotidianos cerrados:** descarte confirmado de
ejecución en curso y series, con cita restaurada e historial cerrado protegido;
Perfil sin acceso duplicado; Añadir entrenamiento en agenda; días/minutos
separados; FAS con carga acotada y reintento. Análisis limpio, 685 pruebas
completas correctas con una omisión web existente, captura de Disponibilidad
y tres pruebas SQL con `ROLLBACK`. 134 migraciones coincidentes en desarrollo.
[Recorridos, contrato y límites](UX_REVIEW_2026_10_09.md).

El único siguiente bloque recomendado continúa siendo la revisión pausada de
Javier del recorrido preparación → Mi plan → Hoy, por estados reales. Este
cierre no acredita gimnasio, iPhone físico ni recorrido Flutter autenticado
nuevo. Los pendientes de negocio, motores, vídeo y comparativas siguen aparte.

**UI-021, 08/10/2026 · coherencia localizada cerrada:** referencias y meta de
carrera mantienen campos separados, selección completa y ayudas legibles.
Mi plan sin programa ofrece Elige una preparación antes de la semana, diferencia
borrador/pausa/finalización y resume el contexto común de disponibilidad/material.
Inicio usa Preparaciones y no elige la primera entre varias sin programa activo.
El bloqueo por sesión abre la ejecución concreta y vuelve a la misma propuesta,
conservando la semana; retomar después mantiene el bloqueo y resolverla permite
revisar la activación. Tarjetas y portadas conservadas. Análisis limpio y 671
pruebas completas correctas con la omisión web existente; capturas de fixtures
revisadas y 133 migraciones coincidentes en desarrollo, sin cambios SQL.
[Recorrido, evidencia y límites](PLAN_COHERENCE_2026_10_08.md).

El único siguiente bloque recomendado es la revisión pausada de incoherencias
que Javier quiere hacer, por recorrido y estado real. Este cierre no acredita
una prueba autenticada nueva ni el uso entrenando. Gimnasio, iPhone físico y
primera entrada Android sin permiso quedan como validaciones posteriores.
Negocio Free/Pro, motores, vídeos y comparación configurable siguen aparte.

**UI-020, 08/10/2026 · tiempo y salidas verificados:** corregido el valor de
segundos que el temporizador escribía sin formato en Tiempo realizado. 20 se
muestra como 0:20 y se confirma como 20 segundos; también comprobados 90 y 3601.
La flecha ofrece seguir, retomar o abandonar conservando resultados con motivo.
Cancelación, error/reintento y sincronización pendiente mantienen su contrato.
Diálogos desplazables a 320 px con texto doble. Análisis limpio en app/admin/
entrena_ui y baterías completas de 630/91/6 pruebas correctas, con las dos
omisiones existentes; 30 regresiones específicas correctas.
[Detalle](SESSION_CONTROLS_2026_10_08.md).

**IOS-002, 08/10/2026 · audio del simulador comprobado:** la copia del Mac y la
app instalada seguían en 98e037e, antes de incorporar plugin y WAV. Actualizada
sin cambios de código a 774361b y reconstruida: banco iOS compila, arranca y
confirma reproducción de todos los avisos. Javier confirma «Sí, ahora suena».
Análisis limpio, 621 pruebas correctas con la omisión web; app principal
relanzada con Supabase de desarrollo. La vibración estaba activada y sus llamadas
no dieron errores. [Evidencia y límites](IOS_DEVELOPMENT.md).

**HAPT-001, 08/10/2026 · vibración física confirmada en Samsung:** Javier confirma
que funciona en SM-A326B/Android 13 al conceder el permiso de notificaciones.
El log anterior acreditó que Samsung cancelaba los avisos por tenerlas
desactivadas para EntrenaOP. La prueba manual pide el permiso y respeta su
denegación; análisis limpio, 653 pruebas correctas con la omisión web existente
y compilaciones Android/iOS correctas. Percibe un pequeño adelanto respecto al
sonido, aceptable y sin medir. La primera sesión activa ofrece ahora el permiso
si falta en Android 13+, con explicación, Permitir avisos o Ahora no y recuerdo
local para no repetirlo. La prueba manual sigue disponible. Este nuevo recorrido
de entrada requiere comprobación en un Android físico sin permiso.
[Evidencia y límites](WORKOUT_AUDIO_2026_10_08.md).

Javier aclara que ya ha comprobado parcialmente en Android el recorrido de
avisos, guardado, salida/reanudación y resultado. El uso entrenando en el gimnasio
queda como validación posterior, junto con volumen/silencio, música y auriculares.
iPhone físico y primer uso Android sin permiso conservan sus pruebas pendientes;
no se exige realizarlas ahora para continuar con la revisión de incoherencias
que Javier quiere mostrar. El simulador no acredita sensación física y segundo
plano mantiene su alcance pendiente. Descartar resultados registrados, negocio
y motores continúan aparte.

**UI-019, 08/10/2026 · correcciones localizadas verificadas:** los vídeos de
Javier permiten reproducir la ausencia de abandono en el cierre final y el
ancho fijo de los días en Mi semana. Ambos corregidos conservando diseño y
contratos. Cuenta de trabajo añade los pitidos 3, 2, 1 confirmados por Javier.
Análisis limpio, 621 pruebas completas correctas con la omisión web existente,
regresiones de fallo/reintento/sincronización, anchos y restauración, además de
tres capturas de semana actual y banco web compilado. Cuenta real de cinco
segundos en Chromium con tres pitidos finales y final aceptados, sin errores.
[Cambios, evidencia y límites](SESSION_CONTROLS_2026_10_08.md).
UI-020 amplía la salida con opciones; el posible descarte total sigue pendiente
de contrato. La recomendación original de escucha en el Mac queda comprobada
en IOS-002; este arreglo por sí solo no acredita un cierre global.

**UI-018, 08/10/2026 · sonido implementado, revisión nativa abierta:** corregido
el adaptador que usaba SystemSound.alert, ignorado en Android/iOS/web. Cinco
WAV locales y audioplayers 6.8.1; preparación/inicio/mitad/diez segundos/final
en trabajo y descanso, sin duplicar ni reproducir hitos pasados. Preferencias
independientes, prueba explícita y fallos aislados. Análisis limpio app/admin,
606 y 91 pruebas completas correctas con las omisiones existentes, 27 específicas,
reproducción real aceptada en Chromium y APK debug compilada. Se mantiene el
aspecto de la app y la configuración iOS del Mac. No modifica motores, negocio,
SQL ni producción. [Recorrido, evidencia y límites](WORKOUT_AUDIO_2026_10_08.md).

El recorrido recomendado originalmente fue actualizar y reiniciar completamente
la app de desarrollo en el Mac, compilar el plugin nuevo y escuchar Probar sonido
y un intervalo/descanso. SPM revisado por configuración, sin acreditar aún ese
arranque o escucha en esa comprobación; IOS-002 añade después esa evidencia.
HAPT-001 añade después la confirmación física en Samsung; música/auriculares,
sesión real y segundo plano no se dan por comprobados. Javier comunica una
revisión superficial positiva en
simulador de guardado, Evolución y fotografías; no cierra la auditoría
autenticada global. Recuperación de correo nativa puede esperar. Comparativas
configurables, seguridad de publicación, vídeos, negocio y motores mantienen
su alcance aparte. Esta entrada sustituye las recomendaciones previas ya
realizadas, sin actualizar sus fechas históricas de comprobación.

**UI-017, 08/10/2026 · tramo de formularios cerrado:** nuevo programa admin y
selectores del formulario compartido de ejercicios muestran sus selecciones
completas con texto grande. Nombre/tipo se conservan tras fallo y reintento;
crear programa continúa creando un borrador. Los controles de foto se sitúan
bajo la vista previa cuando necesitan espacio, conservando imagen y encuadre.
No cambia Inicio/Mi plan, datos, permisos, rutas, motores, negocio o producción.
Análisis limpio de app/admin/paquete; 591, 91 y 8 pruebas completas correctas,
con sus omisiones existentes. Seis recorridos visuales y 12 imágenes revisadas.
[Alcance, imágenes y límites](REFRESH_FORMS_2026_10_08.md).

El único siguiente bloque recomendado es la comprobación autenticada de los
recorridos actuales de app/admin. El navegador disponible está sin sesión;
esa prueba queda pendiente. Este cierre es localizado, no cierra todo el pulido
transversal. Comparación configurable, revisión física y pendientes de
publicación de UI-013 permanecen abiertos. iPhone/iOS espera al entorno Mac de
Javier; vídeos, negocio y motores mantienen sus tareas aparte.

**UI-016, 08/10/2026 · tipo histórico y filtro cerrados en desarrollo:**
Evolución filtra Carrera, Fuerza y acondicionamiento, Mixta y Sin clasificar,
combinados con preparación, fechas, estado y paginación. Servidor conserva tipo
y política al iniciar; editar la plantilla no altera el dato. Las sesiones
anteriores mantienen su clasificación ausente y siguen consultables. Selectores
completos con texto ampliado. Análisis limpio, 591 pruebas completas y 25
regresiones específicas correctas (una exclusiva web omitida); tres recorridos
de captura y 15 imágenes revisadas. Solo desarrollo: 133 migraciones coincidentes
y cuatro pruebas SQL con `ROLLBACK` correctas. No cambia Inicio/Mi plan, fotos,
código admin, paquetes, motores, negocio ni producción.
[Recorrido, criterio y evidencia](HISTORY_SESSION_TYPE_2026_10_08.md).

El único siguiente bloque UX recomendado es el pulido localizado de textos,
estados y accesos de app/admin, conservando aspecto y trabajo ya terminado.
Comparación configurable y recorrido autenticado global siguen pendientes.
MAIL-001 ya acredita recepción y recuperación web confirmadas por Javier;
iPhone/iOS espera a su entorno Mac. Keychain, eliminación de cuenta y acceso a
privacidad quedan registrados para preparar publicación. Vídeos, negocio y
motores siguen aparte. Los cierres anteriores conservan sus fechas y pruebas;
esta entrada sustituye sus recomendaciones de siguiente bloque ya realizadas.

**UI-015, 08/10/2026 · comparativas guardadas cerradas en desarrollo:**
«Marcas y resultados» permite elegir prueba y dos fechas, consultar cambio en
repeticiones/tiempo y conservar selección durante refresco, fallo o entrada de
otra evaluación. Tropa exige versión, columna, hito, unidad y dirección iguales;
FAS compara marcas de su catálogo versionado compatible, mostrando edades;
los controles de 2 km conservan RPE y se mantienen separados de evaluaciones.
Los resultados configurables siguen mostrando snapshot/puntos/intentos; faltan
unidad y protocolo históricos completos para compararlos. Tarjetas con estado
de expansión propio y selectores sin recortes con texto grande. Análisis limpio,
579 pruebas de raíz correctas (una exclusiva web omitida) y seis recorridos
de captura, con 19 imágenes revisadas. No modifica Inicio/Mi plan, fotografías,
admin, motores, negocio, paquetes compartidos, SQL ni producción. No cierra toda
Evolución ni la revisión autenticada. Detalle en
[MEASUREMENT_COMPARISON_2026_10_08.md](MEASUREMENT_COMPARISON_2026_10_08.md).
El único siguiente bloque UX recomendado es definir el dato histórico de tipo
deportivo antes de implementar su filtro: la ejecución actual no lo conserva;
no se infiere de una plantilla mutable ni se reclasifican sesiones antiguas sin
evidencia. Se explicará el cambio de contrato antes de aplicarlo. Comparativas
configurables pendientes. Correo/dispositivo real se comprobarán cuando Javier
pueda; vídeos, negocio y motores siguen aparte.

**UI-014, 08/10/2026 · detalle de programa admin cerrado en desarrollo:**
índice fijo de Contenido, Evaluación y Entrenamiento; los saltos conservan las
secciones y sus estados. Sesiones se sitúa junto a la preparación deportiva.
Baremo publicado se presenta como consulta; módulos y cobertura de fuerza
ofrecen reintento. Formularios y acciones admiten texto grande y pantalla estrecha;
las pruebas conservan estado propio al recargar y no comparten el almacenamiento
del scroll. No se presenta una prueba ya vinculada como una prueba inexistente.
Análisis admin limpio, 89 pruebas y seis recorridos de captura correctos
(95 en la ejecución final conjunta), con una captura optativa existente omitida.
24 imágenes de widgets actuales con datos ficticios y tema compartido.
Sin cambios en deportista, paquetes, SQL, permisos, motores, negocio o producción.
Se adelanta este tramo puntual del pulido mientras Javier no puede completar
la prueba del correo desde el móvil; Cuenta permanece abierta para su recorrido
real. No cierra el resto de formularios del pulido transversal ni acredita
revisión autenticada. Detalle en [REFRESH_ADMIN_2026_10_08.md](REFRESH_ADMIN_2026_10_08.md).
El único siguiente bloque UX recomendado sigue siendo Evolución: definir y
mostrar comparativas de mediciones compatibles y el filtro deportivo, sin
inferir protocolos ni tipo histórico de una plantilla actual. Antes de ampliar
sus contratos se explicará el criterio y el impacto; el correo real se comprobará
cuando Javier disponga del dispositivo. Vídeos, negocio y motores siguen aparte.

**UI-013, 08/10/2026 · Cuenta comprobada en desarrollo, recorrido real abierto:**
recuperación con sesión diferenciada por el SDK, pantallas persistentes de correo,
confirmación y contraseña actualizada, errores con campos conservados y reenvío
limitado. Auth autoriza el cambio; URL y marcador local no conceden derechos.
Respuestas tardías no restauran otra cuenta. Retornos web/móvil configurados
solo en desarrollo, conservando confirmación de correo, límites y MFA remotos.
Análisis limpio en ambas apps; 563 pruebas de raíz y 85 de admin correctas, con
una exclusiva web y una optativa de admin omitidas. Tres recorridos de captura,
21 imágenes de widgets actuales; web debug y APK debug compilados. Sin cambios
SQL, RLS, motores, negocio, Inicio/Mi plan o producción. No acredita auditoría
integral de seguridad del login. Pendientes: correo real, enlaces caducados o
reutilizados en servidor y recorrido de nuevo acceso en dispositivo físico;
iOS no compilado desde Windows. Detalle en
[REFRESH_ACCOUNT_2026_10_08.md](REFRESH_ACCOUNT_2026_10_08.md).
El único siguiente bloque UX recomendado es Evolución: filtro por tipo deportivo
y comparativas de mediciones compatibles. Antes de dar por cerrado el recorrido
de Cuenta hay que completar su comprobación real; no se presenta como validado.
Pulido transversal/admin y retirada de ejercicios personales permanecen después;
vídeos, negocio y motores mantienen sus trabajos aparte.

**UI-012, 08/10/2026 · Biblioteca y fotografías cerrado en desarrollo:**
corregida la pérdida de portadas web al regresar, conservando aspecto y
encuadres. Biblioteca ofrece vídeo bajo demanda/enlace externo y edición de
ejercicios personales privados con foto, borrador protegido, error persistente
y retorno conservando búsqueda. RPC de edición con autoría/validación en
servidor; instantáneas históricas preservadas. Análisis limpio en ambas apps,
544 pruebas de raíz y 85 de admin correctas (una exclusiva web y una optativa
de admin omitidas respectivamente), cinco recorridos de captura, doce imágenes
de widgets y dos del navegador. Prueba comparada de cinco retornos en Chromium:
proveedor anterior pierde la imagen, proveedor corregido la conserva.
Compilación web debug correcta; 132 migraciones coincidentes y tres baterías
SQL correctas con `ROLLBACK`, solo en desarrollo. No modifica producción,
motores, diseño de Inicio/Mi plan ni negocio Free/Pro.
Límites: recorrido autenticado/dispositivo pendiente; runner web automatizado
no arrancó, sustituido para las fotos por reproducción compilada y navegador
real. Sin borrado/archivado de ejercicios ni resolución de edición concurrente.
Detalle en [REFRESH_LIBRARY_2026_10_08.md](REFRESH_LIBRARY_2026_10_08.md).
Ese cierre dio paso a Cuenta, implementada después en UI-013 con los límites
indicados arriba. Comparativas de Evolución y pulido transversal/admin siguen
después; negocio y motores mantienen sus trabajos aparte.

**UI-011, 07/10/2026 · resultados e historial cerrado:** Marcas abre una consulta
por preparación; registrar vuelve a los formularios existentes y actualiza al
retornar. Historial con preparación, fechas y estado, páginas de 30 y reintento
sin perder datos. El refresco mantiene la profundidad consultada, también con
más de mil sesiones; cambiar cuenta renueva raíz y vistas de resultados.
`flutter analyze` limpio, 537 pruebas completas y nueve recorridos de captura
correctos, con 22 imágenes de widgets reales y datos ficticios. No acredita
consulta autenticada a Supabase ni dispositivo real. No cambia SQL, motores,
admin, paquetes compartidos, Inicio/Mi plan, portadas ni catálogo.
Alcance, imágenes y límites en [REFRESH_EVOLUTION_2026_10_07.md](REFRESH_EVOLUTION_2026_10_07.md).
Las comparativas nuevas y el filtro por tipo deportivo siguen pendientes: no
se deducen de plantillas actuales ni se mezclan protocolos/baremos.
Este cierre dio paso a Biblioteca, implementada después en UI-012 para consulta
de vídeo y edición de ejercicios propios, respetando autoría e historial.
Cuenta y pulido transversal/admin permanecen después; negocio Free/Pro y
motores se trabajan aparte, manteniendo UI-010.

**UI-010, 07/10/2026 · refresh separado del negocio:** la base sigue siendo la
restaurada en COM-003. Inicio/Mi plan ya están cerrados; no se reabre su diseño
ni el de las tarjetas, catálogo o preparaciones para introducir Free/Pro.
En esa delimitación se recomendó Evolución/Marcas: destino de
resultados, filtros e historial antiguo. Descubrimiento comercial y derechos
de cuenta se abordarán aparte. La delimitación inicial fue documental;
UI-011 implementa el siguiente tramo acotado, sin nueva prueba autenticada.

**COM-003, 07/10/2026 · reversión del último bloque:** se retira `308ae18` y se
recuperan código y pruebas de `82d74df`, conservando el historial de Git. No hay
selector Free/Pro, guardas de simulación ni ficha básica añadida por ese bloque;
la reorganización UI-009 permanece pendiente. No cambia admin, paquetes
compartidos, SQL, datos remotos o producción. El trabajo comercial se deja para
un chat aparte: cerrar capacidades, derechos de servidor y ciclo de pago antes
de adaptar las vistas de la app. No retomar la simulación descartada COM-002.
Validación de la restauración: `flutter analyze` limpio y las 505 pruebas
completas del estado anterior correctas; código y pruebas sin diferencias
respecto a `82d74df`. Compilación web debug correcta, sin despliegue.

**UI-008, 07/10/2026 · Inicio/Mi plan cerrado:** Mi plan presenta programa en
curso, semana y sesiones pendientes, con estados separados para preparaciones
por configurar, pausadas y finalizadas. Abre el programa directamente, conserva
el vínculo de la sesión al consultar/retomar y retira accesos duplicados a
Biblioteca. Inicio comparte estados/siguiente paso y conserva su calendario.
El resumen de Mi plan se carga al visitar la raíz, se actualiza al regresar y
se renueva al cambiar de cuenta, conservándolo al renovar la misma sesión.
Análisis limpio, 505 pruebas completas de raíz y ocho capturas verificadas;
20 imágenes de widgets actuales con datos simulados. Sin cambios en admin,
SQL, motores o producción; pendiente la revisión autenticada en dispositivo.
Detalle en [REFRESH_PLAN_2026_10_07.md](REFRESH_PLAN_2026_10_07.md).
Ese cierre dio paso a Evolución/Marcas, completado después en UI-011 con
resultados e historial consultable.

**UI-008, 07/10/2026 · guardado editorial cerrado:** pruebas, reglas, tramos,
mínimos, importación, clonación y vinculación de estrategia conservan los
formularios hasta persistir y permiten reintentar sin perder campos. Se mantienen
las confirmaciones y reglas actuales; cancelar una revisión devuelve al
formulario. Un fallo de recarga posterior no habilita un nuevo envío del mismo
guardado. Incluye mínimos a 320 × 480 con texto 2×. Análisis limpio en ambas
apps, 482 pruebas de raíz, 85 de admin (una optativa omitida) y seis de
`entrena_ui`. Sin SQL, motores o producción; falta revisión autenticada real.
Detalle en `REFRESH_STATUS_2026_10_07.md` y `VISUAL_DESIGN.md`. El único siguiente
tramo UX recomendado es Inicio/Mi plan orientado a programa, semana y pendientes;
el bloque deportivo conserva su prioridad y se gestiona fuera de este refresh.

**UI-008, 07/10/2026 · refresco cerrado:** Inicio, Perfil, Mi semana y Evolución
actualizan al regresar sin desmontar ramas ni perder selección/posición. Se
conserva la última consulta y se descartan respuestas antiguas en los Cubits
afectados. Análisis limpio y 482 pruebas completas de raíz; sin cambios en SQL,
motores o producción. No acredita el recorrido autenticado en dispositivo.
Comparación del informe anterior en `REFRESH_STATUS_2026_10_07.md`. El único
siguiente tramo UX es completar el guardado retenido editorial de admin, antes
de reorganizar Mi plan y Evolución. El bloque deportivo conserva su prioridad.

**Inventario visual, 07/10/2026:** [mapa de app/admin](SCREEN_MAP_2026_10_07.md)
con imágenes de widgets actuales, estados, recorridos y mejoras diferenciadas.
Análisis de ambas apps limpio; 474 pruebas de raíz y 74 del admin correctas
(una optativa omitida). No modifica SQL, motor ni producción; no cierra la
revisión autenticada. El siguiente tramo UX sigue siendo guardado retenido y
refresco entre secciones; el deportivo, controles de protocolo y prioridades
por déficit.

**UI-008, 06/10/2026 · primer tramo de fiabilidad y navegación:** admin pasa a
`go_router` con URLs por identificador, verificación de acceso y recursos,
reintentos y renovación de la pila al cambiar de cuenta. Las evaluaciones
oficiales y el editor admin protegen cambios pendientes. Referencias, creación
de programa y edición de ejercicios conservan el formulario hasta confirmar
guardado. El cierre del entrenamiento respeta el origen, permite abrir el
resultado concreto y admite notas largas/texto grande. Búsquedas del admin
conservadas al recargar; laboratorio separado de la edición habitual.

Comprobación: análisis de ambas apps sin incidencias, 474 pruebas de raíz,
74 del admin (una omitida por su condición existente), cinco de `entrena_ui`
y compilaciones web correctas. Pruebas con repositorios simulados; no acredita
el recorrido autenticado en dispositivo ni protege el cierre del navegador o
proceso. No cambia SQL, algoritmos, permisos ni producción. Este tramo queda
validado, no todo el refresh. Alcance y pendientes en `VISUAL_DESIGN.md`.

El único siguiente tramo **UX** recomendado es completar el guardado retenido
de los restantes formularios editoriales y el refresco entre secciones sin
perder estado, antes de reorganizar Mi plan y Evolución. El siguiente bloque
**deportivo** permanece sin cambios: controles de protocolo y prioridades por
déficit, gestionados fuera de este refresh.

**Consolidación, 06/10/2026:** se conserva el estado local confirmado por Javier
en el punto de recuperación `236f8b7`, sin importar versiones antiguas. Se
separan pendientes y borradores por usuario, con 17 regresiones nuevas y 470
pruebas completas de la app correctas. v1 permanece intacto: los pendientes se
recuperan mediante comprobación remota del propietario; los borradores sin
propietario requieren recuperación explícita, aún sin pantalla de importación.
`website/` conserva su repositorio independiente y una copia completa en un
bundle versionado. DEV-002 autoriza commit y subida de cada bloque validado;
procedimiento permanente en `AGENTS.md` y detalle en la auditoría. Análisis
final limpio y compilación web del deportista correcta.

**Chequeo general inicial, 06/10/2026:** app, admin, paquetes compartidos y Supabase de
desarrollo contrastados; informe e inventario en
[AUDIT_2026_10_06.md](AUDIT_2026_10_06.md). La auditoría comienza con 123 archivos
modificados y 346 sin seguimiento, entre ellos 81 migraciones aplicadas en
desarrollo. No se crea ningún commit ni se modifica producción.

Análisis limpio, 453 pruebas de raíz, 68 del admin y una omitida por condición
de capturas, seis de `workout_editor_ui` y dos de `entrena_ui`. Compilan las dos
webs y las APK Android debug/release de desarrollo; se corrigió el permiso de
red de release, que aún usa firma de depuración. Pasan las 55 baterías SQL tras corregir una
expectativa antigua del tamaño del catálogo. Windows carece de componentes
del toolchain e iOS no se compila desde este equipo.

El aislamiento y la consolidación recomendados por el chequeo inicial se
abordan en el cierre descrito arriba. Este chequeo no cierra el bloque
deportivo; continúa el único siguiente bloque deportivo de controles de
protocolo y prioridades por déficit. La recuperación explícita de borradores
v1 queda registrada como límite técnico, sin ampliar ahora el motor deportivo.

**STR-033/UI-007, 06/10/2026 · contexto y navegación de tareas:** Perfil y
«Mi programa» usan el contexto real por usuario del coordinador, con días y
minutos concretos y material seleccionable/retirable. Carrera integrada
reutiliza disponibilidad y ofrece una continuación visible. Configuración,
registro de marcas, creación de ejercicios, editores y ejecutor se abren sin
barra; las secciones de consulta conservan su estado. Salidas distinguen
descarte, borrador y sesión retomable. Migración `20261006001000` aplicada
solo en desarrollo; no se redefinen carrera v5 ni su adaptador.

Verificación del recorrido: pruebas de navegación y conservación de campos,
guardado/recuperación de borradores, salida sin abandonar ni perder series,
persistencia del mismo contexto Perfil/programa e aislamiento de cuentas en SQL.
Revisión de capturas de Flutter a 360 px y adaptación a 320 px con texto 2×,
y escritorio de 1000 px. Los formularios de evaluación oficial existentes y
el cierre del navegador/proceso no se reorganizan en este tramo. El siguiente
bloque deportivo recomendado sigue siendo controles de protocolo y prioridades
por déficit; esta corrección no amplía el alcance deportivo de STR-032.

Comprobación el 06/10/2026: 451 pruebas de raíz, 67 del admin (una omitida por
su condición existente) y seis del paquete `workout_editor_ui`; análisis de
ambas apps, compilación web y trece baterías SQL transaccionales sobre desarrollo
instalado. Historial de migraciones enlazado sin diferencias. No acredita el
recorrido autenticado en el dispositivo de Javier ni modifica producción.

**STR-029/031/032, 06/10/2026 · tramo v3 aplicado en desarrollo:**
flexiones, plancha y COD incorporan fase real por respuesta, previsión visible,
principal/apoyo calibrado y alternativas con/sin accesorios. Referencias libres
y temporales independientes; comprobación submáxima que sustituye trabajo;
calentamiento guiado omisible con neutralidad comprobada. La continuidad,
selección, pausa y recuperación conservan sus contratos. Carrera v5 y su
adaptador no se redefinen. Migración `20261006000000` aplicada solo en desarrollo.
Reglas, evidencia y límites: `docs/ESTRATEGIAS_RENDIMIENTO_V3.md`.

Verificación del tramo el 06/10/2026: análisis Flutter limpio, 437 pruebas de la
aplicación del deportista, compilación web y doce baterías SQL transaccionales
contra desarrollo instalado. Se comprueba la identidad de las funciones de
carrera v5 y su adaptador, además de sus regresiones y horizontes. Las capturas
de widgets contrastan las fases a 360 px; no acreditan una revisión autenticada
en el dispositivo de Javier. Las semanas guardadas mantienen su versión; la
selección nueva entra en las siguientes adaptaciones.

El único siguiente bloque recomendado es definir controles de protocolo que
actualicen marcas y prioridades por déficit con datos comparables, antes de
ampliar cuerda/reactividad. No se presenta el banco entero como activado ni una
simulación como eficacia en deportistas reales. Los horizontes no fijan la
duración de mesociclos obligatorios.

**STR-027, 04/10/2026 · selección, pausa y reanudación verificadas:** preparación
completa, solo carrera o solo rendimiento con preguntas y cobertura condicionales.
Un único generador por usuario, cambio aceptado y atómico, conservación del
historial y nueva pauta al retomar con calendario/contexto actuales. Inicio y
agenda distinguen preparación pausada de programa entrenando. Migración
`20261004012000` aplicada solo en desarrollo; análisis limpio, 375 pruebas Flutter,
compilación web y nueve baterías SQL sobre el esquema instalado con `ROLLBACK`.
Los tres modos ejecutan sesiones reales y continúan automáticamente desde sus
resultados; carrera conserva v5. Capturas de widgets a 390 px, sin acreditar
recorrido autenticado en el dispositivo del usuario. Detalle y límites:
`docs/PROGRAMA_ADAPTATIVO.md`. Este recorrido queda comprobado; el bloque
deportivo completo sigue abierto por controles específicos y metas de fuerza.
El único siguiente bloque recomendado continúa siendo el descrito más abajo.

**STR-024, 04/10/2026:** aplicación explícita de datos nuevos a semanas no
empezadas, conservación de semanas realizadas y reinicio administrativo de
ensayos desde desarrollo. Migración `20261004011000` aplicada; análisis limpio,
357 pruebas Flutter, compilación web y cuatro fixtures SQL con `ROLLBACK`.
Detalle y validación: `docs/PROGRAMA_ADAPTATIVO.md`.
No cierra los controles deportivos y metas de fuerza pendientes del bloque.

**STR-023, 04/10/2026:** reabierto el cierre de recorrido tras el vídeo del usuario.
Se corrigen el retorno al cuestionario desde una semana vacía, el cálculo expuesto
como tarea cotidiana y la ausencia de recuperación desde Inicio/agenda. El
programa activo tiene panel propio y continuidad única; las estrategias y el
coordinador existentes conservan sus reglas. La simulación usa un reloj aislado
y el recorrido real de publicación/ejecución, incluyendo adelantos y recuperación.
El detalle de verificación y los límites están en `PROGRAMA_ADAPTATIVO.md`.
Migración `20261004010000` aplicada solo en desarrollo; análisis limpio,
354 pruebas de app, compilación web y 21 baterías SQL distintas con `ROLLBACK`.
Revisión visual de widgets a 390 px. El bloque deportivo completo permanece
abierto por los controles y la aplicación de metas numéricas descritos debajo.

**Instantánea anterior, 04/10/2026 (STR-022):** se declaró cerrado el recorrido de programa y
continuidad automática en desarrollo: fecha/metas, disponibilidad común, paso de
carrera, referencias agrupadas, propuesta y activación; cierre de sesiones →
siguiente semana desde resultados, con revisión ante omisiones completas o
molestias. Control común de 2 km sin desvío a baremos. Revisión informativa de
fuerza por señales/fase, no por contador. Migraciones hasta `20261004009000`.
Análisis limpio, 352 pruebas Flutter, compilación web y 21 baterías SQL distintas
correctos. Revisión visual de widgets; falta recorrido autenticado en dispositivo.

**Tramo recomendado antes de STR-029, integrado en esa ampliación:** cerrar la política deportiva de controles
específicos y de priorización por meta, incluyendo protocolo, motivo, sustitución
de carga, recuperación, registro y efecto sobre decisiones posteriores. No está
implementado por el mero hecho de guardar metas o mostrar revisiones. No ampliar
cuerda/reactividad antes de cerrar ese contrato. Detalle:
`docs/PROGRAMA_ADAPTATIVO.md`. El motor completo de rendimiento sigue abierto.

**Instantánea anterior, 04/10/2026 (STR-021):** aplicado en desarrollo el selector v2
y coordinador v2.1. Referencias explícitas, dosis submáximas, feedback pertinente,
componentes COD, formatos cortos y cobertura. Sesiones mixtas con preparación
compartida y resultados de carrera separados; revisión y continuidad semanal.
Dieciocho baterías SQL verifican recorrido y fronteras con `ROLLBACK`.
Análisis limpio en ambas apps; 348 pruebas de la app y 58 de ADMIN correctas,
compilación web completada y migraciones de desarrollo hasta `20261004006000`.
Detalle vigente: `docs/MOTOR_FUERZA_RENDIMIENTO_V2.md`. Las instantáneas v1 que
siguen describen entregas anteriores, no el selector aplicado hoy.

**Tramo recomendado entonces, sustituido por STR-022:** revisar con Javier las salidas guardadas
y el recorrido autenticado recompilado, contrastando dosis/respuesta antes de
ampliar programación autónoma de cuerda/reactividad. No falta enlazar un selector
local: la aplicación consulta el servidor v2.1. La revisión visual actual abarca
widgets reales, no una prueba autenticada completa en su dispositivo.

**Banco V2 recibido (04/10/2026, STR-020):** revisión y correspondencias completas
con las propuestas anteriores en `docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`.
Se recomienda un banco normalizado de estímulos y recetas reutilizables, sin
duplicar versiones ni activar sus cifras como políticas aprobadas. Persisten
entradas ambiguas, reglas de progresión por concretar y familias ausentes en
los textos nuevos. La V2 no sustituye aún `performance_v1_1`. Se mantiene el
único siguiente tramo de STR-019, con carrera v5 conservando sus reglas.

**Revisión de sesión y programación deportiva (04/10/2026, STR-019):** el vídeo
de Javier confirma que la integración técnica no cierra la dosificación ni
la selección de estímulos previstas. El servidor v1 sigue copiando la dosis
declarada; circuito por componentes y evolución del banco siguen pendientes.
Corregidos campos impropios del circuito fijo, lenguaje e instrucciones de
trabajo, acceso a preparar la semana elegida y continuidad explícita semanal.
El calentamiento nuevo tiene una guía derivada de los patrones del trabajo,
con instantánea histórica inmutable; siete minutos siguen siendo una reserva
aproximada. Migración `20261004002000` aplicada solo en desarrollo.

Conservados los dos textos aportados y revisadas sus 40 fichas, composición,
entradas, porcentajes, compatibilidad y límites de evidencia en
`docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`. No se han activado sus dosis
ni cambiado carrera v5. Verificación técnica: análisis de ambas apps, 344 pruebas
de raíz, 58 de ADMIN y doce baterías SQL transaccionales correctas. La revisión
del vídeo y esas pruebas no acreditan eficacia deportiva ni recorrido manual
de la versión corregida en el dispositivo de Javier.
**Único siguiente tramo:** cerrar el banco parametrizable y las entradas de
capacidad/dosis, y sustituir el selector deportivo de servidor con las regresiones
de fuerza/carrera pertinentes. Este bloque permanece abierto.

**Corrección de usabilidad e integración (04/10/2026, STR-018):** el vídeo de
Javier detectó que una propuesta con sesiones rompía la pantalla al formatear
el día en español. Corregido junto al descanso obligatorio con un solo intento,
las instrucciones de plancha, los detalles de preparación y el acceso duplicado
a carrera. El flujo común admite solo carrera y revisión explícita de la última
semana publicada aún sin empezar, conservando decisiones y cancelando solo sus
pendientes al sustituirla. Migraciones `20261004000000`/`20261004001000` en
desarrollo; análisis y pruebas completas de raíz, regresiones móviles y diez
baterías SQL con `ROLLBACK` correctos. Carrera v5 conserva sus reglas.
Siguiente paso del mismo piloto: comprobar estos recorridos con la sesión real
de Javier. No se acredita todavía esa comprobación desde su dispositivo.

## Fuerza y rendimiento: contrato, catálogo y persistencia (03/10/2026)

Javier confirma empezar por el contrato deportivo y el catálogo antes de
implementar progresión y fatiga. Sus pautas completas siguen siendo el alcance
del bloque: flexiones, dominadas, fuerza con carga, isométricos, cuerda,
saltos/reactividad, COD/agilidad y circuitos. La entrega inicial contiene un
contrato documentado y 63 variantes editoriales en JSON, con dominio puro y
codec en `workout_core` y pruebas de las doce combinaciones de aceptación.

**Tramo comprobado el 03/10/2026:** persistencia aplicada en **entrenaop-dev**,
con 63 perfiles versionados y las 63 variantes como ejercicios públicos de
EntrenaOP. La corrección de Javier ha llevado a materializar las 60 entradas
que quedaron pendientes; la biblioteca debe estar disponible en la app y ser
independiente de cualquier prueba oficial. Los dos enlaces revisados del
borrador CNP son adaptadores opcionales de evaluación. Ambas apps leen los
perfiles desde datos sin dependencias de Supabase en dominio. La plancha de
ensayo queda definida sobre antebrazos. Análisis limpio de ambas apps,
255 pruebas en raíz y 36 en ADMIN junto al contrato compartido; historial de
migraciones contrastado. Pruebas SQL de perfiles, biblioteca, seguridad de
ejercicios, módulos y publicación correctas con `ROLLBACK`. La regresión del
selector carga las 63 variantes y permite buscar/añadir una dominada desde
EntrenaOP. El ejecutor conserva su capacidad actual: falta
ampliar prescripción/resultados, no hay reglas adaptativas de fuerza ni cierre
del bloque funcional. El catálogo mantiene clasificación editorial provisional.

**Avance experimental posterior (STR-007, 03/10/2026):** primera estrategia de
flexiones en dominio puro y laboratorio ADMIN, con lectura del catálogo real,
selección específica/apoyo calibrado, agenda reservada y respuesta simulada.
Las constantes de dosis quedan pendientes de revisión deportiva. El ejecutor
ya distingue esfuerzo prescrito y declarado: RIR/RPE reales permanecen nulos
si no se informan. Análisis limpio en ambas apps; raíz completa, 278 pruebas;
ADMIN y contratos compartidos, 56 pruebas, correctas; compilación web de ADMIN
correcta. Sin cambios SQL ni
publicación automática. Detalle y límites en
[`ESTRATEGIA_FLEXIONES_V1.md`](ESTRATEGIA_FLEXIONES_V1.md).

**Base ejecutable posterior (STR-010, 03/10/2026):** contrato común de objetivos,
pendientes y propuestas en dominio puro, con bloques pertinentes y cobertura
incompleta visible. Comprueba representación de las 63 variantes sin declarar
políticas adaptativas disponibles. El adaptador de flexiones conserva dosis,
versión y estado experimental; ADMIN lo consume. Raíz completa, 292 pruebas,
y ADMIN con contratos compartidos, 73 pruebas, correctas. No hay cambios del
motor/recorrido de carrera ni SQL. No se ha cerrado el bloque de coordinación.

**Criterio deportivo previo (STR-011, 03/10/2026):** Javier solicita explicar y
consensuar progresión y evolución temporal por modelo antes de ampliar dosis.
La [propuesta deportiva](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md) conserva
el alcance completo y los seis horizontes, separando evidencia de parámetros
por revisar. Esta entrega es documental; no modifica carrera ni el laboratorio.

**Avance ejecutable (STR-012, 03/10/2026):** Javier respalda el planteamiento
general. Dominio compartido para repeticiones, carga/repeticiones y segundos
isométricos, con dosis calibradas y respuesta comparable; laboratorio ADMIN
por bloques con ejemplos de flexiones, dominadas, plancha, suspensión y banca.
Los objetivos sin dosificación conservan su estado pendiente. Las constantes
siguen siendo experimentales; no publica sesiones, coordina carrera ni
implementa aún los seis horizontes en fuerza. La investigación incorpora
fuentes militares y CrossFit, sin extrapolar sus protocolos automáticamente.

Verificación de STR-012: análisis limpio en raíz y ADMIN; 312 pruebas completas
en raíz y 98 en ADMIN junto con contratos compartidos, correctas. Incluye
regresiones de progresión, protocolo/montaje, ausencia de datos, retorno entre
bloques y pantalla de 360 px. Se comprueba la compilación web de ADMIN; no se
han modificado SQL, entorno o sesiones del deportista. El bloque global de
planificación conjunta permanece abierto.

**Revisión aplicada (STR-013, 03/10/2026):** Javier revisa el laboratorio y
descarta el campo de series separadas por espacios. ADMIN ahora permite
editar cada serie con su unidad, añadir y quitar filas, conservando valores
al volver. Análisis limpio, compilación web y 41 pruebas completas de ADMIN correctas, con
regresiones de edición/eliminación y pantalla estrecha; renderizado revisado.
Las reglas de progresión y carrera conservan su comportamiento.

**Captura ejecutable (STR-016, 03/10/2026):** el laboratorio permite registrar
resultados ficticios de cada serie, editar/cancelar y conservar la dosis
original. Retira el selector de respuestas prefabricadas y mantiene los
ejemplos explícitos. Dominio experimental v2: condiciones declaradas y carga
real compatible antes de atribuir mejora/dificultad a la dosis pautada. No
hay cambios SQL, publicación o evolución temporal nueva; carrera conserva
su comportamiento.

Comprobación de STR-016: análisis limpio en ambas apps, 315 pruebas completas
de raíz y 52 de ADMIN correctas, compilación web y renderizado del registro revisado. Los
resultados del ensayo siguen siendo ficticios y locales.

**Actualización STR-017 · cierre técnico del recorrido integrado (03/10/2026):**
los tramos experimentales anteriores quedan superados para publicación por
`performance_v1_1` en servidor. Contexto real → referencias por prueba → semana
coordinada → agenda → ejecución → historial → adaptación están implementados
en desarrollo. ADMIN configura estrategias; FAS/Tropa identifican sus pruebas;
64 variantes tienen perfil público (63 v1 y el circuito específico v2).

Verificación: migraciones hasta `20261003016000`, 328 pruebas de raíz, 54 de
ADMIN, análisis de ambas apps y compilaciones web. SQL transaccional: contrato,
catálogo/modelos, seis horizontes, respuesta de calidad, seguridad bajo rol real,
deduplicación e integración, junto a regresiones de carrera. El cuestionario y
la política v5 de carrera permanecen; su adaptador admite tiempo/carga conjuntos.
No se ha realizado una revisión manual autenticada en navegador ni en dispositivo.

**Límites:** dosis operativas pendientes de validación con deportistas; práctica
completa de protocolos no sustituible por apoyos; cámara aparte. Se publica una
preparación respetando agenda global; aún no hay optimización conjunta de todos
los programas activos ni prioridad basada en déficit de baremos.

**Único siguiente bloque recomendado:** piloto deportivo y de usabilidad del
recorrido ya integrado, sin abrir otro laboratorio de dosis desconectado.
Contrato y reglas exactas en
[`MOTOR_FUERZA_RENDIMIENTO_V1.md`](MOTOR_FUERZA_RENDIMIENTO_V1.md).

## Carrera 2 km: cierre técnico del bloque el 01/10/2026

Motor `running_2k_v5` aplicado en **entrenaop-dev**. FAS, Tropa y programas
con prueba vinculada al módulo 2 km usan un único planificador de servidor,
con sus propias marcas y baremos. Reutiliza agenda y ejecutor; no hay IA de
pago ni selector deportivo en Flutter. Incluye objetivos libre/tiempo/margen,
lectura de registros incompletos, contraste del RPE y vuelta gradual tras fatiga.
V3 corrigió encaje de calidad y repetición del foco; v4 añade dosis repartida
al pasar a dos calidades; v5 permite progresar minutos fáciles al mantenerlas.
Recomendaciones de disponibilidad sin modificar la elección.

Verificados 1.573 semanas sintéticas, publicación → ejecutor → adaptación y
reinicio → nueva publicación en SQL transaccional, además de análisis Flutter,
batería completa de la app y compilación web. La experiencia de series anterior
puede declararse sin hacerse pasar por ejecución verificada; el RPE persistente
se aclara sin reducir minutos automáticamente. Existe reinicio voluntario por
preparación, con doble confirmación, y las sesiones completadas abren su
resultado. Límites y evidencia en [`MOTOR_CARRERA_2K_V5.md`](MOTOR_CARRERA_2K_V5.md).

**Alcance cerrado:** recorrido técnico de carrera 2 km en desarrollo. No se ha
probado la eficacia fisiológica ni se ha realizado aún el recorrido visual con
la cuenta autenticada tras la última compilación. Javier supervisará marca,
contexto, propuesta, publicación, sesión completada y reinicio en la app. El
visor histórico compara 13 perfiles; el comparador controlado de 2/3/4/5 días
queda fuera del bloque. Producción no modificada.

**Único siguiente bloque recomendado:** coordinación de carrera con fuerza y
otras pruebas dentro de la misma semana. Abrirlo después de la supervisión
visual. Esta revisión del 01/10/2026 cubre el código del motor 2 km, las
migraciones de desarrollo, sus tests transaccionales, widgets y compilación; no
certifica los bloques ajenos ni sustituye la instantánea general anterior.

Este roadmap expresa prioridades, no fechas cerradas. La instantánea histórica
anterior se había contrastado con código, las 48 migraciones locales y remotas de desarrollo, las
pruebas Flutter y las pruebas SQL transaccionales el 24 de septiembre de 2026,
tras el cierre de Carrera V1 mínima, la autoría oficial inicial y la calculadora
FAS 2027. Esa instantánea precede al piloto de carrera FAS de 30 de
septiembre: ya publica semanas de carrera en desarrollo y lee ejecuciones para
la siguiente decisión. El bloque funcional completo sigue abierto: faltan
fuerza, coordinación entre módulos y comprobación visual de extremo a extremo.

## Estado del ciclo principal (actualizado el 06/10/2026)

El ciclo objetivo continúa siendo:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

| Tramo | Estado | Evidencia y límite actual |
| --- | --- | --- |
| Acceso y contexto inicial | Terminado | Autenticación restaurable, varias preparaciones, evaluación inicial e historial de Tropa y Marinería, y preferencias de disponibilidad, experiencia y material. |
| Biblioteca y sesiones personales | Terminado para fuerza V1 | Biblioteca pública, sesiones privadas, ejercicios propios, descripción y vídeo HTTPS, duplicado, archivado, borradores locales y revisiones versionadas. |
| Agenda semanal manual | Terminada | Reúne biblioteca y sesiones personales; permite programar, reprogramar, retirar, iniciar y continuar. Inicio resume los siete días y abre la fecha seleccionada. Conserva nombre, versión y duración como instantánea. |
| Contexto por preparación | Terminado | Permite entrar en una preparación activa, ver objetivo, marcas vinculadas expresamente a ella y sesiones oficiales vinculadas. El deportista solo consulta y ejecuta: no puede crear, vincular, mover ni retirar sesiones del plan oficial. |
| Creador de fuerza por bloques | Terminado en V1 | Series variables, superseries A1/A2, circuitos con transiciones, intervalos de trabajo, Tabata 8 × 20/10, EMOM y AMRAP, con vista previa coherente. |
| Sesión guiada e historial | Terminado para los formatos V1 | Objetivo y resultado real, omisión, abandono, RPE final, notas, vídeos, temporizadores restaurables, avisos configurables, cola idempotente e historial con correcciones auditadas. |
| Funcionamiento sin conexión | Parcial; defecto de cambio de cuenta | Encola completar/omitir serie, AMRAP, finalizar y abandonar una ejecución cargada. Cola y borradores nuevos aún carecen de aislamiento por cuenta. No replica catálogo o agenda y las correcciones exigen conexión. |
| Evaluación y progreso | Parcial | Registra, evalúa y compara marcas con el catálogo versionado de ingreso a Tropa y Marinería, calcula evolución y recomienda focos. La evaluación periódica FAS 2027 tiene registro e historial propios y calculadora gratuita separada. No hay panel longitudinal completo ni simulacro. |
| Plan semanal adaptativo | Carrera v5 y rendimiento v3 en desarrollo | Coordinador común, referencias, contexto, alcance y un generador activo por usuario. Persisten los límites deportivos de STR-032. |
| Adaptación posterior | Continuidad automática en desarrollo | Resultados versionados, publicación al resolver las sesiones, recuperación, pausa/reanudación y revisión cuando corresponde; no exige publicar manualmente cada semana. |
| Carrera especializada | Terminada en V1 manual | Creador de carrera continua, series y pirámides; repeticiones agrupadas al prescribir, registro individual obligatorio de parciales y recuperaciones, ritmo calculado, RPE, FC opcional, clasificación de cumplimiento e historial. No incluye GPS, mapas, zonas ni integraciones. |
| Seguimiento profesional | No existe | No hay relación entrenador-cliente, asignación, anulación manual, panel profesional ni chat. |
| Derechos y monetización | Accesos y cuotas Dev; Test Store conectado al servidor | COM-008 verifica derechos temporales, cuotas Free 8/4 y gestión manual. COM-013 añade SDK Test Store y COM-014 despliega Dev y verifica receipt, webhook y Pro canónico con compra simulada. Aceptación móvil completa y sandboxes reales siguen pendientes. |

## Base completada

### Estabilización y seguridad

- Entornos de Supabase separados por configuración.
- Línea base SQL reproducible, saneamiento de acceso, RLS, constraints e
  índices.
- Restauración y observación de autenticación, navegación centralizada y
  pruebas base.
- Arquitectura modular aplicada sin imponer capas que no aporten valor.

### Dominio de evaluación y contexto

- Catálogo versionado de ingreso a Tropa y Marinería 2026 y evaluación de sus
  cuatro pruebas.
- Historial de evaluaciones, progreso y recomendación explicable del foco.
- Preferencias de entrenamiento y bloqueo cuando se solicita revisión
  profesional.
- Múltiples preparaciones activas, sin duplicar un mismo programa activo.
- Detalle de preparación que compone fecha objetivo, última evaluación
  compatible y agenda semanal relacionada, sin generar aún decisiones
  deportivas. El vínculo queda reservado al futuro algoritmo o a un servicio
  administrativo de confianza.

### Vertical manual de entrenamiento

- Plantillas jerárquicas y ejecuciones con instantáneas inmutables de la
  prescripción, el formato y el contenido explicativo usado.
- Biblioteca pública, sesiones personales y agenda semanal común.
- Creador privado y transaccional con múltiples bloques y objetivos por serie.
- Series convencionales, superseries, circuitos, intervalos, Tabata, EMOM y
  AMRAP; posiciones repetibles y transiciones de circuito.
- Ejercicios privados, búsqueda por catálogo, descripción y vídeo HTTPS.
- Borradores locales por sesión, duplicado, archivado y familias de revisiones.
- Vista previa, sesión guiada, temporizadores persistentes, avisos sonoros y
  hápticos, resultados, omisiones, abandono, notas y esfuerzo final.
- Cola local de mutaciones con recibos idempotentes, historial y correcciones
  auditadas limitadas por tiempo y número.
- Carrera personal mediante un formato distinto de los intervalos de fuerza,
  con borrador local, revisión versionada, tramos ordenados, ritmo y
  recuperación propia; usa la biblioteca, agenda, ejecución e historial
  comunes.

## Prioridades históricas del piloto inicial

Esta sección conserva el contexto anterior al programa integrado. El estado
y el único siguiente bloque vigentes son los indicados al comienzo del documento.

El control independiente de carrera de 2 km ya dispone de registro repetible,
fechado y vinculado a una preparación, con RPE obligatorio, FC y parciales de
400 m opcionales. Su protocolo de calentamiento y su cadencia de repetición
siguen pendientes de validación deportiva; ninguna semana se recalcula aún
automáticamente a partir de estas marcas.

La batería de evaluación acordada para Carrera incluye VAM, 2.000 m y Cooper.
Solo el control de 2.000 m está implementado. Antes de incorporar las otras dos
pruebas deben cerrarse el protocolo de VAM y las reglas que deciden cuándo usar
VAM o Cooper; no se crearán equivalencias implícitas entre sus resultados.

El contrato y la primera decisión determinista de carrera se documentan en
`docs/ALGORITMO_CARRERA_V1.md` y `docs/RECORRIDO_CARRERA_2K.md`. El piloto FAS
ya recoge días concretos y carga reciente, publica sesiones de carrera en
agenda y usa sus ejecuciones al calcular la semana siguiente. La coordinación
con fuerza y otras preparaciones sigue pendiente.

El **piloto de evaluación periódica militar separado del ingreso a Tropa y
Marinería** ya permite la primera semana de carrera FAS en desarrollo. Javier
conoce mejor las pruebas que denomina PAFAS/PAEF y prefiere validar ahí el
contenido deportivo. No se cambiará el identificador ni el catálogo del
programa de ingreso existente: tiene marcas y preparaciones históricas. La
Orden DEF/15/2026 comparte tipos de prueba entre ingreso y evaluación
periódica, pero diferencia sus baremos; los nuevos baremos periódicos entran
en vigor el 1 de enero de 2027. Ya existe el programa estable
`fas_periodic_assessment` **habilitado en desarrollo** y un catálogo local
versionado con la tabla íntegra de 0–100 puntos por prueba, columna H/M y edad
del anexo II. La calculadora gratuita está visible en Inicio, no requiere una
preparación activa y calcula en directo al escribir o mover sus deslizadores.
Solo guarda un test cuando el usuario lo confirma. Muestra cada puntuación y el
mínimo general de 20 puntos, sin presentar la suma como resultado normativo ni
certificar aptitud oficial. Sí ofrece una suma matemática visible, rotulada como
orientativa y separada del criterio normativo. El resumen precede a una
cuadrícula compacta de pruebas para reunir total, marcas, puntos y controles en
el primer vistazo. Cada registro pertenece al
perfil del usuario y puede enlazarse opcionalmente a una preparación, sin que
esta sea su dueña. Su historial periódico sigue siendo independiente de Tropa
y valida las marcas en PostgreSQL. Antes del 1 de
enero de 2027 se muestra como referencia futura. La calculadora aislada no
prescribe; una marca elegida dentro de Mejora FAS sí puede iniciar el piloto.

Queda por completar en este bloque:

1. Completados el contrato separado de registro, los mínimos por edad/sexo,
   el historial y la validación de propiedad en PostgreSQL. Completados también
   la tabla íntegra de 0–100 puntos y su cálculo local auditable. El BOE no
   define una suma total y contiene una secuencia anómala no corregida en II.3;
   se conserva literalmente y se mantiene como limitación conocida.
   La fecha de nacimiento se recoge en el perfil; la edad se calcula para
   cada intento y el servidor comprueba que coincide. El circuito deja de
   exigirse al cumplir 45 años.
2. **Calculadora gratuita de puntos completada** para la evaluación periódica
   FAS 2027: usa la fecha de nacimiento del perfil, permite elegir explícitamente
   H/M, acepta entradas móviles de repeticiones y tiempos, muestra puntos por
   prueba, versión y fuente, permite guardar con fecha en un historial personal
   independiente y mantiene las simulaciones fuera de ese historial. Próxima
   ampliación: selección de otros programas/convocatorias cuando dispongan de
   catálogos completos igualmente verificables. La conversión a Premium no
   ocultará el cálculo gratuito ni lo confundirá con una certificación oficial.
3. Curar un catálogo **mínimo** de ejercicios oficiales de fuerza aptos para
   las primeras plantillas: técnica, objetivo, material, variantes y
   limitaciones. La carga de fotos y una biblioteca amplia no bloquean el
   piloto; tampoco se debe inventar una progresión de fuerza a partir de solo
   flexiones, sentadillas y plancha. El creador administrativo y el creador
   privado ya comparten contrato, validación y formulario.
4. Componer y revisar con Javier una semana de plantillas ejecutables de
   carrera y fuerza, registrables con los flujos existentes. Mantenerla como
   borrador hasta validar su contenido.
5. Auditar visualmente el recorrido completo de la propuesta FAS ya publicada:
   entrada, semana visible, ejecución y siguiente decisión. Revisar dosis y
   límites deportivos antes de extenderlo a otros programas.

El trabajo existente de carrera de Tropa es un prototipo específico de ese
programa: sus reglas y el borrador de `assets/programs/tropa/` no pasan
automáticamente al nuevo piloto. Se reutilizarán contratos y componentes
compatibles, no baremos ni prescripciones sin revisión.

CNP 2026 permanece como borrador administrativo hasta la revisión y publicación
explícitas. Contiene los tres ejercicios del anexo II de BOE-A-2026-15055,
variantes H/M, tablas de puntos y la repetición de agilidad solo tras nulo. El
editor ya permite crear y revisar baremos de cualquier programa, pegar tablas,
validar cobertura y publicar. ADMIN puede copiar un programa publicado a un
borrador con versión nueva. El deportista puede introducir intentos y guardar
el resultado dentro de su preparación publicada. El siguiente enlace pendiente
es utilizar esta evaluación genérica como entrada del algoritmo semanal y
decidir cómo se incorpora una edición nueva a preparaciones activas.

La **primera planificación semanal adaptativa** ya tiene un piloto de carrera
FAS. Su cierre completo debe abarcar un único tramo del ciclo:

1. Definir una prescripción mínima con entradas explícitas: preparaciones
   activas, evaluación vigente, disponibilidad, material e historial necesario;
   y separar el contenido deportivo versionado de las decisiones por usuario.
2. Versionar las reglas y guardar para cada propuesta entradas, salida y razones.
3. Generar una semana privada con origen `algorithm` y colocarla en
   `scheduled_workouts` sin modificar plantillas ni ejecuciones históricas.
4. Mostrar al usuario por qué se pauta cada sesión y permitir ejecutarla o
   registrar su resultado; cualquier sustitución futura deberá decidirla el
   algoritmo o un servicio autorizado bajo reglas versionadas.
5. Cubrir dominio, persistencia, permisos y una prueba vertical desde contexto
   válido hasta semana visible en agenda.

Se recomienda este orden porque el producto ya puede crear, programar,
ejecutar y auditar sesiones, y ya conecta cada preparación con sus marcas y su
agenda. El piloto FAS ya convierte ese contexto en sesiones de carrera;
necesita contenido de fuerza revisable para la planificación conjunta.
Una biblioteca completa o nuevos formatos no son condición previa.

La adaptación de la siguiente semana también existe en el piloto FAS; faltan
validación deportiva, revisión visual del recorrido, fuerza y extensibilidad
antes de declarar cerrado el bloque.

El panel administrativo ya tiene una aplicación web separada. Distingue
biblioteca general y plantillas de cada programa; permite crear, buscar
ejercicios, revisar, editar borradores, versionar y retirar sesiones. Solo las
sesiones generales publicadas aparecen en la biblioteca abierta; publicar una
plantilla de programa la deja disponible para las futuras reglas de esa
preparación, sin asignarla aún. Comparte modelo y validación con la app mediante
`workout_core`, pero no reutiliza sus pantallas. Todavía no define mesociclos
ni reglas deportivas. No es un requisito previo para esta primera vertical.
Las reglas y sesiones que alimente el futuro algoritmo deben seguir revisándose
como datos versionados en Git y Supabase. Publicar una sesión en la biblioteca
general no la convierte todavía en parte de un mesociclo ni la asigna a nadie.

## Después, no en paralelo

Una vez validada la primera semana adaptativa, el orden natural será:

1. Interpretar cumplimiento, RPE/RIR, molestias, omisiones y abandono para
   adaptar la semana siguiente con reglas auditables y anulación profesional.
2. Completar evolución longitudinal, simulacros y comparación con baremos.
3. Incorporar relación entrenador-cliente, panel profesional y asignaciones.
4. Consolidar derechos comerciales y monetización antes de integraciones o
   expansión a otras oposiciones.

## Fuera del camino crítico del MVP

- **Directorio profesional · TRN-040 · acordado el 28/10/2026, pendiente:**
  primero directorio voluntario de entrenadores en la web, con ficha, foto,
  descripción, especialidades y contacto externo; prever acceso a la búsqueda
  desde «Mi preparador», con integración móvil concreta aún por diseñar.
  Después ampliar a centros, sin anticipar gestión de organizaciones/equipos.
  Se mantiene el máximo de dos preparadores externos activos por alumno;
  descubrir/contactar no crea un vínculo ni utiliza el chat de la app.
  **Propuestas confirmadas:** presentación libre con campos comunes y servicios,
  disponibilidad/pausa, enlace propio, contacto voluntario por correo profesional,
  web o WhatsApp, vínculos actuales prioritarios con «Buscar preparador» y piloto
  con pocos profesionales activos. Informar del límite antes de aceptar un
  tercero, sin sustituciones automáticas. Diseño y criterios de revisión pendientes.
  No es el siguiente bloque ni modifica las prioridades comerciales actuales.
  [Acuerdos futuros y cuestiones abiertas](TRAINER_PLATFORM.md#directorio-profesional-futuro--trn-040--28102026).
- Resolver todas las oposiciones a la vez.
- Chat, nutrición, desafíos o red social.
- Las integraciones no condicionan el cierre del ciclo adaptativo. INT-001
  autoriza desde el 21/10/2026 su definición común y acceso a proveedores para
  carrera, aislados del desarrollo profesional activo; implementación y envío
  conservan sus fases y condiciones. Strava permanece fuera del primer alcance.
- Algoritmos opacos o aprendizaje automático antes de validar reglas
  deterministas.
- Academias y multi-tenancy sin un caso profesional validado.
- Arquitectura preventiva para funcionalidades todavía indefinidas.

## Regla de ejecución

Cada bloque debe entregar un recorrido utilizable y probado. No se abrirán
varias áreas grandes a la vez ni se considerará terminada una funcionalidad
porque existan sus capas si el usuario todavía no puede completar el caso de
uso.
