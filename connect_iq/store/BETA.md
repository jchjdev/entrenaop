# EntrenaOP Beta · preparación de Connect IQ Store

Estado del 27/10/2026: paquete generado y probado, **todavía sin subir**.
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

## Antes de enviar

El formulario Garmin exige crear un nombre visible de desarrollador y aceptar
su Developer License Agreement and Terms of Use al enviar. Nombre propuesto:
**EntrenaOP**. Hace falta confirmación de Javier en ese punto; preparar la beta
no equivale a aceptar ese acuerdo.

Seleccionar **This app is for testing purposes only**. Nunca enviar este UUID
sin la casilla Beta. Después del primer paso, revisar los requisitos reales de
la ficha (capturas, icono y privacidad); no se dan por completados antes de verlos.
La política pública actual de la web no describe todavía esta integración y no
debe presentarse como si lo hiciera.

La instalación Beta tendrá almacenamiento propio: requiere un nuevo código de
vinculación aunque Dev siga instalada. Verificar instalación desde Store,
vinculación, descarga y actualización de esta variante antes de declarar cerrado
el recorrido de distribución sin USB. No publicar una versión pública ni cambiar
el servidor a producción dentro de este bloque.

Fuente: documentación oficial del SDK 9.3.0, `Core_Topics/Beta_Apps.html` y
`Core_Topics/Publishing_to_the_Store.html`; formulario
<https://apps.garmin.com/en-US/developer/upload>.
