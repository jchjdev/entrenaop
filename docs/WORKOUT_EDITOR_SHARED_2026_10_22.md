# Creador común de sesiones · INT-008 · 22/10/2026

Javier pide corregir los creadores de deportista, ADMIN y Trainer como un único
componente. ADMIN y Trainer ya consumían `WorkoutEditorPage` de
`packages/workout_editor_ui`; el deportista conservaba formularios propios de
carrera y fuerza, aunque reutilizaba algunos campos. Esta entrega sustituye
esos dos formularios por adaptadores al mismo creador.

## Responsabilidades

| Parte | Responsabilidad |
| --- | --- |
| `workout_core` | Receta tipada, validación y codificación ya existentes. |
| `workout_editor_ui/WorkoutEditorPage` | Formulario de carrera/fuerza, búsqueda, series, formatos, agrupación y protección de salida. |
| `WorkoutEditorSnapshot` | Estado de formulario incompleto y proyección común hacia la receta. Se mantiene schema 1. |
| `workoutEditorStateFromInput` | Adaptación de borradores personales anteriores al formulario común, conservando valores por serie. |
| `PersonalWorkoutEditor` | Catálogo personal autorizado, recuperación local, acceso Pro y guardado mediante el Cubit/repositorios existentes. |
| Adaptadores ADMIN/Trainer | Catálogos y permisos propios, publicación/revisión, trabajo durable y navegación existentes. |

Las rutas personales anteriores siguen existiendo; sus páginas solo montan el
adaptador personal. No se importan aplicaciones entre sí. El formulario no
consulta Supabase, no comprueba roles ni concede derechos; cada consumidor y
el servidor siguen siendo responsables de su acceso y persistencia.

La entrada personal de carrera/fuerza mantiene su modalidad. ADMIN y Trainer
conservan el selector existente. Una mejora del formulario común llega a las
tres aplicaciones; sus servicios, catálogos, cuotas y permisos siguen separados.

## Borradores y regresiones corregidas

- Los borradores personales previos siguen leyéndose con su receta tipada.
  Al recuperar uno, se adapta al mismo formulario sin perder series, ritmos,
  recuperaciones ni variaciones de carga/RIR/descanso.
- El almacén local por cuenta añade opcionalmente `editor` con los textos del
  formulario. Permite conservar campos incompletos; `input` mantiene la última
  proyección recuperable para compatibilidad y no se publica automáticamente.
- Las escrituras locales se serializan. Antes del guardado final se espera a
  las pendientes; una escritura antigua no resucita el borrador después de
  guardar la sesión y limpiarlo. Se conserva guardado al salir y al suspender.
- Un estado incompatible o de otra modalidad se conserva sin sobrescribirlo.
- Las excepciones por serie creadas durante build se observan desde su primer
  cambio: ya no dependen de otro rebuild para disparar el autoguardado.
- Al revisar una sesión o recuperar un borrador, una serie sin carga/RIR no
  hereda accidentalmente el valor de otra. Se adapta el valor común y las
  excepciones para conservar también la ausencia explícita.
- Búsqueda y creación de ejercicios propios siguen disponibles. Los filtros
  `EntrenaOP/Míos` son etiquetas del catálogo que aporta el consumidor, sin
  ampliar acceso. Las superseries mantienen posiciones A1/A2.
- Carrera incorpora en el creador común repetición del último tramo, recuento
  expandido y rango de duración estimada. El límite de cuarenta se comprueba
  sumando todas las tarjetas, no solo el contador de cada una.

La entrega INT-008 conservó bindings durables, revisión, intención congelada,
recibos y RPC de ADMIN/Trainer, sin cambios SQL. INT-009 amplía después la
persistencia y validación de pasos, manteniendo las autoridades existentes.
[Estado actual de carrera V2](RUNNING_STEPS_V2.md).

## Creador de carrera compacto · INT-011

El 22/10/2026 Javier señala el exceso de desplazamiento y la conversión visible
de una recuperación en otro paso. Se contrasta el editor abierto de Garmin
Connect sin modificar ni guardar su sesión. La solución común a deportista,
ADMIN y Trainer incorpora:

- Resumen de cada tramo con fase, tiempo/distancia/Lap, objetivo y recuperación.
  Solo se abre uno. Las diez parejas iguales se presentan como una tarjeta
  «Carrera × 10», más calentamiento y enfriamiento.
