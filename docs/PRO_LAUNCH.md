# Pro: interfaz inicial y conexión de pagos

## Acuerdo · COM-006 · 10/10/2026

Javier aprueba el descubrimiento Pro y la pantalla de contratación de la
conversación: primero implementar su interfaz, después conectar pagos. COM-004
mantiene 3,99 €/mes y 29,99 €/año para el mismo acceso Pro; COM-005 deja aplazado
el descuento militar. La renovación automática forma parte del diseño aceptado,
sin productos configurados ni garantía de mantener tarifas para siempre.

## Primera entrega

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

**Límite deliberado:** interfaz inicial de desarrollo, no suscripciones
terminadas. Los accesos existentes a los programas siguen disponibles para
validar algoritmos. No hay bloqueo comercial de servidor, SDK de compras,
recibos, derechos persistidos, compra simulada ni selector local Free/Pro. No
se recupera la simulación retirada en COM-003. Los precios son la oferta
acordada, no productos obtenidos de una tienda. No habilitar cobros sin la
siguiente fase.

## Único siguiente bloque: pagos y derechos verificados

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
4. Proteger generación/adaptación en las RPC afectadas, conservando historial y
   sesiones manuales. Resolver programas existentes al vencer Pro antes del
   bloqueo comercial.
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

## Verificación

Verificado el 10/10/2026: `flutter analyze --no-pub` limpio; 53 pruebas
relacionadas y 726 completas correctas, con la omisión web existente. Incluye
regresión del router real desde preparación a oferta y vuelta, ausencia de
acciones de compra/restauración, cambio de modalidad, ejemplo/origen y pantallas
a 320 px con texto doble. Capturas de widgets reales en
`build/performance_v2_review/pro-*.png` revisadas; son recursos de build, no
datos de usuarios ni nuevos assets de producto. No acredita pruebas de tienda,
dispositivos físicos o derechos de servidor. No se modifica Supabase,
producción, admin, paquetes compartidos ni dependencias.
