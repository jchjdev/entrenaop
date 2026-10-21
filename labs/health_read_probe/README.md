# Ensayo local de lectura de carrera · INT-003

Aplicación independiente de deportista, ADMIN y Trainer. No usa Supabase,
identidad de producto, almacenamiento, telemetría ni conexiones de fabricantes.
Consume el dominio puro `device_activity_core` mediante adaptadores de HealthKit
y Health Connect. No se importa desde ninguna de las tres aplicaciones.

El recorrido es explícito: comprobar disponibilidad → solicitar lectura → leer
los últimos siete días → vaciar memoria. No lee al abrir ni al regresar del
segundo plano. Pasar a segundo plano vacía el resultado e invalida respuestas
tardías; el diálogo del sistema conserva su solicitud pendiente. Vaciar no
revoca permisos del sistema.

## Ejecutar y comprobar

Desde esta carpeta, con Flutter 3.47.5 / Dart 3.13.4:

En el Mac se puede preparar antes de conectar el iPhone:

```sh
bash tool/prepare_iphone.sh
```

El script fija la carpeta del ensayo, comprueba SDK/Xcode, resuelve el lockfile,
analiza, prueba y lista destinos. No instala, firma, cambia Git ni solicita
acceso a Salud. Al conectar el iPhone, revisar el equipo propio en Xcode y seguir
el comando Release que imprime. La firma/provisión de este identificador debe
validarse en el Mac; no se acredita por compilar sin firma en CI. No hacen falta
archivos `.env` ni configuración de las aplicaciones existentes.

Comprobación manual equivalente:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter devices
flutter run -d ID_DEL_MOVIL
```

Android: API 28 como mínimo; Health Connect debe estar disponible en el equipo.
Se fija `androidx.health.connect:connect-client:1.1.0` estable. Solo se solicita
`READ_EXERCISE`, se distinguen carrera y cinta y se conservan origen, identidad,
fechas y offsets disponibles. No se agregan muestras de distancia de otras apps
por coincidencia horaria, ni se deducen pausas. Distancia y temporizador quedan
sin informar en este primer ensayo. El manifiesto principal no pide red;
Debug/Profile conservan el permiso de red de desarrollo de Flutter.

iOS: HealthKit, lectura de entrenamientos, sin escritura ni entrega en segundo
plano. Conserva distancia decimal y duración del entrenamiento cuando existen.
No inventa zona ni fecha de modificación. Completar la autorización no prueba
que Apple haya concedido lectura. Para instalar en iPhone hace falta Mac/Xcode,
seleccionar equipo y provisionar este identificador propio con HealthKit;
no se reutiliza ni modifica la firma de la app del deportista.

CI compila Android e iOS Simulator sin publicar. Un simulador o las muestras
sintéticas de las pruebas no acreditan lectura física ni compatibilidad con
un reloj. No se distribuye este ensayo a tiendas.

## Fronteras

- `domain/`: puerto local, ventana acotada y estados; sin Flutter ni SDK nativo.
- `data/`: canal nativo, validación, precisión, identidad y revisión de snapshot.
- `presentation/`: Cubit, acciones explícitas y descarte de resultados tardíos.
- `android/` e `ios/`: permisos mínimos y consultas a los SDK oficiales.
- `main.dart`: composición de dependencias; ningún dominio conoce el puente.

El hash de revisión describe el snapshot leído, no permite ordenar dos
revisiones diferentes de HealthKit. Una identidad de cuenta efímera limita esta
prueba a la memoria de la sesión. No debe reutilizarse para sincronización
persistente. Límite: 200 carreras; Android también limita a veinte páginas de
cien sesiones. La interfaz avisa cuando la lectura es parcial y cuenta registros
apartados por validación sin imprimir su contenido ni mensajes nativos.

Contrato, fuentes y protocolo físico:
[DEVICE_HEALTH_READ_PROBE.md](../../docs/DEVICE_HEALTH_READ_PROBE.md).

## Lectura FIT sin móvil

Se añade un adaptador experimental en `lib/data/fit_running_activity_reader.dart`
y una herramienta de terminal independiente de la interfaz móvil:

```sh
dart run tool/read_fit.dart garmin /ruta/a/carrera.fit
```

Admite proveedor declarado `garmin`, `coros` o `suunto`, sin autenticarlo ni
conectar su API. Añadir `--show-metrics` muestra métricas locales explícitamente;
por defecto solo se muestra el resumen de validación. No escribe resultados.
FIT reales quedan fuera de Git. El lector tiene límites de tamaño/registros y
rechaza codificaciones no admitidas, incluidos timestamps comprimidos y campos
developer. Una muestra sintética no acredita compatibilidad de un reloj.

[Contrato, dependencia, pruebas y límites](../../docs/DEVICE_FIT_READ_PROBE.md).
