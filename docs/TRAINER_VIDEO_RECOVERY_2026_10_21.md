# Recuperación de demostraciones y técnica · 21/10/2026

El cliente web `cross_file` 0.3.5+5 puede conocer el tamaño desde el selector y
necesita después un XHR GET de su URL `blob:` para leer los bytes. Ambos portales
omitían `blob:` en `connect-src`; se añade exclusivamente a esa directiva.
`script-src` no admite blob ni unsafe-eval; destinos externos, MFA y permisos de
medios se conservan. Una regresión de configuración comprueba los dos portales.
El campo común identifica lectura/reserva/transferencia y el transporte usa solo
categorías cerradas de error: nunca copia mensajes de red con firmas o URLs.

La confirmación de creación RPC void/204 ya no se interpreta como JSON fallido.
La subida usa título técnico y MIME en TUS; no transmite el nombre local del
archivo. Los errores de inicio/fragmento y destino incompatible se muestran sin
copiar respuestas privadas del proveedor ni URLs firmadas.

Una consulta antigua podía dejar en SQL `processing` una reserva cuyo vídeo en
Bunny seguía en estado REST `Created (0)`, todavía sin archivo. La guarda SQL
monotónica se conserva: no se rebaja a `uploading`, se libera cuota ni se modifica
una migración aplicada. Consultar Created devuelve estado de transferencia al
cliente sin actualizar esa fila. «Revisar reserva y continuar» permite pedir al
servidor que vuelva a comprobarla.

Antes de renovar credenciales de una reserva `uploading` o `processing`, el servidor consulta
Bunny y verifica vídeo, biblioteca y entorno. Solo `status === 0` permite subir
el original al mismo vídeo; los estados REST 1..8 no entregan credenciales.
Se conservan la autorización por propietario/MFA/acceso profesional, el tamaño
original, el UUID, el presupuesto y el contenido anterior. No se permite
sobrescribir un vídeo recibido, listo o terminal ni crear otra reserva al revisar.

Referencia primaria: [enum REST del SDK oficial](https://github.com/BunnyWay/bunny-stream-android/blob/main/bunny-stream-api/src/main/java/net/bunny/api/model/VideoModelStatus.kt).
Su numeración es distinta de los eventos de webhook: no usar el estado Queued
del [webhook](https://bunny.net/docs/stream/webhooks) para interpretar REST.

Verificación focal: 32 pruebas HTTP del servicio, incluidos vacío204, aislamiento,
entorno incorrecto, origen/cupo, recuperación Created sin escritura SQL y rechazo
de credenciales tras recibir el archivo. Quince pruebas Trainer de medios y
transporte pasan; análisis de las dos fuentes UI/test sin incidencias. Las
validaciones completas anteriores de esta entrega no se repiten por este ajuste.

Las revisiones automáticas de «Descartar esta subida» interpretaron una purga;
el código comprobado solo limpia `_pending` local y avisa al formulario, sin RPC
ni borrado/liberación del activo. El cierre posterior se autorizó con esa evidencia.
Se mantienen intactas las reservas remotas.

La release 14 acredita en Chrome la transferencia y reproducción completa del
MP4 original (5,733333 s), con la misma reserva y cupo 3/100 conservado. El
creador abre el vídeo preparado sin subir otra copia. Las pruebas simuladas
se mantienen separadas de esa aceptación, y la técnica física del alumno sigue
pendiente. [Evidencia](TRAINER_STUDENT_RELEASE_2026_10_21.md). No se amplían límites comerciales,
se habilitan cobros, se relaja MFA ni se toca producción.

El reproductor compartido limita el vídeo a 360 px de alto, mantiene su proporción
y deja los controles próximos al clip vertical. Siete pruebas verifican vistas de
390/1600 px, reproducción bajo demanda, búsqueda y selección del instante; el
análisis focal pasa. La misma mejora llega a ADMIN y al deportista mediante el
paquete compartido.
