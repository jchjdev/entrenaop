# Envío común de carrera · INT-007 · 22/10/2026

Javier autoriza implementar y probar una primera carrera en Garmin, solo en
desarrollo, manteniendo Clean Architecture y reutilización por entrenadores.
El recorrido de cuenta de INT-005 está aceptado desde navegador. El equipo
físico elegido es su fēnix 8 ya enlazado a Garmin Connect; el fēnix 6X queda
como posible segundo dispositivo de comprobación, sin cobertura acreditada aún.

## Contrato compartido y límites

El servidor recibe una cita y su revisión, nunca una receta dictada por Flutter.
`device_private.training_source` proyecta la jerarquía publicada existente de
`workout_templates/blocks/items/sets`, fecha, versión y autoridad. Para algoritmo
exige decisión/objetivo propios activos; para entrenador exige asignación propia,
relación y servicio profesional vigentes. Biblioteca, usuario y preparación
genérica quedan fuera de esta primera exportación, conforme a INT-006.

`garmin-training` admite al alumno sobre sí mismo y al preparador sobre sus
propias asignaciones del alumno, con aal2 tanto en JWT verificado como en sesión
persistente. La concesión Garmin pertenece siempre al alumno. El preparador no
obtiene tokens ni identidad Garmin, no puede enviar pautas de otros profesionales
y no sustituye el consentimiento del deportista. El alumno profesional no
necesita contratar Pro adicional.

La primera interfaz de selección/revisión está en Perfil → Conexión con Garmin
→ Enviar una carrera de la app del deportista. Trainer puede consumir el mismo
endpoint mediante su adaptador de presentación y `client_id`; su pantalla todavía
no incorpora ese botón. No se cambia Inicio, Preparador ni el portal profesional.

## Clean Architecture

| Parte | Responsabilidad |
| --- | --- |
| `device_training/prescription.ts` | Modelo puro de carrera y normalización de la receta ya existente; sin HTTP, Garmin, SQL o Flutter. |
| `device_training/delivery.ts` | Servicio de aplicación y puertos de persistencia, proveedor, cuenta y cifrado; revisión, orden de efectos y resultado incierto. |
| `garmin/training.ts` | Traducción a Training API y transporte HTTP del fabricante. |
| `garmin/training_http.ts` | Composición, Auth, cuenta esperada y adaptador RPC; cerrado a Dev por la configuración existente. |
| Dart `features/device_training` | Dominio de presentación sin SDK, repositorio Supabase con aislamiento por sesión y Cubit/vista previa. |

Se reutiliza la receta común, sin copiar el algoritmo o el editor ni introducir
paquetes externos. El endpoint compartido evita otro motor de Garmin para
entrenadores. No modifica el contrato de ejecución o cumplimiento de una pauta.

## Compatibilidad de la primera entrega

