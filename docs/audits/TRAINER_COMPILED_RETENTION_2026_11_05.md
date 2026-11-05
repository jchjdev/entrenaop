# Retención de compilados Trainer Dev · 05/11/2026

La copia real ya supera restauración aislada y cifrado en el intento 2 de
42085037509; la conservación falla con artifact_budget_limit. El inventario
público contiene 111 ZIP Trainer activos, además de cinco ADMIN. El plan de
solo lectura conserva cinco Trainer y siempre la revisión publicada; retira
106 ZIP por 1.653.961.869 bytes. No incluye copias de datos, fuentes, sesiones,
clientes ni archivos del alojamiento. La retención ADMIN existente no cambia.

Javier autoriza expresamente la limpieza y su automatización en respuesta a la
pregunta con esas cifras y consecuencias. Los ZIP retirados dejan de poder
descargarse; Git conserva el código para volver a compilarlos.

El job separado se ejecuta después del despliegue Trainer Dev verificado. Tiene
solo permiso de contenido de lectura y Actions de escritura, sin credenciales de
Hostinger ni Supabase. El script es plan de solo lectura por defecto; aplicar
exige repositorio/main/revisión iguales al entorno y al manifiesto HTTPS Dev.
Revalida identidad del artefacto y versión publicada antes de cada eliminación.
No reintenta DELETE de resultado incierto. Se excluyen ADMIN, copias, expirados,
nombres ajenos y revisiones que no coinciden con la ejecución de main.

32 pruebas de herramientas Trainer y 48 ADMIN correctas antes de activar, incluido
el aislamiento entre familias y la protección de la versión publicada. La ejecución
real y su inventario final se acreditan al cerrar la recuperación.
