# Pro: interfaz inicial y conexión de pagos

## Estado actual · COM-008 · 10/10/2026

**Bloque abierto · COM-010, aclarado por Javier.** Este chat continúa dedicado
a Free/Pro del deportista e incluye la conexión de pagos. Javier rechaza el cierre
provisional interpretado por el agente. El producto para entrenadores se estudiará
en otro chat; enseñarles la beta no decide su modelo comercial. Accesos, cuotas,
interfaz y gestión administrativa de pruebas están verificados en desarrollo;
las compras siguen pendientes dentro de este mismo trabajo. La recepción del
nuevo correo de alta y las pruebas reales en móvil conservan sus límites conocidos.

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

### Límite pendiente: cobros

No hay compras, restauraciones, webhooks, recibos, reembolsos ni estados de tienda
implementados. Los botones de cobro siguen deshabilitados. La recepción fiable
de pagos deberá incorporar una fuente y referencias verificables al modelo de
derechos, con idempotencia y conciliación, y nunca permitir que las concesiones
manuales cancelen o editen una suscripción de tienda. RevenueCat sigue siendo
una recomendación pendiente de configuración y elección definitiva.

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

## Siguiente tramo del bloque abierto: conectar pagos a los derechos de servidor

COM-008 concreta e implementa las cuotas propuestas en COM-007. El
[contrato vigente](PRODUCT.md) distingue recursos propios, revisiones, agenda e
historial; el contador visual refleja el servidor y no concede autorizaciones.

Se recomiendan compras de App Store/Google Play y RevenueCat para coordinar
productos y estados. Supabase seguirá autorizando generación y continuidad
adaptativa. RevenueCat es una recomendación pendiente de elección/configuración,
no una dependencia añadida en esta entrega.

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
integración se propone RevenueCat Test Store; el proyecto externo todavía no
se ha creado o verificado en esta tarea. No hay SDK instalado ni compras activas.

1. Entrar en [RevenueCat](https://app.revenuecat.com/) y crear **EntrenaOP Dev**.
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

### Contrato técnico propuesto antes de implementarlo

- Flutter inicia compras únicamente con una cuenta autenticada y su UUID de
  Supabase como App User ID. No se envían marcas, historial o datos deportivos
  al proveedor. Un cambio de cuenta debe descartar respuestas de la anterior.
- RevenueCat coordina las compras; Supabase conserva la autorización comercial.
  El resultado del SDK no concede Pro por sí solo: se confirma mediante backend.
- Se necesitan una función de servidor para recibir eventos autenticados y una
  consulta de conciliación con el proveedor. Los identificadores de evento evitan
  procesar duplicados; la conciliación resuelve demoras y desorden de entrega.
- Las suscripciones se almacenarán separadas de `development_manual`, con
  proveedor, cuenta, entorno y vigencia. La autorización combinará las fuentes
  válidas; retirar un acceso administrativo no cancelará una compra de tienda.
- Sandbox solo autorizará en Dev. El webhook validará proyecto/app y entorno;
  los secretos de API y del webhook permanecerán en servidor. Todavía no se han
  definido estos valores ni desplegado funciones.
- Cancelar la renovación conserva el acceso hasta su vencimiento. Caducar no
  borra recursos ni historial. Restauración, cambios de cuenta, período de gracia
  y transferencias se concretarán antes de implementar sus reglas; no se adopta
  silenciosamente la política predeterminada del proveedor.

El SDK oficial permitirá compra/restauración y lectura del catálogo. Antes de
añadirlo se comprobarán versión, resolución y requisitos reales con Flutter,
Android e iOS actuales. Se conservará la oferta propia de EntrenaOP. El navegador
no se habilitará como nuevo canal de venta en este primer tramo.

La aceptación requiere probar compra mensual/anual, cancelación del diálogo,
fallo, renovación/caducidad, restauración, cambio de cuenta, eventos duplicados
y derechos confirmados en servidor. Se necesitará una cuenta Free sin concesión
manual para observar la transición; el Pro de prueba vigente puede ocultarla.
Estas comprobaciones y la integración siguen pendientes: este documento no
acredita que funcionen compras.

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
- Si se elige RevenueCat, su cuenta/proyecto, conexión a tiendas y un acceso Pro
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
