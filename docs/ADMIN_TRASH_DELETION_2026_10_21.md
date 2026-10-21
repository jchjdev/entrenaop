# Papelera de sesiones y borrado manual · ADM-004 · 21/10/2026

## Decisión y recorrido

Javier amplía ADM-003: borrar definitivamente programas desde su papelera, con
confirmación, y aplicar el mismo recorrido a sesiones. Se mantiene el guardado,
revisión y publicación conjunta existentes. Solo desarrollo.

- **Programas guiados → Papelera → Borrar definitivamente** elimina todas las
  versiones de la familia, sus enlaces, metadatos de portada y trabajos vinculados
  propios. **No elimina ninguna sesión**, tampoco las que solo usaba esa familia.
  Un programa con seguimientos se conserva: el servidor impide purgarlo.
- **Sesiones → ⋯ → Mover a papelera** retira una versión concreta, sin eliminar
  su receta. La ficha también ofrece esta acción, sustituyendo el antiguo borrado
  inmediato del borrador. Las sesiones enlazadas a cualquier programa, incluso
  uno en papelera, o a calentamientos no pueden retirarse. Las citas pendientes
  o en curso también bloquean la retirada.
- **Sesiones → Papelera** permite recuperar o borrar definitivamente. Recuperar
  conserva el ID: los borradores vuelven editables; antiguas publicaciones vuelven
  retiradas y privadas, sin republicación automática.
- La eliminación definitiva de una sesión exige que no tenga programas,
  calentamientos, versiones posteriores, referencias en trabajos guardados,
  citas, ejecuciones ni sesiones de seguimiento. El mensaje explica el bloqueo.
  Las comprobaciones ocurren en PostgreSQL, aunque se invoque la RPC directamente.
- Los trabajos privados descartados pueden eliminarse por separado, con su
  propietario, revisión y fecha vigentes. El diálogo explica qué se elimina y
  ofrece **Cancelar** como acción principal. El botón final dice **Borrar para
  siempre**; fuera del diálogo se llama **Borrar definitivamente**.

La papelera no se vacía automáticamente. No cambia preparaciones deportivas,
recetas personales, algoritmos de carga ni producción. No se purgan archivos
de Storage: una portada puede reutilizarse y necesita una limpieza independiente
que conozca sus referencias. El historial conserva la auditoría y las copias
cifradas anteriores duran su retención normal; «definitivo» significa que no hay
recuperación desde la papelera ni el historial del admin, no borrado de respaldos.

## Contrato y seguridad

Migración `20261021065836_admin_editorial_permanent_delete.sql`, instalada en Dev.
`workout_templates.trashed_at` y `trash_previous_status` guardan el estado de una
sesión oficial retirada. CHECK y trigger impiden publicar/editar desde una pestaña
obsoleta. Las consultas ADMIN excluyen `trashed_at`; la visibilidad privada y el
estado retirado la excluyen del catálogo del deportista. No se cambia su lector.

RPC protegidas con admin/MFA, `search_path` vacío y sin ejecución anónima:
`trash_admin_session`, `restore_admin_session`, `list_admin_session_trash`,
`purge_admin_trash` y `load_admin_guided_work`. `remove_admin_workout` delega en la
retirada recuperable. DELETE directo en `workout_templates` queda limitado por
RLS a recetas personales propias; las funciones oficiales existentes conservan
su escritura SECURITY DEFINER. Así no puede saltarse la papelera desde el cliente.

La purga de familias comparte su bloqueo de autoría. Fecha exacta del lote y
revisión rechazan acciones antiguas. El borrado de recetas bloquea su fila y las
FK siguen impidiendo eliminar referencias, incluidas nuevas referencias
concurrentes. Cualquier violación revierte la operación completa.

`admin_ops_private.deleted_resources` conserva solo tipo, UUID, propietario de
trabajo y fecha. RLS y ausencia de grants impiden leer sus marcas desde el cliente.
Impide resucitar trabajos por URLs antiguas, volver a guardar referencias JSON a
sesiones purgadas y recuperar recursos purgados desde el historial. El cargador
devuelve un estado cerrado distinguible de un trabajo todavía no creado. El guard
del trabajo bloquea las recetas mencionadas y después consulta estas marcas para
coordinar las referencias JSON con su purga; no se atribuye un ensayo simultáneo
de varias conexiones.

El asesor informa las cinco RPC como SECURITY DEFINER autenticadas: es deliberado,
con admin/MFA probado. La tabla privada con RLS sin políticas es también deliberada;
no hay acceso cliente. No se declaran corregidos los avisos anteriores ajenos.
Referencias oficiales: [permisos de funciones](https://supabase.com/docs/guides/database/functions),
[asesor de RPC autenticadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
[tabla privada sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

## Verificación

- Migración y ensayo nuevos ejecutados juntos con ROLLBACK antes de instalar.
  **176 migraciones locales/remotas coinciden** después de instalar solo en Dev.
- **Trece SQL con ROLLBACK:** purga editorial, papelera de programas, autoría de
  sesiones, trabajo privado, publicación conjunta, autoría guiada, seguimiento,
  portadas, operaciones editoriales, MFA, cuota/pausa, descubrimiento editorial
  y edición de ejercicios personales. El ensayo nuevo también acredita DELETE
  personal propio, rechazo de DELETE directo oficial, referencias JSON, sesiones
  compartidas, protección de ejecuciones, propiedad y URLs obsoletas. No deja datos.
- **296 pruebas ADMIN correctas**, dos omisiones previas; las siete regresiones
  nuevas cubren confirmación/cancelación, petición única, bloqueo con motivo,
  rutas de sesiones, filtrado HTTP y carga del trabajo purgado. **30 Python** del
  publicador/copias correctas con el runtime GPG instalado.
- Capturas de widgets reales en escritorio y 320 px/texto 2×; cancelación y acciones
  utilizables. La confirmación utiliza palabras cortas para evitar partir el título.
- Análisis ADMIN limpio y build web release Dev correcto. Vista local actualizada
  sin recargar el montaje abierto de Javier.
- Publicación automática [39561491328](https://github.com/jchjdev/entrenaop/actions/runs/39561491328)
  correcta: validación, despliegue y retención. Revisión publicada
  `4b2759dc313bed390eb3c6ac2933405111b6ad65`. Comprobación HTTPS independiente de
  manifiesto Dev, hash JavaScript, cabeceras y MIME WASM correcta.
- Chrome acredita la navegación Sesiones → Papelera, retirada → recuperación
  como el mismo borrador → nueva retirada. La sesión técnica
  `10e66ff8-2f19-45bc-9f78-ac5a4ba63550` nunca se publica ni aparece como suelta.
  Se comprueban las confirmaciones definitivas de programa y sesión y se cancelan
  durante el ensayo automatizado; la purga se ejercita en SQL con ROLLBACK.
- La consulta final del navegador compartido y Dev muestra después esa sesión
  técnica ya purgada, con marca `session` a las 07:33:15 UTC y sin receta. Esta
  acción posterior no la ejecutó el ensayo automatizado. Los programas temporales
  del ensayo SQL no persisten. No se recrea la sesión eliminada.

Único siguiente paso recomendado: aceptación del recorrido de papelera con el
catálogo de prueba de Javier antes de ampliar la gestión del catálogo.
