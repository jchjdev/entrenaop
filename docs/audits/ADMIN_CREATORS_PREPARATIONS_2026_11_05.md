# Creadores y preparaciones integradas de ADMIN · 05/11/2026

Javier pide revisar creadores, solapamientos y por qué FAS y Tropa parecen vacíos.
La ausencia de síntomas de carga no acredita truncamiento: la paginación de los
catálogos editoriales grandes sigue siendo una propuesta preventiva independiente.

## Hechos contrastados

En Supabase Dev, los programas `armed_forces_troop_entry` y
`fas_periodic_assessment` están habilitados y no tienen filas en las tablas de
evaluación configurable. La ficha ADMIN solo consultaba esas tablas, mostraba
«sin regla»/«sin pruebas» y ofrecía clonar una regla nula, sin resultado ni aviso.
Sus catálogos reales siguen presentes: Tropa tiene 24 mínimos y FAS 64; cada
preparación tiene tres objetivos específicos de rendimiento. Los dos catálogos
vigentes proceden de `preparation_program_catalogs` y `assessment_catalogs`.

CNP y Guardia Civil sí tienen definición configurable (cuatro y una pruebas en
los borradores consultados). El fallo no depende de quién creó las filas, sino
del circuito de datos que utiliza cada preparación.

## Correcciones y capacidad entregada

- Repositorio ADMIN de solo lectura para los dos catálogos integrados. Consulta
  versión vigente, fuente, pruebas, mínimos y objetivos/condiciones existentes,
  con orden estable y páginas. No importa código de la app del deportista.
- Ficha específica conectada desde el router/composición real. Evita las tres
  consultas configurables equivocadas, mensajes de vacío y clonación inerte.
  Conserva la portada. Error de lectura tiene reintento, no se convierte en cero.
- Tiempos originales en milisegundos se presentan con su precisión. FAS conserva
  la distinción entre mínimos de referencia de 20 puntos y tabla completa 0–100;
  la consulta de mínimos no inventa la puntuación completa ni determina aptitud.
- Secciones plegables para consultar datos y condiciones; los objetivos
  adaptativos no se presentan como sesiones fijas del catálogo editorial.
- Diálogo de descarte del creador guiado: desbordamiento de 332 px reproducido
  a 320×600/texto 2×; título y contenido pasan a ser desplazables. Cancelar
  conserva el trabajo hijo. El mecanismo de guardado/publicación no cambia.
- Se cumple el rótulo acordado «Guardar borrador y salir» en ADMIN con checkpoint;
  «Guardar y revisar» y estado draft se mantienen por separado.

Versión ADMIN 0.6.0+11. No se modifican esquema, RLS, grants, reglas deportivas,
resultados, planificaciones ni versiones activas. Deportista/Trainer conservan
sus versiones al no cambiar su recorrido funcional; se verifica el consumidor
compartido conforme a la matriz del repositorio.

## Alcance comprobado y límites

98 pruebas dirigidas revisan autoría, recuperación, guardado, revisión, Compacto,
catálogo y tamaños 320/390/1100 con texto ampliado. El paquete común pasa 250;
la app del deportista 1.844 y una omisión previa. ADMIN pasa 397 con dos
omisiones previas. Análisis de raíz y ADMIN sin incidencias.

La consulta real de catálogos, definiciones, mínimos y seis objetivos se verificó
con rol authenticated mediante BEGIN/DO/ROLLBACK, sin datos nuevos ni cambios de
permisos. Las pruebas de repositorio usan respuestas HTTP controladas; las de
ficha comprueban ambos IDs y cero lecturas de tablas configurables. Render,
reintento, parámetros largos y unidades se prueban a 320 px/texto 2×.

Esto no acredita ausencia universal de fallos, rendimiento medido con miles de
recursos ni aceptación autenticada en navegador de todos los creadores. Una
hipótesis de catálogo guiado desactualizado desde URL directa se ensayó y no se
reprodujo; no se modifica por suposición.

## Propuesta que requiere acordar el siguiente bloque

Consultar no hace editables FAS/Tropa. Para ello se propone una autoría versionada
que reconozca la procedencia/capacidad de cada preparación, permita crear una
revisión completa, compare sus datos y publique explícitamente. Debe preservar
las identidades y resultados anteriores, sus hitos/edades/unidades y las lecturas
de los motores existentes. No basta con copiar los mínimos al creador genérico:
FAS no tiene ahí la puntuación completa y el entrenamiento adaptativo no es una
lista fija de sesiones.

Antes de habilitar edición se necesita concretar con Javier qué campos administra
(fuente, vigencia, pruebas, mínimos/puntuación y condiciones de entrenamiento),
validar su representación y probar las RPC/versiones con historial existente.
No se implementa esa conversión ni se presenta como aprobada por pedir una revisión.
Los planes nuevos creados con el editor configurable siguen su autoría actual;
una futura preparación integrada directamente necesita declarar su adaptador.

## Publicación verificada

El commit `1c095c996725016f910523c8846e46f002957f4f` está en main. La ejecución
[ADMIN Dev 42013395095](https://github.com/jchjdev/entrenaop/actions/runs/42013395095)
terminó correctamente en validación, despliegue y retención. Se comprobó por
HTTPS el 05/11/2026: versión 0.6.0, compilación 11, entorno development, proyecto
`sxbxfjqgoddzhtcyhalw`, revisión y base de recursos de esa ejecución, SHA-256 de
main.dart.js coincidente, X-Frame-Options DENY y Cache-Control no-store. Esto
acredita publicación y destino; la aceptación autenticada con la cuenta de Javier
queda como comprobación de uso posterior.
