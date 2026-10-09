# Sesión, tiempo y ancho de Mi semana · UI-019/020 · 08/10/2026

**Ampliación UI-022, 09/10/2026:** Javier confirma descartar también series
registradas de una sesión en curso. Flecha y botón inferior ofrecen Salir sin
guardar, con confirmación/conexión y restauración de la cita a pendiente.
El historial cerrado está protegido. Retomar y abandonar conservando resultados
mantienen su contrato. [Implementación y pruebas](UX_REVIEW_2026_10_09.md).

## Ampliación UI-020: tiempo realizado y flecha

Javier muestra un reloj de 20 segundos finalizado que escribe `20` en Tiempo
realizado (min:seg); la validación lo rechaza. Los input formatters solo actúan
al escribir con el teclado, no al asignar el texto del controlador. El objetivo
inicial y los segundos emitidos por el reloj se formatean ahora como min:seg:
`20 → 0:20`, `90 → 1:30`, `3601 → 60:01`. No se interpretan segundos reales como
dígitos de teclado. La confirmación conserva 20, 90 y 3601 segundos en el contrato
de resultados; escribir manualmente 20 sigue convirtiéndose en 0:20.

La flecha ofrece **Seguir aquí**, **Salir y retomar después** y **Abandonar y
conservar lo realizado**. La última opción reutiliza el mismo diálogo de motivo
y la misma operación que el botón inferior. Cancelar el motivo o fallar el
guardado impide salir y mantiene el borrador; el abandono confirmado o encolado
conserva las series y permite volver. Los dos diálogos admiten desplazamiento
con texto grande. No hay eliminación de series, descarte de historial ni cambio
en la interpretación de las sesiones por los motores.

El guard compartido incorpora un callback opcional de confirmación, después de
sus controles existentes de estado ocupado y guardado de borrador. Se conserva
el router y la confirmación predeterminada de los formularios de app/admin.

Verificación del 08/10/2026:

- Las cuatro regresiones de valor inicial/reloj rechazaban el formato anterior;
  las de abandono desde atrás no encontraban la opción antes del arreglo.
- **30 pruebas específicas correctas** de ejecución, guard y formato: incluye
  guardado sin reescribir, 20 manual, motivo, cancelación, error/reintento,
  sincronización pendiente y 320 px con texto doble.
- Análisis limpio en app, admin y entrena_ui. Baterías completas: **630**, **91**
  y **6** correctas; se mantienen las omisiones exclusivas web y captura optativa.
- Recorridos de sesión con repositorio de prueba. No hay cambios SQL ni se
  acredita aquí una prueba autenticada nueva del servidor.
- Las fotos, Inicio/Mi plan, negocio y motores no se modifican. Javier confirma
  escucha en navegador Android. IOS-002 acredita por separado que actualizar y
  reconstruir la copia antigua del Mac resuelve el silencio del simulador,
  con escucha confirmada por Javier; los dispositivos físicos quedan pendientes.

## Alcance original de UI-019

## Abandono: fallo reproducido y corrección

El vídeo de Javier muestra una ejecución abierta con todas las series resueltas,
esperando RPE y confirmación final. El botón de abandono se ocultaba porque su
visibilidad dependía de tener una serie pendiente o estar descansando. La
regresión nueva falla antes de corregirlo: no encuentra el botón de abandono.

El criterio ahora es el estado `inProgress` de la ejecución. Se puede abandonar
antes de registrar trabajo, a mitad, durante el descanso y esperando el cierre
final. Se reutiliza el diálogo existente con motivo obligatorio. Resolver las
series no equivale a cerrar la sesión; abandonar no exige declarar RPE.

La operación existente conserva las series confirmadas, sus resultados y las
omisiones; tampoco convierte las pendientes en resultados inventados. Un error
mantiene abierta la sesión y conserva el borrador de la pantalla para reintentar.
El cierre encolado muestra su sincronización pendiente. El retorno sigue usando
`go_router` y una sesión terminal no pregunta de nuevo si se quiere retomar.

## Qué significa cada salida hoy

| Acción | Estado y datos |
| --- | --- |
| Seguir entrenando / Seguir aquí | Cancela el diálogo y permanece en la pantalla. |
| Salir y retomar después | Mantiene la ejecución en curso y las series confirmadas. Los campos no confirmados en pantalla no se registran. |
| Abandonar la sesión definitivamente | Cierra esa ejecución con motivo y conserva lo confirmado para consultar el historial. |
| Finalizar sesión | Confirma el cierre normal con el RPE obligatorio y las notas introducidas. |

