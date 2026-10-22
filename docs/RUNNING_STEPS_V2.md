# Pasos de carrera V2 · INT-009 · 22/10/2026

## Recorrido implementado

El creador común de deportista, ADMIN y Trainer permite definir calentamiento,
carrera, recuperación, descanso, enfriamiento, caminar y trotar. Cada paso
termina por tiempo, distancia o avance manual. El objetivo de intensidad de esta
primera entrega es libre o un ritmo/rango; pulso, cadencia, potencia y zonas
siguen pendientes y no se muestran como capacidades disponibles.

Las repeticiones mantienen el orden y la recuperación final. La referencia es:
calentamiento hasta avance manual → cinco repeticiones de 400 m con ritmo y
90 s de recuperación → enfriamiento hasta avance manual. Se guardan siete
tramos con cinco recuperaciones asociadas; Garmin recibe doce pasos ordenados.
No se prometen grupos nativos `WorkoutRepeatStep`: la expansión actual conserva
la pauta completa y el límite de cien pasos, incluyendo recuperaciones.

En la aceptación del creador, Javier confirma que la sesión muestra sus fases y
series con recuperaciones. Los selectores compartidos pasan a decir «Tiempo»;
los valores y unidades conservan el contrato anterior. La recuperación asociada
permite pasiva/andar/trotar y tiempo/distancia, pero aún no tiene objetivo de
ritmo propio ni repeticiones de grupos de varios tramos. Esto limita la autoría
de fartlek con pautas suaves precisas; no debe presentarse como soporte completo.
Javier confirma ambas necesidades. El ajuste de terminología supera los análisis
de deportista, ADMIN y Trainer, y las 161 pruebas del creador compartido.

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
161. Tras separar el codec se repiten las 391 regresiones de workouts/envío.
Servidor: 114 pruebas correctas y tipos TypeScript estrictos. Captura sintética
del widget real a 320 px con texto 2×, sin datos privados en Git.

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

La interfaz del iPhone requiere actualizar desde GitHub Desktop (Fetch/Pull de
`main`), ejecutar `bash tools/prepare_iphone_dev.sh` en el Mac y compilar desde
Xcode con el esquema «Runner iPhone» y el iPhone físico. No hay que copiar
credenciales Garmin. Javier confirma que hará la prueba más tarde: queda
aplazada por disponibilidad, sin declarar comprobado el nuevo recorrido.

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
