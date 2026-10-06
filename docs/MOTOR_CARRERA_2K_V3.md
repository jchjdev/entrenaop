# Motor de carrera 2 km: selección v3

Aplicada en Supabase de desarrollo el 01/10/2026, sobre [v2](MOTOR_CARRERA_2K_V2.md).
Calibración deportiva provisional: no certifica eficacia en personas.
El CSV de Javier es referencia descriptiva; no se importa ni cambia la pauta.

## Criterios de esta revisión

- No perder calidad por repartir rígidamente todos los días en 30 minutos.
- Recomendar disponibilidad respetando la elección y la carga reciente. No
  eliminar sesiones de 30 minutos que permitan una sesión completa.
- No añadir por ahora caras/sensaciones como otra variable que modifique carga.
- Resolver primero selección y progresiones. Aplazar la ampliación del HTML
  comparativo de disponibilidades 2/3/4/5 días. A petición de Javier se regenera
  el visor existente con v3; v2 se conserva como histórico.

## Implementación

Migración `20261001010000_running_engine_selection_v3.sql`:

- `running_selection_policy_v3`: parámetros explícitos y versionados.
- `running_fit_slot_v3`: transfiere minutos fáciles entre días conservando
  presupuesto semanal, disponibilidad y suelo de 25 minutos existente. Nunca
  recorta calentamiento, recuperaciones o repeticiones para hacer caber calidad.
- `running_second_quality_v3`: busca dos familias conocidas y separadas,
  dentro de una cota de trabajo tolerado.
- `running_plan_v3`: prueba dosis propuesta, dosis mantenida y otra familia
  elegible. Audita transferencias, alternativas, rechazo y recomendaciones.
- El adaptador autenticado `calculate_running_week_core` usa v3 para decisiones
  nuevas. V1/v2 siguen reproducibles; semanas publicadas conservan su versión.
  Continúan la misma agenda y el mismo ejecutor. Flutter no decide sesiones.

### Ejemplo de cabida

Referencia 11:00, presupuesto 90 minutos, tres días con 45 disponibles y
tolerancia previa: S de 6×200 necesita 30 min 18 s. Cabe **31/30/29** en lugar
de perder S por 30/30/30. Con tope real de 30 diarios se prueba T/V compatible.
La recomendación de reservar 45 minutos ofrece margen de encaje; no constituye
una dosis óptima universal ni obliga a entrenar todo el tiempo disponible.

### Entrada a dos calidades

Parámetros operativos provisionales:

- Tres días y al menos 120 minutos de presupuesto actual.
- Cuatro exposiciones T/V/S toleradas en 42 días, repartidas en tres semanas,
  y al menos dos exposiciones en los últimos 21 días.
- Semana anterior registrada/tolerada y ninguna observación adversa o
  desconocida en 14 días; marca vigente, semana normal y separación de fuerza.
- No introducirla junto a una nueva marca o aumento del número total de días.
- Dos familias previamente toleradas. Segunda en su dosis de entrada; primera
  puede repartir trabajo mediante un escalón inferior conocido.
- Trabajo intenso conjunto limitado a **1,20 × el mayor trabajo semanal
  tolerado de los últimos 28 días**, con referencia comparable (diferencia ≤3 %).
  Es una cota provisional, no una recomendación de crecer un 20 % cada semana.
- Al introducirla no se incrementan además ritmo, escalón de la primera ni
  minutos semanales. Repartir calidad puede elevar minutos intensos dentro de
  aquella cota: ese efecto también requiere calibración individual.
- Si la pareja todavía no cabe, continúa la progresión de una sola calidad;
  esperar a la segunda no bloquea el crecimiento previo de dosis.

Una nueva marca consolida dosis y repite el foco antes de avanzar la rotación.
Evita que controles cada cuatro semanas coincidan siempre con una familia y
frenen sistemáticamente su progresión.

## Evidencia y límites

Se conservan los principios de los puntos 3, 7–8, 14–18 y 24–26 originales:
mezcla de estímulos, predominio fácil, tolerancia, dosis completa, progresión
identificable, descargas y pruebas longitudinales. Catálogo v1 sin nuevas
familias. Los límites numéricos son hipótesis operativas, no fronteras
fisiológicas demostradas ni números extraídos literalmente de un estudio.

