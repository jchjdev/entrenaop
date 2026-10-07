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
