# Carrera 2 km: selección y progresión v6

## Decisión PLAN-026 · 16/10/2026

Javier autoriza corregir selección y progresión para aprovechar el repertorio
activo, sin añadir variedad por apariencia, y repetir el mismo FAS de seis
meses. El diagnóstico previo se conserva como evidencia histórica en
[VARIEDAD_CARRERA_2026_10_16.md](audits/VARIEDAD_CARRERA_2026_10_16.md).
La aceptación de esta corrección no autoriza incorporar automáticamente las
sesiones candidatas pendientes ni hacer que todos los perfiles recorran todo
el catálogo.

## Problemas y corrección

1. **Comparabilidad confundida con ancla.** V5 contaba éxitos de una dosis solo
   si el ancla estaba dentro del 3 % de la actual. Una marca nueva podía
   descartar datos que todavía cumplían el ritmo, esfuerzo y recuperaciones
   vigentes. `running_dose_evidence_v6` vuelve a evaluar los parciales reales
   contra la receta de la misma familia y escalón con el ancla actual. Exige
   que la ejecución fuese tolerada originalmente y siga siendo compatible.
   Conserva la ventana de 56 días, excluye futuro y puesta a punto, y una
   incidencia posterior de esa familia reinicia el permiso de progresar.
   No transforma sesiones lentas, incompletas, con molestias o esfuerzo
   desconocido en éxitos nuevos. La tendencia fisiológica no se recalcula:
   `running_evidence_v2` mantiene sus comparadores anteriores.
2. **La meta retrasaba la progresión del formato.** En las series S cortas,
   dos éxitos podían activar +3 % de velocidad y retener el escalón, incluso
   cuando ya procedía probar el siguiente. V6 no introduce ese incremento
   desde el tiempo deseado. Progresa una dosis compatible y las marcas reales
   recalibran sus ritmos por separado. Un factor histórico se conserva mientras
   no cambia el ancla; el cambio de referencia sigue sin aumentar dosis,
   frecuencia o minutos fáciles simultáneamente.
3. **Más días expulsaban la calidad conocida.** Llegar a 75 minutos podía
   repartir tres salidas de 25, sin espacio para el estímulo previamente
   tolerado. Antes de ampliar frecuencia, v6 comprueba que esa receta completa
   quepa junto a los mínimos de las otras salidas. Si no cabe, conserva días y
   puede desarrollar minutos fáciles según las reglas existentes. No obliga
   a entrenar más días ni rellena toda la disponibilidad.
4. **Prioridad poco específica al acercarse el examen.** En desarrollo y
   especificidad se prioriza S, con las puertas de entrada y las tendencias
   observadas existentes. Si no es viable se prueban las alternativas completas;
   no se recortan repeticiones, pausas o calentamiento para publicar S a toda
   costa. En preparación general se conserva el reparto de funciones T/V/S.
5. **Reserva inviable de otra calidad.** La reserva de una pareja podía retener
   la progresión de la primera sesión aunque la segunda exigiera una familia
   todavía desconocida que el colocador rechazaría. V6 comprueba ambas familias
   antes de reservar; mantiene las demás puertas de frecuencia, trabajo y agenda.
6. **El primer día ocultaba un hueco posterior.** Si el escalón nuevo no cabía
   en el primer día elegido, se volvía inmediatamente al anterior aunque otro
   día ya previsto tuviera tiempo. V6 comprueba ese hueco con las mismas
   restricciones de recuperación antes de aceptar la regresión de formato.
   Conserva el presupuesto semanal y no añade otra salida para resolverlo.
7. **Un control consumía una práctica que había sustituido.** La propuesta
   ordinaria avanzaba su rotación antes de que el control reemplazara la calidad.
   En la siguiente decisión parecía haberse practicado T aunque solo se hubiera
   realizado el test. El adaptador normaliza ese contador, con
   `running_previous_evidence_v6`, si el control tipado sustituyó la única
   calidad y no hubo recalibración que ya hubiera impedido avanzar. La operación
   es idempotente, conserva el historial y distingue tests de sesiones de trabajo.
   Queda auditada como `running_control_evidence_v1`; no modifica la política
   pura v6 ni las semanas guardadas.

Cada dosis seleccionada conserva los datos utilizados por el permiso de
progresión: número de ejecuciones revisadas, compatibles, sus fechas, anclas,
ritmos y esfuerzo. Una incompatibilidad con el nuevo ritmo no se presenta como
pérdida de forma ni borra el resultado original.

