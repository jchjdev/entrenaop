# Contrato comercial profesional · propuesta para el punto 14

**Actualización COM-022 · 28/10/2026:** Javier retoma la implementación de pagos,
inicia el alta de Stripe y diferencia contratación profesional web de Pro personal
en las tiendas. Se prepara el adaptador de pruebas descrito al final. No existe
aún Checkout integrado en el portal ni concesión automática tras pago.

**21/10/2026 · propuesta técnica y núcleo simulado comprobado; proveedor y
políticas pendientes de decisión humana.** Se añaden el núcleo puro y sus pruebas
en las rutas reservadas, sin integración de cobros, cuentas externas, secretos,
contratos aceptados, productos publicados, pruebas Stripe, movimientos de dinero
ni cambios en Dev/producción.

## 1. Base vigente y propuesta principal

### Posibles niveles comerciales · propuesta del 28/10/2026

Javier plantea conservar el cupo de alumnos y diferenciar tres niveles: gestión
profesional; algoritmo para el preparador y sus alumnos, con Pro personal del
preparador; y un nivel que incluya además Pro para los alumnos. Son ideas para
evaluar, no planes aprobados ni derechos implementados. No se fijan precios,
suplementos, cantidades ni cuotas de generación por esta conversación.

La evaluación debe distinguir usar el algoritmo como herramienta del preparador
para revisar y asignar una propuesta, de conceder al alumno generación autónoma
y todo Pro. El servicio básico sigue incluyendo recibir y ejecutar lo pautado
sin compra adicional. El algoritmo profesional requiere concretar revisión,
versionado y convivencia con otras planificaciones antes de habilitarlo.

Una futura concesión Pro incluida debe conservar su origen y vigencia por
servicio/plan, sin sobrescribir compras personales u otras concesiones. Antes
de implementarla hay que acordar qué ocurre al terminar el vínculo o cambiar
de plan, cómo evitar pagos personales duplicados y qué alumnos cubre el cupo.
Ninguna de estas propuestas concede permisos administrativos ni elimina
cuotas de recursos. La cancelación conserva el historial conforme al contrato
vigente; no se acuerda aquí una nueva política de acceso posterior.

Se conserva lo acordado en [TRAINER_PAYMENTS.md](TRAINER_PAYMENTS.md) y
[TRAINER_PLATFORM.md](TRAINER_PLATFORM.md): el preparador paga a EntrenaOP por
herramientas/cupo y el alumno paga al preparador por su servicio. Pro personal,
acceso profesional, capacidad, vínculo deportivo y pago son conceptos distintos.
Los alumnos consumen sus asignaciones sin comprar otro Pro y sin ampliar sus
cuotas personales.

