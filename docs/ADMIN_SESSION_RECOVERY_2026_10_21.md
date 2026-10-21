# Sesiones incompletas y pendientes de ADMIN · 21/10/2026

ADM-008. Encargo de Javier: recuperación de sesiones incompletas y portada de
pendientes. Se conserva el diseño actual del creador, su ventana y Compacto.
Las otras propuestas del estudio de Harbiz y cualquier rediseño se enseñan antes
de implementar. No se cambian dosis, kg opcionales, RIR, RM ni algoritmo.

## Estado de entrega

Código y portal Dev implementados y comprobados en Chrome autenticado. Las
migraciones `20261021195030_admin_workout_work_recovery.sql` y
`20261021210246_admin_session_pending_receipt_guard.sql` están aplicadas solo en
Dev; contrato SQL repetido sobre el esquema aplicado con `ROLLBACK`. Al cierre
hay 201 migraciones coincidentes y ninguna pendiente. Las dos migraciones
profesionales intermedias fueron aplicadas por su chat. Producción no se ha
consultado ni modificado. La aceptación de Javier sigue siendo el siguiente paso.

## Recuperación

- `WorkoutEditorPage` incorpora un binding opcional. Sin binding conserva su
  guardado y callbacks anteriores. Captura texto crudo, carrera/fuerza, ramas
  ocultas de formatos, variaciones, orden y huecos automáticos de Tabata.
- El codec es independiente del contenido final. Mostrar una variación vacía
  que hereda valores no genera un cambio; espacios realmente escritos se conservan.
- El checkpoint canónico se extrae del controlador de programas; este mantiene
  su API. Ambos serializan escrituras y reintentan una petición incierta antes
  de enviar el siguiente estado. No mezclan automáticamente dos pestañas.
- El contexto oficial tiene un codec propio para `showInLibrary`. El adaptador
  fija propietario y token antes de enviar. Cada RPC comprueba propietario esperado,
  permiso administrativo, AAL2 y factor TOTP verificado.
- La conversión existente del formulario a receta se extrae a una función pura
  compartida (`projectWorkoutEditorSnapshot`), sin otra implementación paralela.
  El raw permite recuperar entradas incompletas; la intención incluye la receta
  final y se somete al validador existente del servidor. El servidor no interpreta
  el raw como una segunda receta ni acredita una comparación semántica raw/receta.
- La intención final se guarda con la receta validada antes de crear/revisar.
  Servidor crea versión y recibo en una transacción. Recargar consulta ese recibo;
  no vuelve a crear una sesión. Un rechazo definitivo permite volver a editar
  mediante operación explícita que comprueba que no existe resultado confirmado.
- Fuera del programa, URL estable `/sessions/work/:workId` y entradas desde
  Sesiones/Pendientes. Dentro, el programa conserva fase/posición/UUID del trabajo
  antes de abrir la ventana. Retomar usa la misma identidad y enlaza exactamente
  esa posición, incluso si la misma sesión aparece dos veces.
- Los campos incompletos viven en esquema privado, con RLS habilitado y sin
  acceso directo de clientes. Fachadas invoker delegan operaciones autorizadas.
  Límites técnicos: 512 KiB por snapshot, 1.000 trabajos conservados por cuenta,
  consulta de hasta 100 recientes con aviso de posible parcialidad. No son tarifas.
- Descartar exige confirmación y conserva versiones guardadas. No hay purga
  automática. El guardado de programas antiguos no puede quitar referencias a
  hijos con datos sin confirmar su descarte o enlace. Retirada/borrado de una
  receta base con trabajo abierto queda protegido. No se serializan catálogo,
  credenciales, vídeos, URLs firmadas ni errores.

## Portada

`/home`, destino de entrada tras autenticación, reúne sesiones y programas
incompletos, avisos editoriales y diagnóstico existente de copias/errores.
Cada sección carga y reintenta por separado. Un fallo se indica como desconocido,
no cero. Los avisos cuentan incidencias, no recursos únicos; borradores se
distinguen de errores. Se explican retención/periodo y límites de las consultas.
Los destinos mantienen sus permisos y no se añade lectura de datos profesionales
privados ni otro cálculo de métricas.

## Idioma

Javier aporta selector de fecha profesional en inglés. ADMIN y Trainer declaran
`es_ES` y delegados oficiales `flutter_localizations` del mismo SDK; ya estaba
resuelto transitivamente. Sin actualización de paquetes ni fechas deportivas.
Las pruebas montan cada aplicación y abren su selector: octubre y Cancelar.

## Límites y coordinación

El editor personal del deportista conserva su store. Trainer conserva su
repositorio, SQL y rutas; su conexión al binding común se coordina en su chat,
sin importar código de ADMIN. La app del alumno y avisos profesionales se trabajan
allí. Calentamientos usan su guardado específico actual y no se declaran cubiertos
por la recuperación nueva de sesiones oficiales.

