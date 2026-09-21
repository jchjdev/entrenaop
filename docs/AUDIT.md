# Auditoría inicial de EntrenaOP

Fecha de la revisión: 19 de septiembre de 2026.

Este documento separa hechos comprobados, puntos pendientes de verificación y
recomendaciones. No sustituye el historial de cambios ni convierte hipótesis
sobre el backend en hechos.

## Alcance revisado

- Estado y ramas de Git.
- Código Dart de `main`, autenticación, navegación y ejercicios.
- Configuración Android, iOS, web y Windows.
- Dependencias declaradas y resueltas.
- Pruebas existentes.
- Disponibilidad local de Flutter, Supabase CLI y Docker.
- Referencia pública del proyecto remoto de Supabase.
- Rama remota `origin/backup/fase1-claude`.

## Estado recuperado

La rama `main` contiene autenticación básica y el módulo de ejercicios con
capas de dominio, datos y presentación. La rama remota
`origin/backup/fase1-claude` conserva además un prototipo de unas 3.500 líneas
con registro, perfil, navegación principal, ejercicios, rutinas y sesión
activa. No es necesario abrir VS Code ni recuperar esos archivos del equipo
anterior: Git ya los conserva.

El respaldo se mantendrá como referencia y fuente de ideas. No se fusionará de
forma completa porque sus decisiones de rutinas, sesión, derechos y
persistencia no cumplen el modelo de producto vigente.

## Bloqueos y roturas

### Backend recuperado y esquema auditado

El proyecto Supabase estaba pausado y Javier lo reanudó. La referencia del panel
coincide con la configurada en la aplicación: `izzsttrrgrowktfjssqv`.

La API de Auth responde con la clave pública existente. Se auditó el catálogo
remoto desde el SQL Editor en modo de solo lectura. Existen `profiles`,
`exercises`, `routines`, `routine_exercises` y `session_logs`, y las cinco
tablas tienen RLS activado.

El estado remoto anterior no era reproducible desde Git. Se ha reconstruido
una línea base SQL con tablas, claves, función y trigger, seguida de una
migración de saneamiento independiente. La línea base no debe ejecutarse sobre
producción porque sus objetos ya existen allí; primero tendrá que marcarse como
aplicada en el historial remoto.

Hallazgos comprobados en producción:

- Las políticas de ejercicios, rutinas y sesiones estaban duplicadas y se
  solapaban entre roles `public` y `authenticated`.
- RLS estaba activo, pero cuatro tablas no concedían `SELECT` ni operaciones de
  escritura a `authenticated`; sus políticas no bastaban para hacerlas
  accesibles y explican los errores `permission denied` del cliente.
- `profiles` sí concedía `SELECT` y `UPDATE` completos a `authenticated`. La
  política permitía editar la fila propia, incluido `role`, por lo que un
  cliente manipulado podía autoasignarse `admin`, `premium` o `seguimiento`.
- Solo existían índices de clave primaria; las claves foráneas y consultas de
  historial carecían de índices de apoyo.
- `public.handle_new_user()` y el trigger `on_auth_user_created` crean el perfil
  después del alta en `auth.users`.
- En el momento de la auditoría había un perfil administrador, un ejercicio y
  ninguna rutina, relación de rutina o sesión. Las comprobaciones agregadas no
  detectaron claves obligatorias nulas en esos datos.

La migración de saneamiento conserva al administrador existente en una tabla
de permisos separada, retira al cliente la escritura del campo `role`, rehace
grants y políticas con mínimo privilegio y añade constraints e índices básicos.
Todavía no se ha aplicado a producción.

Se creó además un proyecto Supabase independiente para desarrollo
(`sxbxfjqgoddzhtcyhalw`). La línea base y el saneamiento se aplicaron allí y la
API pública responde respetando RLS. La aplicación usa este entorno por defecto;
producción solo puede seleccionarse mediante configuración explícita de build.

### Herramientas del Omnibook

- SDK local actualizado: Flutter 3.47.5, Dart 3.13.4 y DevTools 2.60.0.
- Flutter necesita acceso de escritura a la caché del SDK situada fuera del
  repositorio. Con ese permiso, el SDK responde correctamente y el análisis
  termina.
- Supabase CLI 2.117.0 está instalada como dependencia local fijada del
  repositorio y `supabase init` ya creó la configuración. Docker no está
  instalado y no bloquea el flujo actual porque el backend de desarrollo es
  un proyecto cloud independiente.
