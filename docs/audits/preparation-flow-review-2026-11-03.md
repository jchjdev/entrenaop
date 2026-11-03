# Revisión de preparación, configuración y consulta · 03/11/2026

**Corrección posterior autorizada · UI-067:** los hallazgos de esta instantánea
se corrigen en la app **1.7.0+15**. Se añaden regresiones de selección, asincronía,
identidad, navegación, Pro, formularios y recuperación del paso. Se mantiene el
algoritmo y se descartan cambios basados solo en estados sintéticos. El texto
inferior documenta el estado anterior, no el resultado de la corrección.
Validación posterior: análisis sin incidencias, 1.833 pruebas raíz correctas
(una omisión previa), incluidas setenta regresiones nuevas y capturas de la
configuración con el tema real. Aceptación física en iPhone pendiente.
[Recorrido implementado y límites](../ATHLETE_TRAINER_NAVIGATION_2026_10_22.md#preparación-configuración-y-consulta--03112026).

Revisión sobre `dcc20495cdcfd9987a45eb4e52c170b025b0c241` (app 1.6.0+14).
Javier pide revisar minuciosamente el vídeo y las combinaciones de estado antes
de retocar este recorrido. Esta auditoría **no cambia la aplicación ni acuerda
una nueva selección persistida de preparación**.

## Alcance y evidencia

- Vídeo completo adjunto de 168 segundos: gestión de preparaciones, configuración
  de FAS, referencias de movimientos, propuesta, activación, semana, cambio de
  sección y consulta de otra preparación. Se revisaron 84 muestras a intervalos
  de dos segundos y el código de los recorridos afectados.
- Tres agentes revisaron selección/cargas, interiores/formularios y fronteras
  de navegación/identidad/derechos. La revisión principal cotejó vídeo, hallazgos,
  decisiones y el flujo completo.
- 31 observaciones ejecutables de selección y cargas; incluyen una matriz de
  25 combinaciones de DTO y cuatro respuestas controladas fuera de orden.
- 37 pruebas existentes de configuración, referencias y disposición visual,
  más 17 observaciones ejecutables de formularios y persistencia.
- 36 comprobaciones de fronteras: tres observaciones nuevas y 33 regresiones
  existentes. Se repitieron los seis casos del harness para precisar la
  transición de cuenta y la pila de navegación.
- Las ejecuciones finales terminaron con código 0. **Las observaciones verifican
  el comportamiento defectuoso actual; no son pruebas de aceptación de una
  corrección ni deben conservar ese comportamiento como requisito.**
- Sin consultas de cuentas reales, cambios SQL, cambios de aplicación ni cambios
  en Trainer/ADMIN. Datos y colaboradores de prueba son sintéticos. Los
  fotogramas, harness y logs están en `build/preparation_flow_review/`, ignorado
  por Git; no se publican capturas ni datos personales del vídeo.
- No se ha identificado la compilación instalada con la que se grabó el vídeo.
  Las reproducciones adicionales corresponden al código actual y a pruebas
  Flutter controladas; no acreditan una instalación o ensayo físico en iPhone.

## Qué explica los cambios que se ven

No existe una preferencia de «última preparación visitada». La protagonista de
Entrenar se obtiene de estados: revisión pendiente, programa comenzado no
pausado/finalizado, pausado y, a falta de ellos, primer objetivo guardado.
Los objetivos se leen por antigüedad. La consulta de otra ficha no escribe
una selección ni activa su programa.

Además hay dos mecanismos que alteran la apariencia sin seleccionar otro plan:

1. Al cambiar de sección se restaura su pila; volver a pulsar la pestaña activa
   regresa a su raíz (`app_shell.dart:17`). Volver a Entrenar puede mostrar una
   ficha abierta de otra preparación, no la tarjeta principal.
2. Inicio/Entrenar/gestión refrescan los programas. Ese refresco llama a la
   continuación automática acordada y puede publicar una semana o actualizar
   estados. No debe retirarse para disimular movimientos de la interfaz.

El servidor mantiene un único generador `auto_advance` y la activación confirmada
pausa el anterior. Una preparación guardada o una consulta no equivalen a activar.

## Hallazgos reproducidos

### 1. Estado de la ficha retenido al cambiar de cuenta

Prioridad alta. Abrir `/plan/goal/g` con A y emitir directamente
`AuthAuthenticated(B)` mantiene el mismo `PreparationDetailCubit` y el nombre
de la preparación cargada por A. La clave de la ficha contiene el objetivo,
pero no la cuenta (`app_router.dart:636`). La consulta del plan sí separa ambos.

Esto demuestra aislamiento incorrecto de datos ya cargados en el cliente en
esa transición. No acredita el comportamiento de logout → login ni una fuga
de RLS o una lectura remota entre cuentas. Corrección propuesta: aplicar a la
ficha la frontera por cuenta ya utilizada por el plan y comprobar respuestas
tardías, renovación del mismo titular y cambio de titular.

### 2. Ficha y plan forman un ciclo de navegación

`AdaptivePlanPage` hace `push` a «Ver preparación y marcas»; la ficha vuelve a
hacer `push` a «Mi plan adaptativo» (`adaptive_plan_page.dart:191` y
`preparation_detail_page.dart:117`). Tres repeticiones obligan a recorrer nueve
páginas al volver, alternando ficha y plan. Las nuevas copias pierden también el
parámetro de semana original. Es un ciclo real, no solo una impresión visual.

La solución debe considerar origen, ruta directa y semana. No sustituir todas
las operaciones por `go` o `pop` sin comprobar sus efectos sobre el recorrido.

### 3. Una semana antigua puede reemplazar la consulta reciente

`PreparationDetailCubit` acepta respuestas antiguas de `load` y `changeWeek`
(`preparation_detail_cubit.dart:42–69`). Se reprodujeron cabecera y detalle de
semanas distintas al avanzar/retroceder, y un error viejo reemplazando un éxito
reciente. Las flechas permanecen disponibles mientras carga, por lo que el caso
es alcanzable desde la interfaz. Cerrar el Cubit sí bloquea respuestas posteriores.

El patrón de versión de petición ya existe en Dashboard y en el plan de consulta.
Reutilizar ese criterio de forma localizada, sin bloquear navegación innecesaria.

### 4. Un plan finalizado antiguo tapa una preparación nueva pendiente

Con objetivos `[antiguo, nuevo]` y estados `[complete, draft]`, la portada elige
el antiguo por `goals.first` (`training_preparation_overview.dart:26`). Contradice
el criterio documentado de no ocultar una nueva preparación tras una finalizada.
El test existente que se titula así no incluye el objetivo antiguo en `goals`,
por lo que no cubre el caso real de la lista de objetivos conservada.

Corregir ese fallback conserva la decisión vigente. Recordar la última ficha
visitada sería otra decisión y no se desprende de esta corrección.

### 5. Validación tardía y alejada del campo

- Descansos de 29/601 segundos permiten pasar de «Tu resultado real» a «Tu
  contexto» y fallan al guardar; 30/600 se aceptan. El vídeo reproduce el rodeo
  con un descanso de 12 segundos. El límite 30–600 se comprueba en `_save`, no
  en la validación del campo (`performance_reference_dialog.dart:251,319,711`).
- Una marca objetivo cero permite llegar a «listo para revisar» y solo se
  rechaza al solicitar los primeros entrenamientos, lejos del movimiento.
  La meta es opcional: vacío y cero no deben confundirse.

Validar en el campo/paso adecuado y reutilizar la misma regla al guardar. No
cambiar límites deportivos, protocolos ni cálculos para resolverlo.

### 6. Atrás cambia de significado dentro del asistente

Disponibilidad solo ofrece Continuar; su flecha superior sale de la ruta en
vez de volver al primer paso. Movimientos y Carrera sí tienen retorno al paso
anterior (`preparation_training_page.dart:502,997`). Parte de los datos ya está
guardada y otra parte no, agravando la sensación de reinicio.

Propuesta: retroceso por pasos dentro de la configuración, salida explícita y
guardia de cambios coherente. Conservar la salida al origen desde una consulta.

### 7. Borradores de referencias sin protección suficiente

- Cancelar/X descarta una referencia sin guardar en cualquiera de los tres
  pasos, sin advertencia. No sobrescribe la referencia que ya estaba guardada.
- Introducir dos series, cambiar a «Una serie» y volver a «Varias series» borra
  la segunda serie introducida (`performance_reference_dialog.dart:461,865,904`).

Propuesta: conservar temporalmente valores al cambiar modalidad y advertir al
salir de un borrador editado. El payload debe seguir incluyendo solo la modalidad
elegida; conservar el borrador no autoriza mezclar clases de referencia.

### 8. Respuesta del catálogo después de cerrar su controlador

`PreparationGoalCubit.load` no comprueba `isClosed`. Cerrar la pantalla y resolver
después su carga produce `StateError` (`preparation_goal_cubit.dart:14`). Aplicar
la protección de ciclo de vida y de peticiones que ya existe en otros Cubit.

## Otros problemas confirmados por código o vídeo

- **Acciones que no describen el destino:** en Tropa/FAS la ficha dibuja una entrada al plan
  y también una promoción «Configurar mi plan» sin conocer si ya está activo.
  Con Pro, esa promoción abre `/training`, que puede mostrar el panel activo en
  vez de la configuración. El estado debería decidir la acción; el derecho
  comercial debería decidir si requiere acceso Pro.
- **Borrador Pro con etiqueta de gestión:** `_PlanAction` depende de
  `proRequired && draft` para llamarse «Configurar». Un borrador Pro aparece
  como «Gestionar» (`adaptive_plan_page.dart:217`). No es un fallo de permisos.
- **Persistencia poco explicada:** objetivo, contexto y referencias se guardan
  en momentos diferentes; el paso actual es local y comienza de nuevo al entrar.
  Guardado parcial y plan activado no son lo mismo.
- **Fechas incoherentes:** `Referencia: 2026-11-03` se interpola desde datos y el
  diálogo construye una fecha con barras (`preparation_training_page.dart:885`,
  `performance_reference_dialog.dart:808`). Reutilizar el formateador visible;
  conservar ISO en datos y transporte.
- **Mensajes de error poco precisos:** el guardado de referencia recomienda
  revisar la conexión para cualquier excepción, aunque el servidor pueda
  rechazar datos. Hace falta distinguir casos sin exponer errores técnicos.
- **Demasiadas entradas con nombres parecidos:** Preparación, Mi programa, Tu
  programa y Mi plan adaptativo mezclan ficha, editor, propuesta y consulta.
  Hay cargas sucesivas visibles en el vídeo; no se ha medido latencia de red
  ni se atribuye un problema de rendimiento al servidor.

## Comportamientos que hay que conservar

- Cambiar de cinco a cuatro pasos al excluir carrera es correcto y está probado.
- Las referencias de entrenamiento y las marcas con protocolo oficial no son
  intercambiables. Tampoco lo son marca objetivo y capacidad medida.
- Cero como resultado se rechaza en el paso del resultado; las fracciones
  válidas, como 12,5 segundos, se conservan.
- Fallar al guardar objetivo/contexto o activar mantiene el paso y permite
  reintentar en los casos comprobados.
- La consulta directa del plan permanece accesible a Free y no calcula ni inicia.
- El plan de consulta conserva identidad/semana en renovación de sesión y
  descarta respuestas antiguas al cambiar semana o cuenta.
- `/training` puede ejecutar `advance` y `calculate`; no es una pantalla de
  consulta intercambiable con `/plan`. La continuación automática se mantiene.
- La activación revisada pausa el generador anterior y conserva sus resultados.
- Guardar una referencia sí incorpora el material confirmado al contexto común;
  no se ha demostrado la supuesta pérdida de material sugerida durante la lectura.

No se encontró un camino normal de las APIs revisadas que mantenga un programa
antiguo `needs_review` y otro nuevo `training` como generadores simultáneos.
La prioridad del DTO puede ensayarse con esa combinación, pero no se presenta
como un fallo real demostrado. Igual límite para `needs_review` con
`auto_advance=false` creado solo en el harness.

## Recorrido recomendado para una propuesta posterior

Mantener las cards, portadas y desplazamiento interno actual de Entrenar.
Unificar el interior alrededor de la preparación identificada por su nombre:

1. Desde Entrenar o Mis preparaciones, una ficha coherente de la preparación.
2. En esa ficha, una acción principal dependiente de su estado: Configurar,
   Continuar configuración, Ver mi plan o Revisar/Retomar cuando corresponda.
3. Configuración como asistente con retroceso coherente y guardado explicado.
4. Propuesta revisable y activación explícita; después, volver a la consulta
   canónica del plan, sin dejar otro panel casi idéntico en la pila.
5. Marcas y datos del objetivo accesibles sin volver a empujar la misma ficha
   desde su propio plan ni perder semana/origen.

Consultar otra preparación no cambia el generador. Si se decide recordar una
preparación consultada, debe ser una preferencia de presentación por cuenta,
separada de la activación; no introducirla como efecto lateral de un clic.

Orden recomendado del siguiente bloque: aislamiento de cuenta y peticiones;
correcciones deterministas de selección/validación/borradores; consolidación de
entradas, nombres y retorno con propuesta visual revisable. Convertir los
contrajemplos en regresiones de comportamiento correcto al implementar.
La reorganización descrita es **propuesta, no implementación ni decisión nueva
confirmada**. Quedan fuera la modificación del algoritmo, dosis, baremos,
cuotas, permisos comerciales y reglas de activación.
