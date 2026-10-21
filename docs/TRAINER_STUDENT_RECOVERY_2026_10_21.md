# Continuidad de Trainer y seguimiento del alumno · TRN-022

## Alcance contrastado

El preparador retoma sesiones de biblioteca y sus nuevas versiones desde trabajos
privados. El mismo editor, snapshot y proyección de ADMIN conservan textos
incompletos y ramas ocultas; el adaptador profesional mantiene identidad, MFA,
revisión esperada, cuotas y recibos. Finalizar crea una versión asignable una sola
vez. No conecta todavía recuperación de hijos de programa o adaptación de pautas.
[Contrato](TRAINER_SESSION_WORK_DRAFTS.md).

El alumno dispone de «Con mi preparador» en Inicio solo si hay recursos propios
confirmados. Desde ahí abre formularios, conversación, pruebas, técnica y avisos.
Las rutas `/my-trainer`, `/my-trainer/technique` y su detalle por ejecución
comprueban la identidad vigente y reutilizan los recursos existentes. Una cuenta
sin recursos no recibe una sección vacía, ni ante un error inicial de consulta.
Abrir no marca leído; el acuse es explícito y no completa tareas. La carga al
entrar/volver/retomar recupera novedades; no hay push con la app cerrada.
[Contrato y backfill](TRAINER_STUDENT_NOTICES.md).

El banco de vídeos permite crear un ejercicio con una demostración lista y el
campo común permite elegir una ya guardada. Seleccionar no reserva ni sube otra
copia; cancelar conserva la anterior. Subir guarda en medios privados y requiere
vincular el vídeo al ejercicio y asignar una sesión para entregarlo al alumno.
Enlaces externos HTTPS y subida conservan sus circuitos y permisos separados.

## Servidor Dev y regresión de vídeo

Solo `sxbxfjqgoddzhtcyhalw`. Aplicadas `20261021201558` (avisos) y
`20261021201803` (recuperación privada), después del ensayo combinado con ambos
DDL y contratos dentro de BEGIN/ROLLBACK. Tras aplicar se repiten ambos contratos
con ROLLBACK. Historial: 200 locales/remotas, sin pendientes. No se toca producción.

La función `exercise-video` interpretaba como JSON una confirmación RPC void con
respuesta 204: la creación ya estaba confirmada, pero el cliente recibía error de
incertidumbre antes de las credenciales. Se admite esa respuesta vacía y se añade
regresión; las respuestas de estado terminal y espera conservan su scope.
Diagnóstico acotado registra solo códigos y estado HTTP, sin tokens, claves,
cuerpos, identificadores personales ni URLs firmadas.

El transporte añade el título técnico requerido a los metadatos TUS, sin enviar
el nombre local del archivo. Referencia primaria revisada el 21/10/2026:
[Bunny TUS](https://bunny.net/docs/stream/tus-resumable-uploads).
El archivo de Javier es MP4 H264, 5,733 s y 15.514.669 bytes: entra en las cotas.
La prueba real inicial reprodujo el fallo antes de entregar credenciales; tras
el arreglo alcanzó la transferencia. La aceptación completa hasta vídeo listo y
reproducción todavía debe acreditarse; no se confunde con los tests simulados.
Las reservas existentes se conservan, sin purga ni reinicio de derechos.

## Verificación de esta integración

- Deportista: análisis limpio y 1.241 pruebas correctas, una omisión previa;
  dos regresiones posteriores del panel condicional se comprueban focalmente.
- Trainer: análisis limpio y 163 pruebas correctas con rutas conectadas.
- Compartido: batería de 135 correcta durante coordinación ADMIN; selección y
  metadatos TUS tienen verificación focal adicional.
- ADMIN: análisis y 312 pruebas correctas, dos omisiones previas, acreditados por
  su responsable sobre el código compartido; 15 pruebas focales de vídeo correctas
  tras añadir los metadatos TUS.
- Servicio de vídeo: 29 pruebas HTTP correctas; autenticación propia conservada.
- SQL real: ambos contratos de aislamiento/reintentos/recetas con ROLLBACK.
  Backfill independiente contrastado con datos anteriores al DDL.
- PG17 local: 108 contenciones de trabajos y cuatro de avisos/perfil correctas.
  El arnés local de trabajos usa constructor deportivo mínimo; el ensayo Dev
  posterior sí consume el motor deportivo real.

## Límites de entrega

Este tramo no cierra los dieciséis puntos. Permanecen cobros reales y sus reglas,
push, recuperación de sesiones hijas/adaptación, sincronización externa y
aceptación física completa con dos cuentas. La distribución web y el APK
compilado se acreditan con revisión y artefacto; compilar no equivale a instalar.
El siguiente recorrido recomendado es probar asignación, ejecución, técnica,
formulario, conversación y revisión con preparador y alumno.

Compilación local final: Trainer web release Dev y APK Android debug Dev correctos.
APK en `build/app/outputs/flutter-apk/app-debug.apk` (artefacto ignorado, 280.229.893
bytes); no instalado por esta tarea. Capturas fixture de los widgets reales a
390 px en `docs/visual-audit/trainer-student-2026-10-21/`, sin desbordamientos.
No representan una sesión real de un alumno ni sustituyen aceptación física.
