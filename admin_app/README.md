# EntrenaOP Admin

Aplicación Flutter exclusiva de web para crear contenido oficial. No importa
pantallas ni servicios de la aplicación del deportista. Ambas aplicaciones usan
`packages/workout_core/` para el modelo, la validación y la conversión de
sesiones; cada una conserva su propia interfaz y su propio guardado.

En Programas, abre un programa y pulsa **Nueva sesión**. Esta primera pantalla
crea sesiones de carrera por tramos o fuerza convencional con series iguales.
Las repeticiones de carrera se muestran agrupadas al editar, pero se guardan
como parciales separados. La operación de Supabase crea una plantilla
`system/private/draft` y la vincula al programa de forma atómica. No publica,
asigna ni modifica la agenda de ningún alumno. Edición de borradores,
publicación, bloques avanzados, fases y mesociclos siguen pendientes.

Desde VS Code, abrir **esta carpeta `admin_app/`** como proyecto independiente y
elegir `EntrenaOP Admin · Chrome 55555` en **Ejecutar y depurar**. La dirección
local es `http://localhost:55555`. Desde esta carpeta también se puede usar
`flutter run -d chrome --web-hostname=localhost --web-port=55555`.

Sin `--dart-define` se conecta a EntrenaOP Dev. Una compilación de producción
requiere `APP_ENV=production`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`
explícitos. No se guardan secretos administrativos en el cliente.
