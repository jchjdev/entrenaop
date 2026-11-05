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
el aislamiento entre familias y la protección de la versión publicada. La
evidencia de ejecución real figura a continuación.


## Aplicación acreditada

Commit 3f289ed8e87e24b5eaf57480376733e3d047c96a; ejecución Trainer Dev
42088472822 con validación, despliegue y retención correctos. La nueva compilación
hace avanzar la ventana de cinco: se retiran finalmente 107 ZIP por
1.669.615.012 bytes bajo la misma regla aprobada. Inventario posterior: cinco
Trainer y cinco ADMIN, 158.250.328 bytes activos. No se eliminó ninguna copia de
datos ni se modificó una sesión, cliente o código fuente.
