# Refresh: comparación con el informe anterior

Javier confirma el 07/10/2026 continuar el refresh aprobado y conservar los
motores de ejercicios para sus tareas de dominio. El texto entregado corresponde
a la revisión previa a `cf7025f`; se contrasta con el código local, no se ejecuta
como una lista de defectos que todavía existan.

## Estado al comenzar este tramo

| Observación del texto | Estado real al 07/10, antes de esta implementación |
|---|---|
| Evaluaciones Tropa/FAS/programa sin protección ni pantalla dedicada | Hecho en UI-008: tareas sin barra, cambios pendientes protegidos y guardado bloquea edición/salida. |
| Editor de sesiones admin sin protección | Hecho: guard de salida en router. |
| Ejercicios admin y referencias se cierran antes de guardar | Hecho: formulario retenido; error conserva valores y permite reintentar; evita doble envío. |
| Crear programa admin pierde valores si falla | Hecho: guardado retenido y descarte confirmado. |
| Formularios de pruebas, reglas, mínimos, tramos/importación/clonación | Pendiente al inicio de este tramo; aún cierran antes de persistir. |
| Secciones conservadas muestran información antigua | Pendiente: refresco al volver sin reiniciar navegación/posición. |
| Cierre de sesión siempre lleva a Mi plan | Hecho: vuelve al origen, entrada directa ofrece Mi semana; resultado por ID, deshabilitado mientras falta sincronización. |
| Pantalla final sin scroll y con notas largas | Hecho: finalización/abandono adaptados y comprobados con texto 2× y notas largas. |
| Recuperación de contraseña y confirmación persistente | Pendiente. |
| Mi plan como menú y accesos redundantes | Pendiente de reorganización. |
| Marcas abre gestión de preparación | Pendiente: destino específico de resultados. |
| Evolución: filtros, comparación e historial anterior a 30 registros | Pendiente; el límite de consulta no implica borrado de datos. |
| Vídeo como URL; edición/retirada de ejercicios propios y etiquetas | Pendiente de Biblioteca. |
| Nombres técnicos, jerarquía/contraste y acciones de formularios largos | Pendiente transversal; la identidad visual se mantiene. |
| Admin sin buscadores | Hecho: programas, sesiones y ejercicios; búsqueda/filtros conservados al recargar. |
| Admin sin rutas propias | Hecho: go_router, URLs por ID, comprobación de recurso/acceso, atrás/recarga y renovación de identidad. |
| Errores sin reintento; regla de simulación sin tratamiento | Hecho en las rutas y vistas afectadas por UI-008; no se afirma que todo posible error tenga el mismo tratamiento. |
| Filas de botones estrechas en baremos/pruebas | Primer pulido hecho con Wrap; queda la revisión transversal de densidad/zoom. |
| Laboratorio mezclado con edición | Hecho: página separada y simulaciones identificadas. |
| Navegador/Android autenticados, teclado/atrás/conexión/reanudación | Sigue pendiente de comprobación real; los tests usan repositorios simulados. |

## Dirección confirmada

Cerrar conservación del trabajo, retorno y refresco → Inicio/Mi plan orientados
a programa activo/semana → vocabulario visible consistente → Evolución con
resultados por preparación → Biblioteca operativa → admin organizado y cuenta.
Mantener cinco destinos, Biblioteca central, calendario, preparaciones,
favoritos, tema compartido y portadas. Consultar conserva estado; tareas tienen
pantalla dedicada. No modificar motores, dosis, algoritmo, SQL o producción
como parte de este refresh. Las reglas comparativas deben usar datos compatibles.

La implementación se guarda por bloques comprobados. La aprobación no convierte
todos los pendientes en hechos; cada cierre actualiza alcance, pruebas y límites.

## Cierre: refresco de secciones · 07/10/2026

Implementado: Inicio, Perfil, Mi semana y Evolución consultan de nuevo al volver
desde otra sección o una tarea, sin desmontar la rama ni repetir recargas desde
sus botones. Inicio/agenda/historial descartan respuestas de cargas anteriores y
no emiten tras cerrarse. La agenda conserva semana y día; el historial conserva
resultados durante el refresco y ofrece reintento si falla.
Los retornos del editor y del formulario de carrera se unifican con `go_router`,
manteniendo `Navigator` para diálogos y paneles modales.