## Comprobaciones del tramo · 21/10/2026

- Análisis global y ADMIN sin incidencias. Editor compartido también analizado.
- Batería raíz: 1.241 correctas y una omisión previa. Incluye fuentes de otros
  bloques presentes en el árbol compartido; no se atribuyen todas a ADM-008.
- Editor compartido: 132 pruebas correctas; recuperación, formatos, conversión,
  reintento incierto, recibo previo, destino repetido y ausencia del binding.
- ADMIN: 312 correctas y dos omisiones previas. Incluye portada, reintento
  independiente, visibilidad restaurada, filtro de preparación y calendario
  real de la aplicación en castellano.
- Compilación web release ADMIN Dev correcta. SDK `flutter_localizations` se
  declara directo, sin cambiar versiones del lockfile.
- Contrato SQL `supabase/tests/admin_session_work_recovery.sql`: permisos,
  AAL1/AAL2, propietario esperado, CAS, recibo idempotente, rechazo y reapertura,
  descarte y protección de referencias. Termina en ROLLBACK sin datos de prueba.
- Se revisaron los asesores de seguridad tras aplicar: la tabla privada nueva
  aparece como INFO por RLS sin políticas. Es intencional: no hay grants de acceso
  directo y se accede por funciones autorizadas. Las advertencias anteriores del
  proyecto no se corrigen ni se presentan como resueltas por esta entrega.
  [Explicación del asesor](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
- Evidencia visual de widgets con datos de prueba, no de la cuenta real:
  [escritorio](visual-audit/admin-recovery-2026-10-21/admin-pendientes-1200-1.png)
  y [320 px con texto al doble](visual-audit/admin-recovery-2026-10-21/admin-pendientes-320-2.png).
  No hay desbordamientos; a texto doble se conserva el desplazamiento vertical.

Único siguiente paso de ADMIN: aceptación con la cuenta de Javier al retomar una
sesión incompleta y abrir sus pendientes. Antes de biblioteca de medios, métricas,
resumen visual del programa o rediseño del creador se enseña propuesta; no se
implementan como extensión implícita de este bloque.

## Publicación web y comprobación autenticada

El paquete `ac7284fd5195cb3bffb223e3c61d028e5d182069` se publicó en
`admin.entrenaop.es`, conectado exclusivamente a Dev. La CI
[39671787411](https://github.com/jchjdev/entrenaop/actions/runs/39671787411)
validó y compiló correctamente. El primer envío falló con OSError; reintentar
solo los trabajos fallidos publicó y verificó HTTPS sin volver a compilar ni
alterar credenciales. Deploy y retención terminaron en success. Manifiesto:
`ac7284fd5195cb3bffb223e3c61d028e5d182069-39671787411-1`.

Chrome autenticado acredita portada con datos reales, trabajo de sesión sin
receta completa, salida al catálogo y reapertura desde Pendientes con la misma
identidad, nombre, indicaciones y modalidad. El trabajo de prueba queda pendiente,
sin crear versión de sesión ni publicarla. No se editó el programa de Javier.

La entrada directa por URL destapó una consulta antigua al volver al catálogo.
El ajuste posterior escucha el regreso a su ruta y renueva consultas y clave de
trabajos, incluso si la lista de recetas no ha cambiado. Dos regresiones cubren
entrada por botón y URL directa; junto a las anteriores del catálogo pasan nueve
pruebas y el análisis ADMIN vuelve a quedar limpio. Se publicó como
`ac45df0a5e4dfa527a54ae9ad743e630f17f16df-39674478528-1`; validación, despliegue y
retención de [esa CI](https://github.com/jchjdev/entrenaop/actions/runs/39674478528)
terminaron correctamente. Chrome acredita el regreso desde URL directa y el
nombre actualizado en el catálogo, sin recarga adicional. La captura real se
conserva localmente; las imágenes versionadas anteriores siguen siendo fixtures.

## Protección del recibo antes del enlace

La revisión final detectó que el origen con trabajo abierto estaba protegido,
pero faltaba proteger el resultado confirmado cuyo enlace al padre aún no se
había acusado. La migración posterior amplía la misma guarda: mientras el padre
conserva la referencia `sessionWorks`, no se retira ni elimina esa receta. No
modifica otras sesiones, la finalización ni los permisos.

La regresión falla antes de la corrección al intentar mover ese resultado a la
papelera por la RPC normal; después pasan retirada y borrado bloqueados, enlace
confirmado y ciclo normal de papelera/restauración. El contrato completo termina
en ROLLBACK y no conserva datos de prueba. Se repitieron historial de migraciones
y asesores de seguridad; la tabla privada conserva el INFO intencional ya descrito.
No hay nuevas tablas ni grants en esta corrección.
