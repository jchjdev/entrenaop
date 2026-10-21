# Ensayo aislado de Salud y Health Connect · INT-003 · 21/10/2026

## Estado y objetivo

Javier autoriza el ensayo de lectura de carrera manteniendo Clean Architecture
y sin intervenir en el desarrollo profesional. Se prepara una app independiente
en `labs/health_read_probe`, con identificadores propios y dependencia del
dominio puro `device_activity_core` y el plugin interno `device_health`.
No se conecta todavía con ninguna
de las tres apps, servidores, resultados, citas ni algoritmo.

Android compila localmente y las pruebas del puente/flujo se ejecutan con
muestras sintéticas. La CI confirma compilación Android e iOS para simulador
del commit `4575e32`, con ambos jobs correctos. **La primera lectura física de
Salud en iPhone queda acreditada por la captura aportada por Javier el
21/10/2026:** el ensayo muestra carreras y el escritor
`com.garmin.connect.mobile`, con inicio, duración y distancia presentes. Javier
confirma después la correspondencia de dos carreras y aporta una captura de
Garmin: distancia y duración coinciden a la precisión mostrada; el ritmo
calculado es compatible. Javier comprueba después descarte al volver de Garmin
y relectura de las mismas carreras sin repetición en la lista. Confirma además
que al retirar lectura desaparecen y al restaurarla vuelven. Pausas
y reinstalación del plugin extraído siguen pendientes; la fase móvil
no está cerrada.
Android aún no tiene evidencia física. Javier utiliza iPhone como móvil
principal y su Android no contiene actividades propias.

## Recorrido y contrato de lectura

El usuario comprueba disponibilidad, solicita lectura y pulsa leer. La consulta
abarca los siete días previos, con hasta 200 carreras y aviso de lectura parcial.
Android limita además a veinte páginas de cien sesiones. Se muestran los datos
legibles y el número de registros apartados por validación, sin exportar ni
imprimir identificadores de salud o mensajes nativos.

No hay cuenta, permisos de servidor, subida, persistencia ni analítica. Los datos
permanecen en memoria. Vaciar o pasar a segundo plano descarta la lectura e
invalida respuestas tardías; al volver no se consulta de nuevo automáticamente.
El diálogo de permisos puede pausar la app y se permite completar esa solicitud
sin iniciar una lectura. Los permisos se retiran en los ajustes del sistema:
vaciar memoria no los revoca.

| Canal | Permiso solicitado | Evidencia leída | Límites explícitos |
| --- | --- | --- | --- |
| Salud / HealthKit | Lectura de entrenamientos, sin escritura | `HKWorkout` de carrera: UUID, inicio/fin, duración, distancia si consta, app escritora, fabricante/zona si constan | Completar autorización no revela si se concedió lectura. Sin muestras de pulso, rutas, salud diaria ni fecha de modificación inventada. |
| Health Connect | Solo `READ_EXERCISE` | Sesión de carrera o cinta, ID, inicio/fin, app escritora, modificación y offsets/fabricante si constan | Sin distancia/temporizador inferidos; no se suman registros de otras fuentes por franja horaria. Disponible desde API 28 según almacén/dispositivo. |

El adaptador conserva microsegundos y distancia decimal. Diferencia duración
entre inicio/fin de duración del temporizador; no traduce ausencia a cero.
Se valida el sobre completo y se apartan filas inválidas, fuera de ventana o con
identidad repetida. La revisión es un hash estable del snapshot normalizado,
sin incluir la hora de recepción. Android conserva su fecha de modificación;
HealthKit no recibe una fecha ficticia para hacer ordenable la revisión.
La cuenta efímera del ensayo no constituye una identidad de sincronización.

## Decisión de implementación

Se emplean puentes nativos pequeños a los SDK oficiales, detrás de un puerto
local independiente. El adaptador Dart y el puente Swift se extraen a
`packages/device_health`, plugin interno consumido por el ensayo. El puerto
tipado se conserva sin imports Flutter en `src/domain/` de ese paquete; el
dominio `device_activity_core` sigue sin dependencias de ejecución. El puente
Android permanece en el ensayo. La app principal consume ahora el plugin iOS
con lectura explícita e historial privado aplicado solo en Dev; su prueba física
queda pendiente. [Integración y límites actuales](DEVICE_RUNNING_HISTORY.md).
[Contrato de entrega e integración](DEVICE_HEALTH_APP_HANDOFF.md).

