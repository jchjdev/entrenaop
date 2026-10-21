# Ensayo aislado de Salud y Health Connect · INT-003 · 21/10/2026

## Estado y objetivo

Javier autoriza el ensayo de lectura de carrera manteniendo Clean Architecture
y sin intervenir en el desarrollo profesional. Se prepara una app independiente
en `labs/health_read_probe`, con identificadores propios y dependencia exclusiva
del dominio puro `device_activity_core`. No se conecta todavía con ninguna
de las tres apps, servidores, resultados, citas ni algoritmo.

Android compila localmente y las pruebas del puente/flujo se ejecutan con
muestras sintéticas. La compilación iOS se encarga al workflow de macOS; debe
consultarse su resultado antes de acreditarla. **La lectura física permanece
pendiente en ambos sistemas y la fase móvil no está cerrada.** No hay teléfono
conectado al Windows de desarrollo. Javier tiene iPhone como móvil principal,
con carreras en Garmin Connect, y Android sin actividades propias. La primera
evidencia real recomendada es su iPhone cuando esté disponible; no hace falta
conseguir un voluntario Android para seguir preparando el ensayo.

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
local independiente. Flutter/Cubit y MethodChannel no entran en el dominio
puro, y HealthKit/Health Connect no entran en el dominio compartido.

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
4. Ejecutar disponibilidad → permiso → lectura. Comparar con esa carrera de
   Salud: tipo, inicio, duración y distancia cuando exista. La distancia diaria
   de caminar/correr no equivale necesariamente al total del entrenamiento.
5. Repetir sin crear otra actividad; comprobar que conserva identidad/revisión
   en memoria. Vaciar, leer de nuevo tras acciones explícitas y verificar que
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

Pasan 25 pruebas de mapeo, tiempos, revisiones, validación, permisos, errores
reducidos a códigos, acciones explícitas, revocación, respuestas tardías y
pantalla de 320 px con texto al doble. Análisis del ensayo limpio y APK Debug
compilado. Análisis global de raíz limpio y batería completa: 1145 pruebas
correctas, con una omisión previa. El dominio conserva sus 56 pruebas y análisis
limpios. El detector real de alcance de ADMIN cubre doce casos, incluidos
ensayo aislado y cambios mixtos: solo el ensayo/dominio/docs/CI no publican ADMIN;
los cambios mixtos conservan el comportamiento de despliegue existente.

El workflow propio solo verifica y compila; no despliega ni publica artefactos
de salud. La compilación iOS para simulador no instala en teléfono ni valida
los permisos reales. Registrar después fecha, sistema, escritor, tipos/métricas
comprobados, resultado de denegar/revocar y límites; no subir datos de salud
personales ni capturas identificables al repositorio.

**Siguiente tramo único:** acreditar lectura real en iPhone desde una carrera de
Connect ya presente en Salud; después contrastar Android con datos reales.
Persistencia, autorización de resultados y conexiones de fabricantes permanecen
fuera de este ensayo. No se abre otro bloque transversal mientras falte esta
evidencia, ni se modifica Trainer para integrar el prototipo.

## Fuentes primarias contrastadas

- [Garmin: compartir Connect con Salud](https://support.garmin.com/en-AU/?faq=lK5FPB9iPF5PXFkIpFlFPA).
- [Garmin: programa y aprobación](https://developer.garmin.com/gc-developer-program/program-faq/).
- [Apple: autorización HealthKit](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).
- [Android: lectura de Health Connect](https://developer.android.com/health-and-fitness/health-connect/read-data).
- [Android: SDK y versiones](https://developer.android.com/jetpack/androidx/releases/health-connect).
- [Código del paquete evaluado](https://github.com/carp-dk/carp-health-flutter), contrastado además con el paquete 13.3.2 resuelto localmente.
