# Motor de carrera 2 km: entrada gradual a dos calidades

Aplicado en Supabase de desarrollo el 01/10/2026. [V3](MOTOR_CARRERA_2K_V3.md)
permanece para reproducir semanas ya publicadas. Calibración deportiva
provisional: las marcas de laboratorio son entradas simuladas, no mejoras
predichas.

## Decisión

La v3 exigía que dos sesiones completas de entrada (T 2×5 min y V 4×2 min)
sumasen menos de 1,20 veces el mayor trabajo semanal tolerado en los 28 días
anteriores. En el perfil intermedio ya había exposiciones suficientes alrededor
de la semana 9, pero esos 18 minutos intensos no cabían bajo la cota. La segunda
calidad aparecía por primera vez en la semana 19 del ensayo de seis meses.

V4 añade dos variantes **solo para repartir calidad entre días**: T 2×4 min
y V 3×2 min. Juntas suponen 14 min de trabajo; ambas incluyen 10 min de
calentamiento, recuperaciones y al menos 6 min de vuelta a la calma. Conservan
los ritmos de entrada, sin acelerar a la vez que aumenta la frecuencia de
calidad. Las dosis normales T/V/S, fuerza, días disponibles, separación entre
calidades, controles y descargas conservan las reglas previas. Con dos semanas
de pareja tolerada, se puede probar T 2×5 + V 3×2; la pareja completa llega
después si cabe bajo la cota.

La elección no se activa por una buena marca aislada. Exige la misma historia
de exposiciones T/V/S toleradas, datos completos, semana previa cumplida,
al menos tres días y 120 min, ninguna señal adversa reciente ni nueva marca
simultánea. En dos días no añade una segunda calidad.

## Implementación

- `20261001011000_running_engine_split_quality_v4.sql` incorpora catálogo
  v2 y sesión con variante `paired_entry_v2`. Mantiene catálogo v1 y motores
  anteriores para historial.
- `running_plan_v4` sigue siendo la única decisión de servidor para nuevas
  semanas. El adaptador autenticado conserva agenda y ejecutor actuales.
- Las variantes cortas usan el mismo contrato de segmentos, registro y
  evaluación de resultados. Se registra la razón `quality_frequency` y la
  variante elegida.

## Evidencia y límites

El documento deportivo original propone T → E → V/S en tres días y pide
progresar una variable principal cada vez, preservar predominio fácil y evitar
días intensos consecutivos. Estas variantes concretas y la cota 1,20 son
**decisiones operativas del producto**; ningún ensayo citado valida que 14 min
sean óptimos ni fija la semana ideal de entrada.

- [Estudio de distribución de intensidades en corredores recreativos de 2 km](https://pubmed.ncbi.nlm.nih.gov/33344993/): dos distribuciones diferentes mejoraron el resultado en ocho semanas; no fija una dosis universal para cada corredor.
- [Ensayo de planificación individualizada en corredores recreativos](https://pubmed.ncbi.nlm.nih.gov/35975912/): la respuesta y la recuperación importan al cambiar volumen o frecuencia de intervalos; EntrenaOP dispone de menos señales que aquel estudio.

## Verificación

- Regresión transaccional: con 12 min tolerados, v3 mantiene una calidad y v4
  reparte 8 + 6 min sin superar la cota, aumentar ritmo u otra variable, ni
  recortar tramos de la sesión. Caso de marca nueva, dos días, datos incompletos
  y permisos también pasan.
- 78 trayectorias y 1.573 semanas con `ROLLBACK`: los perfiles intermedio y
  avanzado de tres meses tienen dos semanas de doble calidad; los de seis meses
  tienen catorce. El caso de 7:58 con dos días no recibe doble calidad. Las
  semanas normales de perfiles tolerados no pierden toda la calidad.
- Integraciones FAS y programa configurable: publicación, agenda, ejecutor,
  resultado, siguiente decisión, idempotencia y RLS, también con `ROLLBACK`.

## Pendiente para cerrar el bloque

Recoger y tratar con prudencia calidad tolerada antes de usar la app, aclarar
RPE alto persistente, probar el recorrido visual recompilado y auditar el bloque.
La eficacia deportiva requiere datos longitudinales reales; estas pruebas
acreditan coherencia del software, no una mejora garantizada.