Validación: `flutter analyze` limpio y las 482 pruebas completas de raíz
correctas. Regresiones de router real con ramas y tarea raíz, conservación de
texto/scroll, respuestas fuera de orden, cierre durante carga y fallo/reintento.
Repositorios simulados; sigue pendiente el recorrido autenticado en dispositivo.
No cambia SQL ni motores. Siguiente bloque: guardado retenido editorial de admin.

## Cierre: guardado editorial de admin · 07/10/2026

Implementado en creación/edición de pruebas, regla de calificación, tramos de
puntos, mínimos, importación de tabla, clonación de edición y vinculación de
estrategia. El diálogo espera la persistencia; un fallo mantiene sus campos y
ofrece reintento. Bloquea doble envío, salida y foco de teclado durante la
petición; al cancelar avisa solo si el contenido difiere del inicial.

La revisión de cambio de medición conserva el bloqueo por módulo y la
confirmación de retirada del baremo; cancelar vuelve al formulario. La
importación conserva su revisión y sustitución atómica existentes: cancelar o
fallar mantiene la tabla escrita. No se cambia qué se guarda ni las reglas de
entrenamiento. Tras persistir, un fallo de consulta se presenta como recarga y
no vuelve a abrir/habilitar el mismo envío. Clonación mantiene sus controles
hasta terminar el cierre del diálogo. Mínimos admite 320 × 480 y texto 2×.

Validación: análisis limpio en ambas apps; 482 pruebas de raíz, 85 de admin
correctas (una optativa omitida) y seis de `entrena_ui`. Regresiones con
repositorios simulados: fallo/reintento por formulario, doble envío/atrás,
descarte cancelado y revertido, revisión cancelada, fallo posterior de recarga,
clonación y accesibilidad. Sin cambios en SQL, motores o producción.

Quedan los demás bloques del refresh. El único siguiente tramo UX recomendado
es Inicio/Mi plan con programa en curso, semana y pendientes, retirando accesos
redundantes sin sustituir Biblioteca ni los motores.

## Cierre: Inicio/Mi plan · 07/10/2026

Mi plan deja de ser un menú de Biblioteca y muestra el programa realmente en
curso (incluida revisión pendiente), la semana natural con recuentos de agenda,
las tres primeras sesiones pendientes y el acceso a la semana completa. Retomar
abre la ejecución existente; ver una sesión abre su fecha/ID en agenda y no la
inicia desde una plantilla. Las otras preparaciones mantienen sus estados de
borrador, pausa y finalización, acceso a gestión e historial y configuración
propia. Se conserva disponibilidad/material y se retiran las entradas duplicadas
a Biblioteca y sesiones personales de esta raíz; Biblioteca sigue siendo el
tercer destino y la agenda conserva los entrenamientos extra.

Inicio conserva calendario, selección diaria, preparaciones, herramientas y
favoritos. Nombra la preparación de la sesión y comparte la tarjeta de siguiente
paso y los estados con Mi plan. Volver de esa tarjeta usa una única recarga desde
la frontera de navegación, sin el segundo callback que aún duplicaba la consulta.
No se cambian los criterios de siguiente paso ni las reglas deportivas.

Mi plan reutiliza el caso de uso/Cubit de resumen existente, con instancia por
cuenta. Una entrada directa a una ruta hija no carga el resumen de la raíz;
tras visitarla conserva la instancia y el scroll al salir y volver. Renovar la
sesión de la misma cuenta conserva la instancia; cambiar identidad la sustituye
y descarta una respuesta antigua pendiente. Carga, error persistente y reintento
conservan la consulta anterior.

Validación: `flutter analyze` limpio, 505 pruebas completas de raíz correctas y
ocho recorridos de captura correctos. Regresiones con router real para entrada
directa, retorno, identidad, cargas tardías, fallo/reintento, evaluación Tropa/FAS/
genérica, agenda manual y texto 2× a 320/1100 px. Las 20 imágenes proceden de
widgets actuales con datos simulados y fuentes legibles del entorno de captura;
no son una prueba autenticada en dispositivo. [Imágenes y recorrido](REFRESH_PLAN_2026_10_07.md).
No cambia admin, paquetes compartidos, SQL, motores ni producción.

