# Reparación adaptativa · 16/10/2026

## Alcance

Reproducción del programa combinado autorizado por Javier y reparación de los
seis defectos confirmados en el diagnóstico de Astra sobre main `85ef548`.
Solo Supabase de desarrollo (`entrenaop-dev`). Se conserva carrera v5,
rendimiento v3, pausa/alcances, generación automática y calentamiento neutral.
No se amplía el banco ni se sustituyen sesiones publicadas.

## Caso real

Consulta del contexto, referencias y última decisión activa, seguida de
previsualizaciones transaccionales con cinco huecos de 60 y 90 minutos:

| Entrada | Resultado previo | Resultado con reparación |
| --- | --- | --- |
| 5×60, cero carrera reciente, referencias de rendimiento a frecuencia 1 | Listo, dos carreras y un día de rendimiento compartido | Misma cobertura |
| 5×90, mismo contexto deportivo | Listo, dos carreras y un día de rendimiento compartido | Misma cobertura |

Las carreras son dos salidas fáciles de treinta minutos. El número de días
ocupados no revela un tope general de dos; proviene de la dosis de entrada y
de agrupar trabajo compatible. No se modifica la cuenta para aparentar cinco
entrenamientos. Las consultas y previsualizaciones de prueba terminan con
`ROLLBACK`; no se publican pautas experimentales sobre sus entrenamientos.

El fixture anonimizado `adaptive_combined_frequency.sql` reproduce las mismas
restricciones relevantes y añade un corredor con cinco salidas recientes, que
supera dos salidas pautadas. También comprueba un encaje estrecho compartido
en dos huecos de 35 minutos y el límite final de tiempo.

## Reparaciones

| Hallazgo | Corrección y evidencia |
| --- | --- |
| Falta de tiempo interpretada como dificultad | Evaluación temporal independiente, carga parcial conservada, sin dosis completa ni señal fisiológica inventadas. Regresión de 1.200/600 segundos a RPE 4. |
| Abandono combinado contagia modalidades terminadas | Proyección de estado/motivo por bloque; marca del primer bloque pendiente en el cierre. Sesión persistida con carrera y un bloque de fuerza terminados, abandono del siguiente y dolor global conservador. |
| Agenda/recepción sustituyen realización | Instante y offset local persistidos en nuevos cierres; misma carga offline en reintento. Adaptadores y recuperación usan realización; pruebas de cambio de día, cita distinta, fecha futura inválida y permisos. |
| Máximo de tres repeticiones con RIR 3 | Solicitud de una carga de trabajo compatible antes de prescribir un margen imposible; regresiones con máximos 3/4 y capacidad 6. |
| RIR temporal distinto entre capas | SQL permite `effort_mode=rir` en `REPS_IN_TIME` de trabajo; duración, control y práctica siguen rechazándolo. |
| Ahorro compartido reconocido demasiado tarde | Reservas alternativas en búsqueda y validación exacta previa a puntuación, usando orden y segmentos reales. No se reduce recuperación ni se sobrepasa disponibilidad. |

## Reproducción

La migración `20261016124517_adaptive_evidence_and_shared_budget.sql` se compone
con `tools/build_adaptive_evidence_migration.py`, que comprueba las sustituciones
contra las últimas definiciones revisadas. No reescribe migraciones aplicadas.

`tools/build_adaptive_regression_suite.py` recibe nombres de pruebas de
`supabase/tests/`, crea una cuenta ficticia y separa cada fixture con savepoints.
Por defecto usa funciones instaladas; `--migration` permite ensayar una
migración pendiente dentro de la misma transacción. Siempre acaba en ROLLBACK.

`tools/build_adaptive_longitudinal_preflight.py` ensaya el ciclo completo con
funciones instaladas y reloj aislado, incluyendo los DEFAULT temporales.
Admite los seis horizontes mediante `--months`. Inicia y cierra las sesiones
en sus fechas simuladas; no modifica sus fechas después de que los disparadores
hayan planificado la siguiente semana. Confirmaciones de contexto y controles
son entradas explícitas del deportista simulado; no predicciones de mejora.

## Verificación técnica

| Comprobación | Resultado |
| --- | --- |
| Aplicación deportista | Análisis sin incidencias; 909 pruebas correctas y una omisión web existente. |
| ADMIN | Análisis sin incidencias; 109 pruebas correctas y una omisión existente. |
| SQL instalado | 18 baterías transaccionales correctas: nuevas reproducciones, carrera v5/horizontes, fuerza v3, calentamiento, publicación/revisión, modos, pausa, continuidad y permisos. |
| Un mes integrado | Cinco semanas completas con reloj coherente; termina antes de la prueba sin publicar otra semana. |
| Seis meses integrados | 26 semanas, cinco revisiones contextuales explícitas resueltas y continuación hasta finalizar. No son mejoras físicas observadas. |
| Migraciones | 144 entradas locales/remotas coincidentes tras aplicar solo esta reparación en desarrollo. |
| Definiciones efectivas | Cuerpos de las 14 funciones reparadas coincidentes con la migración; cuerpo de `running_plan_v5` idéntico a su fuente anterior. |
| Seguridad | 114 avisos previos conservados; dos avisos adicionales por RPC de cierre autenticados con SECURITY DEFINER, revisados con autorización por propietario, bloqueo e idempotencia. Anónimos sin EXECUTE; auxiliares sin acceso cliente. |

Los avisos sobre ejecución autenticada se explican en la
[regla del asesor de Supabase](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
Esos RPC siguen el patrón existente para actualizar resultados y disparar la
continuación con integridad del servidor. No se presenta el esquema entero
como una auditoría de seguridad cerrada.

## Límites conocidos

- La recepción histórica y las colas antiguas no permiten reconstruir una zona
  local desconocida. No se aplica backfill especulativo.
- La atribución al primer bloque pendiente corresponde al ejecutor secuencial
  actual. Un futuro ejecutor que altere libremente el orden deberá comunicar
  explícitamente el bloque de interrupción.
- Las pruebas de reintento no equivalen a una prueba de estrés concurrente.
  El bloqueo de ejecución serializa los nuevos cierres observados; los RPC
  históricos se conservan para compatibilidad.
- El contexto caduca; las marcas no se renuevan porque una semana se complete.
  La revisión contextual existente sigue siendo necesaria cuando corresponda.
- Las prioridades por distancia cuantitativa a la meta y estrategias específicas
  para todos los deportes del catálogo no se dan por completadas con esta reparación.
- La repetición física en móvil, incluyendo pérdida y recuperación de conexión,
  sigue siendo aceptación necesaria de la experiencia de usuario.
- El lote conjunto de doce meses superó el límite HTTP de Management API y
  **no se cuenta como aprobado**; se comprobó que no quedara una prueba activa.
  Se conservan el escenario y los seis horizontes disponibles en el generador.
  Las pruebas anuales por motor sí pasan, pero no sustituyen ese recorrido
  completo. No se han retirado guardas ni reducido pruebas para ocultarlo.
