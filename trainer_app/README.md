# Panel profesional de EntrenaOP

Flutter web independiente para el destino acordado `trainer.entrenaop.es`.
Publicado y verificado por HTTPS con EntrenaOP Dev el 21/10/2026.
La primera carga usó el paquete de `tool/trainer_release.py` y el gestor de
Hostinger. El workflow `trainer-dev.yml` valida, empaqueta y publica Dev con su
cuenta FTPS confinada y sus secretos, sin utilizar la cuenta ADMIN.
[Automatización y comprobaciones](../docs/TRAINER_DEPLOYMENT_2026_10_25.md).
[Primera publicación y entrada verificadas](../docs/TRAINER_HOSTING_2026_10_21.md).

```powershell
cd trainer_app
flutter pub get
flutter run -d chrome
```

Por defecto usa exclusivamente EntrenaOP Dev y su clave pública. Desde el login
web se puede crear una cuenta, reenviar la confirmación y recuperar contraseña,
sin instalar la app. Abrir los enlaces de correo en el navegador que los solicitó.
Registrarse no habilita acceso profesional, Pro ni permisos administrativos:
ADMIN concede el acceso y el cupo desde la ficha de la cuenta. El panel
profesional requiere TOTP verificado y AAL2 también en servidor.
[Registro y recuperación web](../docs/TRAINER_WEB_ACCOUNT_2026_10_27.md).

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
La contratación autónoma y los cobros siguen pendientes; el alta profesional
continúa siendo manual. El contenido privado y las asignaciones ya tienen su
recorrido propio en el portal.
[Contrato del bloque](../docs/TRAINER_PORTAL_2026_10_21.md).
