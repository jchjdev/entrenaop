# Recuperación de trabajo de ADMIN · UI-056 · 19/10/2026

Javier pide continuar las mejoras del admin y priorizar su fiabilidad. Este
bloque completa los límites de conservación de UI-055 para **programas guiados**.

## Recorrido implementado

- Crear o editar un programa abre `/guided-programs/work/:id`, con identidad
  estable también después de recargar. Una edición conserva su programa de origen.
- Los cambios se guardan tras 700 ms sin edición y mediante «Guardar trabajo
  ahora». Se conserva el texto original, orden, categorías, fases, descansos,
  calentamientos y referencias a sesiones pendientes, aunque todavía no sean válidos.
- «Continuar trabajando» muestra los trabajos privados de la cuenta con fecha
  local de guardado. Descartar confirma la acción y marca el trabajo como apartado;
  conserva sus datos en servidor y no elimina sesiones ni el programa de origen.
- El estado distingue cambios pendientes, petición en curso, confirmación y fallo.
  Solo la confirmación acredita persistencia. El guard avisa si quedan cambios
  sin confirmar; un trabajo ya guardado permite salir y retomarlo.
- Antes de abrir el creador de sesión o calentamiento se confirma el programa
  de origen. Antes de revisar una sesión pendiente se guarda su referencia.
- «Guardar en catálogo» aplica las validaciones existentes y crea/actualiza un
  borrador editorial. Sigue requiriendo sesiones publicadas y pendientes resueltas.
  Publicar el programa conserva su acción explícita e independiente.
- Una respuesta ambigua de guardado final permite reintentar la misma operación.
  La pantalla conserva la petición y bloquea su edición hasta confirmar el resultado.
  Recargar un trabajo ya completado indica que está guardado en el catálogo.

## Contrato de datos y concurrencia

`admin_guided_work_drafts` contiene estado de trabajo por administrador, revisión,
origen y resultado final. Se separa del contenido deportivo validado; ningún
borrador incompleto entra en los catálogos del deportista. Tamaño máximo 512 KiB
y formato de estado versionado (`schema: 1`). No añade dependencias Dart.

Solo el propietario con permiso administrativo vigente puede leer o modificar
su trabajo. RLS protege las lecturas y las RPC verifican identidad, permiso y
propiedad. No se permiten escrituras directas ni acceso anónimo. Se aplica la
separación de [permisos de tabla y RLS de Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security).

La revisión optimista evita sobrescribir cambios de **otra pestaña del mismo
trabajo**. La petición inicial tiene un UUID estable; el servidor devuelve la
misma revisión cuando se reintenta exactamente la escritura cuya respuesta se
perdió. El cliente serializa peticiones y resuelve primero la incierta antes de
enviar campos más recientes. Un conflicto conserva los campos en pantalla y
detiene los reintentos de sobrescritura.

Finalizar bloquea el trabajo, llama a `save_guided_program` y registra el ID
resultante en la misma transacción. Repetir la petición devuelve ese ID, incluida
una revisión de un programa publicado. El contrato anterior sigue operativo;
sus consumidores externos no adquieren idempotencia automáticamente.

Migración generada con CLI y aplicada a Dev mediante MCP; el archivo usa la
marca temporal real registrada por el servidor:
`20261019080620_admin_guided_work_drafts.sql`. El historial local y Dev coincide.

## Verificación

- Análisis de ADMIN limpio; 167 pruebas correctas y dos capturas optativas
  existentes omitidas. Compilación web release correcta.
- Pruebas nuevas de concurrencia y respuesta perdida; recuperación de semanas y
  descansos inválidos, pendientes, URL estable, reintento final sin duplicados,
  pantalla de 320 px con texto 2× y pérdida de conexión.
- SQL transaccional propio: repetición inicial y final, revisión sin duplicados,
  conflictos, escritura directa rechazada, aislamiento entre administradores,
  rechazo a deportistas/permisos retirados y validaciones editoriales intactas.
- SQL existentes `guided_program_authoring`, `guided_program_categories` y
  `guided_program_follow_through` correctos. Los cuatro scripts acaban en ROLLBACK.
- Asesores revisados: las tres RPC nuevas aparecen en el aviso genérico de
  funciones SECURITY DEFINER ejecutables por authenticated. Es intencional:
  verifican administrador/propiedad y revocan PUBLIC/anon. No hay otros avisos
  sobre los objetos de este bloque. Los avisos ajenos quedan fuera del alcance.
- Chrome autenticado contra Dev: un trabajo «QA recuperacion admin» guarda
  modalidad por fases y duración textual «pendiente», sin sesiones; recargar
  recupera sus campos y volver al catálogo permite continuarlo. Es un trabajo
  privado de prueba conservado, sin publicar un programa ni una sesión.
  [Captura real y procedencia](visual-audit/admin-recovery-2026-10-19/README.md).

## Límites y siguiente bloque

No es funcionamiento sin conexión: cerrar el navegador antes de que confirme
el guardado puede perder los últimos cambios. Un error conserva los campos
mientras permanezca abierta la pantalla. No se añade almacenamiento local de
contenido por cuenta ni sincronización de borradores de sesiones/calentamientos.

El conflicto protege la misma identidad de trabajo. Dos trabajos distintos
originados en el mismo borrador editorial conservan el contrato previo de
actualización del catálogo; no se acredita bloqueo editorial entre autores.
Tampoco se añade idempotencia a la creación independiente de sesiones o ejercicios.

Se verifican ADMIN, su nuevo contrato y las fronteras del catálogo. No cambian
la app del deportista, paquetes compartidos, algoritmo, subdominio ni producción.
El único siguiente bloque recomendado es **vista previa del programa como
deportista y revisión previa a publicar**, reutilizando el modelo vigente.
Duplicar como punto de partida, avisos de contenido sin uso/retirado y registro
de actividad administrativa quedan como propuestas ordenadas después de él.
