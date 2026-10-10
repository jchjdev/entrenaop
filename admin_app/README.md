# EntrenaOP Admin

En desarrollo, **Cuentas de prueba** (icono de cuentas en la cabecera de Programas
o `/development-accounts`) busca una cuenta registrada por correo y concede Pro
durante 1/7/30/90 días, o retira sus concesiones de prueba. Requiere permiso
administrativo y habilitación de servidor por el operador; no se publica su
entrada en producción. Conserva los datos y no cobra ni cancela compras de tienda.
El usuario consulta el resultado en Perfil → Mi suscripción → Actualizar acceso.

Aplicación Flutter exclusiva de web para crear contenido oficial. No importa
pantallas ni servicios de la aplicación del opositor. Ambas aplicaciones usan
`packages/workout_core/` para el modelo y la validación de sesiones y
ejercicios. `packages/workout_editor_ui/` aporta el formulario de ejercicios,
los campos de carrera, el buscador con miniaturas, el selector de formatos de
bloque y los campos de objetivo, descanso, carga y RIR de cada serie. Cada
aplicación conserva su navegación, guardado, autorización y funciones propias.
La organización de bloques, repeticiones y variantes aún tiene adaptadores de
pantalla distintos.

`packages/entrena_ui/` comparte el tema, los componentes de marca y las portadas
con la app del deportista. Programas incorpora edición de pruebas/baremos,
previsualización de intentos, vínculos deportivos, configuración de estrategias
y portadas con encuadres separados. Los laboratorios permiten revisar escenarios;
la prescripción del deportista corresponde al motor de servidor.

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
archivan para conservar el historial. El programa adaptativo ya tiene fases de
rendimiento v3 y coordinación con carrera v5 en desarrollo; quedan límites
deportivos pendientes descritos en `../docs/PROGRAMA_ADAPTATIVO.md`.
Una sesión con entrenamientos pendientes o en curso no se puede retirar hasta
reprogramarlos, para no dejar citas imposibles de ejecutar.

Desde VS Code, abrir **esta carpeta `admin_app/`** como proyecto independiente y
elegir `EntrenaOP Admin · Chrome 55555` en **Ejecutar y depurar**. La dirección
local es `http://localhost:55555`. Desde esta carpeta también se puede usar
`flutter run -d chrome --web-hostname=localhost --web-port=55555`.

Sin `--dart-define` se conecta a EntrenaOP Dev. Una compilación de producción
requiere `APP_ENV=production`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`
explícitos. No se guardan secretos administrativos en el cliente.

El [chequeo del 06/10/2026](../docs/AUDIT_2026_10_06.md) recoge análisis,
pruebas, compilación web y limitaciones actuales. El admin todavía utiliza
`Navigator`/`MaterialPageRoute`; su adopción de `go_router` queda pendiente.