Ese cierre dio paso al bloque Evolución/Marcas: destino de
resultados por preparación, filtros e historial de sesiones antiguas. Biblioteca,
cuenta, pulido transversal/admin y verificación autenticada real siguen pendientes.

## Continuación acotada tras la reversión · UI-010 · 07/10/2026

Javier plantea retomar este refresh evitando las pantallas y decisiones que
llevaron a mezclarlo con Free/Pro. La lista inicial de pendientes es histórica:
Inicio/Mi plan ya se cerró y sigue conservado en la base restaurada por COM-003.
No se vuelve a ejecutar esa lista como si todo siguiera pendiente.

La delimitación recomendó Evolución/Marcas. La inspección previa confirmó
que el acceso «Marcas» llevaba a `/plan/goal/:goalId`, es decir,
gestión de preparación, y que el historial de entrenamientos consulta como
máximo 30 registros. Corregir sus destinos y permitir consultar resultados
anteriores sigue pendiente; no se modifica su código en esta delimitación.

Esta descripción corresponde a la delimitación previa. El cierre UI-011 que
sigue acredita la implementación posterior y conserva sus exclusiones.

Para ese tramo, el alcance se limita a resultados e historial: conservar tema,
contratos de medición y navegación existentes, con filtros y retornos que no
pierdan estado. Inicio, Mi plan, tarjetas fotográficas, catálogo y preparación
actuales se mantienen como referencia, sin cambio comercial. Si alguna mejora
exige modificar esas áreas, se explicará primero su necesidad y el nuevo
alcance; no se ampliará el bloque por proximidad de una idea.

La propuesta de descubrimiento y ficha conserva ideas para el trabajo comercial
en otro chat. No autoriza recuperar la composición duplicada o las tarjetas
genéricas descartadas en UI-009, ni la simulación retirada COM-002. Derechos de
cuenta, pagos y cuotas siguen pendientes; los motores mantienen su tarea aparte.
Cada cierre se basará en diff, recorridos probados e imágenes de widgets reales,
indicando si usa datos simulados o una cuenta autenticada. Se guarda únicamente
el alcance comprobado, sin presentar el refresh completo como terminado.

## Cierre: resultados por preparación e historial · UI-011 · 07/10/2026

«Marcas» abre resultados de la preparación en Evolución. Tropa conserva su
baremo y controles de carrera; FAS conserva versión y referencia anterior a
vigencia; los programas configurables muestran resultados e intentos guardados.
El registro explícito abre las tareas existentes y actualiza al regresar.
No activa, pausa ni cambia una preparación desde la consulta.

Historial con filtros de preparación, fechas y estado, carga por páginas,
errores persistentes/reintento y resultado vacío propio de filtros. Volver
conserva criterios y profundidad; refrescar no recorta a 30 ni al máximo de
una respuesta del servidor. Cubits/páginas de resultados se renuevan por cuenta
y recurso y descartan respuestas tardías. FAS personal conserva datos al fallar
un refresco; con otra versión muestra marcas sin inventar puntuación.

Verificado: análisis limpio, 537 pruebas completas de raíz y nueve recorridos
de captura, con 22 imágenes de widgets actuales y datos ficticios. Incluye
HTTP local del contrato PostgREST, empates de fecha, 1205 ejecuciones,
fallo/reintento, filtros combinados, router real, identidad y texto 2× a
320/1100 px en Evolución y resultados configurables. No acredita un recorrido
autenticado ni una consulta real al backend. [Imágenes y esquema](REFRESH_EVOLUTION_2026_10_07.md).

Inicio/Mi plan, tarjetas/recursos fotográficos, catálogo, gestión de preparación,
admin, paquetes compartidos, SQL y motores no cambian. El negocio permanece
separado. Comparativas nuevas y tipo deportivo siguen pendientes; la lista de
preparaciones filtra las no archivadas. El único siguiente bloque UX recomendado
es Biblioteca: vídeo y gestión de ejercicios propios. Recuperación de cuenta,
pulido transversal/admin y revisión autenticada real siguen pendientes.
