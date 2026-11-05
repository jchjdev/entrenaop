# Revisión de ADMIN · 05/11/2026

Javier pide revisar los colapsos del laboratorio y mejorar estabilidad y eficiencia;
aclara que se refiere a campos o textos solapados. Se reparte la inspección entre
agentes de esta tarea con archivos separados. No se coordina con otros chats.

## Fallos reproducidos y correcciones

| Área | Evidencia | Corrección |
| --- | --- | --- |
| Fuerza y rendimiento | A 320 px con padding real y texto 2× la unidad «repeticiones» deja el editable con ancho cero, sin excepción Flutter. | La unidad pasa debajo cuando no cabe y el error admite varias líneas; escritorio conserva su sufijo. |
| Registro de ejecución | El diálogo real desbordaba 124 px a 320 px/texto 2×. | Título y contenido desplazables usando el patrón existente de AlertDialog. Se prueba editar y guardar. |
| Dominadas | Los dos ensayos de 26/52 semanas se ejecutaban dentro de build incluso al consultar otra semana. | Reutilización por marca, material, agenda, respuesta y horizonte. Cambiar esos parámetros recalcula; cambiar la semana consultada reutiliza ambos brazos. |
| Sesiones | El retorno propio y el observador de rutas pedían de nuevo las mismas consultas; rekey inicial repetía la lista de trabajos. | Un solo refresco coordinado al regresar, también desde URL directa. Contadores verifican consulta inicial y un retorno; filtros conservados. |
| Calidad | Después de corregir un recurso, sus avisos permanecían hasta Actualizar. | Recarga al volver del recurso sin sustituir el listado por otra pantalla. |

No se modifican algoritmos, dosis, publicación conjunta, permisos, servidor,
paquetes compartidos ni dependencias. Versión ADMIN: 0.5.1+10, corrección sobre
0.5.0+9. Raíz/deportista y Trainer conservan su versión y código.

## Verificación

Pruebas de tamaño real a 320/600/1440 px y texto 1×/2×; también área editable,
edición, guardado, navegación directa y por botón, recuento de consultas y
resultado actualizado de Calidad. Análisis ADMIN sin incidencias y batería completa de 390 pruebas correctas,
con dos omisiones previas. Las imágenes de prueba usan datos ficticios, no la cuenta real:
[320 px/texto doble](../visual-audit/admin-review-2026-11-05/admin-performance-series-320-2.png)
y [escritorio](../visual-audit/admin-review-2026-11-05/admin-performance-series-1440-1.png).

## Propuestas antes de ampliar

1. Catálogos grandes: paginación de consultas y metadatos con orden estable.
   La configuración local limita max_rows a 1.000 y existen lecturas sin range.
   Esto demuestra riesgo de truncamiento al crecer, no que el catálogo remoto
   actual esté truncado. Se debe concretar alcance y conservar selección/búsqueda.
2. Tarjetas de catálogos: carga perezosa en lugar de construir todas en un Wrap.
   Medir primero con un catálogo representativo y enseñar propuesta visual.
3. Ampliar la matriz visual a diálogos de estrategia, baremos e importación.
   Comparten patrón de título fijo, pero aún no se declara un fallo reproducido.

Único siguiente tramo recomendado: proponer y validar paginación completa de
catálogos/metadatos sin perder resultados ni filtros. No se aplica un rediseño
ni se activan estrategias deportivas experimentales como parte de esta revisión.
