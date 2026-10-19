# Compacto: implementación compartida y cobertura de los creadores

Fecha de contraste: 19/10/2026. Decisión UI-059.

## Acuerdo y estado

Javier prefiere Compacto y pide coherencia en toda la app, conservar todas las
opciones y reutilizar los controles entre deportista y ADMIN. Solicita preview
antes de aplicar el cambio. Tras ver la propuesta ampliada autoriza el cambio
en toda la app y ADMIN. La implementación usa el tema y controles existentes;
no modifica contratos de guardado, dominio, permisos ni servidor.

La primera maqueta solo mostraba una superserie de ejemplo. Omitía el selector
de objetivo y otros formatos. Permitía variar series de una superserie de forma
independiente, aunque en el editor personal real dependen de las rondas. No es
una especificación funcional ni una implementación lista para trasladar.

## Fuente real y reutilización

- Deportista: `lib/features/workouts/presentation/pages/workout_editor_page.dart`
  y `running_workout_editor_page.dart`, con `WorkoutEditorCubit` y borradores.
- ADMIN: `admin_app/lib/features/workouts/presentation/admin_workout_editor_page.dart`,
  con modos de fuerza/carrera, versiones y contexto de calentamiento.
- Común: `packages/workout_editor_ui/lib/strength_set_fields.dart`,
  `running_step_fields.dart`, `workout_format_field.dart`,
  `workout_effort_field.dart`, `exercise_search_list.dart`, formateador temporal
  y `responsive_field_group.dart`.
- Modelos y validación deportiva: `packages/workout_core/`.
- Estilo y teclado: `packages/entrena_ui/`, incluido `EntrenaInputPolicy`.

Hoy se comparten modelos y controles, pero no hay una única pantalla completa
del creador. No se debe presentar lo contrario. El cambio de estilo debe
evolucionar los componentes existentes, sin crear otra implementación paralela.
Una eventual unificación de los contenedores requiere definir aparte estado,
acciones y adaptadores; esta elección estética no inicia esa refactorización.

## Inventario que debe conservarse

| Área | Opciones y comportamiento existente |
| --- | --- |
| Sesión | Nombre, descripción/indicaciones, duración estimada donde procede, edición existente, guardar y errores conservando entradas. Borrador recuperable en el editor personal y protecciones de salida. |
| Bloques | Nombre, formato, añadir/quitar, orden y traslado de ejercicios donde lo ofrece cada contenedor. Límites actuales, hasta diez bloques y cuarenta ejercicios en el personal. |
| Por series | Añadir/quitar series, objetivos independientes, igualar, repeticiones/tiempo/distancia, carga y descanso. RIR entero 0–10 o ausencia solo cuando corresponde. |
| Superserie | Dos ejercicios A1/A2, rondas, descanso entre rondas y objetivo de cada ejercicio en cada ronda. No inventar un contador independiente de series en el editor personal. |
| Circuito | Orden de estaciones, rondas, descanso entre rondas y transición entre estaciones en el editor personal, objetivos por ronda. |
| Intervalos de trabajo | Un ejercicio, número de intervalos, recuperación y objetivos por intervalo. La carrera conserva su recorrido específico. |
| Tabata | Ocho intervalos de 20 s/10 s, tiempos fijos y secuencia. Se conserva la representación distinta actual: el personal repite los movimientos hasta ocho; ADMIN dispone las posiciones. |
| EMOM | Vueltas, orden de minutos y objetivos por vuelta. Cada ejercicio ocupa un minuto; se conservan límites de duración/capacidad. |
| AMRAP | Límite global y objetivo por vuelta de cada movimiento, secuencia y reglas vigentes. No añadir descansos o contadores de series independientes. |
| Ejercicio | Selección/búsqueda de catálogo, filtros de origen y creación personal donde existen; cambiar, quitar, ordenar y mover entre bloques según el contenedor. |
| Carrera | Tramos por distancia o duración, repeticiones agrupadas, ritmo mínimo/máximo opcional, sin recuperación/pasiva/andando/trotando. Recuperación activa por duración o distancia y pasiva por tiempo. Añadir, ordenar, eliminar, repetir último en personal y crear pirámide. Estimación de duración existente. |
| ADMIN | Valores por defecto y personalizar cada serie; campos opcionales, originales/versiones y guardar/revisar según el contexto. Calentamientos reutilizan el editor existente con sus restricciones; no son un nuevo formato libre del selector convencional. Catálogo común y sesiones enlazadas desde programas conservados. |