**Recomendación:** Stripe Billing para facturar el acceso profesional y Stripe
Connect para que cada preparador cobre directamente a sus alumnos mediante
Checkout alojado. Es una recomendación, no una elección ya confirmada por Javier.
Stripe documenta ambos flujos de suscripción en Connect y un modelo SaaS con
cobros directos de cada negocio a sus clientes.
[Suscripciones Connect](https://docs.stripe.com/connect/subscriptions),
[modelo SaaS](https://docs.stripe.com/connect/saas).

La propuesta se centra en cuentas conectadas con Dashboard completo, cobros
directos y modalidad en la que Stripe gestiona las tarifas de procesamiento del
preparador. Evita diseñar ahora una cartera de fondos de EntrenaOP y transferencias
propias a entrenadores. Es una decisión de diseño propuesta, no una garantía de
ausencia de costes o responsabilidades. Las opciones de Dashboard, pagador de
tarifas y gestión de pérdidas son configuración explícita de Connect.
[Configuración oficial](https://docs.stripe.com/connect/saas/tasks/create).

Stripe incluye España entre sus países admitidos; esto no acredita que haya
aceptado a EntrenaOP o a un preparador concreto ni que todas las capacidades
estén habilitadas para ellos.
[Disponibilidad](https://stripe.com/global).

La página española de Connect distingue tarifas gestionadas por Stripe de las
gestionadas por la plataforma; Billing y procesamiento tienen sus propios costes.
Antes de activar debe calcularse el coste conjunto de la configuración elegida.
Este contrato no importa tarifas de Harbiz, no fija nuestros precios y no supone
que una comisión propia sea cero por estar aún sin decidir.
[Connect España](https://stripe.com/es/connect/pricing),
[Billing España](https://stripe.com/es/billing/pricing).

## 2. Dos circuitos, con identidades y contabilidad separadas

Los identificadores siguientes son vocabulario propuesto, no tablas ni RPC ya
publicadas. «EntrenaOP cobra al preparador» indica quién vende; el flujo de dinero
va del preparador a EntrenaOP.

| Contrato | `platform_access` | `coach_service` |
| --- | --- | --- |
| Vendedor / receptor | EntrenaOP | Preparador dueño de su cuenta conectada |
| Pagador | Preparador | Alumno |
| Objeto contratado | Herramientas y capacidad profesional | Servicio concreto del preparador |
| Cuenta del proveedor | Cuenta de la plataforma | Cuenta conectada del preparador |
| Catálogo | Planes versionados autorizados por EntrenaOP | Ofertas versionadas del preparador, autorizadas para su propio servicio |
| Capacidad o derechos | Solo una política profesional aprobada podría derivarlos | No concede Pro, ADMIN, cupos ni acepta una invitación deportiva |
| Reintegros/incidencias | Asociados a la venta de EntrenaOP | Asociados a la venta del preparador |

Para el acceso profesional se propone un plan de capacidad fija con cantidad
uno, no facturación por cada alumno añadido. `client_capacity` es un atributo del
plan, independiente de los clientes activos; 5, 7 y 100 siguen siendo ejemplos,
no planes aprobados. Los cambios de uso no crean cargos automáticamente.

En el servicio al alumno se propone una oferta recurrente de servicio, con
periodicidad, precio, moneda, condiciones y versión aceptada. El proveedor admite
suscripciones en la cuenta conectada; en cobros directos los objetos de pago
pertenecen a esa cuenta y se consultan con ese contexto, no desde el de la
plataforma.
[Suscripciones por cuenta](https://docs.stripe.com/connect/subscriptions),
[alcance de cobros directos](https://docs.stripe.com/connect/direct-charges?platform=web&ui=stripe-hosted).

Un preparador necesita una referencia de comprador de herramientas en la
plataforma y una de cuenta que cobra a alumnos. El adaptador puede implementar
el comprador mediante `Customer` o la configuración de cliente de Accounts v2,
pero el dominio no confunde ambas funciones. Cada alumno tiene una referencia
de comprador acotada a la cuenta conectada correspondiente; no se reutilizan
credenciales ni IDs de otra cuenta por coincidir su email.

## 3. Recorridos propuestos

### Acceso y capacidad profesional

1. El preparador autenticado/MFA consulta un catálogo habilitado para el entorno.
2. El servidor resuelve su identidad y la versión del plan; ignora importes,
   capacidad o IDs de proveedor elegidos libremente por el cliente.
3. Se registra una orden de compra y se crea Checkout con la cuenta plataforma.
   No permitir una segunda suscripción concurrente para el mismo contrato; un
   cambio de plan requiere una orden de modificación identificada.
4. La vuelta de Checkout muestra «pendiente de confirmación» o el estado ya
   conciliado. No concede acceso por parámetros de la URL.
5. El servidor recupera factura, suscripción, líneas y estado canónico; registra
   cobertura verificada. Solo una política comercial aprobada puede proponer
   el acceso/cupo efectivo, preservando las concesiones manuales existentes.

El retorno del navegador puede faltar aunque se haya pagado; Stripe exige
webhooks para el cumplimiento automático de suscripciones. Usamos el retorno
solo para consultar o solicitar la misma conciliación autenticada.
[Confirmación de Checkout](https://docs.stripe.com/checkout/fulfillment?payment-ui=stripe-hosted).

### Cobro del servicio del preparador

1. Cuando se autorice el alta externa, el preparador realiza el onboarding alojado
   por Stripe. La propuesta evita recoger en nuestras pantallas documentación
   bancaria/de identidad. El retorno del onboarding tampoco acredita su finalización;
   hay que consultar requisitos y capacidades.
   [Onboarding oficial](https://docs.stripe.com/connect/hosted-onboarding).
2. El servidor vincula la cuenta externa al preparador correcto y verifica su
   capacidad para cobrar. Las capacidades de cobrar y recibir liquidaciones se
   conservan por separado; la política de habilitación debe decidir ambas.
3. El preparador ofrece el servicio a un alumno identificado de su relación;
   el alumno acepta sus condiciones y abre Checkout del vendedor correcto.
   No se cobra por aceptar la invitación existente ni se autoriza un cargo por
   el mero hecho de asignar un entrenamiento.
4. La orden y la aceptación del servicio quedan asociadas a esa relación/etapa.
   El cobro se concilia en la cuenta conectada. Las ofertas y cobros anteriores
   no cambian al editar después el precio del servicio.
5. La ficha muestra lo abonado y el periodo cubierto, separado del estado del
   vínculo. Una factura pendiente o una devolución no finaliza automáticamente
   la relación ni retira pautas mientras no exista una política aprobada.

Stripe recomienda cobros directos para cuentas con Dashboard completo y permite
Checkout alojado para ese flujo. El objetivo es que el alumno pague al negocio
del preparador, sin que EntrenaOP simule cobrar y repartir fondos después.
[Cobro directo alojado](https://docs.stripe.com/connect/direct-charges?platform=web&ui=stripe-hosted).

## 4. Estados independientes y reglas de cobertura

| Agregado propuesto | Estados o datos | Regla |
| --- | --- | --- |
| Conexión de cobros | `not_configured`, `onboarding_required`, `verification_pending`, `ready`, `restricted`, `disconnected`, `unknown`; capacidades y motivos aparte | Solo el adaptador tras consulta canónica informa capacidades; `unknown` no habilita cobros nuevos. |
| Orden propia | `prepared`, `submitted`, `requires_action`, `provider_pending`, `completed`, `expired`, `failed`, `uncertain` | Estado de nuestra operación, no estado de suscripción ni permiso. `uncertain` exige recuperar, no cobrar de nuevo. |
| Suscripción externa | Estado bruto y normalizado: `trialing`, `incomplete`, `incomplete_expired`, `active`, `past_due`, `unpaid`, `paused`, `canceled`; valor desconocido se conserva | No copiar directamente su estado a `trainer_access.enabled` ni al vínculo. |
| Documento de cobro | Factura, líneas, moneda, importes, vencimiento, pagos e intervalo de servicio | Una factura no es cada intento de tarjeta. Reintentos no duplican el periodo facturado. |
| Ajustes | Devolución parcial/total y disputa, cada una con estado propio | No borrar el pago anterior ni transformar una devolución en cancelación de suscripción. |
| Cobertura | Intervalos verificados y evidencia; política/versiones aplicadas | Separar dinero pagado, saldo/crédito, promociones aprobadas, gratuidad y ensayo. |
| Acceso profesional | Fuentes manuales y comerciales independientes, resolución vigente | La proyección efectiva sigue en servidor y mantiene su control de revisión/cupo. |

Stripe diferencia suscripción, factura y pago. Un estado `active` no demuestra
que todas las facturas estén pagadas; también existen métodos de confirmación
diferida. Cancelación programada, cancelación efectiva y pausa de cobro tampoco
son una sola situación. El adaptador conserva estos hechos sin inventar vigencias.
[Ciclo de suscripciones](https://docs.stripe.com/billing/subscriptions/overview).

La propuesta no usa `current_period_end` de la suscripción como prueba universal
de periodo pagado. Recupera líneas y suscripción en la versión API fijada y usa
el intervalo de servicio de la línea contratada. Los campos de periodo de items
y la factura se interpretan en el adaptador, no mediante rutas JSON asumidas
por las apps.
[Objeto suscripción](https://docs.stripe.com/api/subscriptions/object),
[objeto factura](https://docs.stripe.com/api/invoices/object).

Una factura con importe cero o marcada como pagada fuera del proveedor no prueba
un nuevo ingreso por tarjeta. La cobertura por crédito, cupón, prueba gratuita o
pago externo requiere su evidencia y política aprobada; no se inventa dinero ni
se descarta una gratuidad que posteriormente se apruebe. Importe siempre entero
en unidad menor y moneda explícita; instantes UTC e intervalos `[inicio, fin)`.

## 5. Seguridad, separación y continuidad

- Toda referencia externa se acota por proveedor, entorno, cuenta y tipo de
  objeto. La identidad del usuario viene de la autenticación; metadatos/email
  del evento no constituyen por sí solos la asociación autorizada con EntrenaOP.
  El entorno incluye el namespace de ensayo/sandbox configurado, no solo un
  booleano test/live; una configuración de pruebas ajena no se acepta como Dev.
- Preparador consulta solo cobros de su negocio; alumno, sus documentos y
  aceptación. ADMIN editorial no recibe acceso a finanzas profesionales ni
  historial de alumnos. Soporte comercial exige permiso específico y auditoría;
  el contenido deportivo privado no se abre por ese permiso.
- Mantener facturas/contratos fuera de datos del entrenamiento: no mandar
  molestias, marcas, mensajes ni cuestionarios en metadatos del proveedor.
- Separar origen `manual`, evidencia del proveedor y `simulation`. Un registro
  manual de transferencia/Bizum declara quién lo anotó, cuándo y qué periodo
  dice cubrir; no equivale a conciliación bancaria ni crea un cobro Stripe.
- Cancelar una suscripción no elimina cartera, resultados, versiones o datos.
  Finalizar un vínculo no se traduce por defecto en cancelar o mantener cobros:
  esa decisión comercial es requisito previo al lanzamiento del circuito.

Desconectar Connect no cancela automáticamente las suscripciones que se hayan
creado. Hay que acordar y probar qué se cancela, quién actúa y cómo se conservan
los documentos antes de habilitar desconexión con contratos recurrentes activos.
[Restricciones de Connect](https://docs.stripe.com/connect/subscriptions).

El código actual de acceso profesional utiliza `trainer_access`, revisión y una
operación administrativa manual. Esta propuesta requiere una fuente comercial
separada y un resolutor auditable antes de conectarla al acceso efectivo; el
webhook no debe hacerse pasar por un administrador ni sobrescribir concesiones.
Cómo combinar fuentes concurrentes es decisión pendiente. Si falta la política,
solo se registran hechos y el estado `policy_required`; los accesos vigentes
siguen con su contrato actual.

La reducción de capacidad con más alumnos activos que el nuevo límite produce
una propuesta/conflicto revisable. No se borran alumnos, no se escogen por orden
ni se modifican etapas o pautas. La fecha efectiva, prorrateo y comportamiento
durante el exceso necesitan la política comercial antes de activar el cambio.

## 6. Idempotencia y conciliación implementables

### Órdenes de salida

`CommercialCommand` contiene ID aleatorio de operación, circuito, actor,
vendedor/cuenta, contrato y revisión esperada, oferta/versiones, entorno y hash
canónico del payload. Reintentar lo mismo devuelve el resultado conservado;
mismo ID con otro payload se rechaza. El servidor no admite `amount`, `currency`,
`account`, `capacity` o `application_fee` arbitrarios del cliente.

Registrar orden y outbox en una transacción local; un worker reclama el envío.
La llamada externa ocurre fuera de la transacción de datos y utiliza una clave
idempotente estable derivada de la orden. Su respuesta se vincula y concilia;
crash o timeout deja la orden recuperable. No se promete transacción atómica
entre nuestro servidor y Stripe.

Stripe API v1 conserva respuestas de claves idempotentes durante al menos 24
horas y puede reutilizar una clave después de retirarla; API v2 tiene semántica
distinta para fallos parciales. Nuestro registro no expira con esa ventana.
El adaptador fija versión API y, ante una respuesta incierta antigua, recupera
por referencias/evidencia en vez de enviar otro cargo a ciegas.
[Idempotencia oficial](https://docs.stripe.com/api/idempotent_requests).

### Entrada de eventos y estado canónico

1. Verificar firma sobre el cuerpo original y secreto del endpoint correcto;
   validar entorno, cuenta y versión antes de tratar el evento como confiable.
   En v2, recuperar el recurso cuando el formato de evento lo requiera.
2. Persistir un inbox duradero antes de responder éxito; si falla la persistencia,
   responder error para que la entrega pueda repetirse. Evento repetido aceptado
   no duplica trabajo económico ni concesiones.
3. Resolver la asociación cuenta/objeto desde registros propios. Lo desconocido
   queda en cuarentena operativa, sin vincular a una cuenta por email o metadata.
4. Procesar asíncronamente con serialización por agregado/cuenta y lease con
   generación. Recuperar suscripción/facturas/pagos actuales, no aplicar el
   snapshot tardío del webhook como si fuese el más reciente.
5. Confirmar hechos y proyección de política en transacción local con revisión
   esperada; un worker sin lease vigente no confirma su respuesta tardía.
   Nuevos eventos recibidos durante la consulta provocan otra conciliación.
6. Registrar cursor, paginación, resultado y trabajo pendiente. Reconciliación
   periódica y reintento manual autorizado reparan webhooks ausentes usando
   el mismo camino; un error de red no acredita impago o cancelación.

Stripe puede repetir eventos y entregarlos fuera de orden. `event.created` no
es una versión ni resuelve empates. La firma requiere el cuerpo original y los
secretos de endpoints de prueba y reales son diferentes. Estos hechos motivan
el inbox y la conciliación anterior, que son diseño propuesto de EntrenaOP.
[Webhooks](https://docs.stripe.com/webhooks).

El inbox deduplica `(provider, environment, account_scope, event_id)`. Los hechos
económicos/proyecciones tienen además identidad por objeto/periodo/operación:
dos eventos diferentes sobre la misma factura tampoco la pagan dos veces.
No colapsar todo `(object_id, event_type)` para siempre: perdería actualizaciones
legítimas sucesivas del mismo objeto.

Escuchas separadas para recursos de plataforma y de cuentas conectadas. Un
evento de alumno en Connect nunca renueva el cupo del preparador en la plataforma.
El adaptador normaliza los eventos de Billing, cuenta, reembolso/disputa y
Checkout necesarios, sin suscribirse indiscriminadamente a todo el catálogo.
[Scopes Connect](https://docs.stripe.com/connect/webhooks),
[eventos de suscripción e incidencias](https://docs.stripe.com/billing/subscriptions/webhooks).

## 7. Puertos y datos mínimos para un ensayo

Todos los nombres son propuestos. Son contratos puros sin Flutter, SDK Stripe,
JSON del proveedor, Auth o transporte dentro de las reglas. No se obliga a crear
un paquete o capas adicionales si el módulo existente puede alojarlos con claridad.

```text
CommercialContext(circuit, environment, sellerId, providerAccountRef)
Money(minorUnits, currency)
OfferVersion(id, version, circuit, sellerId, money, interval, capacity?, termsVersion)
CommercialCommand(id, context, contractId, expectedRevision, offerVersion, payloadHash)
ProviderSnapshot(context, objectRef, observedAt, providerApiVersion,
                 subscriptionFacts, invoiceLines, paymentFacts, adjustments, completeness)
PolicyDecision(policyVersion, sourceFacts, proposedAccess?, proposedCapacity?, effectiveAt?, reason)

CommercialProviderPort:
  prepareCheckout(command) -> ProviderCheckoutReference
  readCanonical(context, objectReference) -> ProviderSnapshot
  requestContractChange(command) -> Submitted | RequiresAction | Uncertain

ConnectedMerchantPort:
  readCapabilities(context) -> MerchantCapabilities
  prepareOnboarding(command) -> TemporaryProviderLink

CommercialStorePort:
  recordCommandAndOutbox(command)
  acceptVerifiedEvent(envelope) -> New | AlreadyAccepted
  claimReconciliation(aggregate) -> Lease
  commitFactsAndDecision(lease, expectedRevision, snapshot, decision)

CommercialPolicy:
  evaluate(facts, currentSources, activeClientCount, approvedPolicy, clock)
    -> Unchanged | PolicyRequired | ProposedChange | Conflict
```

El DTO de webhook firmado se verifica en infraestructura antes de llegar al
dominio. `completeness` impide tratar una página parcial como la lista completa
de facturas. `observedAt` sirve para auditoría, no para ordenar versiones del
proveedor. Preservar los IDs de factura, suscripción, línea y pago pertinentes;
no depender exclusivamente del `PaymentIntent` de un ejemplo de API anterior.

## 8. Ensayo local primero; proveedor después

**Primera entrega ejecutable recomendada:** fake determinista del proveedor,
almacén de ensayo separado y pruebas de contrato, con datos sintéticos. Sin
claves, HTTP a Stripe, altas, onboarding real ni concesiones al acceso vigente.
La UI del ensayo, si existe, muestra «Simulación, no cobra ni activa derechos».
Reutilizar el contrato de revisión/cupo como frontera, sin conectarlo todavía.

El fake implementa esos mismos puertos, pero no se acepta como prueba de firma,
TLS, autorizaciones Connect, API real o conciliación bancaria. La configuración
del entorno debe rechazar mezcla de simulación, sandbox y live, incluidos IDs
y eventos; las métricas sintéticas no aparecen como ingresos reales.

En fase posterior autorizada, un sandbox Stripe permite pruebas sin movimiento
real de dinero y las simulaciones de Billing permiten avanzar el tiempo. Esta
documentación solo investiga esas capacidades: no ha creado un sandbox, cuenta
conectada ni reloj de pruebas.
[Sandbox oficial](https://docs.stripe.com/testing-use-cases),
[simulaciones de Billing](https://docs.stripe.com/billing/testing/test-clocks).

| Caso de contrato obligatorio | Resultado esperado |
| --- | --- |
| Retorno Checkout manipulado o sin webhook | No concede derechos; consulta autenticada y conciliación pendiente. |
| Mismo command/ID/payload tras respuesta perdida | Una operación externa y una evidencia; recupera el resultado. |
| Mismo ID, precio/cuenta o payload distinto | Rechazo sin segundo cobro. |
| Dos solicitudes simultáneas del mismo contrato | Una creación o conflicto; no dos suscripciones. |
| Evento repetido, dos eventos para la misma factura, entregas inversas | Mismos hechos finales y una proyección económica. |
| Firma inválida, body alterado o entorno/cuenta equivocados | Rechazo antes de modificar hechos/acceso. |
| Proceso cae tras persistir inbox o después de crear Checkout | Recuperación sin perder evento ni repetir cargo. |
| Lease vencido/respuesta antigua con worker nuevo | El worker anterior no confirma una proyección obsoleta. |
| `active` con pago pendiente/diferido o factura antigua sin pagar | No inventa cobertura; aplica solo política aprobada y evidencia adecuada. |
| Pago tardío, devolución parcial/total o disputa | Conserva el ledger y periodos; produce revisión/decisión trazable. |
| Factura cero, crédito o anotación de pago externo | Fuente diferenciada; sin ingreso bancario ficticio ni derechos no aprobados. |
| Alumno paga a preparador A; webhook llega con contexto B | Ningún movimiento de cupos ni acceso cruzado. |
| Concesión manual y nueva fuente comercial concurrentes | No sobrescribe regalo/acceso; resuelve con política o informa conflicto. |
| Reducción de cupo por debajo de activos | No elimina clientes ni pautas; conserva propuesta/conflicto. |
| Cancelación, baja deportiva o Connect desconectado | Tres hechos distintos; no continuar/cancelar cobros por una regla inventada. |
| Páginas incompletas, proveedor caído, estado desconocido | No interpreta ausencia como cancelación; conserva estado e informa incertidumbre. |
| Cuenta cambiada o sesión sin MFA | No abre Checkout ajeno, documentos o enlaces temporales. |
| Snapshot/cambio comercial concurrente con aceptación de última plaza | El resolutor usa revisión y bloqueo del contrato vigente; no supera cupo ni pierde vínculo. |

Las pruebas de dominio/fake pueden hacerse ya. La integración de persistencia,
permisos, fuentes comerciales y RPC requiere migraciones nuevas, matriz Dev de
`AGENTS.md`, SQL transaccional con `ROLLBACK` y concurrencia donde corresponda.
El núcleo simulado cubre los escenarios de la matriz con los límites de evidencia
de la sección 11; las pruebas de persistencia/servidor anteriores siguen pendientes.

## 9. Decisiones humanas mínimas antes de activar

| Decisión pendiente | Propuesta o preparación disponible | Hasta resolver |
| --- | --- | --- |
| Proveedor, entidad vendedora y configuración Connect | Stripe Billing + Connect, cobro directo/Dashboard completo; revisar condiciones y responsabilidades de la configuración | Sin alta ni aceptación de términos. |
| Planes de herramientas | Capacidad fija, precios/moneda/periodicidad/impuestos y condiciones versionadas | Catálogo solo sintético; no publicar tarifas inventadas. |
| Oferta del preparador y aceptación del alumno | Preparador propone precio y periodo de su servicio; quién puede cobrar y a quién debe quedar definido | Sin cargo ni suscripción real. |
| Comisión propia y costes del proveedor | Parámetro explícito y versionado; no interpretar «pendiente» como comisión 0 | No enviar application fees reales ni presentar márgenes. |
| Impago, prueba, gracia, cancelación y reembolsos | Separar dinero, cobertura y acceso; fijar inicio/fin y atención de incidencias | Registrar hechos de ensayo; no suspender ni renovar acceso real. |
| Ampliación/reducción de cupo y fuentes manuales | Fijar fecha efectiva, prorrateo, exceso y precedencia entre concesiones | Sin aplicación automática a `trainer_access`. |
| Fin de vínculo y desconexión del proveedor | Decidir quién cancela qué, saldo/reintegros y avisos al alumno | No habilitar ciclo real con cobros huérfanos. |
| Facturación y canal de contratación | Identificar emisor/responsable de cada factura y las condiciones del servicio; alcance inicial web | No declarar resueltas obligaciones fiscales ni habilitar compra móvil por inferencia. |

La propuesta comercial profesional es web. El Pro personal mantiene su integración
RevenueCat/tiendas, descrita en [PRO_LAUNCH.md](PRO_LAUNCH.md). No se añade por este
contrato un botón Stripe a la app móvil. Apple distingue servicios individuales
en tiempo real de otros contenidos/servicios: esa excepción no acredita por sí
sola nuestros programas asíncronos. Antes de incorporar contratación móvil debe
contrastarse el producto y canal con las reglas de cada tienda; este documento
no resuelve su clasificación.
[Apple, 3.1.3](https://developer.apple.com/app-store/review/guidelines/#other-purchase-methods).

## 10. Criterio real de entrega

El punto 14 puede avanzar ahora con dominio, fake, ledger de ensayo y pruebas.
No se marca como «cobros funcionando» por mostrar importes o completar una
redirección. Para cerrar integración hacen falta adaptador del proveedor probado,
asociaciones/conciliación/aislamiento de ambos circuitos, decisiones anteriores,
pruebas sandbox y aceptación del recorrido de cada pagador. Cobros reales,
contratación externa y producción conservan su autorización específica.

Este archivo se entrega al coordinador Trainer para su revisión e integración
documental; no modifica índices globales ni usa el índice Git compartido. Las
fuentes oficiales se consultaron el 21/10/2026 y soportan las capacidades citadas;
las tablas de estados internos, puertos, reglas y pruebas son propuestas propias
de EntrenaOP. El adaptador debe fijar una versión API compatible probada: no
copiar cabeceras preview o JSON de ejemplos como contrato estable del dominio.

## 11. Núcleo de simulación implementado y verificado

API pública en
[`trainer_commerce/mod.ts`](../supabase/functions/_shared/trainer_commerce/mod.ts):

- `model.ts`: contexto con circuito, entorno/namespace, proveedor/cuenta,
  vendedor/comprador/contrato; ofertas y órdenes; hechos de factura, pago y ajuste;
  fuentes manuales, revisiones y lease. Importes normalizados por línea, sin
  repetir el total de una factura por cada línea.
- `ports.ts`: proveedor canónico, verificador de eventos y almacén. Son contratos
  tipados; el futuro adaptador debe validar/normalizar el JSON externo.
- `policy.ts`: `evaluateCommerce` solo devuelve propuesta, conflicto, ausencia
  de cambio o `policy_required`. Exige `provider=fake` y `mode=simulation`; una
  política de fixture explícita puede proponer capacidad, nunca concederla.
  Sin política no deriva acceso, aunque registre evidencia de un pago simulado.
- `simulation.ts`: `FakeCommercialProvider`, `MemoryCommercialStore`,
  `FixtureEventVerifier` y `CommerceSimulation`. El proveedor devuelve referencias
  locales, sin URL pagable; el almacén separa órdenes, inbox, historial y evidencia
  económica, y conserva las fuentes manuales. Solo una orden de creación por
  contrato en este ensayo; cambios de plan, cancelación y onboarding siguen sin
  adaptador implementado.

La simulación comparte el mismo almacén al recrear el coordinador. Sus operaciones
de memoria no demuestran supervivencia a reiniciar el proceso, atomicidad SQL,
durabilidad de inbox/outbox ni coordinación entre máquinas. Las reclamaciones
de envío y conciliación reproducen las reglas de revisión y generación únicamente
en memoria. El worker con lease vencido o revisión antigua no puede confirmar;
una señal nueva durante la lectura exige reconciliar otra vez.

`FixtureEventVerifier` acepta exclusivamente pares cuerpo/prueba registrados en
el test: **no es un verificador criptográfico**. `Actor` representa evidencia de
identidad/MFA ya obtenida fuera del dominio; comprobar esos campos en el ensayo
no acredita Auth real ni impide que un llamador local invente la estructura.
No existe handler HTTP, endpoint desplegable, acceso a variables de entorno,
SDK/cliente Stripe, escritura SQL ni puerto de concesión de derechos reales.

El ledger conserva pagos históricos y trata devoluciones/disputas como hechos
separados. Una respuesta que intenta modificar un pago ya registrado se rechaza
para revisión. Esto no es una contabilidad financiera completa: reparto de pagos
entre líneas, créditos, prorrateos y ajustes requieren política y adaptador reales.
Suscripciones desconocidas, facturas incompletas, deuda anterior y evidencias
parciales nunca se interpretan como cobertura automáticamente aprobada.

Verificación realizada desde la raíz:

```text
node --experimental-strip-types --test supabase/functions/tests/trainer_commerce_test.ts
deno check --no-config --no-remote --no-npm supabase/functions/_shared/trainer_commerce/mod.ts supabase/functions/tests/trainer_commerce_test.ts
deno fmt --check --no-config supabase/functions/_shared/trainer_commerce supabase/functions/tests/trainer_commerce_test.ts
deno lint --no-config supabase/functions/_shared/trainer_commerce supabase/functions/tests/trainer_commerce_test.ts
```

Las 21 pruebas pasan: los 18 escenarios numerados y tres casos adicionales de
validación monetaria/datos, señales en vuelo y conservación de evidencia/copia.
La comprobación de tipos, formato y lint pasa en Deno 2.9.6 y las pruebas usan Node 24.19.0 sin
dependencias nuevas. No se ejecuta Flutter ni SQL porque no hay cambios en apps,
paquetes Dart, esquema o permisos; la integración persistente deberá ejecutar su
matriz correspondiente. Este tramo se entrega al coordinador sin commit propio
para respetar la ventana del índice Git compartido.

## Pasarelas y descuento militar · propuesta revisada el 28/10/2026

El flujo principal recomendado conserva tres contratos: EntrenaOP factura al
preparador en web mediante Billing; el preparador cobra a sus alumnos mediante
Connect y su propia cuenta de cobro; Pro digital del deportista en móvil conserva
Apple/Google con RevenueCat. No son tres suscripciones obligatorias para el alumno:
recibir y ejecutar lo pautado sigue incluido en su servicio con el preparador.
No se contrata ni configura cobro real en esta tarea.

Apple Pay es un medio de pago; no sustituye las compras integradas de una
suscripción digital en iPhone. La excepción de servicios individuales en tiempo
real de las normas de Apple no permite asumir que programas asíncronos o acceso
a contenido digital queden exentos. Antes de añadir un enlace de pago en la app
hay que contrastar el servicio concreto, región y requisitos de la tienda.
[Normas de Apple, 3.1.1 y 3.1.3(d)](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase).
El Apple Developer/APNs para notificaciones es otra configuración; se mantiene
aplazada conforme pide Javier, sin renovaciones ni pagos iniciados.

El anual general de Pro queda confirmado en **39,99 €**, mensual **3,99 €**.
**34,95 €/año para militares** es una propuesta por diseñar: definir beneficiarios
(en activo/reserva y otros casos), verificación mínima, periodo acreditado,
renovación y convivencia con la suscripción ya comprada. Recomiendo empezar con
validación manual, conservar solo estado/fecha de revisión y evitar almacenar
copias de TMI/DNI por defecto. Es una recomendación, no una autorización de recogida.
El reconocimiento debe hacerse en servidor; una casilla o metadato editable no
concede el derecho. Antes de venderlo se debe decidir cómo aplica cada tienda
la tarifa y qué ocurre cuando caduca la acreditación, avisando al usuario y sin
cambiar silenciosamente una renovación contratada. No se crean productos,
cupones ni descuentos militares automáticos en esta tarea.

## Preparación Stripe · COM-022 · 28/10/2026

La web pública debe separar «Soy entrenador» (planes, registro e ingreso en
Trainer) de «Quiero entrenar» (app y Pro en las tiendas). Se reutiliza el registro
web de Trainer; no se crea otra identidad ni se concede acceso profesional por
registrarse. Este chat lleva contratos, integración y acceso; la web pública
presentará esas entradas cuando exista el recorrido de contratación verificado.
No se modifica ni publica `website/` en esta preparación.

### Código preparado y límite real

`_shared/trainer_commerce/stripe_sandbox.ts` reutiliza Context/Command/Offer y las
validaciones puras existentes. Es un adaptador HTTP de infraestructura, separado
del motor simulado. Solo acepta clave test, namespace `entrenaop-dev` y API fija
`2026-09-30.endive`, contrastada con la documentación vigente. No añade SDKs ni
paquetes. No está conectado a una función pública ni a Flutter: no es una
pasarela de producción ni un portal comercial completo.

- Valida cuenta canónica, precio activo, moneda, importe, periodicidad y comprador
  antes de crear una sesión de suscripción alojada en Stripe Checkout. Usa Price
  y Customer enlazados por infraestructura, nunca un importe enviado por Flutter.
- Acceso profesional cobra en la cuenta de EntrenaOP; servicio del preparador
  utiliza su cuenta Connect en cada petición. Debe estar lista para cobrar y
  recibir abonos. No reutiliza IDs entre cuentas ni permite mezclarlos.
- Una comisión debe ser explícita para el servicio del preparador; una decisión
  pendiente no se interpreta como cero. El cero de los fixtures es solo un ensayo.
- Idempotencia por namespace/cuenta/circuito/pedido; no hay reintentos ocultos ni
  cambio de clave tras timeout. Un pedido de más de 20 horas necesita conciliación
  antes de intentar crearlo de nuevo; no se confía indefinidamente en la retención
  del proveedor. Recuperar una sesión exige contrastar dueño, contrato y metadata.
- Respuestas acotadas, timeout, sin redirecciones HTTP y sin devolver errores
  privados. Solo se admite URL HTTPS del Checkout del proveedor.
- Verificación de webhook sobre cuerpo original con HMAC, ventana de cinco
  minutos, cuenta, entorno de pruebas y versión API. Devuelve una señal para
  conciliación, nunca concesión de acceso basada en el JSON del evento.

El adaptador requiere bindings persistidos/autorizados por servidor; no permite
exponer sus argumentos directamente al navegador. La firma no sustituye el
registro idempotente de eventos ni la conciliación canónica: ambos siguen por
integrar. No se ejecuta el motor simulado como política de acceso real.

Diez pruebas nuevas del adaptador, 21 del núcleo y 12 de transporte push pasan
localmente (43 en total). Deno comprueba tipos; el workflow `trainer-commerce.yml`
añade los contratos comerciales y TypeScript estricto a CI sin secretos ni
llamadas reales a Stripe. Se conservan los contratos de avisos agrupados y canales
por dispositivo, correctos contra Dev con ROLLBACK. No se aplica una migración ni
se modifica el worker en este tramo.

### Pendiente para un recorrido completo

1. Terminar/conectar la cuenta Stripe de pruebas y configurar credenciales de
   servidor/webhook fuera del repositorio. No se aceptan claves live en este módulo.
2. Catálogo versionado y precios profesionales aprobados; pedido, comprador,
   cuenta conectada y eventos duraderos con aislamiento. Cuenta y retorno Checkout
   jamás autorizan derechos por sí solos.
3. Acordar política de altas/bajas, pagos fallidos, cambios de cupo, comisiones y
   convivencia con regalos/accesos manuales antes de proyectar `trainer_access`.
4. Integrar pantallas web, Checkout/portal de gestión, conciliación, activación y
   ambos recorridos completos con Stripe sandbox. No se considera resuelto por
   devolver `payment_status=paid` desde una sesión.

Javier selecciona suscripciones y plataforma en el asistente. Se recomienda
configuración por productos individuales: Managed Payments no soporta Connect;
no se confunde con automatización fiscal ni con facturación ya configurada.

Fuentes contrastadas el 28/10/2026:
[versión API](https://docs.stripe.com/api/versioning),
[Checkout](https://docs.stripe.com/api/checkout/sessions/create),
[cobros directos](https://docs.stripe.com/connect/direct-charges?platform=web&ui=stripe-hosted),
[firmas](https://docs.stripe.com/webhooks),
[pruebas sin fondos](https://docs.stripe.com/testing),
[incompatibilidad de Managed Payments con Connect](https://docs.stripe.com/payments/managed-payments#unsupported-integrations).
