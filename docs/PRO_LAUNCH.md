# Pro: interfaz inicial y conexión de pagos

## Estado actual · COM-013/014 · 13/10/2026

La integración inicial de Test Store existe en código: SDK móvil, catálogo,
compra/restauración y confirmación por servidor. Se han comprobado los contratos
con pruebas automatizadas y SQL transaccional en Dev. Javier autoriza después
crear la clave privada y conectar exclusivamente desarrollo. La migración y las
dos funciones están desplegadas; Dev habilita SANDBOX. El webhook autenticado
responde HTTP 200 y las peticiones sin autorización HTTP 401. Una compra mensual
simulada con el CLI oficial genera INITIAL_PURCHASE y el servidor verifica
su estado canónico y guarda Pro de Test Store, sin cobro. El recorrido de
aceptación nativa completa sigue pendiente. En la prueba posterior de Android
físico, Javier utiliza los tres botones del simulador y se acredita en servidor
una compra mensual para la cuenta secundaria, ahora Pro de origen RevenueCat.
El registro aportado no acredita por separado las respuestas visibles de
cancelación/error ni la pantalla final; tampoco acredita restauración. Javier
confirma Pro tras reiniciar y aporta un error de navegación al pulsar «Ir a
Mi plan» desde Mi suscripción; COM-015 lo reproduce y corrige, como se detalla
a continuación.
El [recorrido de configuración](../tools/payments_dev/README.md) concreta el
siguiente paso. El proyecto **EntrenaOP** (`bb91cf72`), Test Store y el acceso
`pro` con su catálogo están verificados. Javier autoriza el CLI oficial y su
sesión local limitada a este proyecto; no se conecta Gmail. Los productos
canónicos mensual/anual tienen **3,99 EUR y 29,99 EUR** y el catálogo público
utilizado por el SDK devuelve estos precios con configuración española. La
oferta `default` conserva los dos paquetes correctos y el producto auxiliar
sin asociaciones está archivado. Los precios USD de ejemplo permanecen como
alternativa en Test Store; no son tarifas comerciales aprobadas. Falta completar
la aceptación nativa. Las comprobaciones anteriores
conservan sus fechas y alcance.

**Bloque abierto · COM-010, aclarado por Javier.** Este chat continúa dedicado
a Free/Pro del deportista e incluye la conexión de pagos. Javier rechaza el cierre
provisional interpretado por el agente. El producto para entrenadores se estudiará
en otro chat; enseñarles la beta no decide su modelo comercial. Accesos, cuotas,
interfaz y gestión administrativa de pruebas están verificados en desarrollo;
la aceptación nativa de compras sigue pendiente dentro de este mismo trabajo. La recepción del
nuevo correo de alta y las pruebas reales en móvil conservan sus límites conocidos.
La cuenta principal conserva su Pro manual y recibe la transacción sandbox de
verificación. La secundaria nace Free y su prueba física posterior genera
INITIAL_PURCHASE el 13/10 a las 21:08, hora de Madrid; la consulta posterior
confirma Pro de origen RevenueCat, SANDBOX y el producto mensual. El móvil
conectado es un Samsung SM-A326B con Android 13. No se realiza ningún cobro.
La compra mensual de Test Store renueva cada cinco minutos hasta finalizar su
ciclo acelerado; no representa un mes de acceso real. La comprobación inicial
del reloj SQL descartó una vigencia vencida. Posteriormente también se reciben
RENEWAL y EXPIRATION de esa compra inicial; el estado queda inactivo y el Pro
manual se conserva. La APK debug con clave pública Test Store compila y Javier
ejecuta después la app en el móvil. Restauración, respuesta visible de cada
opción y aceptación completa de tiendas reales siguen pendientes.