El selector compartido ofrece siete formatos convencionales. `WorkoutBlockFormat`
contiene además `running`, `warmUp` y `coolDown`: no equivale a que existan diez
opciones libres en ese selector. No se deben añadir formatos a raíz de una
enumeración ni retirar contextos que no aparecían en la preview.

## Propuesta ampliada y sus límites

La preview de la conversación permite revisar Series, Formatos, Carrera y ADMIN.
El selector incluye los siete formatos; las rondas determinan el número de
objetivos donde corresponde, Tabata bloquea el tiempo y el RIR solo aparece con
repeticiones. Carrera muestra objetivo, ritmos y tipos/medidas de recuperación.
ADMIN ilustra los valores comunes y el acceso a la personalización por serie.

Es una maqueta local con datos de ejemplo. Las acciones de catálogo, guardado,
publicación y orden no sustituyen los flujos reales. No verifica todos sus casos,
validaciones, cambios de formato, decimales históricos o recuperación de errores.
Sus comprobaciones de ancho en navegador no acreditan Flutter ni teclado nativo.

## Implementación comprobada

- `EntrenaTheme` afecta a ambas apps: superficies rellenas, sin borde permanente,
  radios de 10 px, relleno menor y etiquetas/ayudas discretas. Foco y errores
  conservan sus contornos. Los botones siguen teniendo un mínimo táctil de 48 px.
- `StrengthSetFields` conserva propiedades/callbacks y calcula el espacio para
  valores y etiquetas. Admite hasta cuatro celdas por fila, redistribuye con texto
  ampliado o datos largos y limita el grupo a 520 px en escritorio. Unidades
  fuera del valor, con los relojes completos. Las entradas vacías siguen vacías.
- `WorkoutEffortField` usa el mismo decorador compacto en ambas apps y recorridos;
  conserva enteros, ausencia distinta de cero y valores históricos decimales.
  El guion del campo compacto tiene valor accesible «Sin registrar»; su panel
  mantiene la opción completa. No se redondean datos.
  Fuera de la tabla de series, las etiquetas largas de RPE/RIR se colocan sobre
  el control y pueden envolver varias líneas, sin volver al botón sobredimensionado.
- `CompactFieldLayout` comparte la distribución de formato/objetivo, alineada
  en línea cuando cabe y apilada con poco ancho o texto grande. El menú mantiene
  los siete formatos y sus restricciones.
- El editor personal retira las cajas anidadas en secuencias, ejercicios y series;
  conserva contadores, igualación, acciones, borrador y protección de salida.
- ADMIN mantiene valores por defecto, personalización y calentamientos. Se
  corrigen títulos que competían con acciones y etiquetas que se recortaban con
  texto doble. «Fuerza» nombra el selector que incluye los siete formatos;
  las unidades y «entre rondas» se trasladan a la ayuda cuando es necesario.
- Carrera comparte la nueva densidad, con dos columnas cuando caben y una
  cuando se necesita; conserva distancias, tiempos, ritmos y recuperación.
- Las cabeceras de los tres editores pueden crecer con texto ampliado.
- Acceso desplaza sus ejemplos a la ayuda cuando el texto está ampliado, y la
  cabecera de evaluación Tropa crece para conservar el título completo.
- La política UI-057 no cambia: toque exterior, paso entre campos, accesorios,
  desplazamiento, diálogos y paneles siguen cubiertos. El cierre de teclado no
  consume el botón pulsado ni descarta entradas.

## Verificación y evidencia

| Proyecto | Análisis | Batería completa |
| --- | --- | --- |
| Deportista | `flutter analyze --no-pub`, limpio | 1.084 correctas; una omisión existente |
| ADMIN | `flutter analyze --no-pub`, limpio | 220 correctas; dos capturas optativas omitidas |
| `workout_editor_ui` | `flutter analyze --no-pub`, limpio | 32 correctas |
| `entrena_ui` | `flutter analyze --no-pub`, limpio | 13 correctas |

Las regresiones nuevas miden el ancho de los valores editables y las etiquetas,
incluyen errores y valores largos, anchos útiles 220–600 px y texto normal/doble.
Los formularios reales se comprueban a 320, 390 y 1024 px; el editor personal
recorre los siete formatos a 320/390 y ambos tamaños de texto. Carrera tiene
recorrido propio. ADMIN comprueba los siete formatos, carrera y calentamientos
a 390/1×, 320/2× y 1100/1×, guardando y contrastando todos los valores de la
prescripción: objetivos, cantidades, cargas, RIR antiguo, descansos y ritmos/
recuperaciones. Se verifican campos que se construyen al desplazar, no solo
la ficha inicial. Las pruebas previas de borrador, errores y edición se mantienen.

