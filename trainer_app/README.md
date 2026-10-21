# Panel profesional de EntrenaOP

Flutter web independiente para el destino acordado `trainer.entrenaop.es`.
El subdominio no se publica con el flujo de ADMIN.

```powershell
cd trainer_app
flutter pub get
flutter run -d chrome
```

Por defecto usa exclusivamente EntrenaOP Dev y su clave pública. La cuenta se
crea/recupera desde la app habitual. El acceso profesional requiere TOTP
verificado y AAL2 también en servidor. Entrar no habilita el derecho comercial.

`APP_ENV`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` se configuran por entorno.
Una compilación de producción rechaza la URL Dev predeterminada.
No introducir claves secretas o service_role en defines.

```powershell
flutter analyze
flutter test
flutter build web --release
flutter test tool/capture_clients.dart
```

Las capturas usan datos ficticios, nunca cuentas ni códigos reales. El último
comando usa fuentes locales del entorno Windows descritas en su script.
La contratación autónoma, contenido privado y asignaciones siguen pendientes.
[Contrato del bloque](../docs/TRAINER_PORTAL_2026_10_21.md).