Se contrastó `health` 13.3.2 y se descartó para este ensayo: el contrato Dart
de distancia de entrenamientos utiliza enteros y su lector Android consulta
distancia/calorías/pasos por intervalo, ampliando permisos y sin atribuir esos
agregados a la sesión/origen concreto. El puente mínimo conserva precisión y
permite comprobar exactamente qué se lee. Esto no supone una auditoría general
ni una vulnerabilidad del paquete. Se fija Health Connect 1.1.0 estable,
Fragment 1.8.9 y coroutines Android 1.10.2; compilación local resoluble con
Flutter 3.47.5, Dart 3.13.4, AGP 9.1.0 y JDK 21. No se añaden dependencias
a las aplicaciones existentes.

## Primera prueba real: Garmin → Connect → Salud → ensayo

### Preparar el Mac antes de conectar el iPhone

En GitHub Desktop del Mac, Fetch origin y Pull origin sobre `main`, conservando
cualquier cambio local. Abrir una terminal en `labs/health_read_probe` y ejecutar:

```sh
bash tool/prepare_iphone.sh
```

El preparador verifica que se ejecuta en macOS con Flutter 3.47.5, muestra Xcode,
resuelve el lockfile del ensayo y ejecuta su análisis/pruebas. Después muestra
los destinos de Xcode y Flutter. Fija su propia carpeta, aunque se invoque desde
otra ruta, y no ejecuta instalaciones, firma, lecturas de Salud ni operaciones
de Git que modifiquen archivos o historial. Descarga dependencias y puede crear
la configuración generada de Flutter dentro del ensayo.

Revisar en Xcode el equipo propio, el identificador exclusivo y HealthKit.
La matriz oficial de Apple incluye HealthKit entre las capacidades del acceso
Apple Developer; no se da por necesaria una compra de membresía para este
ensayo. La concesión concreta del perfil debe comprobarse en Xcode, sin quitar
el entitlement para conseguir compilar ni reutilizar el identificador de la
app del deportista. Si Xcode informa de conflicto de identificador, licencia,
certificado o perfil, resolver ese mensaje específico antes de instalar.

Javier ejecutó el preparador en su Mac: las capturas muestran análisis sin
incidencias, 43 pruebas correctas y detección de su iPhone físico. Después
configuró la firma del ensayo con su equipo personal en Xcode y aportó una
captura de la app ejecutándose y mostrando carreras. Esta evidencia sustituye
la preparación e instalación pendientes; las cuatro pruebas del script con
herramientas simuladas siguen siendo únicamente pruebas del preparador.

### Cuando esté conectado al Mac

Garmin documenta envío de entrenamientos de Connect a Salud cuando se autoriza
el intercambio. Esto permite probar una vía indirecta de lectura sin disponer
de acceso propio a Garmin Activity API. No acredita acceso directo a Garmin,
envío de pautas al reloj ni fidelidad completa: Garmin no escribe el trazado GPS
y para actividades temporizadas comparte valores alto/bajo de pulso en lugar
de la serie completa. Este ensayo no solicita esas dos categorías.

1. En iPhone, revisar Salud → perfil → apps y servicios → Connect y permitir
   entrenamientos. Si Connect no aparece, revisar en Connect sus aplicaciones
   conectadas y activar Salud. El nombre exacto puede variar por versión.
2. Sincronizar el reloj con Connect manteniendo Connect en primer plano.
   Comprobar en Salud una carrera reciente cuya fuente sea Connect.
3. En Mac, resolver dependencias de la carpeta del ensayo, abrir
   `ios/Runner.xcworkspace`, seleccionar equipo propio y comprobar HealthKit en
   la firma del identificador `es.entrenaop.healthReadProbe`. Instalar solo el
   ensayo en el iPhone; no sustituye la app existente.
   Desde esa misma carpeta, usar `flutter run --release -d ID_DEL_IPHONE --no-pub`
   con el identificador físico que muestra `flutter devices`. Release permite
   abrir el ensayo desde su icono sin mantener el depurador conectado. No hacen
   falta Supabase, archivos `.env`, claves de fabricantes ni credenciales de
   otras personas; tampoco se publica en una tienda.
4. Ejecutar disponibilidad → permiso → lectura. Comparar con esa carrera de
   Salud: tipo, inicio, duración y distancia cuando exista. La distancia diaria
   de caminar/correr no equivale necesariamente al total del entrenamiento.
5. Repetir sin crear otra actividad y comparar lista/métricas; las identidades
   y revisiones se comprueban en las pruebas del adaptador y no se exponen en
   pantalla. Vaciar, leer de nuevo tras acciones explícitas y verificar que
   no hay persistencia. Pasar a segundo plano y comprobar el descarte.
6. Retirar lectura desde Salud y repetir. Apple puede devolver una lista vacía;
   no debe mostrarse como prueba de permiso concedido ni de denegación.

