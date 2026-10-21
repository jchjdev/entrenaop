# Sesiones incompletas y pendientes de ADMIN · 21/10/2026

ADM-008. Encargo de Javier: recuperación de sesiones incompletas y portada de
pendientes. Se conserva el diseño actual del creador, su ventana y Compacto.
Las otras propuestas del estudio de Harbiz y cualquier rediseño se enseñan antes
de implementar. No se cambian dosis, kg opcionales, RIR, RM ni algoritmo.

## Estado de entrega

Código implementado y verificado localmente. Migración
`20261021195030_admin_workout_work_recovery.sql` aplicada solo en Dev y contrato
SQL repetido sobre el esquema aplicado con `ROLLBACK`. En esa comprobación hay
198 migraciones coincidentes; dos migraciones profesionales de otro bloque
siguen pendientes y no se incluyen en esta entrega. Producción no se ha consultado
ni modificado. La publicación web y aceptación de Javier se acreditan aparte.

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
