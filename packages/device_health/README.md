# device_health

Plugin Flutter interno de lectura local explícita de carreras. Extrae el
adaptador y puente HealthKit del ensayo; `device_activity_core` sigue puro.
No tiene UI, autenticación, servidor, persistencia ni dependencias de otra app.

```dart
final source = NativeRunningHealth.forCurrentPlatform(ownerId: currentOwnerId);
final status = await source.availability();
// Solicitar lectura solo por acción del usuario; consultar después por otra acción.
```

El puerto de `src/domain` no importa Flutter. El factory integra solo iOS;
Android devuelve `notIntegrated` y web/escritorio, `unsupported`, sin canal.
Health Connect permanece en el ensayo mientras se resuelve su requisito de
SDK sin elevar el mínimo Android 24 de EntrenaOP. El constructor explícito del
adaptador permite inyectar ese puente en el ensayo o en pruebas.

La cuenta/ámbito del caller no autentican al titular. El consumidor invalida
lecturas al cambiar de cuenta, cerrar sesión o suspenderse. No inferir concesión
de lectura HealthKit a partir del diálogo o de una consulta vacía.

iOS 15, Swift Package Manager o CocoaPods: añadir en el anfitrión el entitlement
HealthKit y la descripción de lectura de entrenamientos. No escritura, datos
clínicos ni entrega en segundo plano. Registro estándar Flutter, conservando
los otros plugins/callbacks de la app. No copiar el lector al AppDelegate.

Pruebas: `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`.
La compilación iOS de esta extracción está pendiente; no se acredita integración
en la app principal por existir el plugin.

[Contrato completo de entrega](../../docs/DEVICE_HEALTH_APP_HANDOFF.md).