Garmin indica que al activar el intercambio solo recupera hasta dos semanas
previas; el ensayo consulta siete días. Una carrera ausente primero en Salud
no debe atribuirse al lector de EntrenaOP.

La web, app y un caso de uso documentado pueden respaldar una nueva solicitud
empresarial al programa Garmin. Su FAQ mantiene revisión y aprobación: no
garantiza admisión por integrar otros proveedores ni una fecha para EntrenaOP.
No se tramitan solicitudes, aceptan condiciones ni contacta con Garmin aquí.

## Prueba Android posterior

Con un voluntario, comprobar primero el modelo y versión Android, disponibilidad
de Health Connect y una carrera visible allí con su aplicación escritora.
Tener un Huawei o la actividad en Huawei Health no acredita que esa sesión haya
llegado a Health Connect. No se pide compartir cuentas ni exportar historial.
Si no hay sesión real, una muestra sintética solo sirve para validar el puente.

Instalar `build/app/outputs/flutter-apk/app-debug.apk` del ensayo con consentimiento
del titular, solicitar solo entrenamientos y contrastar tipo/inicio/fin/origen.
La falta de distancia/pausas es un límite acordado del ensayo Android, no cero.
Probar denegación, revocación, almacén no disponible, lectura repetida y retorno
del segundo plano. No se promete compatibilidad universal por este resultado.

## Evidencia y criterio de continuación

### Primera lectura física de iPhone · 21/10/2026

La captura de la app aportada por Javier acredita disponibilidad de HealthKit,
solicitud de autorización completada y consulta no vacía de entrenamientos de
carrera con origen Garmin Connect. Se muestran inicio, duración entre inicio y
fin, temporizador y distancia; la zona de origen aparece sin informar. La
captura corresponde a la presentación técnica inicial. El ensayo actualizado
muestra distancia en kilómetros, duración en horas/minutos/segundos, origen
legible y fecha/hora del dispositivo, conservando los valores originales en
un desplegable técnico y sin atribuir esa zona al origen.

Javier confirma dos carreras propias y aporta después una captura de Garmin;
distancia y duración coinciden al redondear a la precisión de su pantalla.
El ritmo calculado a partir de distancia/temporizador también es compatible,
sin afirmar que se haya leído una serie de ritmo de HealthKit. Se corrige el
formato humano para redondear los segundos, conservando microsegundos originales.
Javier aclara además que la app funciona y la confusión era de presentación;
no estaba comunicando bloqueos o cierres. Esto no acredita pruebas de estabilidad
prolongadas ni los demás recorridos pendientes.

Javier autoriza expresamente guardar sus métricas para desarrollar y verificar la
integración. Se conserva evidencia local en
`labs/health_read_probe/local_evidence/`, ignorada por Git. Incluye los campos
visibles y la comparación de presentación; las pausas siguen sin contrastar.
No se versionan la captura ni los valores personales. Esta evidencia de
desarrollo no constituye persistencia del historial en la app del deportista.

Javier autoriza además expresamente compartir el resumen técnico de lectura,
comparación, descarte y permisos con los chats responsables de Trainer y
Arquitectura, y guardarlo en la documentación de GitHub, sin métricas exactas
ni capturas. Esta autorización de desarrollo no cambia los permisos de acceso
del producto ni autoriza tratar datos de otros deportistas.

Se acredita la vía Garmin Connect → Salud → ensayo, sin acceso directo a la API
de Garmin ni conexión con las apps del deportista, ADMIN o Trainer. La captura
no permite comprobar comportamiento de pausas ni estabilidad prolongada.
Después, Javier confirma que al volver de Garmin la lista está vacía y debe
repetir las acciones explícitas; vuelven las mismas carreras sin repetirse en
la lista. Esto acredita descarte y relectura física del lector instalado, no
deduplicación de un historial persistente ni la reinstalación de la extracción.
Javier comprueba además revocación y restauración desde Salud: sin permiso
desaparecen las carreras y al restaurarlo vuelven. Se acredita el efecto de
la revocación en la consulta, no que Apple exponga un booleano de concesión.
Pausas y prueba física Android permanecen abiertas. Completar el
diálogo de Apple tampoco demuestra acceso a todo el historial.

### Extracción reutilizable para el primer consumidor

El plugin interno `device_health` registra HealthKit mediante el registrador
estándar, sin copiar canales al Runner anfitrión. El ensayo ya lo consume y
mantiene Android independiente. El factory productivo distingue Android aún
no integrado de plataformas no soportadas y no invoca un canal inexistente.
No se eleva el mínimo Android 24 de la app principal ni se usa overrideLibrary:
Health Connect 1.1.0 requiere SDK 26 y su servicio, 28. La conexión inicial a
deportista será iOS, conforme a la frontera ratificada por Trainer/Arquitectura.

