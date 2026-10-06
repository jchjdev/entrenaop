# Motor de carrera 2 km: progresión fácil con dos calidades

Aplicado en Supabase de desarrollo el 01/10/2026. La [v4](MOTOR_CARRERA_2K_V4.md)
conserva las decisiones ya publicadas; v5 rige las nuevas propuestas de FAS,
Tropa y programas que vinculan una prueba compatible de 2 km.

## Problema comprobado

En v4, volver a colocar la misma pareja T/V o S/T marcaba la semana como si
hubiera progresado una variable. Eso impedía añadir minutos fáciles aunque las
sesiones se hubieran tolerado. En dos trayectorias de seis meses, los totales
quedaban en 120 y 160 min incluso con semanas normales y disponibles.

## Regla v5

La pareja mantenida solo libera la progresión de volumen si las dos sesiones
conservan familia, paso, segundos de trabajo y factor de ritmo de la semana
previa. Una nueva segunda calidad, un cambio de dosis o de ritmo siguen
consumiendo esa progresión. Cuando procede, se añaden cinco minutos a una
sesión **fácil** que quepa en la agenda y capacidad declaradas. El motor no
alarga una variante T/V/S para fingir más carrera fácil. No añade volumen si
hay ancla nueva, descarga, mala respuesta o datos insuficientes.

La dosis de cinco minutos es un parámetro operativo conservador, sujeto a
calibración deportiva. Las trayectorias sintéticas prueban la coherencia de
la regla, no garantizan mejora del 2 km.

## Verificación

- Regresiones v5 y 78 trayectorias de 1, 2, 3, 4, 6 y 12 meses (1.573 semanas)
  pasaron con `ROLLBACK`. La trayectoria avanzada supera 120 min tras mantener
  dos calidades; ninguna semana aumenta simultáneamente minutos fáciles y
  calidad, ritmo o referencia.
- Integración FAS y de programa configurable: publicación, agenda, ejecutor,
  resultados, siguiente propuesta, idempotencia y RLS pasaron en desarrollo,
  también con `ROLLBACK`.
- La política nueva no cambia semanas ni ejecuciones anteriores. La comprobación
  visual completa de la app recompilada permanece pendiente.

## Cierre operativo del recorrido (01/10/2026)

- El usuario puede declarar en cuántas de las últimas cuatro semanas completó
  series o cambios de ritmo sin molestias (`running_initial_context_v3`). El
  servidor guarda esa cifra en la entrada y la decisión, pero **no la suma** a
  las exposiciones verificadas ni permite una segunda calidad solo por decirlo.
  La carga reciente y la capacidad cómoda ya permiten que un corredor activo
  reciba una primera calidad sin meses obligatorios de rodajes fáciles.
- Ante dos rodajes fáciles completados con RPE alto y sin incumplimiento
  objetivo, la propuesta mantiene la carga y explica brevemente cómo revisar
  el esfuerzo conversacional y las molestias. No diagnostica la causa.
- `reset_running_plan` reinicia una preparación de forma atómica tras dos
  confirmaciones: borra decisiones, sesiones automáticas y sus ejecuciones;
  preserva marcas oficiales, contexto y sesiones personales. Rechaza una sesión
  en curso y las solicitudes de otro usuario. La misma semana puede pautarse
  de nuevo. Las semanas históricas se siguen versionando cuando no se reinician.
- «Mi semana» adapta el selector de días a móvil y abre el resultado de una
  sesión completada en el historial existente. Una pendiente usa el ejecutor
  compartido. El título del formulario pasa a «Plan y preferencias de carrera».

Verificación: migraciones `20261001013000` y `20261001014000` aplicadas a
**desarrollo**; pruebas SQL de reinicio y calidad declarada con `ROLLBACK`,
`flutter analyze`, 240 pruebas Flutter y compilación web correctos. La prueba
SQL recorre publicación → agenda/ejecutor → tramos y resultado → propuesta
siguiente → reinicio → nueva publicación. Las pruebas de widgets comprueban
tarjeta completada en 360 px y dos confirmaciones. Falta la comprobación visual
con una sesión autenticada tras recompilar: no se ha realizado en navegador.

**Límite deportivo:** la calidad declarada orienta la conversación y queda
auditada, pero no prueba tolerancia ni modifica directamente las puertas de
dosis. La calibración de los umbrales sigue provisional y las trayectorias
sintéticas no acreditan mejoras humanas. Fuerza y coordinación entre pruebas
quedan fuera de este bloque de carrera.

## Coordinación operativa con fuerza · STR-017 (03/10/2026)

La política pura v5 permanece. Su adaptador interno acepta disponibilidad
restante y regiones cargadas por fuerza, distinguiendo tren superior de
piernas. La publicación conjunta reutiliza su materialización privada y ejecutor.
Con referencias activas de fuerza, la publicación se realiza en «Fuerza y
carrera». Una semana coordinada impide el reinicio destructivo exclusivo de
carrera; las preparaciones de solo carrera conservan el reinicio anterior.
Regresiones v5, horizontes e integraciones comprobados nuevamente en desarrollo.
Detalle: [MOTOR_FUERZA_RENDIMIENTO_V1.md](MOTOR_FUERZA_RENDIMIENTO_V1.md).
