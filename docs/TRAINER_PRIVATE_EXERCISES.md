# Ejercicios privados profesionales · TRN-019 · 21/10/2026

## Contrato

Javier autoriza continuar ejercicios propios reutilizando el creador de ADMIN,
incorporarlos a sesiones/programas y pautarlos a alumnos. Confirma para el piloto
500 ejercicios y 1.000 imágenes de hasta 500 KB por preparador, configurables
en servidor e independientes del cupo de alumnos y de Free/Pro personal.
Las versiones conservadas cuentan dentro de los 500 ejercicios. Las reservas
de imágenes también cuentan: una subida abandonada no permite recursos infinitos.

`ExerciseForm` ya estaba en `workout_editor_ui`; Trainer lo consume directamente,
con el mismo borrador, validación y optimización de fotos que ADMIN. No se mueve
ni copia su formulario. Los vídeos se añaden mediante URL HTTPS externa; no se
habilita la subida profesional de archivos a Bunny ni se promete privacidad del
alojamiento externo. La interfaz lo explica.

## Versiones, propiedad y permisos

`exercises.origin='coach'`, propietario obligatorio y `is_public=false` separan
el contenido profesional de los ejercicios personales y del catálogo oficial.
Cada edición crea un ID nuevo y retira la anterior de la selección general.
La sesión conserva el ID exacto del ejercicio; el programa conserva el de la
sesión. Revisar no modifica técnica, vídeo ni foto de recetas anteriores.
El selector conserva versiones antiguas que ya formen parte de la receta editada.

La autoría requiere acceso profesional activo y MFA. Las lecturas propias
requieren MFA, aun si el acceso ha caducado. El alumno solo consulta el ejercicio
presente en una receta autorizada asignada o en su ejecución histórica. No puede
copiarlo a una sesión personal, editarlo ni consultar el resto de la biblioteca.
Tener ADMIN no concede acceso a contenido profesional ajeno. Un trigger también
cierra la inyección de IDs privados mediante escrituras heredadas de items.

`trainer_private.exercise_versions` mantiene familia, versión, operación y
payload; los reintentos idénticos devuelven el mismo ID y los distintos se
rechazan. El formulario conserva el envío tras un error incierto y permite
reintentarlo sin alterar su contenido. La identidad se comprueba antes y después
de cada operación remota.

## Imágenes y cuotas

Bucket privado `trainer-exercise-images`, JPEG y límite de 512.000 bytes.
La reserva idempotente tiene ruta `propietario/operación.jpg`. Solo su dueño con
MFA y acceso activo puede subirla; no existen permisos de sobrescritura o
borrado de estas imágenes. El alumno obtiene firma mediante acceso al recurso
asignado. Una edición conserva, sustituye con otra ruta o retira la imagen en
la nueva versión, manteniendo la anterior intacta. No se guardan firmas en SQL.

Los contadores condicionados de `exercise_limits` y el bloqueo de autoría hacen
cumplir cuotas bajo concurrencia. Cada ejercicio/version guardado consume una
unidad y su payload de reintento queda limitado a 8 KiB.
Cada reserva nueva consume una imagen; reintentar no consume otra.
Las reservas fallidas o abandonadas no se recuperan automáticamente en este
tramo. Los límites pueden ajustarse en servidor; no hay interfaz de ampliación,
compra ni purga de recursos profesionales. No son tarifas comerciales.

Las firmas del portal se solicitan por lotes, sin una petición por cada foto.
Al reintentar una subida se comprueban sus bytes, sin sobrescribir ni eliminar
un objeto cuya confirmación pudiera haberse perdido.

## App del deportista y distribución

La app reconoce `ExerciseOrigin.coach` y firma la foto en el bucket profesional
cuando carga la técnica del ejercicio recibido. La biblioteca personal pide
solo catálogo público y ejercicios de origen `user` propios, aunque la identidad
también sea ADMIN/preparador. El ejecutor conserva sus instantáneas y carga la
imagen de la versión inmutable. Se reutilizan agenda, técnica, resultados e
historial; no se crea otra biblioteca vacía para usuarios sin entrenador.

