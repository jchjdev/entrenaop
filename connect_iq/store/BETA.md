# EntrenaOP Beta · preparación de Connect IQ Store

**Ensayo 1.5.0 publicado en la misma beta privada (Internal: 4):** descarga
silenciosa explícita de una revisión nueva
de la única cita compatible. Se arma desde el menú y se sale a la esfera antes
del cambio. Sin avisos ni intents; una solicitud FIT como máximo. Al volver,
la app lee solo la biblioteca local, sin descargar para falsear el resultado.
Terminar prueba restaura el modo habitual. Credencial, UUID y permisos se
mantienen. 38 pruebas por variante y firma correctas.
El aviso de privacidad Dev ya describe el ensayo y está desplegado/verificado.
Paquete 1.5.0: 49.753 bytes, SHA-256
`2f72dff5fc9118eb48ce1e0338b59ed1c632991ef3a2427f488a22404fabb3f8`.
Garmin verifica archivo/firma y confirma envío al fēnix de 47 mm para la próxima
sincronización. Descripción y novedades explican el ensayo en castellano e inglés.
Se solicita instalar 1.5, armar el menú y salir a la esfera antes de cambiar la
muestra. Después Javier confirma EOP1000000144 en Fuerza nativa sin abrir
EntrenaOP, con 3×5 a 20 kg y descansos nuevos de 1:15: descarga e importación en
segundo plano aceptadas en su fēnix 8 de 47 mm. Pendiente terminar el modo de
prueba. No acredita todavía sincronización silenciosa continua ni otros modelos.

**Corrección 1.4.1 publicada en la misma beta privada (Internal: 3):** timeout
-300 distinguido de denegación de acceso;
reintento manual con autorización nueva y texto medido dentro de la pantalla
circular. Treinta pruebas por variante, firma y revisión visual en simulador
correctas. 43.644 bytes, SHA-256
`33528244223d99307c28fa45ac5f39dad8facb841a159f438a2f4d99bb430f87`.
La prueba de 1.4 recupera la consulta y Javier confirma Fuerza con contenido.
Garmin verifica archivo/firma y confirma la instalación en el fēnix de 47 mm para
la próxima sincronización, con los mismos permisos. Después Javier responde
**TODO EN ORDEN** al comprobar Beta 1.4.1, textos completos y apertura de la
sesión: instalación, presentación y apertura físicas aceptadas. Reintento ante
otro timeout, cancelación y reapertura repetida no ensayados de nuevo en 1.4.1.

Hito anterior del 27/10/2026: **Beta 1.4.0 registrada en la misma ficha privada**
(Internal: 2), con firma Verified. Veinticinco pruebas por variante y firma IQ
correctas. La llegada al reloj y apertura repetida de 1.4 están pendientes de
aceptación física. Conserva UUID, clave, permisos, vinculación y ajustes de avisos.

