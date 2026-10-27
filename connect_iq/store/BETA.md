# EntrenaOP Beta · preparación de Connect IQ Store

Estado del 27/10/2026: **beta creada en Garmin**, versión 1.3.0, estado inicial
**Pending Scan**. Todavía no se acredita descarga/instalación desde Store.
[Ficha privada](https://apps.garmin.com/apps/4199b1e5-24da-4106-a832-bc212ca91865).
Destino acordado con Javier: beta privada de Garmin, visible solo desde la
cuenta Garmin que la suba. No es una beta compartida por enlace entre cuentas.
Para instalarla desde Connect IQ en el reloj, usar esa misma cuenta Garmin.

## Identidad y compilación

- Nombre: **EntrenaOP Beta**; versión **1.3.0**; idioma castellano.
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

Paquete comprobado: 34.966 bytes, SHA-256
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

**Novedades 1.3.0:** Primera beta privada. Vinculación por código, descarga de
sesiones vigentes, apertura en Fuerza, icono OP y avisos opcionales de cambios.

## Envío privado y siguiente comprobación

Javier autoriza expresamente crear el nombre **EntrenaOP**, aceptar el Developer
License Agreement and Terms of Use y enviar exclusivamente esta beta privada.
Se crea ese nombre y se mantiene marcada **This app is for testing purposes only**.
Garmin confirma la ficha con distintivo **BETA**, versión 1.3.0 (Internal: 1),
propietario EntrenaOP y mensaje de acceso solo para el propietario. El panel
muestra **Status: Pending Scan** y la ficha deshabilita Download inicialmente.

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
el recorrido de distribución sin USB. Abrir la ficha con la misma cuenta Garmin
desde el iPhone cuando termine el escaneo y comprobar su instalación mediante
Connect IQ; no se ha acreditado aún ese paso. No publicar una versión pública ni cambiar
el servidor a producción dentro de este bloque.

Fuente: documentación oficial del SDK 9.3.0, `Core_Topics/Beta_Apps.html` y
`Core_Topics/Publishing_to_the_Store.html`; formulario
<https://apps.garmin.com/en-US/developer/upload>.
