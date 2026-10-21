# Salud en la app del deportista · contrato de entrega · 21/10/2026

## Alcance y propiedad

Javier confirma lectura real desde su iPhone y pide funcionalidad y conservación
de sus métricas. La evidencia de desarrollo está guardada localmente; la lista
actual del ensayo permanece en memoria y no es un historial persistente.

Trainer y Arquitectura ratifican extraer un plugin Flutter interno, consumido
por el ensayo y después por deportista, con `device_activity_core` puro. No se
importa código de `labs` desde ninguna app. Dispositivos prepara `device_health`
y, cuando se conecte la dependencia, la feature `device_activities`; Trainer
conecta pubspec/lock, rutas/perfil, composición y configuración nativa. Estas
reservas no conceden editar sus archivos profesionales ni los compartidos.

La extracción no cambia SQL, servidor, agenda, ejecuciones ni resultados.
La compilación iOS del nuevo plugin y su reinstalación física están pendientes;
la lectura física positiva previa acredita el lector antes de extraerlo.

## API y consumidor

`device_health` expone un puerto sin imports Flutter:

- `LocalRunningHealth.availability()` distingue disponible, actualización,
  no disponible, no integrado y no soportado.
- `requestReadAccess()` devuelve concedido/denegado en Health Connect o estado
  desconocido tras completar la autorización de Apple. No prueba la concesión
  de lectura de HealthKit ni permite inferir denegación por una lista vacía.
- `read(window:, localSessionScope:)` recibe ventana UTC positiva de hasta siete
  días y devuelve observaciones, número apartado y aviso de truncado. No guarda
  ni asocia resultados; no ejecuta lecturas automáticas.

`NativeRunningHealth.forCurrentPlatform(ownerId:)` es el adaptador productivo.
El titular procede de la composición del consumidor, no del permiso OS ni de
los registros de Salud. No autentica al titular ni concede acceso de servidor.
El constructor explícito permite al ensayo inyectar su puente Health Connect;
el factory productivo inicial solo habilita iOS. No hay caché del adaptador.

La feature recibe el puerto por constructor. UI/Cubit no conocen MethodChannel,
SDK, Auth ni Supabase. El anfitrión proporciona una instancia/clave nueva al
cambiar titular; el Cubit debe invalidar generaciones, descartar respuestas
tardías y vaciar memoria al cerrar sesión o cambiar cuenta. La autorización OS
puede seguir activa tras cambiar la cuenta de EntrenaOP: no habilita compartir
el resultado anterior. Se debe comprobar ese ciclo antes de conectar la ruta.

## Configuración nativa y paridad

| Canal | Implementación del plugin | Consumidor de ensayo | Consumidor principal |
| --- | --- | --- | --- |
| iOS | Swift, HealthKit, registrador Flutter estándar; iOS 15; SPM y podspec. Cancela consulta en segundo plano y libera consulta/autorización/observador al detach. | Consume el plugin, sin segundo lector Swift en Runner; lectura física anterior positiva, extracción pendiente de build/reinstalación. | Dependencia, entitlement, descripción de lectura y ruta aún sin conectar. |
| Android | No declarada en el plugin inicial. Factory devuelve `notIntegrated` sin invocar un canal ausente. | Conserva su puente Health Connect 1.1.0, solo READ_EXERCISE y mínimo 28. Sin prueba física. | Mantiene mínimo 24, MainActivity y callbacks actuales. No se eleva mínimo ni se usa overrideLibrary. |
| Web/escritorio | Factory devuelve `unsupported`, sin llamadas nativas. | No lee datos de salud. | No hereda lectura nativa por compartir Flutter. |

iOS: añadir solo `com.apple.developer.healthkit` y
`NSHealthShareUsageDescription`. No datos clínicos, escritura ni entrega en
segundo plano. El plugin se registra con los demás plugins: conservar
WorkoutVibration y callbacks actuales de AppDelegate. El ensayo mantiene su
bundle independiente; la app principal conserva el suyo.

Android: Flutter 3.47.5 fija mínimo 24; la dependencia Health Connect 1.1.0
requiere 26 y su servicio, 28. Integrarla exige resolver explícitamente ese
encaje antes de añadirla al consumidor, sin cambiar la cobertura de teléfonos
actual. No sustituir FlutterActivity por FlutterFragmentActivity como efecto
colateral de salud; el ensayo no constituye la configuración de la app.

## Criterio de verificación y siguiente contrato

El paquete cubre precisión, ausencia frente a cero, procedencia, identidad del
titular inyectado, revisión estable, límites, errores reducidos a códigos,
permisos y ausencia de canal en plataformas no integradas. El ensayo mantiene
pruebas del flujo explícito, cancelación de respuestas tardías, segundo plano y
pantalla estrecha con texto grande. CI debe compilar el consumidor iOS del
plugin; las muestras o un build no sustituyen la comprobación física.

El registro publica la instancia del plugin para que Flutter notifique
`detachFromEngine`; se contrasta este requisito con la
[documentación del protocolo FlutterPlugin](https://api.flutter.dev/ios-embedder/protocol_flutter_plugin-p.html).
El ciclo nativo de desmontaje todavía requiere verificación en iOS.

El próximo contrato de guardado personal debe definir almacenamiento por
titular y conexión estable, deduplicación por identidad/revisión, atomicidad,
retención y cambio de cuenta. Una consulta parcial o vacía no borra historial.
No debe persistir como cuenta real el ámbito efímero del ensayo. Guardar una
carrera no completa ni confirma una pauta; la asociación revisada y cualquier
entrega autorizada a un preparador son acciones y contratos separados.

Fuentes: [plugins Flutter](https://docs.flutter.dev/packages-and-plugins/developing-packages),
[SPM del plugin](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)
y [Health Connect](https://developer.android.com/health-and-fitness/health-connect/get-started).
