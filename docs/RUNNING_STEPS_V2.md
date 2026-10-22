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

`garmin-training` actualizado en Dev; una petición sin sesión devuelve 401.
La instalación iOS y la distribución web deben corresponder a esta revisión
antes de probar la interfaz nueva. El script de iPhone sigue siendo
`bash tools/prepare_iphone_dev.sh` tras Fetch/Pull de `main` en el Mac.

## Único siguiente recorrido

La implementación y las pruebas sintéticas no acreditan todavía la nueva
receta en el fēnix. Crear/asignar una pauta nueva de referencia, revisarla en
EntrenaOP y enviarla conscientemente desde el perfil del alumno; comprobar
calentamiento hasta Lap, las cinco parejas de pasos, recuperación final,
enfriamiento hasta Lap y avisos de ambos límites de ritmo. No reutilizar ni
reenviar por defecto la cita que ya tiene un recibo anterior.

Después de esa comprobación se ampliarán objetivos de intensidad y capacidades
de otros proveedores. No se declara cerrado el ensayo físico ni un recorrido
completo de carrera al terminar las pruebas de software.