Se generan capturas desde widgets Flutter reales con repositorios ficticios,
sin cuentas ni escrituras remotas. Las muestras guardadas solo reducen escala y
agrupan pantallas; no reconstruyen controles con otra tecnología:

- [Editor y carrera](visual-audit/compacto-2026-10-19/app-editor-carrera.jpg).
- [Acceso y registro de marcas](visual-audit/compacto-2026-10-19/app-formularios.jpg).
- [ADMIN en escritorio](visual-audit/compacto-2026-10-19/admin-editor.jpg).
- [Pantalla estrecha y texto doble](visual-audit/compacto-2026-10-19/texto-ampliado.jpg).

Las capturas individuales se reproducen con `CAPTURE_PERFORMANCE_REVIEW=true`
en `test/core/presentation/app_input_layout_audit_test.dart`,
`test/features/workouts/presentation/workout_editor_cubit_test.dart` y
`admin_app/test/features/workouts/presentation/compact_workout_editor_test.dart`.
Se escriben en `build/performance_v2_review/` de la app correspondiente.

## Límite pendiente: dispositivos físicos

### Publicación web y preparación iPhone · 19/10/2026

ADMIN sirve Compacto en `https://admin.entrenaop.es/`, revisión
`1ac37816c2749d71680e26a62d6531fafb8ccb96`, que incluye `6e32099`.
La ejecución [39252195710](https://github.com/jchjdev/entrenaop/actions/runs/39252195710)
termina correctamente en su segundo intento. El primer despliegue de Compacto
se detuvo porque `main` había avanzado; la primera publicación de la revisión
actual falló con un error de transporte y pasó al reintentar solo ese trabajo.
No fue un fallo de las pruebas ni de la compilación. Se contrastan por HTTPS
el manifiesto, SHA-256 del JavaScript, entrada versionada, cabeceras y MIME de
WebAssembly. [Manifiesto servido](visual-audit/compacto-2026-10-19/admin-served-build-info.json).

El Mac se actualiza hasta esa revisión mediante fast-forward, conservando sus
ajustes locales de Xcode y las resoluciones SPM. La compilación Release sin
firma pasa con `APP_ENV=development`, sin la clave de compras Test Store.
La firma desde SSH falla con `errSecInternalComponent`; se utiliza Xcode con
el esquema existente `Runner iPhone` y destino `Iphone-JVR`. El resultado de
instalación se registra en [la guía iOS](IOS_DEVELOPMENT.md).

Recorrido de aceptación en el teléfono, con texto normal y ampliado:

1. Crear/editar una sesión: escribir tiempo, descanso, repeticiones y carga;
   comprobar valores completos, RIR y etiquetas. Añadir, quitar e igualar series
   debe actualizar tanto el contador como los campos visibles.
2. Tocar una zona vacía y desplazar la página: el teclado debe cerrarse. Pasar
   directamente a otro campo debe mantener la edición; el botón tocado debe
   ejecutar su acción al primer toque.
3. Abrir los formatos disponibles, descansos entre rondas y transiciones;
   comprobar también carrera, notas largas y un panel de RIR abierto/cerrado.
4. Revisar acceso, marcas/calculadora y otros formularios usados habitualmente.
   Volver atrás debe cerrar el teclado; valores, ayudas y acciones inferiores
   deben seguir accesibles sin solaparse.

Compilar, instalar o arrancar no acredita por sí solo este recorrido físico.

`flutter devices` solo encuentra Windows, Chrome y Edge en este equipo. Las
pruebas de foco/ocultación se ejecutan con el entorno de texto de Flutter,
incluyendo las variantes iOS/Android. No sustituyen comprobar el teclado nativo
en un iPhone y Android reales. Ese es el siguiente paso de aceptación.

Los nombres editables largos admiten desplazamiento horizontal y las notas su
desplazamiento vertical; no se promete que ochenta caracteres quepan en una
sola línea móvil. Los valores numéricos y relojes de las pruebas deben caber
completos sin ese desplazamiento. Tampoco se acredita cada combinación de
contenido remoto de todos los recorridos de la aplicación por estas capturas.

La revisión general de la app debe conservar la identidad Compacto, con anchos
adecuados al dato y texto largo disponible. No se impone un ancho estrecho a
nombres/descripciones ni una altura fija que falle con accesibilidad.