La ventana «Test Store Purchase» tiene textos ingleses literales en el SDK
Android de RevenueCat: «Test valid purchase», «Test failed purchase» y «Cancel».
Es el simulador del proveedor; no se modifica el SDK ni se cambia la traducción
del producto para ocultarlo. Los estados posteriores de EntrenaOP son españoles.
[Implementación oficial del diálogo](https://github.com/RevenueCat/purchases-android/blob/main/purchases/src/main/kotlin/com/revenuecat/purchases/simulatedstore/SimulatedStoreBillingWrapper.kt).

### Retorno a Mi plan · COM-015 · 13/10/2026

«Ir a Mi plan» apilaba otra navegación principal mediante `push`, duplicando
la clave de página de `StatefulShellRoute` y provocando la aserción
`!keyReservation.contains(key)` de Navigator. El acceso de servidor estaba
conservado: el reinicio mostraba Pro. El botón usa ahora `go` para acceder a la
navegación principal o a la preparación contextual, sin apilar otro shell.

La regresión reproduce la aserción antes del arreglo y pasa después desde
Mi suscripción y desde la oferta. El segundo recorrido compra como Free,
actualiza a «Ya tienes Pro» después de confirmar en servidor, retira los
controles de compra y abre Mi plan sin reiniciar. Análisis limpio, 37 pruebas
Pro y 768 de raíz correctas, con una omisión web preexistente. El arreglo debe
repetirse en el Android físico; no acredita todavía restauración ni todos los
estados visibles del simulador.

Javier pide probar el negocio con cuentas reales y retoma Free con 8 ejercicios
propios y 4 sesiones personales activas. Esta fase implementa derechos de
servidor, las cuotas y los accesos de la app. Pro se concede temporalmente en
desarrollo sin pagar. No representa una prueba gratuita de tienda, renovación
automática ni una compra. COM-006 describe la interfaz previa, ahora ampliada.

La cuenta sin concesión vigente es Free. Tener permiso de administración no
la convierte en Pro. `profiles.role` sigue siendo heredado y no se modifica.
Las concesiones del origen `development_manual` tienen fechas y actores; solo
las operaciones de confianza o las RPC administrativas autorizadas escriben.
Una configuración de servidor cerrada por defecto habilita estas RPC en Dev;
el panel de producción omite la herramienta. No se cambia producción.

### Presentación según el acceso · COM-009

La ruta `/pro`, también desde URL directa o el ejemplo, vuelve a consultar el
acceso del servidor. Free conserva la oferta mensual/anual y «Seguir con Free».
Pro ve «Ya tienes Pro», su vigencia y contadores, con acceso a Mi plan o a la
preparación desde la que llegó. No se muestran precios ni invitaciones a pagar
o pasar a Free. «Volver» mantiene el retorno al origen. Mi suscripción muestra
«Conocer Pro» únicamente a Free. Durante carga o error de verificación no se
presupone Free: se conserva el reintento.

La consulta de solo lectura del 10/10 confirma dos cuentas con correo validado:
la principal conserva Pro de prueba y la segunda indicada por Javier es Free.
El acceso de esta última con su contraseña queda pendiente de su prueba.

Esta corrección de interfaz no concede ni retira derechos, modifica cuotas o
habilita cobros. La pantalla incluida por una guarda ya comprobada como Free
puede reutilizar la oferta; el servidor sigue autorizando cada operación.

### Cómo probar

1. Registrar una segunda cuenta en EntrenaOP Dev: nace Free. La cuenta elegida
   por Javier tiene Pro de prueba durante 30 días, hasta el 09/11/2026, sin cobro.
   La concesión inicial la aplica el operador de desarrollo con motivo registrado,
   sin inventar un actor administrativo; las RPC registran al admin autenticado.
2. Abrir Perfil → Mi suscripción para consultar acceso, vigencia y contadores.
   «Actualizar acceso» reconsulta al servidor; después de actualizar código se
   necesita un reinicio de la app para registrar el nuevo repositorio.
3. En admin Dev, abrir **Cuentas de prueba** desde el icono de cuentas de la
   cabecera de Programas, o `/development-accounts`. Buscar el correo exacto,
   elegir 1/7/30/90 días y escribir el motivo. Conceder/renovar o retirar el
   acceso modifica solo concesiones de prueba y conserva sus filas de auditoría.
4. En Free, guardar ocho ejercicios propios y cuatro sesiones de cualquier tipo.
   El noveno ejercicio o la quinta sesión/duplicado debe invitar a Pro conservando
   el borrador. Editar mantiene la plaza; archivar una sesión la libera. El
   catálogo, las revisiones, las citas y las ejecuciones quedan excluidos.
5. En Pro, crear más recursos y entrar al programa. Retirar/caducar el acceso y
   comprobar que siguen el uso, la edición, agenda, resultados e historial,
   mientras nueva creación al alcanzar el límite y cálculo/adaptación requieren
   Pro. Una URL directa tampoco concede acceso.

Un error de verificación muestra reintento, no una oferta de pagar por defecto.
Las respuestas comerciales de servidor mantienen códigos estables para que los
editores distingan cuota de errores de red o permisos. Pro contextual abre la
configuración existente y Free abre la oferta. Las tarjetas y fotos se conservan.

### Límite pendiente: aceptación móvil y cobros

COM-013 añade compra, restauración y conciliación de Test Store en código,
con una fuente de derechos separada e idempotencia por evento y cuenta. Las
concesiones manuales no cancelan ni editan una compra. COM-014 conecta el backend
Dev; los botones de prueba requieren móvil debug con clave pública configurada.
Tiendas reales, renovaciones y
reembolsos completos conservan su validación pendiente; no se habilitan cobros.

## Acuerdo · COM-006 · 10/10/2026

Javier aprueba el descubrimiento Pro y la pantalla de contratación de la
conversación: primero implementar su interfaz, después conectar pagos. COM-004
mantiene 3,99 €/mes y 29,99 €/año para el mismo acceso Pro; COM-005 deja aplazado
el descuento militar. La renovación automática forma parte del diseño aceptado,
sin productos configurados ni garantía de mantener tarifas para siempre.

## Primera entrega · COM-006, anterior a los derechos COM-008

- Mi plan sin programa en curso incorpora descubrimiento Pro conservando
  preparaciones, tarjetas fotográficas y agenda. No elige una preparación cuando
  hay varias. No presenta un estado Free/Pro ficticio.
- Tropa y Mejora FAS incorporan la misma tarjeta en su ficha, con su contexto.
  Otros programas no anuncian generación por el hecho de estar en el catálogo.
- «Crear mi plan · Pro» abre `/pro`; «Ver un ejemplo» abre `/pro/example`, una
  explicación didáctica sin generar ni activar entrenamientos.
- El anual destaca total, equivalente mensual y ahorro frente a doce
  mensualidades. El mensual permanece visible. Cambiar modalidad solo afecta
  a la presentación.
- Cerrar o «Seguir con Free» recupera el origen mediante la pila. Desde el
  ejemplo, cerrar la oferta devuelve al ejemplo; cerrar este vuelve al origen.
  Una URL directa sin origen vuelve a Mi plan.
- El identificador y nombre de preparación son contexto de presentación,
  nunca autorización ni comprobación de propiedad.
- Perfil incorpora «Mi suscripción» (`/pro/subscription`), indicando contratación
  pendiente sin deducir derechos del antiguo `role`.
- Compra, restauración y enlaces contractuales están deshabilitados y
  explicados hasta conectar el servicio y completar su información.

**Límite de aquella entrega, superado parcialmente por COM-008:** interfaz inicial de desarrollo, no suscripciones
terminadas. Los accesos existentes a los programas siguen disponibles para
validar algoritmos. No hay bloqueo comercial de servidor, SDK de compras,
recibos, derechos persistidos, compra simulada ni selector local Free/Pro. No
se recupera la simulación retirada en COM-003. Los precios son la oferta
acordada, no productos obtenidos de una tienda. No habilitar cobros sin la
siguiente fase.

## Siguiente tramo del bloque abierto: comprobar compras desde el móvil

COM-008 concreta e implementa las cuotas propuestas en COM-007. El
[contrato vigente](PRODUCT.md) distingue recursos propios, revisiones, agenda e
historial; el contador visual refleja el servidor y no concede autorizaciones.

Javier elige compras de App Store/Google Play y RevenueCat para coordinar
productos y estados (COM-012). Supabase seguirá autorizando generación y
continuidad adaptativa. COM-013 instala el SDK y prepara la integración inicial;
COM-014 conecta Dev y verifica una transacción del proveedor hasta SQL. La
aceptación de compra/restauración desde la interfaz móvil sigue pendiente.

### Coste y crecimiento acordados · COM-012 · 13/10/2026

Se conserva Supabase y su PostgreSQL, autenticación, permisos y funciones de
servidor existentes. La elección busca reducir mantenimiento y coste total;
no afirma que un proveedor sea el mejor para cualquier aplicación. Cambiar
alojamiento exigiría comprobar también los contratos de acceso e integración,
además de comparar el precio de una base de datos aislada.

RevenueCat estándar es gratuito por debajo de 2.500 USD de ingresos mensuales
registrados; si no hay ingresos, su cargo es cero. Al alcanzar el umbral cobra
el 1 % del total registrado antes de comisiones e impuestos; si se vuelve a
quedar por debajo, vuelve a ser gratuito. Esta tarifa no elimina las comisiones
de tiendas o los costes de otros servicios.
[Facturación de RevenueCat](https://www.revenuecat.com/docs/welcome/set-up-revenuecat/account-management).

Se comienza con pruebas gratuitas. Para lanzamiento se recomienda presupuestar
Supabase Pro desde 25 USD/mes, con una instancia básica incluida y copias diarias
de base de datos; potencia, proyectos o consumo adicionales pueden aumentar
el coste. Es una previsión: no se contrata ni cambia ningún plan en esta tarea.
El precio de Supabase es independiente de los ingresos de EntrenaOP. La cuota
de usuarios activos incluida no acredita rendimiento con ese número de usuarios;
el dimensionamiento requiere pruebas de carga y medidas del algoritmo real.
[Precios de Supabase](https://supabase.com/pricing).

Antes de abrir ventas hay que:

1. Configurar tiendas y productos mensual/anual; utilizar sus precios localizados
   reales en oferta y botón de compra.
2. Vincular compras a la identidad estable de Supabase y definir cambios de
   cuenta, restauraciones y transferencias.
3. Comprobar eventos del proveedor en backend, procesarlos de forma idempotente
   y reconciliar derechos con fuente y vigencia. No permitir su autoasignación.
4. Integrar y revalidar la protección de generación/adaptación ya implementada
   con los estados de tienda, conservando historial, sesiones y recursos previos.
5. Conectar compra, restauración y gestión. Distinguir carga, acceso vigente,
   ausencia de acceso, compra pendiente y error de verificación; un fallo no
   equivale a Free ni debe pedir pagar otra vez.
6. Confirmar acceso desde el servidor y volver al contexto de preparación para
   configurar/revisar. Comprar no activa ni sustituye automáticamente programas.
7. Completar condiciones/privacidad y probar renovación, cancelación, caducidad,
   devolución, restauración, compra pendiente y cambio de cuenta en pruebas.

Los cobros web requieren configuración propia; el navegador no procesa compras
nativas móviles. No se añaden ahora pagos web ni una segunda app.

## Qué tendrá que configurar Javier

### Primer paso preparado · COM-011 · 13/10/2026

Javier confirma que su membresía Apple Developer está caducada. Para la primera
integración se prepara RevenueCat Test Store tras la elección de COM-012;
el proyecto externo se ha creado como **EntrenaOP**, con Test Store. COM-013 añade el
SDK y COM-014 verifica después una compra simulada, sin ventas reales. En el
registro de RevenueCat, la pantalla
de tarjeta permite **Add it later**: no hace falta añadirla para estas pruebas.
La tarjeta pagaría el servicio de RevenueCat; Apple/Google recibirán por separado
la información bancaria para sus ingresos cuando se preparen ventas.

1. Entrar en [RevenueCat](https://app.revenuecat.com/). El proyecto de pruebas
   creado se llama **EntrenaOP**, `bb91cf72`; no crear otro duplicado.
2. En **Apps & providers**, utilizar **Test Store**; puede venir creada en el
   asistente. No conectar Apple ni Google en este primer paso.
3. En **Product catalog**, preparar un único derecho **`pro`**, dos productos
   de prueba y una oferta **`default`** que contenga ambos paquetes:

| Producto propuesto de prueba | Duración | Paquete | Precio de lanzamiento de referencia |
| --- | --- | --- | --- |
| `entrenaop_pro_monthly` | Un mes | Monthly | 3,99 €/mes |
| `entrenaop_pro_annual` | Un año | Annual | 29,99 €/año |

Ambos productos deben conceder `pro`. La moneda y el precio que ofrezca el
catálogo de prueba se comprobarán en el panel; los euros anteriores no acreditan
productos reales de las tiendas. La app utilizará los precios localizados del
proveedor y no impondrá un símbolo de moneda sobre una cantidad distinta.

Test Store utiliza una clave pública de SDK propia y compras marcadas sandbox.
Se probará en compilaciones **debug**: el SDK Flutter no permite usar esa clave
en release y no se utilizará para la beta profile, TestFlight o pistas de Play.
La prueba inicial no sustituye la validación posterior de las tiendas nativas.
[Test Store y restricciones de compilación](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store).

### Contrato técnico de la integración inicial · COM-013

- Flutter inicia compras únicamente con una cuenta autenticada y su UUID de
  Supabase como App User ID. No se envían marcas, historial o datos deportivos
  al proveedor. Un cambio de cuenta debe descartar respuestas de la anterior.
- RevenueCat coordina las compras; Supabase conserva la autorización comercial.
  El resultado del SDK no concede Pro por sí solo: se confirma mediante backend.
- Se necesitan una función de servidor para recibir eventos autenticados y una
  consulta de conciliación con el proveedor. Los identificadores de evento evitan
  procesar duplicados; la conciliación resuelve demoras y desorden de entrega.
- La migración preparada almacena suscripciones separadas de `development_manual`, con
  proveedor, cuenta, entorno y vigencia. La autorización combinará las fuentes
  válidas; retirar un acceso administrativo no cancelará una compra de tienda.
- Sandbox solo autoriza en Dev. El webhook valida app y entorno; los secretos
  de API y del webhook permanecen en servidor. COM-014 configura estos valores
  y despliega ambas funciones únicamente en el proyecto de desarrollo.
- Cancelar la renovación conserva el acceso hasta su vencimiento. Caducar no
  borra recursos ni historial. El período de gracia solo conserva acceso hasta
  una fecha explícita del proveedor, sin añadir días propios. Un evento TRANSFER
  concilia origen y destino. Antes de las tiendas reales se debe acordar y
  configurar su política de restauración/transferencia; no se considera decidida
  por probar la conciliación técnica.

El SDK oficial 10.15.2 permite compra/restauración y lectura del catálogo. La
resolución añade únicamente este paquete y sus mínimos son compatibles con
Flutter 3.47.5, Dart 3.13.4 e iOS 15 del proyecto. Se conserva la oferta propia
de EntrenaOP, con tarjetas y precios localizados. El navegador no se habilita
como nuevo canal de venta en este primer tramo. La compilación iOS y la prueba
nativa siguen requiriendo el Mac y sus tiendas.

La aceptación requiere probar compra mensual/anual, cancelación del diálogo,
fallo, renovación/caducidad, restauración, cambio de cuenta, eventos duplicados
y derechos confirmados en servidor. Se necesitará una cuenta Free sin concesión
manual para observar la transición; el Pro de prueba vigente puede ocultarla.
La aceptación móvil completa y los sandboxes reales siguen pendientes. La
transacción Test Store de COM-014 acredita receipt y conciliación del proveedor,
pero no el diálogo de compra/restauración de la interfaz nativa.

Referencias oficiales revisadas el 13/10/2026:

- [Catálogo de derechos](https://www.revenuecat.com/docs/getting-started/entitlements).
- [Ofertas y paquetes](https://www.revenuecat.com/docs/offerings/overview).
- [Configuración e identidad del SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk).
- [Eventos autenticados y duplicados](https://www.revenuecat.com/docs/integrations/webhooks).
- [Restauración y asociación de cuentas](https://www.revenuecat.com/docs/projects/restore-behavior).

### Conexión posterior de tiendas y venta real

- Cuentas de Play Console y App Store Connect, acuerdos e información comercial,
  bancaria y fiscal que soliciten las tiendas.
- Dos modalidades de suscripción con precios y disponibilidad.
- Cuenta/proyecto RevenueCat, conexión a tiendas y un acceso Pro
  común a ambas modalidades.

Flutter/Supabase, recepción de eventos y pruebas serán el trabajo técnico
siguiente. No hacen falta datos bancarios ni claves privadas en el chat. Los
secretos del proveedor van en backend/configuración segura, no en el repositorio
ni en Flutter.

Referencias oficiales consultadas el 10/10/2026:

- [RevenueCat para Flutter](https://www.revenuecat.com/docs/getting-started/installation/flutter).
- [Derechos de RevenueCat](https://www.revenuecat.com/docs/getting-started/entitlements).
- [Configurar compras en App Store Connect](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/).
- [Acuerdos de App Store Connect](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).
- [Suscripciones en Google Play](https://support.google.com/googleplay/android-developer/answer/140504?hl=es).

## Verificación de la integración preparada · COM-013 · 13/10/2026

Análisis limpio y batería completa de raíz con **766 pruebas correctas**, además
de la omisión web existente. Se comprueban confirmación exclusiva de servidor,
cancelación, compra pendiente, fallo de confirmación, no repetición del recibo
activo y cambio de cuenta en la oferta y Mi suscripción. Restaurar sin compras
vigentes conserva la posibilidad de suscribirse. La preparación también vuelve
a comprobar el acceso al cambiar de identidad.

Dieciocho pruebas de funciones correctas; `deno check`, formato y lint limpios
para ambas entradas, código compartido y pruebas. Android debug y web compilan.
Android emite avisos del toolchain XML/Java; no impiden la compilación.
Los mínimos iOS/SPM son compatibles por inspección, pero no se ha compilado iOS
desde Windows. El SDK añade una sola dependencia resuelta; admin y paquetes
compartidos no consumen este paquete y no se modifican.

Antes del despliegue de COM-014: 138 migraciones aplicadas y solo la nueva `20261013000000` local
pendiente. Dos ejecuciones SQL correctas combinan su esquema y las pruebas
`revenuecat_pro_reconciliation.sql` y `pro_access_and_free_quotas.sql` dentro de
transacciones que terminan en ROLLBACK. Se verifican permisos, aislamiento,
idempotencia, instantáneas antiguas, vigencia, cuotas y fuentes independientes.
La consulta posterior confirma ausencia de la tabla nueva y cero usuarios de
los fixtures. En esa comprobación aún no se había desplegado ni activado la
integración. COM-014 acredita después 139 migraciones coincidentes, repite
ambas pruebas con ROLLBACK y verifica el webhook y el estado canónico real.

Capturas de widgets reales revisadas a 390 y 320 px, con precios USD ficticios,
sin desbordamientos, en `build/visual-atlas-20261007/raw/` con prefijo
`build_purchases_review_capture_test_dart`. Conservan marca, tarjetas y moneda
del catálogo; no acreditan cuenta autenticada, SDK real ni compra del proveedor.
Estas capturas se realizan antes de configurar el catálogo EUR y el backend
de COM-014. La aceptación nativa completa sigue pendiente en este bloque.

## Verificación de interfaz · COM-009

Verificado el 10/10/2026: análisis de raíz limpio y batería completa con 742
pruebas correctas y la omisión web existente. Las regresiones distinguen la
oferta Free del acceso Pro, verifican que Mi suscripción no ofrezca comprar a
Pro, el retorno a la preparación y carga/error/reintento sin suponer Free.
Captura real de la oferta de una cuenta Pro revisada a 390 px en
`build/performance_v2_review/pro-oferta-cuenta-activa.png`, con datos ficticios;
no acredita inicio de sesión real ni dispositivos físicos. Admin, migraciones,
derechos, cuotas, dependencias y producción permanecen sin cambios en COM-009.

## Verificación de derechos · COM-008

Verificado el 10/10/2026 contra EntrenaOP Dev: 138 migraciones locales/remotas
coincidentes, incluidas `20261010000000`, `20261010001000`, `20261010002000`
y `20261010003000`.
La configuración de gestión manual se habilita solo en ese proyecto mediante una
operación de confianza. La cuenta indicada por Javier recibe el acceso temporal;
ninguna prueba SQL deja usuarios, recursos o concesiones de sus fixtures.

`flutter analyze --no-pub` limpio en raíz y admin. Baterías completas: 737
pruebas del deportista y 94 del admin correctas, con una omisión web existente
en cada una. Se comprueban acceso Free/Pro, carga/error/reintento, rechazo de
vigencia inválida, navegación contextual, borradores preservados al rechazar
cuotas, búsqueda administrativa, concesión/retirada y cambio de cuenta buscada.
Capturas reales de Mi suscripción Free y Pro en `build/performance_v2_review/`
revisadas, sin desbordamientos. No acreditan dispositivos físicos o compras.

Dieciséis pruebas SQL transaccionales con `ROLLBACK` correctas: la nueva
`pro_access_and_free_quotas.sql`, trece regresiones de programas adaptativos,
seguridad, semanas, revisiones y carrera, y los smoke tests de edición de
ejercicios propios y borradores oficiales. Los fixtures deportivos incluyen
derechos temporales de confianza dentro de su transacción para mantener sus
contratos; la prueba comercial ejercita Free, Pro y caducidad sin ese supuesto.
Se verifican RLS, ausencia de autoasignación, cuotas 8/4, revisiones sin otra
plaza, propiedad antes de Pro, contenido oficial excluido y datos conservados.
El ensayo de continuidad compara el programa antes/después de caducar, comprueba
que no cambian decisiones ni intención automática, recupera el acceso y mantiene
los estados terminado y pausado por el usuario sin sustituir su motivo.
Producción, dependencias y paquetes compartidos no se modifican.

## Verificación anterior · COM-006

Verificado el 10/10/2026: `flutter analyze --no-pub` limpio; 53 pruebas
relacionadas y 726 completas correctas, con la omisión web existente. Incluye
regresión del router real desde preparación a oferta y vuelta, ausencia de
acciones de compra/restauración, cambio de modalidad, ejemplo/origen y pantallas
a 320 px con texto doble. Capturas de widgets reales en
`build/performance_v2_review/pro-*.png` revisadas; son recursos de build, no
datos de usuarios ni nuevos assets de producto. No acredita pruebas de tienda,
dispositivos físicos o derechos de servidor. No se modifica Supabase,
producción, admin, paquetes compartidos ni dependencias.