- Los tokens personales con alcance limitado, actualmente en alpha, son
  rechazados por la validación de esa versión de la CLI. No se sustituyeron por
  un token clásico con acceso total; la auditoría se realizó mediante la sesión
  autenticada del panel.
- Android SDK 35 y 36, Build Tools 36 y CMake 3.22.1 quedaron instalados por el
  propio toolchain. El proyecto usa Gradle 9.3.1, Android Gradle Plugin 9.1.0,
  Kotlin 2.4.0 y Java 17, según la plantilla de Flutter 3.47.5.
- La compilación web de producción y la compilación Android de depuración se
  completaron. El APK verificable queda en
  `build/app/outputs/flutter-apk/app-debug.apk`.

El análisis termina sin incidencias y las siete pruebas actuales pasan. Existe
cobertura inicial de configuración de entornos, restauración de autenticación,
los dos resultados del registro y conversión del repositorio de ejercicios.
Permisos, navegación, dominio de rutinas y algoritmo siguen necesitando pruebas
específicas según se implementen.

## Hallazgos críticos de aplicación

### Autenticación y navegación

- `checkCurrentUser()` existe, pero no se invoca al arrancar. Una sesión
  persistida no se restaura en el estado de la aplicación.
- No se escucha el flujo `authStateChanges` de Supabase. Caducidad, cierre de
  sesión externo y renovación no se reflejan de forma robusta.
- `RouterNotifier` crea una suscripción al Cubit sin conservarla ni cancelarla.
- Login navega explícitamente y el router también redirige; existen dos fuentes
  de navegación para el mismo cambio de estado.
- Un login correcto depende inmediatamente de que exista una fila en
  `profiles`. Si falla el perfil, la sesión remota puede quedar iniciada mientras
  la aplicación muestra un error.
- Se imprimen datos de perfil y correo en salida de depuración.
- Los errores técnicos se transforman en texto con `toString()` y pueden llegar
  directamente al usuario.

### Identidad y negocio

- `UserEntity.role` mezcla en un único valor conceptos que deben separarse:
  administración, derechos comerciales, seguimiento y relación profesional.
- El cliente no puede ser la autoridad que conceda Premium/Pro, Coaching o
  permisos administrativos.
- No hay evidencia verificable de constraints ni RLS para ninguna tabla.

### Ejercicios

- El repositorio convierte `ExerciseEntity` a `ExerciseModel` mediante un cast
  forzado. Una entidad válida que no sea esa implementación fallará en tiempo
  de ejecución.
- `getExerciseById` declara que puede devolver `null`, pero utiliza `.single()`,
  que convierte la ausencia de fila en una excepción.
- Identificadores, `created_by`, visibilidad y otros campos sensibles se envían
  desde el cliente. Su seguridad depende de políticas y constraints que no se
  pueden verificar.
- Dificultad, tipo, grupos musculares y equipamiento se representan con cadenas
  sin restricciones conocidas.
- Las consultas no definen todavía paginación ni una política general de orden.

### Configuración y publicación

- La URL y la clave pública de Supabase están acopladas a `main.dart`. La clave
  anónima no equivale a un secreto de servidor, pero la configuración impide
  separar desarrollo, pruebas y producción.
- Android usa todavía el identificador y metadatos iniciales del proyecto y el
  build `release` está firmado con claves de depuración.
- Web conserva título, descripción, colores e iconos por defecto de Flutter.
- No se ha preparado configuración de publicación para iOS o Windows.

Estos elementos de publicación no bloquean el dominio inicial, pero deberán
resolverse antes de distribuir la aplicación.

## Evaluación de la rama de Claude

### Material aprovechable

- Referencia visual de home, registro, perfil, ejercicios y rutinas.
- Primera aproximación a navegación anidada y sesión sin barra inferior.
- Estados de sesión y temporizadores que ayudan a concretar la experiencia.
- Casos de uso y consultas que revelan las operaciones que se imaginaron en la
  primera fase.

### Motivos para no fusionarla como arquitectura

- Una rutina es una lista plana de ejercicios con series, repeticiones, tiempo,
  peso y descanso; no expresa bloques, intervalos, circuitos ni composición.
- `session_logs` solo guarda un resumen global y pierde lo realizado por serie,
  intervalo o prueba.
- El temporizador suma un segundo por evento periódico; no calcula contra una
  referencia temporal y puede desviarse al suspenderse la aplicación.