## Fronteras conservadas

Se añade `running_plan_v6`, manteniendo v1–v5 reproducibles. El adaptador vigente
elige v6 para nuevas propuestas y acepta evidencia de las seis versiones. Las
semanas publicadas se conservan con su versión; no se reescriben prescripciones
ni ejecuciones. No cambia el contrato de Flutter, el ejecutor, las tablas, los
derechos o las reglas RLS.

Se conserva el catálogo v2, sus constructores y sus recuperaciones temporales:
no aparecen 10×400, 15×200, 1 km o recuperaciones de 200 m por esta corrección.
También se conservan calentamiento y cierre completos, límites de tiempo,
puertas de series largas, control del esfuerzo, reentrada, descarga, puesta a
punto, vigencia de salud y referencia, segunda calidad y coordinación con fuerza.
Los controles de PLAN/STR-041 siguen sustituyendo trabajo y reutilizando marcas.

## Evidencia deportiva y límites

La revisión de [Buchheit y Laursen](https://pubmed.ncbi.nlm.nih.gov/23539308/)
explica que intensidad, duración, repeticiones y recuperaciones cambian el
estímulo cardiovascular y mecánico. Fundamenta revisar la sesión completa y
su intención; no valida una escalera universal 200→400→800 ni los umbrales del
software. Los ensayos de [intervalos de distinta duración e intensidad](https://pubmed.ncbi.nlm.nih.gov/23679147/)
ilustran intervenciones distintas, sin demostrar que el formato más largo sea
siempre mejor para cada corredor.

El ensayo [Run Clever](https://pubmed.ncbi.nlm.nih.gov/29527322/) no halló una
diferencia significativa en riesgo de lesión entre sus progresiones de volumen
e intensidad. No permite vender nuestra regla de una demanda por decisión como
garantía de seguridad. La mantenemos como guarda operativa conservadora.

Dos respuestas compatibles, ventanas, fases y umbrales son parámetros operativos
versionados, pendientes de calibración física. El modelo de ritmo estimado desde
2 km no equivale a medir umbrales fisiológicos. Las simulaciones contrastan
decisiones y límites, no predicen adaptaciones ni garantizan las metas.

## Verificación

Instalado y verificado en desarrollo el 16/10/2026:

- Análisis Flutter limpio; 923 pruebas de raíz correctas y una omisión web.
- Las 29 baterías SQL pasan con `ROLLBACK`, incluidos publicación, reinicio,
  evidencia antigua/nueva, fuerza, controles, tiempo compartido, aislamiento y
  las mismas 78 trayectorias de 1–12 meses (1.573 semanas) ejecutadas también
  con la política pura v6. Se conservan los oráculos y la cobertura de v5.
- Las dos fixtures históricas de publicación/reinicio avanzan ahora por fechas
  reales con el reloj del ensayo completo: no dan por entrenada una semana
  futura al ejecutar sus citas hoy. Los derechos de prueba son explícitos y
  limitados al usuario ficticio; el reloj comercial permanece independiente.
- Coinciden 154 migraciones locales/remotas y 25 cuerpos instalados. Las cinco
  migraciones cotejadas coinciden con sus sentencias registradas, y el núcleo
  v5 y los catálogos/constructores anteriores permanecen intactos. Los avisos
  de seguridad conservan el recuento previo; no se declaran corregidos aquí.

El [mismo caso FAS de seis meses](audits/FAS_SEIS_MESES_CARRERA_V6_2026_10_16.md)
completa 26 semanas, 101 sesiones y 689 registros, con doce controles automáticos,
sin marcas manuales, exceso de días o minutos, ni datos persistentes de ensayo.
Se comprueban por igualdad las marcas, metas, disponibilidad, material y curvas
de capacidad ficticias respecto a STR-041. Los resultados responden al trabajo
realmente pautado: no se fuerzan los formatos ni las marcas finales.

En este perfil aparecen 2×5 y 2×6 min, 4×2 min y 6/8×200 m. No recibe 400/800 m:
no ha reunido su tolerancia específica y esos formatos no se insertan para
embellecer el informe. Las regresiones sí prueban que 400 y 800 son alcanzables
en perfiles con el trabajo previo necesario. El cambio no acredita que toda
sesión candidata esté conectada ni que la trayectoria sea fisiológicamente
óptima. Aceptación física, anualidad conjunta y estrés de concurrencia siguen
pendientes.