- [Lenk et al., 2025](https://pubmed.ncbi.nlm.nih.gov/40976973/): estudio
  exploratorio con 26 participantes y seis semanas que compara frecuencias de
  4×4. Apoya estudiar más de una exposición en sujetos apropiados; no valida
  nuestros requisitos 4/42, 120 minutos o el límite 1,20.
- [Nuuttila et al., 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9473708/):
  planificación individualizada mediante recuperación percibida, HRV y
  relación FC/velocidad. Respalda adaptar al estado y recuperación; EntrenaOP
  no dispone de todas esas mediciones.

Una buena marca no acredita por sí sola tolerancia previa a dos calidades.
El tiempo hasta introducirlas y la dosificación siguen requiriendo revisión,
especialmente para quienes ya entrenan calidad fuera de la app.

## Verificación

Flutter: análisis limpio y 237 pruebas completas aprobadas. Siete pruebas
localizadas de formulario/propuesta también aprobadas. SQL lint sin errores.
No se ha recompilado ni certificado el recorrido visual completo en navegador.
Producción no modificada.

- `running_engine_v3_regressions.sql`: encaje 31/30/29, alternativa con tope
  30, recomendación, tolerancia distribuida, cota de trabajo, no simultanear
  entrada a dos calidades y nueva marca, datos desconocidos y permisos.
- `running_engine_v3_horizons.sql`: 1.573 semanas con comprobaciones nuevas de
  pérdida injustificada de calidad, dosis y acceso efectivo a dos calidades.
  Reejecutado con exportación de planes para regenerar
  [`labs/running_engine_v3.html`](labs/running_engine_v3.html): 13 perfiles,
  78 trayectorias, sin añadir el comparador de días.
- Integraciones FAS y programa configurable: publicación, agenda, ejecutor,
  registros y adaptación. Pruebas SQL con ROLLBACK.

El bloque deportivo sigue abierto: no se demuestra mejora humana mediante
marcas sintéticas, no se añade motor de fuerza, control por FC ni calibración
automática de RPE. La entrevista de aclaración del esfuerzo sigue pendiente.

## Criterios pendientes para cerrar la primera versión de 2 km

1. Entrada del corredor experimentado: definir cómo recoger la calidad que ya
   toleraba fuera de la app, sin deducirla únicamente de su marca ni obligarlo
   a acreditar toda su experiencia entrenando primero dentro de EntrenaOP.
2. Progresión: revisar el tiempo de acceso y la evolución posterior de dos
   calidades. En los ensayos intermedio/avanzado no aparecen en tres meses,
   sí en cinco semanas del horizonte de seis meses. En el intermedio de seis
   meses ya hay exposiciones suficientes alrededor de la semana 9; las dosis
   mínimas T+V aún exceden la cota de trabajo intenso tolerado y la pareja
   aparece en la semana 19. Contrastar la dosis mínima, la cota y el historial
   externo antes de modificar una sola condición. Verificar también escalones,
   controles, meseta, descarga y puesta a punto sin bloqueos.
3. Aclaración de esfuerzo persistente: concretar una pregunta breve ante datos
   discordantes y probar su efecto. Añadir caras como dato opcional no exige
   rehacer el motor; utilizarlas para ajustar carga requiere una regla propia,
   versionada y validada. No es un requisito de cierre añadirlas.
4. Recorrido de la app recompilada y auditoría del bloque: entrada, publicación,
   ejecutor existente, registro, adaptación y fecha objetivo. Contrastar pruebas,
   documentación y migraciones antes de declarar el bloque cerrado.

El comparador pendiente mantendrá el mismo perfil y supuestos de respuesta,
variando solo disponibilidad (2/3/4/5 días). Los perfiles actuales varían también
marca e historial: no son esa comparación controlada. Los 45 minutos son margen
para encajar sesiones completas, no promesa universal de mejores adaptaciones.
El formulario presenta 45 min como opción recomendada con una frase breve;
conserva todas las duraciones y la decisión del usuario.
