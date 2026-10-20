# Operaciones administrativas · ADM-001 · 20/10/2026

Javier autoriza historial editorial, calidad del catálogo, soporte de cuentas y
estado del sistema, además de las mejoras de autoría UI-063. Se reutilizan el
marco, los permisos, los creadores y los guardados existentes. No se añaden
servicios contratados ni dependencias. El alcance es ADMIN conectado a Dev;
producción no se consulta ni modifica.

## Recorrido implementado

- Gestión → **Historial editorial** (`/history`): filtro por recurso, tandas de
  50 cambios, comparación anterior/posterior y recuperación de sesiones o
  programas como borrador independiente. Se conserva el original y nunca se
  publica desde la recuperación. La confirmación describe esta acción.
- Gestión → **Calidad del catálogo** (`/quality`): errores de referencias o
  vídeos, campos/portadas por completar y borradores pendientes separados.
  Búsqueda sin tildes y acceso al recurso. Los ejercicios abren su editor
  existente mediante `/exercises?edit=…`, sin guardar nada al abrir.
- **Cuentas y Pro** conserva su diagnóstico comercial y añade consulta a demanda
  del último inicio de sesión y los 50 seguimientos guiados más recientes, con
  versión, fase y estado. Cambiar de cuenta descarta la consulta anterior.
- Herramientas → **Estado del sistema** (`/system`): entorno compilado,
  manifiesto público del despliegue consultado sin caché, revisión, compilación
  y versión activa. Contrasta entorno/proyecto con la app. Comprueba conexión
  puntual al servidor, cambios editoriales y fallos de vídeo registrados.

Los avisos usan datos guardados: no aseguran que una URL externa reproduzca
vídeo en ese momento. Una subida fallida sin ejercicio asociado conduce al
catálogo de ejercicios; no existe una relación inversa que permita abrir un
ejercicio que aún no se ha guardado. Las portadas se consultan por familia,
también al revisar versiones posteriores.

## Historial, recuperación y seguridad

`admin_ops_private.editorial_events` conserva una instantánea anterior y otra
final por recurso/transacción. Triggers anteriores y diferidos observan la receta
completa de sesiones oficiales, programas guiados, categorías asignadas,
calentamientos y filas de ejercicios oficiales. No captura recetas personales,
tokens, contraseñas, ejecuciones de deportistas ni contenido privado profesional.
El historial empieza al instalar la migración; no reconstruye cambios pasados.
Cambios exclusivos de portadas/archivos y perfiles deportivos relacionados no
tienen auditoría propia en esta entrega.

El esquema privado tiene RLS y carece de acceso de `anon`/`authenticated`.
Las RPC públicas comprueban `is_admin()` en servidor, incluido el MFA existente,
y tienen `search_path` vacío. Soporte exige además
`can_manage_pro_accounts()`: editar contenido no concede acceso a cuentas.
No se añade suplantación del usuario ni acceso a sus recetas personales.

Recuperar usa los guardados existentes. La sesión conserva su alcance de
catálogo y elección de visibilidad; el programa conserva referencias y categorías.
Se crea otra familia en borrador, sin sustituir versiones. Las referencias deben
seguir disponibles y admitidas por el guardado actual. Prescripciones especiales,
RPE antiguo o notas por ejercicio que el guardado no admite se rechazan
expresamente para evitar perder información. Ejercicios y calentamientos permiten
comparación; no se ofrece recuperación automática de esos dos recursos.

`admin_ops_private.restorations` vincula una petición UUID a administrador,
evento, estado elegido y resultado, con bloqueo transaccional. Reintentar una
respuesta perdida recupera el mismo ID. La interfaz conserva esa petición y
bloquea cambiar de estado hasta resolverla; su guard protege salir con resultado
incierto. La garantía del reintento corresponde a esa petición conservada, no a
iniciar otra recuperación deliberada desde una nueva pantalla.

## Límites operativos explícitos

**Copias de seguridad: sin verificar.** No hay integración de estado del
proveedor ni evidencia de un ensayo de restauración. No se presenta un indicador
verde ni una fecha inventada. **Registro general de errores: sin conectar.**
La accesibilidad de la base de datos es una comprobación puntual; no sustituye
monitorización de Auth, Storage, funciones o el proveedor de vídeo.

La calidad devuelve los avisos del catálogo actual en una consulta; historial
sí pagina y soporte limita sus resultados. El volumen actual no exige otro
servicio. Si el catálogo crece, debe paginarse calidad antes de cargar miles de
avisos. No existe política automática de retención de eventos en esta entrega;
debe definirse al medir su crecimiento, sin borrar historial unilateralmente.