El código móvil se actualiza en esta entrega. La instalación física es un hito
distinto: Windows solo detecta escritorio, Chrome y Edge el 21/10/2026; no hay
teléfono conectado. No se acredita instalación iOS/Android ni prueba humana de
dos cuentas. Producción permanece fuera del alcance.

## Referencia de Harbiz

Javier permite revisar su sesión y crear pruebas. Se contrastan creador real,
URL/imagen/sin medio, instrucciones, categorías y etiquetas; no se guarda
contenido de prueba ni se modifican clientes reales en esta revisión.
[Guía de ejercicios](https://intercom.help/harbiz-help/es/articles/10050939-como-crear-y-buscar-ejercicios-en-la-plataforma)
y [rutinas/asignación](https://intercom.help/harbiz-help/es/articles/6492199-como-crear-y-asignar-rutinas-de-entrenamiento).
Favoritos, filtros y etiquetas internas son propuestas posteriores, no funciones
presentadas como implementadas. Aprender de Harbiz no autoriza retroceder en
creadores, contratos o capacidades ya existentes de EntrenaOP.

## Verificación

Antes de publicación: catorce contratos SQL transaccionales sobre Dev con
ROLLBACK, incluido ejercicio → programa → pauta → ejecución y permisos;
69 contenciones observadas sobre PostgreSQL 17 local desechable (24 nuevas de
cuota/reintento, en READ COMMITTED y REPEATABLE READ). Baterías del deportista
y ADMIN completas correctas: 1145 raíz (una omisión previa), 301 ADMIN (dos
previas), 33 portal y seis del publicador. Seis capturas de widgets reales
revisadas, incluida pantalla estrecha y texto 2×. Análisis del alcance modificado,
portal, ADMIN y global final limpios. El primer análisis global detectó trabajo
ajeno en curso de `labs/health_read_probe`; se conservó aparte y el último análisis
global ya pasa. La compilación web Dev del deportista pasa; no se publica.
Las pruebas SQL simulan metadatos de Storage: no sustituyen
la aceptación física de dos cuentas ni el almacenamiento de un JPEG por HTTPS.

## Publicación Dev comprobada

Fuentes `cb435e288a0453283c4804a88bd9d852a49e8fd1`, subidas a main.
Versión web `cb435e288a0453283c4804a88bd9d852a49e8fd1-20261021-7`,
publicada únicamente en `public_html/trainer` de Hostinger. Se conserva el ZIP
fuera de la carpeta pública y los recursos de versiones anteriores.

- ZIP SHA-256: `4feabfb8ad901904512a41c792403ad58440e805dd871bc30705d4fedcbf7991`.
- JavaScript SHA-256: `95b38970c895053ae4f78bdb5d644db59e77b437df47194c75d850bd3db84310`.
- Verificador HTTPS correcto: revisión, hash, entrada de versión, cabeceras y
  MIME de WebAssembly.
- Dev: 185 migraciones locales/remotas coincidentes. Asesores sin avisos WARN
  nuevos de este tramo; tablas privadas con RLS y sin permisos directos.
- Chrome con la sesión existente: cinco destinos accesibles, uso 0/500 y
  0/1.000, biblioteca y formulario común completos, cero errores de consola.
  Se abre/cierra sin guardar datos ficticios. Capturas `published-library.png`
  y `published-editor.png` en `docs/visual-audit/trainer-exercises-2026-10-21/`.

No se acredita todavía una subida real de JPEG ni el recorrido humano de dos
cuentas en un teléfono. La compilación del deportista está en
`build/athlete-trainer-exercises-web/` (local, no distribuida). La publicación
web no instala la app en el móvil ni habilita producción.