Se contrasta Training API V2 2.0, páginas 4–9 y 18–20, descargada desde el
[portal oficial](https://developerportal.garmin.com/developer-programs/programs-docs).
El archivo completo y sus anexos permanecen locales e ignorados por Git.

- Carrera de un deporte, secuencia plana de hasta cien pasos contando
  recuperaciones. No representa circuitos/rondas o modalidades mixtas.
- Duración en segundos o distancia en metros, nunca ambas ni una estimación de
  una a partir de la otra. Se conserva recuperación final prescrita.
- Ritmo opcional en segundos/km convertido a PACE en m/s, invirtiendo extremos:
  mínimo de velocidad = 1000 / ritmo lento. No se inventan zonas o pulso.
- Recuperación pasiva, andando o trotando en su medida original. Andar/trotar y
  RPE se conservan como instrucciones visibles; no se simula una alerta de
  marcha o de RPE que el reloj no ofrece como objetivo.
- Instrucciones de sesión y de cada paso conservadas dentro de los límites del
  fabricante; si exceden capacidad o hay campos no representables se bloquea,
  sin truncar ni omitir instrucciones. Límite inicial de nombre: ochenta caracteres.

La vista previa muestra fecha, instrucciones, todos los pasos y ritmos. El
usuario confirma que los ha revisado antes de enviar. La versión se vuelve a
comprobar en servidor justo antes de cada escritura externa.

## Orden persistente y concurrencia

`20261022132601_garmin_running_training_delivery.sql` añade recibos privados por
propietario/cita/proveedor y un lease de uso de la conexión de tres minutos.
Solo la fachada RPC de servidor tiene EXECUTE para `service_role`; no hay acceso
directo de clientes ni de `service_role` a la tabla. RLS queda activado como
defensa adicional. El recibo conserva snapshot, revisión, versión del adaptador,
generación de conexión y referencias remotas.

El UUID histórico de cita se conserva sin FK que bloquee un reset de agenda o
elimine la evidencia remota por CASCADE. Antes de cada nuevo efecto se vuelve
a resolver su existencia/autoridad. Una cita eliminada no autoriza otro envío.

1. Reclamar una única orden y verificar cuenta, sesión, derecho, prescriptor y
   revisión. Una segunda petición concurrente no recibe las credenciales.
2. Si hace falta renovar OAuth, registrar previamente el estado de rotación y
   persistir el refresh token nuevo antes de cualquier otra operación. Una
   rotación incierta detiene el envío y deja la conexión pendiente de retirada.
3. Verificar identidad Garmin y permisos actuales. No basta el permiso almacenado.
4. Registrar `creating` antes de POST del entrenamiento; guardar su workout ID
   antes de registrar `scheduling` y enviar su fecha.
5. Consultar el calendario por fecha y comprobar una referencia única al workout;
   solo entonces guardar `sent`. Un 204 aislado no acredita el calendario.
6. Liberar lease y completar una retirada que hubiera coincidido con el envío.

La desconexión impide nuevos pasos externos; la revocación espera mientras se
usa la concesión. Un refresh ya devuelto o un efecto externo ya aceptado se
pueden persistir/limpiar aunque el usuario cierre sesión o termine el vínculo.
Eso no permite nuevas escrituras en Garmin tras perder autoridad.

Un POST sin respuesta fiable nunca se repite automáticamente. Se conserva como
incierto y se pide comprobar Garmin. Si el workout quedó confirmado en base de
datos, un rechazo conocido al agendar reutiliza ese ID. Una respuesta perdida
del guardado no borra un recibo final ya confirmado. Hay treinta segundos mínimos
entre reintentos de una orden fallida.

Cambiar receta/fecha o cambiar de conexión tras un posible efecto remoto exige
revisión, sin crear otra copia silenciosamente. Reconectar tras un fallo conocido
sin workout creado sí puede continuar la misma orden. No hay actualización,
retirada de una sesión ya enviada o conciliador de resultados inciertos en esta
primera fase. Desconectar la cuenta no elimina entrenamientos que ya están en Garmin.

## Aceptación y operación Dev

Activado exclusivamente en `entrenaop-dev` (`sxbxfjqgoddzhtcyhalw`): migración
`20261022132601` aplicada y sincronizada con el historial; `garmin-training`
ACTIVE v1 y handlers de cuenta/callback ACTIVE v5. Las credenciales de INT-005
se reutilizan sin reenviarlas ni regenerar la clave de cifrado. La app de
localhost se recompila con la pantalla nueva. No hay aún un envío real acreditado.

Validación: 109 pruebas Node, tipos estrictos, ocho pruebas Flutter nuevas y
batería raíz completa 1.278 correctas/una omisión previa; análisis limpio.
SQL transaccional completo contra Dev con ROLLBACK antes y después de aplicar,
sin usuarios sintéticos ni entregas restantes; concurrencia real en PostgreSQL
local. También pasan las regresiones transaccionales existentes de agenda y
revisión de asignaciones del preparador. El asesor solo añade la información
esperada de RLS sin políticas en la tabla privada sin acceso directo.

[CI 39791868190](https://github.com/jchjdev/entrenaop/actions/runs/39791868190)
correcta para `7c05f8cd2edf015ed4062ca3bcd46250bdaf5fd8`. Petición al endpoint
nuevo sin sesión: 401. Falta la prueba del usuario con cita real y reloj;
estas comprobaciones no se presentan como confirmación de entrega.

La API crea el workout y después su cita de calendario. En la especificación
consultada, creación usa `/workoutportal/workout/v2` y agenda/consulta usan
`/training-api/schedule/` y `/training-api/schedule?startDate=…&endDate=…`.
Solo se permiten destinos oficiales fijos, sin redirecciones; timeout por petición
de diez segundos y respuestas limitadas. Logs de errores: operación/estado/código
cerrados, nunca cuerpos, fechas, nombres, tokens o URLs de retorno.

La primera prueba elegirá una cita real pendiente de entrenador del alumno, con
vista previa; no se crea una prescripción artificial ni se cambia su agenda.
Tras confirmar el calendario en Garmin, se sincroniza Garmin Connect del móvil
y se comprueban nombre, fecha y pasos en fēnix 8. La app mostrará «enviada a
Garmin», sin fingir confirmación física del reloj. No hace falta instalar esta
compilación de EntrenaOP en el móvil para probar el canal de nube.

Sigue pendiente antes de producción la limpieza de la cuenta externa al borrar
Auth, conciliación de permisos fuera de la app, rotación operativa de clave y
recuperación de efectos inciertos ya señaladas en INT-005. No se modifica producción.