- Una sesión en curso no se persiste ni se recupera.
- No existía sincronización offline ni protección contra duplicados. La nueva
  vertical de sesión lo resuelve con una cola persistente y recibos
  idempotentes en PostgreSQL; el hallazgo se conserva aquí como contexto de la
  rama histórica auditada.
- `requiresPremium`, `assigned_to` y `role` condensan conceptos comerciales y
  relaciones que deben tener ciclos de vida separados.
- Se repiten casts forzados entre entidades y modelos.
- El registro espera un tiempo fijo de 500 ms para confiar en la creación del
  perfil remoto, lo que introduce una carrera en vez de un contrato fiable.
- No hay pruebas del dominio ni de la sesión activa.

La rama no se eliminará. Los componentes visuales se podrán recuperar de forma
selectiva después de definir el dominio y los contratos correctos.

## Dependencias

La base tecnológica se mantiene en Flutter, Bloc/Cubit, `go_router`, GetIt,
Supabase y Material 3. Las dependencias directas se actualizaron a versiones
estables compatibles y el `pubspec.lock` quedó regenerado. Hay dependencias
declaradas todavía sin uso en `main`; se revisarán por necesidad, no mediante
una limpieza indiscriminada.

## Primer saneamiento completado

Sin depender todavía del backend remoto se han aplicado y verificado estas
correcciones:

- La aplicación inicia la comprobación de la sesión persistida al arrancar.
- El router posee y cancela su suscripción al estado de autenticación.
- La redirección autenticada queda centralizada en el router; la pantalla de
  login conserva únicamente la presentación de errores.
- Se han retirado las impresiones de perfil y correo.
- El repositorio de ejercicios convierte explícitamente una entidad de dominio
  a su modelo de datos, sin cast forzado.
- La búsqueda de ejercicio respeta su contrato nullable mediante
  `maybeSingle()`.
- Se ha implementado registro con nombre, correo y contraseña, contemplando
  tanto sesión inmediata como confirmación de correo pendiente.
- La configuración separa desarrollo y producción y evita usar el backend de
  desarrollo en una compilación declarada de producción.
- Se han añadido siete primeras pruebas para configuración, autenticación y
  conversión de ejercicios.

Verificación posterior: `flutter analyze` sin incidencias, siete pruebas
superadas, build web de producción y APK Android de depuración correctos.

## Orden aprobado de saneamiento

### P0 — recuperar un entorno verificable

1. Probar localmente la línea base y la migración de saneamiento; después marcar
   la línea base como aplicada y desplegar solo el saneamiento de forma
   controlada.
2. Reparar o actualizar Flutter en el Omnibook y conseguir que `doctor`,
   `analyze` y `test` terminen.
3. Instalar el flujo local de Supabase y una alternativa compatible con Docker.
4. Obtener el esquema remoto si existe; en caso contrario, diseñar un esquema
   inicial nuevo y reproducible.

### P1 — asegurar la base existente

1. Separar la configuración por entorno.
2. Versionar esquema, constraints, triggers, funciones y políticas RLS.
3. Corregir restauración y observación de autenticación.
4. Eliminar la carrera entre usuario y perfil.
5. Corregir contratos y mapeos de ejercicios.
6. Añadir pruebas de autenticación, mapeo, repositorios y router.
7. Actualizar Flutter y dependencias de forma incremental.

### P2 — primera vertical de producto

1. Definir con un caso PAEF/PAFA real la prescripción y el resultado.
2. Modelar sesión, bloques, ejercicios o intervalos y versionado.
3. Implementar persistencia y recuperación de una sesión en curso.
4. Registrar marcas y comparar con el baremo versionado.
5. Generar la primera recomendación determinista y explicable.

### Aplazado

- Chat, nutrición, desafíos e integraciones de actividad.
- Monetización real hasta estabilizar derechos y recursos protegidos.
- Academia y multi-tenancy hasta validar el espacio profesional.
- Firma y publicación final en tiendas.

## Información pendiente del equipo anterior

Si el Victus sigue accesible, solo interesa recuperar material no versionado:

- Archivos `.env` o valores de entorno usados realmente.
- Identidad del proyecto de Supabase y acceso a su panel.
- Exportaciones SQL, migraciones o notas sobre RLS y triggers.
- Claves de firma Android si llegaron a crearse.
- Cualquier recurso gráfico original no subido a Git.

No deben copiarse `build/`, `.dart_tool/`, cachés, SDK de Flutter ni carpetas de
dependencias. El entorno nuevo se reconstruirá de forma limpia y documentada.
