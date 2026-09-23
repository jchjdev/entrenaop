# EntrenaOP Admin

Aplicación Flutter exclusiva de web para crear contenido oficial. No importa
pantallas ni servicios de la aplicación del deportista. Ambas aplicaciones usan
`packages/workout_core/` para el modelo, la validación y la conversión de
sesiones; cada una conserva su propia interfaz y su propio guardado.

En Programas, abre un programa y pulsa **Nueva sesión**. Carrera permite
tramos repetidos, rangos de ritmo y recuperación por tiempo o metros. Fuerza
permite combinar bloques convencionales, superseries, circuitos, intervalos,
EMOM, AMRAP y Tabata con ejercicios del catálogo público. La operación de
Supabase crea una plantilla `system/private/draft` y la vincula al programa
de forma atómica.

Al abrir una sesión se muestra una vista previa de bloques, series y objetivos
con el mismo lector de datos que usa la app. **Publicar** solo aparece desde
esa revisión, requiere confirmación y hace visible esa versión en la biblioteca
general de la app. No la asigna a un plan ni modifica la agenda. La edición
de borradores, las fases y los mesociclos siguen pendientes.

Desde VS Code, abrir **esta carpeta `admin_app/`** como proyecto independiente y
elegir `EntrenaOP Admin · Chrome 55555` en **Ejecutar y depurar**. La dirección
local es `http://localhost:55555`. Desde esta carpeta también se puede usar
`flutter run -d chrome --web-hostname=localhost --web-port=55555`.

Sin `--dart-define` se conecta a EntrenaOP Dev. Una compilación de producción
requiere `APP_ENV=production`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`
explícitos. No se guardan secretos administrativos en el cliente.
