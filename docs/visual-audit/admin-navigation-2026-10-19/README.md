# Capturas del admin local · 19/10/2026

Pantallas Flutter reales, router real y tema EntrenaOP. Repositorios de prueba
de `admin_app/test/core/admin_shell_test.dart`; no representan los recuentos,
permisos ni contenidos de una sesión autenticada en Supabase.

| Archivo | Vista |
| --- | --- |
| `desktop.png` | 1440 × 1000: columna lateral y catálogo de Preparaciones. |
| `mobile.png` | 390 × 844: menú desplegado. |
| `mobile-large-text.png` | 320 × 900: menú desplazable con texto 2×. |

Se cargan Roboto e iconos desde el SDK resuelto en `package_config.json`, sin
rutas específicas de Windows. El wordmark es el asset de `entrena_ui`.

Regenerar desde `admin_app/`:

```powershell
flutter test test/core/admin_shell_test.dart --dart-define=CAPTURE_ADMIN=true --plain-name="capturas del marco real"
```

La salida local se guarda en `admin_app/build/admin_review/`. Copiar las tres
imágenes a este directorio solo tras revisarlas. Los hashes SHA-256 de imágenes
y fuentes están en `manifest.json`.
