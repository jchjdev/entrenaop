# Ficha, evolución e informe del servicio profesional · 21/10/2026

**Integración Dev · 21/10/2026:** migración aplicada dentro del conjunto profesional
de diez; 195 migraciones locales/remotas coinciden. Los 24 contratos relacionados
vuelven a pasar con ROLLBACK sobre el esquema aplicado, sin datos de ensayo
persistentes. La publicación web/móvil se acredita por separado.

## Frontera de acceso

La ficha pertenece al preparador y se abre por `clientId`, también tras recarga.
Devuelve la misma metadata de cartera que consume `TrainerClient.fromJson`, sus
etapas propias y las notas internas de ese preparador. No consulta perfil actual,
marcas personales, entrenamientos libres ni resultados de otros preparadores.
ADMIN ajeno no obtiene lectura por su permiso administrativo.

Requiere identidad propia y TOTP/AAL2 para leer. La cartera y el historial del
servicio siguen consultables al terminar el vínculo. El nombre conservado es el
de la cartera; no se sigue el perfil nuevo de un alumno que ya está inactivo.

## Notas y objetivo internos

Las notas admiten 2.000 caracteres; el objetivo libre del preparador, 500. Son
campos internos, separados del perfil del alumno, de formularios respondidos, de
objetivos deportivos canónicos y de baremos. No aparecen en la app del alumno ni
en el CSV del informe.

Cada guardado crea una revisión inmutable en
`trainer_private.client_note_versions`. El servidor exige `expected_revision`,
propiedad de cartera, MFA y acceso profesional activo. La ficha inactiva puede
recibir anotaciones del preparador sobre su propio servicio mientras conserve
ese acceso; esto no concede lectura de datos nuevos del alumno.

La operación y su payload quedan fijados al enviarse. El mismo reintento devuelve
la misma revisión; otros datos con esa operación se rechazan. Una revisión
obsoleta genera conflicto, conservando el borrador en pantalla. Recargar exige
confirmar el descarte si hay cambios. El guard común protege también la salida
lateral; cancelar conserva texto y objetivo. Los controles se bloquean mientras
se confirma un guardado incierto.

## Periodos, registros y completitud

- El periodo es `[inicio, fin exclusivo)`, con máximo de 366 días por consulta.
- **Cumplimiento:** fecha civil pautada. Citas retiradas se excluyen; las no
  completadas de hoy/futuras no se penalizan. Sin citas evaluables no se ofrece
  un 0 % ni un 100 %. Completar una cita no acredita completar todas sus series.
- **Resultados:** agrupados por fecha de **inicio de la ejecución en UTC**.
  No se inventa una fecha de cada serie ni se sustituye por su día pautado. La
  interfaz y el CSV declaran expresamente ambos criterios.
- Se conservan resultados reales de series completadas aunque la ejecución
  siga en curso o se haya abandonado. Ausentes y cero se distinguen. RPE/RIR y
  cargas no se suman para fabricar volumen; no se calculan 1RM o calorías.
- AMRAP conserva resultados de bloque. Sus referencias de receta no se cuentan
  como series realizadas ni se multiplican para inferir trabajo por ejercicio.
- Los resultados deportivos tipados conservan prescripción, protocolo, versión
  y unidad. No se agregan como equivalentes pruebas o protocolos diferentes.

La RPC pagina cada clase (`assignments`, `sets`, `amrap`) a 200 filas, devuelve
recuento y `has_more`. El adaptador carga **todas las páginas de las tres clases**
antes de mostrar métricas del dominio puro `workout_core/trainer_progress.dart`.
Un error o un recuento que cambia no convierte una primera página en un total.

La huella común del periodo utiliza la cohorte de pautas propias, sus
`planning_revision`/`result_revision`, fecha pautada, estado, enlace e inicio de
ejecución. Depende explícitamente de la migración operacional anterior y de sus
triggers de cabecera, series, AMRAP y agenda. Cambiar valores con igual número de
filas o corregir el inicio para entrar/salir del periodo cambia la huella. Si
alguna página/clase devuelve otra, el adaptador exige actualizar el informe.
La huella es un control de consistencia y nunca un permiso de lectura.

Las etapas se muestran hasta 50 con indicador de parcialidad si existen más.
Esto no afecta a la carga completa de resultados del periodo.

## Informe CSV

El portal genera una descarga local CSV en web, con UTF-8/BOM, coma y CRLF.
No envía resultados a otro servicio. En plataformas sin descarga web ofrece
copia al portapapeles, sin presentar esa copia como una descarga.

Incluye periodo, criterio de fecha, identidades de registros, estados y medidas
con unidades en las columnas. Separa objetivos pautados de valores realizados y
conserva contexto de resultados deportivos tipados. Vacío significa ausencia;
no convierte ausencias en cero. Las notas y objetivo internos quedan fuera.

Escapa comillas, comas y saltos de línea. Neutraliza como texto los campos que,
tras espacios iniciales, comiencen por `=`, `+`, `-` o `@`. Los valores numéricos
reales mantienen su tipo y no se transforman en texto ambiguo. El nombre de
archivo se restringe a caracteres seguros; la URL temporal se revoca.

## RPC y consumidores

| RPC | Parámetros | Resultado |
| --- | --- | --- |
| `get_trainer_client_workspace` | `p_client_id uuid` | `client`, `relations`, `relations_complete`, `notes`, `can_edit_notes` |
| `save_trainer_client_notes` | `p_operation_id uuid, p_client_id uuid, p_expected_revision integer, p_notes text, p_goal text` | Revisión nueva o reintentada |
| `get_trainer_client_progress` | `p_client_id uuid, p_start date, p_end_exclusive date, p_kind text, p_before_date date=null, p_before_id text=null` | `items`, `total`, `has_more`, `limit`, `fingerprint`, periodo y criterio de fecha |

Las fachadas públicas son SECURITY INVOKER; las funciones privadas comprueban
cartera/MFA y acceso cuando corresponde. RLS y ausencia de grants directos
protegen la tabla de notas; el cliente no ejecuta helpers internos.

`TrainerClientWorkspacePage(repository, clientId)` consume
`TrainerClientWorkspaceRepository` y necesita `WorkflowExitScope/onExit` en el
router. `SupabaseTrainerClientWorkspaceRepository` implementa el adaptador.
La ficha enlaza planificación/resultados, formularios y conversación de su etapa.
No importa ADMIN ni depende de `GoRouter.extra` para recuperar identidad.

## Verificación y estado

Migración `20261021153743_trainer_client_workspace.sql`. Su DDL y la dependencia
operacional se comprobaron temporalmente en Dev con el contrato
`supabase/tests/trainer_client_workspace.sql`, terminando todo con ROLLBACK. No
se acredita DDL persistido, publicación, instalación física ni producción.

El SQL comprueba notas versionadas/reintentos/conflictos, MFA, ADMIN ajeno,
consulta tras baja, nombre retenido, acceso desactivado, periodo finito,
paginación real de 206 pautas en lotes 200/6 y exclusión de una ejecución/serie
personal sin pauta. También verifica que la huella cambia por valores nuevos
con igual recuento y por cambios de inicio que alteran la cohorte.

Las pruebas Dart verifican ausentes/cero, AMRAP, futuro no penalizado, carga de
todas las páginas, rechazo de informes truncados/cambiantes, CSV seguro, guard
de salida con notas conservadas, reintento estable y ficha 320 px/texto doble.
La descarga web real debe contrastarse en la validación de publicación del
portal; las pruebas de escritorio solo acreditan el fallback declarado.