- Selectores «Sin objetivo / Ritmo». Elegir libre elimina ambos límites de ese
  trabajo o recuperación; los campos ocultos no siguen enviando un ritmo viejo.
  No se anuncian pulso/cadencia/potencia como opciones funcionales.
- Recuperación dentro de la misma tarjeta, con tipo, finalización y objetivo
  propios. Cambiar su objetivo o finalizarla manualmente usa internamente los
  pasos V2 existentes, sin botón de conversión ni otra tarjeta visible.
- Repeticiones por tramo, omisión explícita de última recuperación y menú para
  añadir debajo, duplicar, mover, eliminar o editar repeticiones por separado.
  Una variación conserva su pauta y no se fusiona con las demás.
- Error de un paso plegado abre su tarjeta. Plegar/desplegar no ensucia el
  borrador ni provoca guardados. Un objetivo de ritmo vacío impide guardar.

`running_editor_groups.dart` opera sobre snapshots y devuelve índices originales;
`running_step_card.dart` presenta el resumen. No crea un modelo deportivo nuevo.
La receta publicada sigue plana, el snapshot conserva schema 1 y no hay cambios
SQL, SDK, algoritmo, permisos o bindings de Trainer. Al reabrir se agrupan solo
pasos semánticamente iguales; las excepciones permanecen separadas. La omisión
se reconoce tanto en pasos V2 independientes como en recuperaciones asociadas.
El máximo de cuarenta sigue aplicándose a pasos expandidos, no a tarjetas.

Se revisan capturas sintéticas del widget real en escritorio y móvil, incluyendo
texto 2×. Las regresiones cubren plegado sin autoguardado, edición de diez parejas,
objetivos libres, excepción individual, omisión y recuperación/publicación de
las recetas anteriores. Las pruebas de consumidores abren los nuevos resúmenes
antes de editar, manteniendo sus verificaciones de prescripción y permisos.
Resultado local INT-011: análisis de raíz, ADMIN y Trainer sin incidencias;
1.294 pruebas raíz correctas (una omisión previa), 314 ADMIN (dos previas),
170 Trainer y 189 del paquete común. Compilación web Release de Trainer Dev
correcta. No se ejecutan migraciones ni se despliegan funciones por este cambio.

Esta entrega requiere actualizar la app iOS para usar el nuevo creador local;
no acredita todavía la siguiente prueba física en el fēnix.

### Reordenación por arrastre · 23/10/2026

Javier pide poder coger las tarjetas y moverlas dentro de la carrera. El asa
lateral permite arrastrar con ratón o dedo; el encabezado sigue abriendo/cerrando
el tramo y el menú mantiene Subir/Bajar como alternativa accesible. Una línea
indica el punto de inserción y el formulario se desplaza en sus bordes.

La serie mueve juntas sus repeticiones y recuperaciones, incluida la última
omitida. Se mueven los controladores existentes: conserva texto incompleto,
objetivo seleccionado y tarjeta abierta. Cancelar no cambia la receta ni guarda
un borrador. Solo al aceptar se cambia el orden, que pasa al guardado común.

`RunningReorderableSteps` usa los controles de arrastre de Flutter y el scroll
exterior del consumidor. No introduce un scroll anidado que impida recorrer
listas largas en formularios incrustados. No cambia snapshot, contrato deportivo,
SQL, permisos ni exportadores; el envío interpreta el orden guardado existente.
Pruebas de ratón/tacto en móvil y escritorio, omisión, guardado por cuenta,
cancelación, valores incompletos y desplazamiento del formulario exterior.

Verificación del arrastre: análisis sin incidencias en raíz, ADMIN y Trainer;
1.294 pruebas raíz correctas (una omisión previa), 314 ADMIN (dos previas),
170 Trainer y 196 del creador común. Capturas sintéticas del widget real durante
el arrastre y revisiones responsivas a 320/390/1200 px, también texto 2×.

Distribución del arrastre comprobada el 23/10/2026: código funcional
`f050b4227ce9f4cfc6404b9c80ea07228ee37018` guardado en main. Javier autoriza
expresamente publicar esta ampliación en Trainer Dev. Paquete
`build/trainer-drag-20261023.zip`, versión
`f050b4227ce9f4cfc6404b9c80ea07228ee37018-20261023-1`, SHA-256
`b82fa25f43eb3211150b7c84e41f357f9ecb50fe02658e7a0f4d457456e0280a`.
Se carga y extrae solo en `public_html/trainer`, conservando versiones previas.
El verificador acredita revisión, JavaScript, arranque, cabeceras y WebAssembly
por HTTPS. Una pestaña nueva abre la biblioteca profesional existente; no se
modifican sus sesiones reales durante la comprobación.

