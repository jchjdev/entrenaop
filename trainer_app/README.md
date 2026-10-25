# Panel profesional de EntrenaOP

Flutter web independiente para el destino acordado `trainer.entrenaop.es`.
Publicado y verificado por HTTPS con EntrenaOP Dev el 21/10/2026.
La primera carga usó el paquete de `tool/trainer_release.py` y el gestor de
Hostinger. El workflow `trainer-dev.yml` añade validación y artefacto propios;
el envío automático se habilita después de configurar su cuenta FTPS confinada
y sus secretos, sin utilizar la cuenta ADMIN.
[Automatización y activación pendiente](../docs/TRAINER_DEPLOYMENT_2026_10_25.md).
[Primera publicación y entrada verificadas](../docs/TRAINER_HOSTING_2026_10_21.md).

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