## Referencias públicas y adaptación

Se investigan ejemplos publicados, sin acceso a proyectos privados de otros
usuarios. [Relay, ejemplo de OpenAI con Codex](https://developers.openai.com/blog/codex-as-a-platform)
aporta la cola de trabajo con detalle y acción contextual. De
[Directus Versions](https://docs.directus.io/reference/system/versions) se toma
comparar estados y recuperar mediante borrador; de
[Strapi/Appsmith](https://www.appsmith.com/case-studies/strapi), la ficha de soporte
con datos reunidos; de [Sentry Issues](https://docs.sentry.io/api/events/list-an-organizations-issues/),
separar incidencias accionables y filtros. El caso Strapi no acredita haber sido
creado con ChatGPT. Ninguno de esos productos se instala ni se copia como otro
sistema de contenido.

## Verificación de este bloque

La migración `20261020200700_admin_editorial_operations.sql` se aplica solo en
Dev tras preflight transaccional con ROLLBACK. La corrección
`20261020202858_admin_quality_family_cover.sql` respeta portadas por familia y
se verifica también antes y después de instalarla.

`supabase/tests/admin_editorial_operations.sql` comprueba aislamiento de atleta,
editor y responsable, MFA, tablas privadas, instantáneas completas, ausencia de
contenido personal, recuperación anterior independiente e idempotente, rechazo
de campos especiales, referencias retiradas y portada heredada. Todas las
fixtures terminan en ROLLBACK. También pasan las regresiones instaladas
`admin_workout_draft_smoke`, `guided_program_joint_publication`,
`admin_web_mfa_access`, `account_directory_and_manager` y
`edit_personal_exercises_smoke`.

El asesor de seguridad se revisa: RLS sin políticas en las dos tablas privadas
es denegación deliberada; las seis RPC autenticadas usan guard de servidor y
no tienen ejecución anónima. Los avisos anteriores de `is_admin`,
`handle_new_user` y protección de contraseñas filtradas no se presentan como
resueltos por este bloque.

Validación final: análisis ADMIN limpio y batería completa de **276 pruebas
correctas**, con dos omisiones previas. Las pruebas nuevas cubren comparación,
filtros, recuperación tras respuesta perdida, separación de permisos, consulta
de soporte por identidad y acceso directo al editor existente sin escrituras.
Calidad y sistema se renderizan a 1100 px/1× y 320 px/2×; se revisan las capturas
de widgets reales. Los filtros admiten varias líneas para que el nombre y el
contador sigan completos con texto ampliado; se añade su regresión. Actualizar
calidad conserva el texto y los resultados de búsqueda durante la espera del
servidor; se prueba con respuesta demorada. Las capturas
se generan en
`admin_app/build/performance_v2_review/`. No se acredita aquí aceptación física.

`supabase migration list --linked` acredita **173 migraciones coincidentes**
local/remoto después de las dos altas; las seis pruebas SQL citadas pasan sobre
el esquema instalado. La compilación web release Dev con CSP, recursos propios
y sin mapas de código es correcta. La configuración compilada y las pruebas no
tocan producción.

## Publicación comprobada · 20/10/2026

- Código: `395e78cd5b65bcbccd80a8eb90026b9a19191d1a`, guardado y subido a main.
- GitHub Actions [39494347075](https://github.com/jchjdev/entrenaop/actions/runs/39494347075):
  validación y publicación correctas, incluidos análisis, 276 pruebas ADMIN,
  pruebas del publicador y build Dev. No hay cambios compartidos de Flutter.
- La publicación anterior `9131d69` también pasó HTTPS. La ejecución inicial de
  `fc5c139` se detuvo antes de transferir al avanzar main: funcionó la protección
  contra publicar una revisión superada; no fue un error de contenido.
- Verificación independiente por HTTPS de la revisión final: identidad Dev,
  manifiesto/índice, hash de JavaScript, cabeceras sin caché, `X-Frame-Options`
  y MIME de WASM correctos. El manifiesto acredita compilación UTC
  **2026-10-20T20:47:53.658478+00:00** y versión `395e78cd5b65bcbccd80a8eb90026b9a19191d1a-39494347075-1`.
- Se conserva el montaje abierto de Javier, sin recargar su página. La aceptación
  manual de los nuevos apartados queda pendiente; esta comprobación acredita
  despliegue, pruebas de interfaz y contrato SQL, no una sesión física en iPhone.


**Único siguiente bloque recomendado:** conectar evidencia real de copias y
recuperación y los errores de servicios, con alcance y coste revisados antes.