[CI Garmin 39906487372](https://github.com/jchjdev/entrenaop/actions/runs/39906487372)
correcta en backend, consumidor y compilación iOS Release sin firma.
[CI ADMIN 39906487330](https://github.com/jchjdev/entrenaop/actions/runs/39906487330)
correcta en validación, publicación y retención automática. Los manifiestos de
ADMIN y Trainer Dev sirven `f050b422` exclusivamente en desarrollo.
La entrega de arrastre queda distribuida; el siguiente recorrido continúa
siendo la aceptación física de la receta en fēnix. La app del iPhone necesita
actualización desde main para incorporar el asa en su creador local.

### Distribución comprobada de INT-011

Código funcional `9deb71a4db25faaa05ff24bb20295aa15a9011f1` subido a main.
La [CI Garmin 39859543902](https://github.com/jchjdev/entrenaop/actions/runs/39859543902)
termina correctamente en backend, consumidor y compilación iOS Release sin firma.
La [ejecución ADMIN 39859543838](https://github.com/jchjdev/entrenaop/actions/runs/39859543838)
supera validación y publicación. El manifiesto HTTPS acredita la revisión
`9deb71a4` y la versión `9deb71a4db25faaa05ff24bb20295aa15a9011f1-39859543838-1`
exclusivamente en Dev.

El primer intento del job auxiliar `retain-packages` falla con `HTTPError`,
antes de imprimir su plan. El 23/10/2026 Javier autoriza expresamente reintentar
solo ese paso y publicar el paquete validado de Trainer Dev. El reintento
(job 120251390252 de la misma ejecución) termina correctamente: conserva los
cinco compilados recientes, incluida la revisión publicada, y elimina un único
compilado antiguo de 15.921.775 bytes. La CI ADMIN queda completamente correcta.
No se cambia el mecanismo de retención ni se repiten pruebas o despliegues.

Trainer Dev publicado el 23/10/2026: paquete
`build/trainer-compact-20261022.zip`, revisión `9deb71a4`, versión
`9deb71a4db25faaa05ff24bb20295aa15a9011f1-20261022-1`, SHA-256
`2d80b003f7e11dcea06f21833d9828d6d98964aa819dd28097c3e40f28765ee5`.
Carga privada en `trainer-releases` y extracción únicamente en
`public_html/trainer`, conservando publicaciones anteriores. El verificador
HTTPS acredita manifiesto, revisión, SHA-256 del JavaScript, arranque versionado,
cabeceras y MIME WebAssembly. Una pestaña nueva abre el panel profesional con
su acceso existente; no se recarga ni guarda la sesión real abierta del usuario.
La captura de comprobación permanece local y no se suben datos de alumnos a Git.
La distribución Dev de INT-011 queda completada. La siguiente aceptación
funcional continúa siendo física en el fēnix.

## Límites y siguiente bloque

El creador guarda un bloque `running` con tramos individuales. Desde INT-009,
cada paso puede conservar semántica V2 de fase y finalización, incluida manual,
en receta, borradores y ejecución. Las sesiones antiguas siguen admitidas.
La siguiente comprobación es física: transiciones y avisos de la nueva receta
en el fēnix. [Implementación y límites](RUNNING_STEPS_V2.md).

La fuerza se crea y revisa con el mismo formulario, pero su exportación a Garmin
sigue pendiente del adaptador de ejercicios/series y de una matriz de capacidad.
No se habilita por esta entrega el envío de sesiones personales: INT-006 sigue
limitando el primer envío a pautas autorizadas del algoritmo o entrenador.

## Siguiente contrato de carrera INT-009

Javier confirma el 22/10/2026 que EntrenaOP debe mantener su propio modelo de
sesión y traducirlo mediante adaptadores por proveedor. El contrato separará:

| Concepto | Significado previsto |
| --- | --- |
| Tipo de paso | Calentamiento, carrera, recuperación, descanso y enfriamiento. Conservar también la distinción deportiva existente entre caminar y trotar. |
| Finalización | Tiempo, distancia o avance manual; este último se presenta como Lap en Garmin, sin introducir esa marca en el dominio. |
| Objetivo | Libre, ritmo, frecuencia cardiaca, cadencia o potencia, con unidades y límites explícitos; las zonas deberán distinguirse de los valores absolutos. |

Las repeticiones conservan el orden de sus pasos y recuperaciones. La receta,
su versión y sus valores originales son la fuente de verdad, también cuando
un proveedor requiera otra representación. No se sustituyen rangos por medias
ni se estiman condiciones de fin manual para fabricar una duración total.

Cada adaptador declarará las capacidades contrastadas: lectura, envío y tipos
de paso, finalización y objetivo admitidos. Antes de entregar, una evaluación
común indicará compatibilidad o los motivos concretos que impiden enviar.
Una adaptación que cambie la pauta requerirá elección explícita; nunca se
suprimen pasos silenciosamente. No se presume que todas las opciones del
creador de Garmin Connect estén disponibles por API ni en todos los relojes.

Secuencia acordada: los puntos 1–2 se implementan en [Carrera V2](RUNNING_STEPS_V2.md);
los puntos 3–4 continúan pendientes:

1. Versionar el contrato de receta y concretar compatibilidad con las sesiones
   anteriores, validación, borradores, almacenamiento y ejecución. Evitar otra
   receta exclusiva de Garmin o una capa de modelos distinta por aplicación.
2. Completar una primera vertical común con los tipos de paso, fin por tiempo,
   distancia o avance manual y objetivos libre/ritmo. Verificar guardado y
   recuperación en deportista, ADMIN y Trainer y traducción Garmin en Dev.
3. Comparar la receta y el detalle del fēnix: calentamiento hasta Lap,
   repeticiones de trabajo/recuperación y enfriamiento hasta Lap; comprobar
   transiciones y ambos límites de las alertas de ritmo.
4. Incorporar frecuencia cardiaca, cadencia y potencia con sus unidades,
   validaciones y capacidades verificadas. Mantener deshabilitada cualquier
   opción todavía no implementada de extremo a extremo.

La primera vertical modifica SQL de forma aditiva y se verifica en Dev.
Mantiene permisos, algoritmo y autoridades de publicación. Otras marcas,
nuevos objetivos y fuerza conservan sus adaptadores y pruebas pendientes.

## Fuerza compacta · UI-061

Javier solicita el 23/10 aplicar a fuerza el patrón visual aceptado en carrera.
Los siete formatos conservan sus reglas: Por series, Superserie, Circuito,
Intervalos, Tabata, EMOM y AMRAP. Cada bloque tiene color y nombre explícito,
resumen plegable de formato/dosis/ejercicios y menú con subir, bajar, duplicar
y quitar según sus límites. Se abre inicialmente el primer bloque; abrir otro
pliega el anterior, y añadir/duplicar abre el nuevo. Los ejercicios siguen
editándose dentro de su bloque, con sus campos y ajustes por serie existentes.

El asa permite arrastrar bloques completos y ejercicios dentro de un bloque
con ratón o dedo sobre el scroll del consumidor. Se conservan subir/bajar y
los límites de ejercicios/formatos. No se mueven ejercicios entre bloques con
formatos distintos mediante arrastre, para evitar reinterpretar su dosis.

`WorkoutEditorCard` y `WorkoutReorderableCards` extraen los componentes ya
probados de carrera; sus fachadas conservan claves y nombres accesibles de
carrera. En móvil y con texto grande las acciones ocupan su propia fila,
evitando estrechar el resumen hasta partir palabras. Los resúmenes largos
admiten tres líneas; la receta completa sigue en el editor desplegado.
Se mueve la identidad del bloque/ejercicio con todos sus controladores, no se
reconstruye desde una proyección que eliminaría entradas incompletas. Plegar y
cancelar un arrastre no ensucian el borrador; soltar un orden nuevo activa la
persistencia existente. No cambia schema 1, codecs, SQL, permisos, SDK ni
bindings de cada aplicación, y no se añaden dependencias.

Las regresiones incluyen los siete formatos, conservación de ajustes por serie,
arrastre táctil de una superserie, cancelación sin escritura, controlador
incompleto que conserva identidad y capturas a 320/1200 px con texto 1×/2×.
La prueba anterior de duplicación/cambio de Tabata mantiene sus aserciones de
receta y usa ahora el menú de cabecera. La distribución de esta ampliación
se registra tras la validación; no queda publicada por una autorización de
otra revisión. El envío de fuerza a Garmin conserva su bloque pendiente.

Comprobación local del 23/10/2026: análisis de raíz, ADMIN y Trainer limpios;
1.294 pruebas raíz (una omisión previa), 314 ADMIN (dos previas), 170 Trainer y
212 del paquete compartido correctas. Revisión de capturas sintéticas del
widget real: siete formatos plegados en escritorio, superserie a 320 px/texto
2× y acciones del ejercicio central de un circuito sin desbordamiento. El
selector de objetivo de fuerza admite varias líneas con texto grande y usa
«Tiempo». Compilación web Release Dev de Trainer correcta. La aceptación
manual del creador de fuerza en navegador/móvil sigue pendiente; esta UI no
modifica ni reenvía la sesión de carrera realizada.

Javier autoriza expresamente la publicación de fuerza en Trainer Dev. Código
funcional `e2294d73fa5106dc08db2046c5c382c9c96308dc`, paquete
`trainer-strength-20261023.zip`, SHA-256
`4dc1054e0751b6a16f749e28796a5da90a94c8454b2da9fe4de67ed7fca7e5ae`.
Se publica el 23/10/2026 únicamente en `public_html/trainer`, conservando las
versiones anteriores. El verificador HTTPS confirma revisión, entorno Dev,
JavaScript, arranque y cabeceras; Chrome carga Inicio y Sesiones. No se crean,
modifican ni asignan sesiones durante esta comprobación. Captura privada local,
sin incluirla en Git. La aceptación manual de fuerza sigue pendiente.

La [CI Garmin 39926567864](https://github.com/jchjdev/entrenaop/actions/runs/39926567864)
termina correctamente en servidor, consumidor e iOS Release sin firma. La
[CI ADMIN 39926567729](https://github.com/jchjdev/entrenaop/actions/runs/39926567729)
termina correctamente en validación, publicación y retención. El manifiesto
HTTPS de ADMIN confirma la misma revisión `e2294d73`, entorno de desarrollo y
release `e2294d73fa5106dc08db2046c5c382c9c96308dc-39926567729-1`.
La compilación iOS no acredita instalación física de esta nueva UI.

## Verificación y distribución

Se comprueban deportista, ADMIN, Trainer y paquete compartido, incluyendo
formatos, regreso al router, cuotas, selección/creación de ejercicios, borradores
y conversión reversible. Las pruebas se adaptan a los controles del formulario
compartido conservando sus casos de negocio; no se mantienen selectores de los
formularios retirados. Las pruebas nuevas cubren también escrituras pendientes
frente al guardado final y series con valores opcionales ausentes.

La CI de Garmin incluye ahora los cambios del creador/receta, sus regresiones y
la compilación iOS Release sin firma. No equivale a instalar la app en un móvil.
Para probar la nueva interfaz en iPhone: Fetch/Pull de `main` en el Mac,
`bash tools/prepare_iphone_dev.sh`, esquema Runner iPhone y ejecución en el
dispositivo. La recepción Garmin del bloque anterior no acredita esta nueva UI.

Resultado local del 22/10/2026: análisis limpios de raíz, ADMIN y Trainer;
1.279 pruebas raíz correctas (una omisión previa), 314 ADMIN (dos omisiones
previas), 170 Trainer y 155 del paquete común. Se mantienen los casos de edición
personal y se añaden recuperación de estados incompletos por cuenta, conversión
de todos los formatos, ausencia de valores por serie y suspensión durante un
guardado pendiente. Revisión de dos capturas sintéticas del widget real de
carrera a 390 px; pruebas responsivas también a 320 px y texto 2×.

### Publicación Dev y CI de la revisión f12df112

Javier autoriza expresamente publicar el paquete validado en Trainer Dev.
El 22/10/2026 se extrae únicamente en `public_html/trainer` la versión
`f12df1129d12d4b17c8cefd9c7662336a06f72e4-20261022-1`, conservando las
versiones anteriores. El verificador HTTPS confirma revisión, proyecto Dev,
SHA-256 del JavaScript, arranque versionado, cabeceras y MIME WebAssembly.
Chrome carga el panel profesional y su biblioteca de sesiones. No se crean
cuentas, sesiones ni asignaciones durante esta comprobación.

La CI Garmin [39812426828](https://github.com/jchjdev/entrenaop/actions/runs/39812426828)
termina correctamente en backend, consumidor y compilación iOS Release sin
firma. ADMIN [39812426894](https://github.com/jchjdev/entrenaop/actions/runs/39812426894)
supera su validación; la primera publicación falla con `OSError` de transporte
con Hostinger. El reintento solo del trabajo fallido publica y verifica ADMIN
correctamente a las 16:31 UTC; el manifiesto HTTPS confirma `f12df112` y la
versión `f12df1129d12d4b17c8cefd9c7662336a06f72e4-39812426894-1`.
