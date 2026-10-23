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
