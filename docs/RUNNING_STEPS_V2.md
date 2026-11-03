# Pasos de carrera V2 · INT-009 · 22/10/2026

Aceptación física del 23/10: pauta de Trainer recibida y realizada con fēnix 8,
cinco trabajos, recuperaciones, calentamiento hasta Lap y alertas confirmados
por Javier. El enfriamiento de esta pauta era temporizado; enfriamiento hasta
Lap y ciclo automático de cambios/cancelaciones conservan pruebas pendientes.
[Contraste de receta, entrega y actividad](DEVICE_GARMIN_TRAINING.md#carrera-física-completa--23102026).

## Recorrido implementado

El creador común de deportista, ADMIN y Trainer permite definir calentamiento,
carrera, recuperación, descanso, enfriamiento, caminar y trotar. Cada paso
termina por tiempo, distancia o avance manual. El objetivo de intensidad de esta
primera entrega es libre o un ritmo/rango; pulso, cadencia, potencia y zonas
siguen pendientes y no se muestran como capacidades disponibles.

Las series mantienen el orden y la recuperación final. La referencia es:
calentamiento hasta avance manual → cinco series de 400 m con ritmo y
90 s de recuperación → enfriamiento hasta avance manual. Se guardan siete
tramos con cinco recuperaciones asociadas; se conservan doce pasos expandidos
para resultados. Desde el 03/11 la exportación puede representar sus repeticiones
idénticas mediante `WorkoutRepeatStep`, sin cambiar esa secuencia ni el límite de
cien pasos incluyendo recuperaciones.

## Repeticiones nativas al exportar · 03/11/2026

En el lenguaje de producto se habla de series de carrera. Aquí «repetición»
designa la repetición técnica de un patrón al exportarlo, sin confundirla con
las repeticiones dentro de una serie de fuerza.

El compilador común añade `repeatBlocks` opcional: inicio sobre los pasos
expandidos, tamaño del patrón, vueltas y omisión de la recuperación final. Se
deriva dentro de cada elemento original; no cruza elementos o bloques, ni agrupa
objetivos, notas, fases, ritmos o medidas distintos. La validación comprueba que
expandir el grupo reproduce exactamente la pauta. No se guarda un árbol nuevo,
ni se cambia el editor compartido o el hash de sus snapshots.

- Garmin usa `WorkoutRepeatStep`, `REPEAT_UNTIL_STEPS_CMPLT`, `repeatValue` y
  `skipLastRestStep` del contrato oficial Training API V2. Los órdenes siguen
  siendo únicos incluyendo el contenedor. Una pauta de diez parejas idénticas
  pasa como diez vueltas, conservando su recuperación final real.
- Apple usa los mismos metadatos para `IntervalBlock(steps:iterations:)`. Sin
  omisión, diez parejas son un bloque con diez vueltas. Cuando se omite la última
  recuperación, se exportan nueve vueltas completas y el trabajo final separado:
  WorkoutKit no ofrece el mismo interruptor de Garmin y no se inventa un descanso
  de cero segundos para forzar el contador. La presentación exacta es de Apple.
- Los resultados mantienen pasos expandidos y mediciones originales. El lector
  Apple compara exactamente tanto con la composición nueva como con la anterior;
  no convierte una falta de referencia en una asociación por nombre o fecha.
- Las nuevas entregas Garmin y los cambios de pauta usan esta traducción. No se
  fuerza el reenvío de recetas ya ejecutadas ni se modifica el recibo para fingir
  una actualización física. Una pauta Garmin previamente enviada sin cambios
  conserva su representación hasta su siguiente entrega/actualización real.
- La agenda automática Apple puede detectar el contenido local anterior y
  actualizar pautas pendientes con el mismo UUID; respeta las ya completadas.

La revisión de la pauta de prueba acredita diez trabajos de 400 m y diez
recuperaciones de 45 s; el formato plano explica la falta de contador observada.
No se usa esa carrera como fixture público ni se cambia su pauta o historial.
Javier confirma físicamente en el fēnix la prueba corta: «repetir ×3» en la vista
previa y 1/3, 2/3 y 3/3 durante la ejecución. El contador Garmin queda aceptado;
el de Entreno de Apple sigue pendiente. Tras guardar, llega el aviso automático
Garmin, pero el importador rechaza el archivo con `invalid_activity` antes de
guardar sus datos. El retorno de todas las vueltas sigue pendiente de contrastar
el original; la aceptación del contador no acredita la importación.

Validación de esta entrega: análisis Flutter sin incidencias, 1.734 pruebas de
raíz correctas y una omisión previa; 262 de servidor, incluida equivalencia de
150 secuencias variadas, y tipos TypeScript estrictos. El canal Apple comprueba
que programación, inspección y lectura reciben el mismo patrón y que una receta
antigua no exige metadatos nuevos. No se cambia SQL ni permisos. En Dev quedan
ACTIVE `garmin-training` v20, `garmin-training-sync` v15 y `apple-training` v8,
con fuentes contrastadas y rechazo 401 sin autorización; Apple conserva JWT
obligatorio y Garmin su autenticación propia. Versión móvil `1.4.0+7`;
compilación iOS y aceptación física se acreditan aparte.

La [CI de `f2da2dec`](https://github.com/jchjdev/entrenaop/actions/runs/41611318159)
finaliza correctamente en servidor, consumidor e iOS Release sin firma.
También pasan las 16 pruebas del paquete de Salud. La comprobación sintética de
retorno mantiene las diez parejas aun cuando se repiten índices nativos de paso;
las vueltas partidas o la presentación física requieren su evidencia del reloj.
Sigue pendiente la aceptación del contador y del retorno de una pauta nueva.

En la aceptación del creador, Javier confirma que la sesión muestra sus fases y
series con recuperaciones. Los selectores compartidos pasan a decir «Tiempo»;
los valores y unidades conservan el contrato anterior. Javier confirma dos
necesidades para fartlek y solicita además omitir la última recuperación:

- «Editar recuperación como paso» desdobla cada pareja de trabajo/recuperación
  sin alterar su orden, repeticiones, tiempo o distancia. El paso suave tiene
  sus propios campos de ritmo; el pasivo conserva tipo descanso y objetivo libre.
- «Repetir grupo» permite seleccionar desde/hasta tramo y las vueltas totales,
  incluyendo la primera. Se expande en pasos individuales editables. Guardar,
  reabrir, ejecutar y exportar usan esa misma secuencia V2, sin un árbol nuevo
  ni agrupación inferida al reabrir. El máximo actual sigue siendo 40 tramos.
- «Omitir última recuperación» está desactivado por defecto. Solo se habilita
  cuando la selección termina en una recuperación asociada o un paso suave.
  Retira exclusivamente esa última recuperación de la última vuelta: no borra
  la serie ni modifica calentamiento o enfriamiento. El resultado se guarda
  como la dosis elegida; el exportador no decide omisiones.

La referencia adicional es calentamiento Lap → 3 × (4 min a 4:10–4:25/km +
3 min suaves a 5:00–5:20/km), omitiendo la última recuperación → enfriamiento
Lap: siete pasos en total. Sin omitirla son ocho. Son valores de un ejemplo de
aceptación, no una nueva pauta creada o enviada a una cuenta real.

La ampliación mantiene el esquema, las RPC, snapshots y funciones desplegadas:
son acciones puras sobre el formulario común que proyectan recetas ya admitidas.
No se modifica la arquitectura profesional ni se añaden permisos o dependencias.

El envío con selección y confirmación de cada cita es el recorrido de ensayo.
La experiencia de producto esperada es vincular la cuenta y entregar las pautas
autorizadas automáticamente, conservando en servidor autoridad, versión,
compatibilidad y recibos. Antes de activarla hay que resolver cómo actualizar o
retirar sesiones ya enviadas y conciliar resultados inciertos; el servicio actual
no implementa aún ese ciclo. La sincronización del dispositivo con Garmin Connect
es un tramo distinto de la entrega de EntrenaOP al calendario Garmin.

## Contrato y fronteras

| Parte | Contrato |
| --- | --- |
| `workout_core/running_step.dart` | Tipo de paso y finalización propios de EntrenaOP, sin SDK ni nombres del fabricante. |
| `running_step_codec.dart` | Representación `running_step = {schema_version: 2, kind, completion}` separada del dominio. |
| Receta y formulario | `WorkoutTargetType.manual` carece de medida prescrita; el cero neutro del borrador no se serializa como tiempo o distancia. |
| SQL | Columna JSONB aditiva en `workout_sets` y `workout_execution_sets`, validación contra sus medidas y snapshot inmutable. |
| Ejecución/historial | Conservan el tipo, explican el avance manual y registran resultados reales. Un descanso explícito admite cero metros. |
| Puerto de envío | El adaptador declara capacidades y el servicio las comprueba durante la vista previa, antes de reservar o llamar al proveedor. |
| Garmin | `RUNNING`, intensidades nativas, `OPEN` para avance manual sin `durationValue`, tiempo en segundos, distancia en metros y ambos límites PACE en m/s. |

El formulario no consulta el fabricante ni decide permisos. La receta sigue
teniendo un bloque `running`; sus pasos ya conservan la semántica de fase, sin
añadir bloques ficticios o duplicar contratos por aplicación. La ejecución de
EntrenaOP avanza con su confirmación explícita del resultado; en el reloj la
condición abierta corresponde a Lap. No se simulan GPS o métricas del reloj.

Los repositorios, cuotas, derechos Pro/servicio profesional, MFA y autoridad de
prescripción existentes se mantienen. Trainer puede usar el mismo servicio de
envío, pero su portal todavía no incorpora un botón propio para enviar al reloj.
El primer envío sigue limitado a citas autorizadas del algoritmo o preparador.
El envío de fuerza y los adaptadores de otros fabricantes siguen pendientes.

## Compatibilidad y persistencia

- Las recetas V1 mantienen `running_step = NULL`; no se reescribe su historial.
- Los borradores anteriores siguen recuperándose. El formulario v1 añade
  opcionalmente `stepKind` y `manual`, conservando textos incompletos y permisos
  de los bindings actuales. El contrato de receta es el que se versiona a V2.
- Revisar o duplicar conserva metadatos; cambiar un resultado no altera su
  prescripción. El servidor bloquea una revisión que suprima todos los metadatos
  V2, como haría un editor anterior que no los entiende.
- `training_source` omite la nueva columna cuando es NULL para conservar la
  huella de las recetas V1 y sus recibos de envío. No se repiten entregas previas.
- Una condición manual no recibe una duración estimada inventada. La duración
  total queda abierta; los rangos de ritmo mantienen ambos extremos.
- Un descanso no admite distancia o ritmo. Una condición manual no admite a
  la vez segundos o metros. Se rechazan versiones/tipos desconocidos.

## Desarrollo y comprobaciones

Migraciones `20261022165134_running_steps_v2` y
`20261022170428_running_step_revision_guard` aplicadas únicamente a
`sxbxfjqgoddzhtcyhalw`. `supabase migration list --project-ref` confirma el
historial local/remoto sin divergencias. No se modifica producción.

Pasan con ROLLBACK `running_steps_v2.sql`, `garmin_running_training.sql`,
`trainer_session_work_recovery.sql` y `admin_session_work_recovery.sql`.
La nueva prueba cubre las tres autorías, guardado/duplicación, snapshot de
ejecución, estado durable incompleto, rechazo de incoherencias y revisión desde
editor antiguo, y preservación del snapshot V1. Las pruebas no dejan datos.

Análisis limpios de las tres apps; batería raíz de 1.292 pruebas correctas y una
omisión previa, ADMIN 314 y dos omisiones previas, Trainer 170 y creador común
161 en el cierre inicial; la ampliación de fartlek eleva el creador a 171.
Tras separar el codec se repiten las 391 regresiones de workouts/envío.
La ampliación repite las baterías completas de las tres apps y sus análisis;
servidor: 115 pruebas correctas y tipos TypeScript estrictos. Captura sintética
del widget real a 320 px con texto 2×, sin datos privados en Git.
Diez regresiones nuevas cubren orden, ambos ritmos, reapertura, omisión explícita,
conversión de recuperaciones, límites y conservación de entradas incompletas;
el diálogo se comprueba visualmente a 320/1200 px con texto doble. La prueba
de servidor verifica intensidades, tiempo y ambos límites PACE de la fase suave.

Se revisan los avisos de seguridad del proyecto y los ACL de las funciones
afectadas: ninguna nueva función privilegiada queda ejecutable por `anon` o por
el cliente autenticado; el helper inmutable de validación sí admite ejecución
autenticada sin acceder a datos. Los avisos globales previos quedan fuera del
alcance de este bloque.

Código funcional guardado en `a3018544`. La
[CI Garmin 39822294290](https://github.com/jchjdev/entrenaop/actions/runs/39822294290)
termina correctamente en servidor, consumidor y compilación iOS Release sin
firma. Esto acredita compilación, no instalación ni aceptación física.

`garmin-training` queda ACTIVE v5 únicamente en Dev; una petición sin sesión
devuelve 401. Trainer Dev está publicado y verificado por HTTPS con la revisión
`a3018544e1c086c53e1cf68a9575006155a129b2` y release
`a3018544e1c086c53e1cf68a9575006155a129b2-20261022-1`; se comprueban identidad,
huella JavaScript, recursos versionados y cabeceras. La biblioteca también
abre correctamente en Chrome tras recargar la nueva publicación.

ADMIN Dev también está publicado y verificado por HTTPS con revisión
`6924e9673c4595e10b78fcd34c6b043c2365a92e`, que conserva el código funcional y
añade la documentación de recuperación de otro chat. Su
[CI 39823651874](https://github.com/jchjdev/entrenaop/actions/runs/39823651874)
termina correctamente en validación, publicación y retención. La ejecución
anterior `39822294381` superó la validación, pero su publicación se detuvo al
avanzar `main`; se ejecuta de nuevo sobre el punto actualizado sin eludir la
guarda ni modificar el trabajo ajeno. Se verifica además desde este equipo la
identidad pública, la huella JavaScript, los recursos y las cabeceras.

La ampliación de fartlek queda guardada en `8998d25c` (terminología previa en
`f2838af4`). Trainer Dev publicado con release
`8998d25c4e8c309c528bc8c2169791a698d106d5-20261022-1`, verificado por HTTPS
y en Chrome: recuperación como paso, «Tiempo», selector desde/hasta, vueltas y
omisión desactivada por defecto visibles. Se abre y cancela el diálogo en una
pestaña de comprobación; no se aplica la repetición ni se publica una nueva
versión de la sesión real. La pestaña original del usuario se conserva.

[CI Garmin 39837977581](https://github.com/jchjdev/entrenaop/actions/runs/39837977581)
correcta, incluida compilación iOS; ADMIN Dev publicado con la misma revisión
y verificado por HTTPS en la
[CI 39837977717](https://github.com/jchjdev/entrenaop/actions/runs/39837977717).
El paquete público contiene únicamente el compilado Dev; el ZIP queda en la
carpeta privada de versiones. No hay nuevas migraciones o despliegues Edge.

La interfaz del iPhone requiere actualizar desde GitHub Desktop (Fetch/Pull de
`main`), ejecutar `bash tools/prepare_iphone_dev.sh` en el Mac y compilar desde
Xcode con el esquema «Runner iPhone» y el iPhone físico. No hay que copiar
credenciales Garmin. Tras aplazar inicialmente la prueba, Javier confirma que
ha instalado la app V2 en el iPhone. Para crear este fartlek en Trainer y
enviarlo desde ese iPhone no necesita otra instalación: no cambia el contrato
de pasos. Las nuevas acciones del creador personal móvil sí requieren actualizar
su compilación. La recepción y fidelidad de la nueva pauta en fēnix siguen
pendientes de comprobación física.

## Único siguiente recorrido

La implementación y las pruebas sintéticas no acreditan todavía la nueva
receta en el fēnix. Crear/asignar una pauta nueva de referencia, revisarla en
EntrenaOP y enviarla conscientemente desde el perfil del alumno; comprobar
calentamiento hasta Lap, las cinco parejas de pasos, recuperación final,
enfriamiento hasta Lap y avisos de ambos límites de ritmo. No reutilizar ni
reenviar por defecto la cita que ya tiene un recibo anterior.

Para la aceptación posterior:

1. Crear una sesión nueva desde ADMIN o Trainer con calentamiento manual,
   cinco series de 400 m con el rango de ritmo elegido para la prueba y
   recuperación de 90 s, y enfriamiento manual; guardarla y volver a abrirla.
2. Pautarla al alumno de prueba. Desde su iPhone actualizado, abrir Perfil →
   Conexión con Garmin → Enviar una carrera y revisar fecha y doce pasos antes
   de confirmar. La biblioteca personal no concede autoridad de envío.
3. Abrir Garmin Connect y sincronizar el fēnix. Comprobar la sesión recibida y
   el orden de sus pasos; iniciar el ensayo en el reloj.
4. Verificar que calentamiento y enfriamiento esperan a Lap, que cada serie
   acaba a los 400 m y cada recuperación a los 90 s, y que los avisos respetan
   ambos límites del ritmo. Conservar las discrepancias para corregirlas antes
   de ampliar objetivos o fabricantes.

Después de esa comprobación se ampliarán objetivos de intensidad y capacidades
de otros proveedores. No se declara cerrado el ensayo físico ni un recorrido
completo de carrera al terminar las pruebas de software.