En Mi semana, una ejecución abandonada conserva su referencia y abre
**Ver resultado**, mientras que una ejecución en curso ofrece **Continuar
sesión**. La migración `20260921004000_weekly_workout_schedule.sql` sincroniza
el estado de la cita con el de la ejecución. Abandonar una sesión no pausa ni
abandona toda la preparación. Los motores mantienen su interpretación existente
del estado y del motivo; no se cambian sus políticas en esta tarea.

Javier propuso valorar una salida más clara con opciones de retomar, abandonar
conservando resultados y salir sin guardar. UI-020 incorpora seguir, retomar y
abandonar desde la flecha. Ese cierre dejó pendiente el contrato de Salir sin
guardar. UI-022 lo implementa después de que Javier autorice incluir las series
registradas: descarta únicamente la ejecución en curso, protege el historial
cerrado y devuelve su cita a pendiente. No se trata como un abandono ordinario.

## Mi semana: ancho disponible

El segundo vídeo muestra la franja de días ocupando solo parte del contenido.
El ancho de cada día estaba limitado a 74 px. La regresión a 800 px reproduce
554 px ocupados frente a los 768 px disponibles.

Se elimina ese máximo y se reparte el ancho entre los siete días, dentro del
contenido existente de hasta 920 px. El mínimo respeta el tamaño del texto:
en ventanas estrechas o con texto ampliado se mantiene el desplazamiento
horizontal para que los días sigan legibles y seleccionables. Se conservan
colores, tarjetas, alturas, separaciones y selección.

Captura del widget actual a 800 px, con datos de prueba y sin cuenta:

![Mi semana utiliza el ancho del contenido](visual-audit/session-controls-2026-10-08/semana-ancho-800.png)

También se conservan capturas de 390 y 1200 px. No proceden de un rediseño ni
de imágenes generadas. Los vídeos personales permanecen fuera de Git.

## Cuenta final de trabajo: 3, 2, 1

Javier confirma empezar el aviso cuando quedan **tres segundos**. Las cuentas
con duración objetivo emiten un pitido breve en 3, 2 y 1, seguido del sonido
de final existente. Se aplica a series por tiempo, ventanas de rendimiento,
EMOM y el reloj global AMRAP. Reutiliza el WAV breve de preparación y el mismo
reproductor, preferencias y manejo de fallos; no añade paquetes ni descargas.

Pausar/reanudar no repite el segundo anterior; repetir permite una cuenta nueva.
Restaurar no reproduce pitidos pasados. Una actualización tardía emite solo el
segundo actual o el final, sin una ráfaga de avisos atrasados. En intervalos de
uno a tres segundos el inicio tiene prioridad y solo avisan los segundos
restantes posteriores; nunca se solapan inicio y cuenta final.

El descanso conserva mitad, diez segundos y final. Los cronómetros sin duración
objetivo no inventan un final. Los pitidos siguen sin confirmar resultados por
el usuario ni garantizar reproducción con la aplicación suspendida.

## Verificación y límites

- Análisis de la app limpio. Batería completa: **621 pruebas correctas**, una
  exclusiva de web omitida en VM, como antes.
- **49 pruebas específicas** de ejecución, semana, cuenta atrás y adaptador de
  audio correctas; otras **15 comprobaciones** de semana/diálogo correctas tras
  actualizar el texto de avisos y generar las capturas.
- Abandono antes de confirmar, parcial, todas completadas y todas omitidas;
  cancelación sin enviar, motivo, fallo/reintento, cierre encolado y retorno.
- Ancho 390/800/1200 px y selección de domingo; 320 px con texto doble y
  desplazamiento horizontal sin errores.
- Pitidos finales, pausa/reanudación/repetición, restauración, tiempos cortos y
  salto al final. Banco manual actualizado y compilado en web. Intervalo real
  de cinco segundos en Chromium: ocho reproducciones aceptadas (preparación
  3/2/1, inicio, cuenta final 3/2/1 y final), sin errores ni avisos en consola.
  Acredita aceptación del reproductor, no una valoración humana del sonido.
- Los recorridos de abandono usan un repositorio de prueba. El contrato SQL
  existente se ha leído, sin modificar ni ejecutar migraciones ni acreditar
  otra prueba autenticada de servidor.
- Alcance localizado de la app. No hay cambios de dependencias, admin, paquetes
  compartidos, motores, datos, permisos ni producción. Se conservan los límites
  nativos de UI-018: una compilación web no acredita iOS/Android físico.

![Preparación, inicio, tres pitidos y final reproducidos](visual-audit/session-controls-2026-10-08/audio-3-2-1.png)

IOS-002 completa después la comprobación del audio en Mac/simulador. El siguiente
recorrido es comprobar sonido/vibración en dispositivo físico cuando esté
disponible. UI-020 cierra las opciones de la flecha, conservando separado el
descarte de sesión en curso, ampliado después mediante UI-022.