La extracción tiene 16 pruebas de contrato y el ensayo conserva 30 pruebas
de FIT, flujo, permisos y pantalla. Análisis limpios en ambos y APK Android
compilado. Se conservan los valores originales; el formato humano solo afecta
a presentación. El preparador comprueba ambos proyectos, y los dieciséis
escenarios de alcance CI conservan la publicación de ADMIN para cambios mixtos
y la omiten en este alcance aislado.
La [CI nativa 39637024250](https://github.com/jchjdev/entrenaop/actions/runs/39637024250)
del commit `124fa76` acredita compilación del plugin en iOS Simulator y del
ensayo Android: ambos jobs completados con `success`. El registro publica la
instancia para recibir el desmontaje del motor. La reinstalación física y el
ciclo de desmontaje nativo de esta extracción siguen pendientes; la evidencia
física anterior corresponde al lector previo a la extracción.

**CI ADMIN del mismo commit `124fa76`:**
[ejecución 39637024185](https://github.com/jchjdev/entrenaop/actions/runs/39637024185)
completada con `success`. El job de validación terminó correctamente, incluidos
análisis, pruebas y empaquetado. `deploy` y `retain-packages` quedaron `skipped`:
esta extracción no publicó ADMIN ni retiró paquetes.

### Verificación automatizada previa

Pasan 25 pruebas de mapeo, tiempos, revisiones, validación, permisos, errores
reducidos a códigos, acciones explícitas, revocación, respuestas tardías y
pantalla de 320 px con texto al doble. Análisis del ensayo limpio y APK Debug
compilado. Análisis global de raíz limpio y batería completa: 1145 pruebas
correctas, con una omisión previa. El dominio conserva sus 56 pruebas y análisis
limpios. El detector real de alcance de ADMIN cubre doce casos, incluidos
ensayo aislado y cambios mixtos: solo el ensayo/dominio/docs/CI no publican ADMIN;
los cambios mixtos conservan el comportamiento de despliegue existente.

El workflow propio solo verifica y compila; no despliega ni publica artefactos
de salud. [Ejecución de compilación Android e iOS correcta](https://github.com/jchjdev/entrenaop/actions/runs/39621174970),
con ambos jobs completados satisfactoriamente. La compilación iOS para simulador
no instala en teléfono ni valida
los permisos reales. Registrar después fecha, sistema, escritor, tipos/métricas
comprobados, resultado de denegar/revocar y límites; no subir datos de salud
personales ni capturas identificables al repositorio.

**CI general ADMIN comprobada:**
[ejecución 39621174972](https://github.com/jchjdev/entrenaop/actions/runs/39621174972)
del commit `4575e32`, terminada con `success`. Incluye resolución de lockfiles,
dominio puro, análisis y pruebas del deportista y ADMIN, pruebas de publicadores,
compilación web y empaquetado. `deploy` y `retain-packages` terminaron como
`skipped`: este alcance no publicó ADMIN ni retiró paquetes. La evidencia no
equivale a una instalación o lectura HealthKit en un teléfono.

**Siguiente tramo único:** entregar a integración la lectura local del deportista
desde el plugin compilado, conservando las pruebas físicas pendientes de
reinstalación y pausas. Guardar un
historial personal requiere después el contrato de persistencia por cuenta;
una lista en memoria no cierra ese recorrido. Android real sigue pendiente.
Persistencia, autorización de resultados y conexiones de fabricantes permanecen
fuera de este ensayo. No se abre otro bloque transversal mientras falte esta
evidencia, ni se modifica Trainer para integrar el prototipo.

## Fuentes primarias contrastadas

- [Garmin: compartir Connect con Salud](https://support.garmin.com/en-AU/?faq=lK5FPB9iPF5PXFkIpFlFPA).
- [Garmin: programa y aprobación](https://developer.garmin.com/gc-developer-program/program-faq/).
- [Apple: autorización HealthKit](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).
- [Apple: capacidades según membresía](https://developer.apple.com/help/account/reference/supported-capabilities-ios).
- [Android: lectura de Health Connect](https://developer.android.com/health-and-fitness/health-connect/read-data).
- [Android: SDK y versiones](https://developer.android.com/jetpack/androidx/releases/health-connect).
- [Código del paquete evaluado](https://github.com/carp-dk/carp-health-flutter), contrastado además con el paquete 13.3.2 resuelto localmente.
