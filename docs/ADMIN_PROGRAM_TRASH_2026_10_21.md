# Papelera de programas guiados · ADM-003 · 21/10/2026

## Acuerdo y recorrido

Javier pide borrar programas con recuperación, conservando las sesiones usadas
en otros programas. Confirma que Dev contiene datos de prueba prescindibles;
eso permite comprobar el recorrido, sin convertirlo en un borrado definitivo.

Programas guiados añade **Papelera** junto a sus acciones principales. En todas
las tarjetas, sean borradores, publicadas o retiradas, **⋯ → Mover a papelera**
explica el alcance y pide confirmar. Retira **todas las versiones de la familia**,
las oculta del catálogo administrativo y oculta sus trabajos vinculados. No
confundirlo con **Retirar del catálogo**, que conserva la tarjeta editorial.

Los trabajos incompletos de **Continuar trabajando** también ofrecen **Mover a
papelera**. Esto afecta solo a ese trabajo, sin retirar su programa de origen.
La papelera distingue familias con sus cantidades de versiones/trabajos y
trabajos incompletos independientes. Recuperar pide confirmación y refresca
la lista. Volver a programas refresca el catálogo sin abrir otro creador.

La recuperación conserva IDs, contenido, enlaces, categorías y portadas:

- Los borradores vuelven como borradores, con el creador y publicación conjunta
  existentes.
- Las versiones antes publicadas vuelven **retiradas**. Para ofrecerlas de nuevo
  se crea/revisa un borrador y se publica mediante el recorrido actual. Recuperar
  no publica contenido por sorpresa.
- Los trabajos privados vinculados reaparecen al recuperar su familia; los
  descartados por separado siguen en su propia papelera.
- Las sesiones, calentamientos, sus versiones y las sesiones sueltas no se
  retiran ni se eliminan. Los otros programas conservan su receta compartida.
- Los seguimientos, entrenamientos y resultados previos continúan conservados.
  Quien ya seguía el programa mantiene el acceso histórico y su continuidad;
  no se admiten nuevos seguimientos de la versión retirada.

No hay borrado físico, vaciado automático ni botón de eliminación definitiva.
No cambia preparaciones/pruebas deportivas, programas personales ni producción.

## Contrato de servidor

Migración `20261021060631_admin_guided_program_trash.sql`, instalada solo en Dev.
`guided_programs.trashed_at` marca el lote de una familia. El CHECK impide que
una versión en papelera siga publicada; la retirada cambia únicamente el estado
publicado a `archived`. Nunca se ejecuta DELETE de programas, sesiones o enlaces.

`trash_admin_guided_program` y `restore_admin_guided_program` comparten el bloqueo
transaccional por familia de guardado/publicación. Recuperar exige la fecha exacta
del lote: una petición antigua no recupera un borrado posterior. Repetir una
recuperación ya resuelta no clona versiones ni vuelve a publicar.

Los triggers impiden guardar, crear otra versión, publicar o cambiar portadas de
una familia en papelera. Un trabajo vinculado tampoco puede guardarse/finalizarse
desde una pestaña antigua. El guard del trabajo toma SHARE sobre su programa;
retirar una familia no actualiza ni bloquea filas de trabajos, evitando invertir
el orden de bloqueo entre programa y trabajo.

El descarte existente de trabajos sigue usando `discarded_at`; ahora incrementa
la revisión. `restore_admin_guided_work` comprueba propiedad, revisión y que no se
haya finalizado. Recuperar incrementa otra vez la revisión para rechazar editores
abiertos antes del descarte. El catálogo carga la marca del programa de origen
por su FK y la URL de un trabajo conserva el estado cerrado mientras su familia
está en papelera; no crea otro trabajo con ese ID.

Las cuatro RPC nuevas exigen `is_admin()` y MFA; no conceden ejecución anónima
ni escritura directa en tablas. La papelera muestra trabajo privado solo de su
propietario, aunque existan otros administradores. Historial incluye `trashed_at`
y Calidad excluye programas retirados a papelera. El esquema y sus nuevas marcas
entran en la copia SQL/Storage existente sin otro sistema de respaldo.

El asesor señala las RPC administrativas como SECURITY DEFINER accesibles a
authenticated: es el acceso deliberado, con comprobación de admin/MFA y
`search_path` vacío; los rechazos se prueban. No se declaran corregidos avisos
anteriores ajenos. Referencia: [asesor de RPC autenticadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

## Validación y límites

- Análisis ADMIN limpio; batería completa: **289 pruebas correctas**, dos
  omisiones previas. Nueve regresiones nuevas de UI/HTTP. Las 86 de autoría
  guiada pasan, incluido creador, revisión y publicación conjunta.
- Nueve SQL transaccionales con ROLLBACK contra Dev: papelera, trabajo privado,
  publicación conjunta, autoría, seguimiento, portadas, operaciones editoriales,
  MFA y cuota/pausa. Los ensayos antiguos reciben su fixture administrativo
  `aal2`; el ensayo MFA conserva sus comprobaciones de rechazo explícitas.
- **175 migraciones locales/remotas coincidentes**. La migración y ensayo nuevos
  se probaron juntos con ROLLBACK antes de instalar, y otra vez sobre el esquema
  instalado. No quedan usuarios, programas ni sesiones del ensayo SQL.
- Capturas de widgets reales con datos ficticios revisadas: escritorio y
  confirmación a 320 px con texto 2×, sin solapamientos ni acciones inaccesibles.
- Build web release Dev correcto y vista local actualizada en el servidor ya
  existente de `127.0.0.1:55555`. No se recarga el montaje abierto de Javier.
- Publicación automática [39555362471](https://github.com/jchjdev/entrenaop/actions/runs/39555362471)
  correcta: análisis, 289 ADMIN/dos omisiones previas, 30 Python, build,
  despliegue y retención. Revisión `b124feeddbb9fd8ac5cae7aeb5e3a13f9ccfc80a`.
  Comprobación independiente HTTPS correcta: identidad Dev, manifiesto, hash de
  JavaScript, cabeceras y MIME de WASM.
- Chrome, con la sesión administrativa existente, acredita el ciclo real:
  crear trabajo incompleto → guardar → papelera → recuperar → reabrir con el
  mismo ID y revisión nueva → reutilizar sesión existente → guardar programa
  en borrador → papelera → recuperar como el mismo borrador.
- Ensayo UI: trabajo `bc6757f6-a5cb-4d6b-826b-b5cbcdf6d222` y programa
  `af41f986-9c51-4004-a098-6f82b1b2bf47`, **Prueba papelera · ADM-003**.
  La instantánea de la sesión compartida `840122a1-5ad7-4c13-9d97-e41f5973f25e`
  mantiene el hash `0d99c635180fb31f28ce67e469fc7553` durante retirada y recuperación;
  conserva los tres enlaces de las versiones del programa original. No se
  modifica su receta, publicación ni visibilidad suelta.
- Al terminar, únicamente ese programa de prueba queda de nuevo en papelera,
  preparado para que Javier pueda recuperarlo. Los datos del catálogo anterior
  no se retiran ni se recuperan durante la comprobación. Las filas del ensayo
  SQL siguen sin persistir; las del ensayo UI son este ejemplo explícito.

El bloqueo y los rechazos de edición obsoleta se prueban transaccionalmente; no
se atribuye una prueba simultánea de varias conexiones. La aceptación de Javier
con su catálogo real queda pendiente. El único siguiente paso recomendado es
esa aceptación: retirar/recuperar un borrador y un programa con sesiones
reutilizadas, antes de abrir otra función grande.