Antecedente aceptado: **Beta 1.3 instalada desde Connect IQ en el fēnix 8 de 47 mm**.
Javier confirma inicio de **EntrenaOP Beta 1.3** y un código de vinculación nuevo.
Aceptado el recorrido Store → sincronización → instalación → inicio físico.
Javier confirma vinculación, una sola sesión y apertura en Fuerza con tres
series de cinco a 20 kg y descansos de 1:00. Aceptado el transporte privado
desde la app distribuida por Store. Javier confirma también el bloqueo físico
tras revocar Beta. El vínculo nuevo queda activo; tras un fallo de apertura
local, un reinicio normal recupera Fuerza y Javier confirma otra reapertura sin
reiniciar. Beta operativa y avisos activados; incidencia de apertura documentada abajo.
[Ficha privada](https://apps.garmin.com/apps/4199b1e5-24da-4106-a832-bc212ca91865).
Destino acordado con Javier: beta privada de Garmin, visible solo desde la
cuenta Garmin que la suba. No es una beta compartida por enlace entre cuentas.
Para instalarla desde Connect IQ en el reloj, usar esa misma cuenta Garmin.

## Identidad y compilación

- Nombre: **EntrenaOP Beta**; versión **1.5.0**; idioma castellano.
- UUID estable: `d38458cfe4d844fcae60b18c9e9d7cf3`.
- Variante independiente de Dev; comparte código y endpoint exclusivamente Dev.
- Perfil oficial `fenix847mm`; aceptación física hasta ahora en fēnix 8 de 47 mm.
- Icono: OP oficial de `assets/branding/entrenaop_app_icon_full_bleed.png`.
- Permisos: Communications, PersistedContent y Background.
- No incluye claves administrativas, tokens Garmin ni la clave privada de firma.

```powershell
./connect_iq/test-dev.ps1 -Variant Beta
./connect_iq/test-dev.ps1
./connect_iq/build-dev.ps1 -Variant Beta -Package
```

Conservar la clave de firma existente fuera del repositorio. El script no crea
otra clave silenciosamente para Beta ni exporta Dev para Store. El paquete se
genera en `connect_iq/bin/entrenaop-beta.iq` (ignorado por Git). La exportación
release del SDK contiene las dos referencias de hardware del mismo perfil;
no representa aceptación física en dos modelos distintos.

Paquete 1.4.0 enviado: 40.966 bytes, SHA-256
`27220303c80e100575e1eccb0edcbbd26ce521105c28f01d8653ad37ff03e150`.
Compilación estricta sin avisos; 25 pruebas Monkey C en Beta y 25 en Dev.

Primera versión 1.3.0: 34.966 bytes, SHA-256
`ec2ab6403eeebee86e035deeae6550d91822c27611165a4c03cf3359e27e5f7f`.
Compilación estricta sin avisos; 16 pruebas Monkey C en Beta y 16 en Dev.

Ese es el paquete adjuntado y aceptado en la primera ficha. Se recompila después
la misma versión con verificación de firma integrada: el IQ local conserva
34.966 bytes y tiene SHA-256
`2d4a8ee7e17033ce4267d3732f2508542c906e92f4ec62872043bb13a6b6bd2c`.
No se afirma igualdad binaria entre exportaciones del SDK.

`VerifyPackage.java` usa `VerifyingUtils.verifyIqFile` del SDK 9.3.0 para verificar
manifiesto y ejecutables contra la clave local original, sin imprimirla. El build
falla si esa comprobación falla. También se verifica independientemente RSA
4096/PKCS#8 y la firma SHA-256 del manifiesto. No se cambia ni regenera la clave.
El texto «Signature check failed» estaba oculto en el DOM; el estado visible de
la ficha era **Verified**. No era un rechazo activo de la firma.

## Borrador de ficha en castellano

**Descripción breve:** Descarga tus sesiones de fuerza de EntrenaOP al reloj.

**Descripción:**

EntrenaOP Beta permite vincular el reloj con tu cuenta de pruebas de EntrenaOP,
descargar sesiones de fuerza compatibles y abrirlas en Fuerza de Garmin.

Esta beta privada se conecta exclusivamente al entorno de desarrollo de
EntrenaOP. Necesita una cuenta de EntrenaOP con Pro o servicio de entrenador
activo, móvil enlazado, Garmin Connect y conexión a Internet. No realiza compras
desde el reloj. La interfaz está en castellano.

Abre la app en el reloj y confirma su código desde Perfil → Garmin de EntrenaOP.
Al abrir se comprueban tus sesiones vigentes; también puedes usar Actualizar.
START permite elegir una sesión y abrirla en Fuerza. El nombre nativo puede ser
un identificador EOP; el título completo se muestra en la lista de EntrenaOP.

Puedes activar avisos de cambios desde el menú. La consulta en segundo plano
detecta revisiones y pide abrir la app; al aceptar se descargan las sesiones.
Garmin decide cuándo ejecutar estas consultas: los avisos no son inmediatos.

Puedes retirar el acceso desde Perfil → Garmin. La retirada bloquea nuevas
consultas y descargas; los entrenamientos ya importados en la biblioteca de
Garmin pueden permanecer allí. Esta beta no registra ni devuelve resultados de
actividad a EntrenaOP y no sustituye la sincronización de calendario de Garmin.

**Novedades 1.4.1:** Texto y botones ajustados a la pantalla circular. El timeout
de conexión -300 se distingue del acceso denegado y permite reintentar manualmente,
comprobando otra vez el permiso. Se mantienen la vinculación y los avisos de cambios.

## Envío privado y siguiente comprobación

Javier autoriza expresamente crear el nombre **EntrenaOP**, aceptar el Developer
License Agreement and Terms of Use y enviar exclusivamente esta beta privada.
Se crea ese nombre y se mantiene marcada **This app is for testing purposes only**.
Garmin confirma la ficha con distintivo **BETA**, versión 1.3.0 (Internal: 1),
propietario EntrenaOP y mensaje de acceso solo para el propietario. El panel
muestra inicialmente **Status: Pending Scan** y Download deshabilitado. Después
avanza a **Pending** y habilita Download para el propietario; el aviso general
«App pending» no impide ya esta instalación Beta.

Javier autoriza aceptar también las condiciones de descarga de Garmin. Se
selecciona el fēnix 8 de 47 mm de su cuenta y se completan los permisos previstos
de la app. Garmin confirma **EntrenaOP Beta will be installed the next time your
device syncs**. Se solicita sincronizar desde Garmin Connect en el iPhone y
confirmar inicio de **EntrenaOP Beta 1.3** en el reloj. Es una solicitud de
instalación aceptada por Garmin. Javier confirma después **Beta 1.3** abierta
en el reloj y código de vinculación: queda aceptada físicamente la instalación
desde Store, sin copiar este paquete por USB.

Javier comunica después **Sesiones vigentes / Sin fuerza compatible**. La beta
está vinculada a la cuenta secundaria de pruebas, con un vínculo activo y permiso
Garmin vigente. Su única cita candidata es **series 300**, carrera del 28/10;
la muestra CIQ anterior pertenece a la cuenta principal. La lista vacía es
coherente con esta cuenta y el filtro de fuerza; no acredita fallo de descarga.

Se conserva esa vinculación y se pauta desde Trainer para el 27/10 una sola
**Prueba Garmin · Fuerza 3x5**, reutilizando la versión publicada: press banca,
tres series de cinco a 20 kg, descansos 60 s. Cita
`2764d39a-3c1f-493a-ae48-9060d6db0b5e`, pendiente y sin ejecución. Se añaden
indicaciones de ensayo sin iniciar actividad. La carrera del 28/10 se conserva.
El manifiesto real contrastado con ROLLBACK devuelve una entrada y cero bloqueadas;
el generador privado acepta esa instantánea y produce un FIT de 501 bytes.
Javier confirma después una sola sesión y datos correctos en Fuerza nativa.
La foto aportada muestra `EOP1000000104`, que Dev relaciona con la exportación
propia `bee566ba-ba44-4a53-a2e4-01f7a9734132` de esta cita. Quedan aceptados
actualización, importación privada y apertura desde Beta Store.

Se retira el vínculo Beta desde Perfil para cerrar la prueba de revocación.
La interfaz confirma Acceso retirado y un ensayo SQL real con ROLLBACK rechaza
estado, manifiesto y descarga con `link_revoked`, sin extraer la credencial.
Javier confirma **Vinculación caducada o retirada** tras salir a la esfera y
reabrir Beta. Revocación física aceptada; no se confunde con borrar los FIT de
Garmin. Se solicita obtener otro código con START y confirmar un vínculo nuevo
para dejarla operativa, comprobando que vuelve una sola sesión. La restauración
se acepta después, como se detalla abajo; no se rehabilita la credencial revocada.

Ficha en castellano e inglés, categoría Strength Training, contacto profesional
`javier.charlez@entrenaop.es`, OP oficial en `cover-500.png` (500×500, 287.424 bytes)
y captura real del simulador `screen-pairing.png` (454×454, 10.718 bytes). El intento
anónimo del simulador que muestra la captura se revoca mediante `ciq_command`
antes de publicarla; no se sube un código de vinculación activo.
Se desactiva la ampliación automática a dispositivos nuevos. Sin ANT+, límites
regionales, enlaces inventados a tiendas móviles ni compras desde el reloj. El
formulario Beta fija monetización No; el texto declara el requisito Pro o servicio.

Se declara uso de datos y se enlaza el aviso específico de la beta:
<https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/privacy>.
Es texto estático, sin cuentas ni consultas SQL, servido por GET únicamente en
Dev. Declara datos, finalidad, infraestructura, conservación real y retirada;
caducar o revocar no se presenta como borrado automático. No sustituye la política
de la web pública. Endpoint desplegado y bytes contrastados, POST rechazado 405
y manifiesto sin credencial rechazado 401. 176 pruebas servidor, tipos estrictos
y contrato SQL transaccional CIQ con ROLLBACK correctos; sin cambios de esquema.

La instalación Beta tendrá almacenamiento propio: requiere un nuevo código de
vinculación aunque Dev siga instalada. Verificar instalación desde Store,
vinculación, descarga y actualización de esta variante antes de declarar cerrado
el recorrido de distribución sin USB. La instalación ya está enviada desde la
ficha privada y su llegada, inicio físico y vinculación están confirmados. El
siguiente mejora entonces era clarificar la espera y el diagnóstico de apertura
en Fuerza; se aplica en 1.4, con repetición física pendiente. El piloto privado
no acredita robustez general ni lanzamiento público.
No publicar una versión pública ni cambiar
el servidor a producción dentro de este bloque.

## Incidencia al recuperar el vínculo

El vínculo nuevo se confirma el 27/10 y Dev registra consultas válidas. Javier
recupera la lista de la sesión, pero al abrirla comunica **No se pudo abrir en
Fuerza / No se muestran copias antiguas**, repetible después de Actualizar.
El error procede del bloque de apertura local tras validar el manifiesto;
no se presenta como fallo de aprobación del código ni se solicita revincular otra vez.
La 1.3 agrupa bajo ese mensaje la búsqueda de contenido, `toIntent()` y
`System.exitTo()`, por lo que no conserva la excepción concreta.

Se solicita un reinicio normal del reloj y un único reintento para comprobar
si hay una apertura nativa pendiente. El SDK documenta que `exitTo()` es
asíncrono y puede rechazar una segunda operación no terminada; eso es una
hipótesis de diagnóstico, no una causa demostrada. No se cambia la clave,
el servidor, la receta ni los permisos. Javier confirma que tras el reinicio
**abre Fuerza** y que al salir a la esfera y repetir **vuelve a abrir sin otro
reinicio**. Recuperación física aceptada; la excepción original no queda
identificada ni se presenta como un defecto corregido en código.

Comunica un breve paso por la pantalla Beta al abrir, también observado antes.
Corresponde al flujo actual: cerrar la lista, solicitar un manifiesto autorizado
y lanzar el intent. Queda como mejora mostrar esa espera con claridad y separar
un fallo de apertura nativa de un fallo de actualización, manteniendo la
comprobación de permiso y revisión antes de abrir una copia.

Javier confirma después **avisos de cambios activados en Beta** y salida a la
esfera. La credencial nueva permite reprogramar las consultas al salir. Esto
acredita configuración; no se ha repetido en Store el recorrido físico completo
de un aviso nuevo. El aviso y su aceptación se comprobaron antes en Dev 1.3.

Fuente: documentación oficial del SDK 9.3.0, `Core_Topics/Beta_Apps.html` y
`Core_Topics/Publishing_to_the_Store.html`; formulario
<https://apps.garmin.com/en-US/developer/upload>.

## Actualización 1.4.0 · apertura controlada

La lista pasa directamente a **Abriendo Fuerza**, donde se comprueba el permiso
vigente. BACK descarta el flujo; callbacks tardíos y pulsaciones repetidas no
pueden enviar otro intent. Un error nativo no se muestra como fallo de descarga
ni retira la lista ya verificada. MENU → **Estado de apertura** guarda etapa,
detalle local y antigüedad. No hay relanzamiento automático tras error/cancelación.
La excepción original de 1.3 no se identificó: no se promete corregir un fallo de
firmware ni se omite la comprobación en servidor para acelerar la apertura.

Garmin verifica archivo y firma; la ficha conserva **BETA**, versión **1.4.0
(Internal: 2)** y el mismo identificador. Novedades actualizadas en castellano
e inglés. Sin nuevos permisos, nuevo vínculo ni ampliación a otros dispositivos.
Se solicita Download para el fēnix 8 de 47 mm y se confirman los mismos permisos.
Garmin muestra **EntrenaOP Beta will be installed the next time your device syncs**.
La actualización queda encolada; esa confirmación no acredita su llegada física.

Validación siguiente: sincronizar desde Garmin Connect en el iPhone, confirmar
Beta 1.4, abrir la misma sesión, salir de Fuerza y volver a abrir sin reiniciar.
Comprobar una sola sesión, cancelar durante la espera y abrir después, además
de la conservación de los avisos. Si falla, leer Estado de apertura antes de
otro intento. Instalación física 1.4 aún pendiente.
