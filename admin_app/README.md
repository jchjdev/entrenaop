# EntrenaOP Admin

Aplicación Flutter exclusiva de web para crear y, más adelante, editar
contenido oficial. No importa código de la aplicación del deportista; comparte
con ella únicamente los contratos de Supabase y la cuenta de usuario.

Desde VS Code, abrir la raíz del repositorio y elegir
`EntrenaOP Admin · Chrome 55555` en **Ejecutar y depurar**. La dirección local es
`http://localhost:55555`. Desde esta carpeta también se puede usar
`flutter run -d chrome --web-hostname=localhost --web-port=55555`.

Sin `--dart-define` se conecta a EntrenaOP Dev. Una compilación de producción
requiere `APP_ENV=production`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`
explícitos. No se guardan secretos administrativos en el cliente.
