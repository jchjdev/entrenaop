# EntrenaOP Admin

Aplicación Flutter exclusiva de web para crear contenido oficial. No importa
pantallas ni servicios de la aplicación del opositor. Ambas aplicaciones usan
`packages/workout_core/` para el modelo y la validación de sesiones y
ejercicios. `packages/workout_editor_ui/` aporta el formulario de ejercicios,
los campos de carrera, el buscador con miniaturas, el selector de formatos de
bloque y los campos de objetivo, descanso, carga y RIR de cada serie. Cada
aplicación conserva su navegación, guardado, autorización y funciones propias.
La organización de bloques, repeticiones y variantes aún tiene adaptadores de
pantalla distintos.

La portada administrativa separa tres áreas: **Programas**, **Sesiones
oficiales** y **Ejercicios oficiales**. El creador de ejercicios guarda mediante
funciones SQL que vuelven a comprobar `is_admin()` y fijan en servidor el origen
oficial, la visibilidad pública y la ausencia de propietario personal.

En **Programas**, abre un programa y pulsa **Nueva sesión** para crear una plantilla
exclusiva de esa preparación. La entrada **Sesiones oficiales**
crea sesiones libres sin destino de programa. Carrera permite
tramos repetidos, rangos de ritmo y recuperación por tiempo o metros. Fuerza
permite combinar bloques convencionales, superseries, circuitos, intervalos,
EMOM, AMRAP y Tabata con ejercicios públicos buscables por nombre, músculo o
material; admite objetivos diferentes por serie. Ambas rutas guardan primero
una plantilla `system/private/draft`.
Los campos de carrera formatean los dígitos como `m:ss` (por ejemplo, `555`
se muestra como `5:55`) y también admiten escribir `:`; el selector enseña la
miniatura de los ejercicios públicos cuando tienen una URL HTTPS válida y un
icono cuando no hay foto.
En fuerza, objetivos temporales y descansos se editan en segundos, igual que
en el creador del opositor; el límite global AMRAP se expresa en minutos.
Los ritmos y tramos de carrera mantienen el formato `m:ss`.

Al abrir una sesión se muestra una vista previa de bloques, series y objetivos
con el mismo lector de datos que usa la app. Desde ahí se puede editar un
borrador, preparar una versión nueva de una sesión publicada, publicar o retirar.
Publicar una sesión general la muestra en la biblioteca de la app; publicar
una sesión de programa solo la deja disponible para las futuras reglas de ese
programa. Ninguna acción la asigna automáticamente ni modifica la agenda.
Los borradores sin uso se borran tras confirmación; las sesiones publicadas se
archivan para conservar el historial. Las fases, los mesociclos y la
prescripción adaptativa siguen pendientes.
Una sesión con entrenamientos pendientes o en curso no se puede retirar hasta
reprogramarlos, para no dejar citas imposibles de ejecutar.

Desde VS Code, abrir **esta carpeta `admin_app/`** como proyecto independiente y
elegir `EntrenaOP Admin · Chrome 55555` en **Ejecutar y depurar**. La dirección
local es `http://localhost:55555`. Desde esta carpeta también se puede usar
`flutter run -d chrome --web-hostname=localhost --web-port=55555`.

Sin `--dart-define` se conecta a EntrenaOP Dev. Una compilación de producción
requiere `APP_ENV=production`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`
explícitos. No se guardan secretos administrativos en el cliente.
