# Control de costes · COST-001

## Criterio acordado el 19/10/2026

Javier prioriza que EntrenaOP tenga el menor coste razonable durante desarrollo
y producción, evitando gasto de infraestructura que no aporte utilidad. Se
reutilizan servicios contratados y se mide el consumo antes de ampliar capacidad.
La revisión de costes no autoriza contratar planes, activar recargas, mover
proyectos, borrar recursos ni modificar producción por iniciativa propia.

El repositorio es público. Facturas, importes personales, formas de pago,
capturas de facturación y datos de cuenta no se guardan aquí. Las verificaciones
de cuenta se comunican a Javier directamente, distinguiendo consumo, descuentos,
importe facturable y cargos históricos. Las tarifas de proveedor son referencias
fechadas, no una factura ni una promesa de precio futuro.

## Publicación administrativa

El flujo `admin-dev.yml` usa ejecutores estándar de Ubuntu y publica solo ADMIN
Dev en Hostinger. Un guardado de contenido en ADMIN no ejecuta ese flujo. Los
cambios de documentación por sí solos tampoco lo activan. Las validaciones no
se reducen para ahorrar ejecuciones que son gratuitas bajo la configuración
actual de repositorio público y ejecutores estándar.

Los artefactos de GitHub caducan a los catorce días. Las carpetas `releases/` de
Hostinger no tienen la misma caducidad: el publicador conserva versiones para
que no se activen archivos parciales y pueda restaurarse la entrada anterior.
Una retención acotada debe acordarse e implementarse con protección de la versión
activa, las necesarias para recuperación y los recursos que puedan estar usando
pestañas abiertas. Esta revisión no borra versiones ni cambia el despliegue.

## Supabase antes de activar producción

El plan se aplica por organización, no por nombre de proyecto. Subir una
organización que incluya desarrollo y producción puede añadir coste de cómputo
por ambos proyectos activos. Antes de contratar, comparar mantener desarrollo
en una organización Free y producción en una de pago si lo requieren carga,
continuidad y copias de seguridad. Es una recomendación; no hay traslados ni
cambios de plan aplicados por este documento.

No confundir tamaño SQL de base de datos y bytes declarados de archivos con
las métricas de facturación, transferencia, usuarios activos o invocaciones.
Contrastar las cuotas y protecciones de gasto vigentes en el proveedor. Una
cuota Free agotada puede restringir el servicio; un tope de Pro no cubre
necesariamente cómputo y complementos contratados.

## Medios y otros proveedores

Los clips gestionados usan Bunny y pueden consumir saldo también en desarrollo.
Conservar clips cortos, límites de tamaño, autenticación y caché móvil existentes.
La web depende de su caché de navegador y no garantiza la misma reutilización.
Medir transferencia y calidad antes de aumentar resolución, réplicas o servicios
adicionales. Revisar descartes y rechazos conservando vídeos referenciados por
historial. La limpieza necesita una política y comprobaciones, no borrados ciegos.

Antes de abrir suscripciones reales, revalidar las condiciones de RevenueCat y
tiendas conforme a COM-012/013. No inferir un contrato o cobro activo por tener
el SDK integrado. Documentar por separado hosting, dominio, correo y servicios
variables para evitar atribuir sus renovaciones a cada publicación de código.

## Referencias de la revisión inicial

- [GitHub Actions: facturación y cuotas](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- [Presupuestos y alertas de GitHub](https://docs.github.com/en/billing/concepts/budgets-and-alerts).
- [Supabase: organizaciones y facturación](https://supabase.com/docs/guides/platform/billing-faq).
- [Supabase: control de costes](https://supabase.com/docs/guides/platform/cost-control).
- [Bunny Stream: precios](https://bunny.net/pricing/stream/).
- [RevenueCat: precios](https://www.revenuecat.com/pricing/).

Se contrastan configuración, publicación Dev, plan de organización y metadatos
de proyectos mediante lecturas; tamaños agregados solo en Dev; facturación y
presupuestos de GitHub y plan/recursos existentes de Hostinger en sus paneles.
El saldo, consumo y recarga automática de Bunny requieren sesión autenticada:
las tarifas públicas y la configuración documentada no acreditan estos datos.

## Preparadores · criterio del 21/10/2026 · TRN-010

Javier pide contemplar contratación autónoma web y límites que eviten que un
preparador consuma recursos ilimitados. El cupo manual de vínculos activos ya
existe; no equivale a una cuota de almacenamiento o vídeo. Antes de cobrar,
medir y acordar alumnos activos, ejercicios/planes privados, tamaño por archivo,
almacenamiento total y transferencia. Las invitaciones no ocupan plaza.
Precios, tramos, excesos y política de reducción siguen pendientes. No se
contrata infraestructura ni se introducen cobros en el bloque de acceso/clientes.


## Presupuesto transversal y contratación web · revisión del 27/10/2026

Javier pide entender el coste conjunto de los proveedores antes de incorporar
la contratación del entrenador. Stripe es una propuesta, no una elección
confirmada ni una cuenta configurada. Crear cuentas web con Supabase no requiere
contratar una pasarela. La carencia inicial era que Trainer ofrecía solo inicio
de sesión y remitía al móvil para registro y recuperación. TRN-035 incorpora
ambos recorridos web con los servicios existentes.

El recorrido objetivo es registro web → confirmación de correo → contratación
o concesión manual vigente → MFA → panel. La cuenta EntrenaOP es única para web
y deportista. Crear cuenta no concede acceso profesional, Pro ni permisos ADMIN.
El control del cupo y de los pagos continuará en servidor. El registro, los
retornos web y la recuperación están implementados y validados según
[TRAINER_WEB_ACCOUNT_2026_10_27.md](TRAINER_WEB_ACCOUNT_2026_10_27.md), que recoge
la evidencia y los límites de la comprobación. Los precios profesionales y el
proveedor de cobros siguen abiertos; no se activan cobros reales.

### Inventario y tarifas públicas de referencia

Tarifas comprobadas el 27/10/2026; no equivalen al plan contratado, su consumo ni
una factura. No se guardan importes personales ni credenciales en este repositorio.

| Concepto | Uso comprobado o previsto | Referencia de coste |
| --- | --- | --- |
| Hostinger y dominio | Web, ADMIN y Trainer publicados; SMTP propio de acceso | Pendiente incorporar renovaciones y servicios incluidos de las facturas, fuera del repositorio público. Publicar código no equivale a contratar otra suscripción. |
| Supabase | Auth, datos, permisos y funciones; las tres aplicaciones consultan el mismo Dev | Free existe; Pro desde 25 USD/mes, primer proyecto básico cubierto. Proyectos adicionales en una organización de pago desde unos 10 USD/mes por proyecto. Consumo y complementos pueden aumentar la cifra. |
| Bunny Stream | Demostraciones y técnica privadas, además del catálogo | Mínimo de cuenta publicado de 1 USD/mes; almacenamiento y transferencia según consumo, configuración y regiones. La referencia de entrada es desde 0,01 USD/GB de almacenamiento y 0,005 USD/GB de transferencia; no atribuirla a todas las regiones/configuraciones. |
| Firebase FCM | Transporte de avisos; no usamos Firebase como segunda base de datos de EntrenaOP | Cloud Messaging sin coste en la tarifa publicada. Esto no afirma que todos los demás productos de Firebase/Google Cloud sean gratuitos. |
| RevenueCat | Integración existente de compras Pro de la app | Gratis por debajo de 2.500 USD/mes de ingresos registrados; al alcanzar ese umbral, 1 % del total registrado antes de comisiones e impuestos. No sustituye comisiones de tiendas. |
| Apple Developer | Distribución y capacidades Apple; renovación aplazada por Javier | Referencia de 99 USD/año, con importe local según región. No es una cuota por alumno. |
| Google Play | Publicación Android, pendiente de cuenta de distribución | Referencia de 25 USD de registro único. Las comisiones comerciales son un concepto separado. |
| Stripe Payments/Billing | Propuesta para entrenador → EntrenaOP por web | Tarjeta estándar EEE: Payments 1,5 % + 0,25 EUR; Billing de pago por consumo, si se elige, 0,7 % adicional del volumen. No es la tarifa de todos los métodos de pago ni incluye otros productos. |

### Modelo de presupuesto

Mantener por separado:

1. Coste fijo mensual: renovaciones prorrateadas + base de Supabase/proyectos +
   otros servicios contratados que realmente lo requieran.
2. Consumo variable: vídeos almacenados/reproducidos, transferencia, servidor y
   excesos de cuota. Medir el consumo de Dev y estimar producción por separado.
3. Coste de cobro: comisiones del proveedor por tipo de pago y producto usado;
   no sumar indiscriminadamente Stripe, RevenueCat y tiendas a cada operación.
4. Distribución anual/única y herramientas de desarrollo, separadas del coste de
   operar el servicio para alumnos.

Ejemplo exclusivamente ilustrativo: para una mensualidad profesional de 30 EUR
cobrada con tarjeta estándar EEE, Payments serían 0,70 EUR y Billing 0,21 EUR,
si se usan ambos productos: 0,91 EUR por cobro bajo esas tarifas. Veinte cobros
iguales darían 600 EUR brutos y 18,20 EUR por esos dos conceptos. No son precios
aprobados de EntrenaOP, beneficio neto ni una estimación de impuestos: faltan
infraestructura, uso y demás costes aplicables.

No existe todavía un total mensual real consolidado. Faltan las renovaciones
vigentes, plan y cargos efectivos por organización, saldo/consumo/configuración
de Bunny y la futura combinación de Dev/producción. Preparar escenarios de
5, 20 y 100 preparadores requiere fijar alumnos activos medios, almacenamiento,
reproducciones y precios. No tratar los límites técnicos reservados de vídeo
como GB reales facturados ni la cuota de alumnos como coste directo por alumno.

El circuito alumno → preparador se presupuestará aparte: procesar y repartir
fondos a terceros puede requerir otro producto y otras comisiones. No atribuirle
las tarifas de cobrar directamente una suscripción propia.

Fuentes oficiales contrastadas:

- [Supabase](https://supabase.com/pricing) y [proyectos adicionales](https://supabase.com/docs/guides/platform/billing-faq).
- [Bunny Stream](https://bunny.net/pricing/stream/).
- [Firebase](https://firebase.google.com/pricing).
- [RevenueCat](https://www.revenuecat.com/pricing).
- [Apple Developer](https://developer.apple.com/programs/enroll/).
- [Google Play](https://support.google.com/googleplay/android-developer/answer/6112435).
- [Stripe Payments](https://stripe.com/es/pricing) y [Stripe Billing](https://stripe.com/es/billing/pricing).


### Primera base presupuestaria · 27/10/2026

Para dimensionar el lanzamiento, una hipótesis mínima sería **25 USD/mes de
Supabase Pro con un solo proyecto básico + al menos 1 USD/mes de Bunny**, más
hosting/dominio/correo contratados y cualquier consumo que exceda esos mínimos.
Por tanto, **desde 26 USD/mes + hosting y renovaciones** es una base parcial de
planificación, no el gasto actual verificado ni un presupuesto cerrado. No se
ha contratado Pro ni se han cambiado planes por esta estimación.

Si más adelante se renueva Apple Developer, los 99 USD/año de referencia
representan 8,25 USD/mes prorrateados: la base parcial pasaría a 34,25 USD/mes,
con las mismas exclusiones y el precio local de Apple pendiente de contratación.
Google Play conserva su alta única y las comisiones comerciales de las tiendas
son otro concepto. Desarrollo adicional dentro de una organización Supabase de
pago puede sumar cómputo; no presupuestar dos proyectos pagados como uno.

Javier confirma ahora **aplazar los cobros** y priorizar registro/recuperación
web con concesión manual desde ADMIN (TRN-035). Ese recorrido reutiliza Auth y
SMTP existentes; no necesita Stripe, Billing ni una suscripción externa nueva.
La estimación final necesita reconciliar renovaciones privadas y medir vídeos,
transferencia y carga. Las facturas reales se mantienen fuera del repositorio.

## Escenarios de mantenimiento y producción de vídeos · COST-003 · 27/10/2026

Javier solicita un presupuesto de mantenimiento completo y su crecimiento con
preparadores/alumnos para estudiar precios. Añade al menos un mes de IA
generativa para producir vídeos. Este encargo permite estimar y comparar;
no aprueba tarifas profesionales, proveedores, compras ni nuevos planes.

Las cifras siguientes son **presupuestos calculados con hipótesis**, no el gasto
real ni una garantía de capacidad. Faltan las renovaciones de Hostinger/dominio,
el importe imputable de IA de programación y los gastos administrativos reales.
Las facturas y datos privados continúan fuera del repositorio público.
La cifra anterior de 26 USD/mes era una base parcial; no incluía este conjunto
de provisiones, distribución y consumo de una población concreta.

### Moneda, alcance y partidas

Referencia del [BCE del 27/10/2026](https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/eurofxref-graph-usd.en.html):
1 EUR = 1,1150 USD. El modelo convierte USD a EUR dividiendo por 1,1150;
el banco, impuestos y fecha efectiva pueden cambiar el importe pagado.

| Partida | Base del presupuesto | Naturaleza y límites |
| --- | --- | --- |
| Hosting y SMTP actuales | Provisión de 12 EUR/mes | Hipótesis reemplazable por renovación real; no añadir otro hosting por cada portal. |
| Dominio | Provisión de 20 EUR/año | Hipótesis; poner cero si ya está incluido en el hosting. |
| Supabase de producción | Pro 25 USD/mes incluyendo crédito de cómputo de 10 USD | Referencia pública. Incluye un Micro básico; cómputo mayor y otros proyectos suman. No se contrata ahora. |
| Desarrollo adicional | 0 USD en las dos poblaciones iniciales; 10 USD/mes de cómputo en las otras dos | Hipótesis de Dev gratuito separado al inicio y Micro adicional de pago después. No hay traslado de organización. |
| Demostraciones y técnica | Bunny: 0,01 USD/GB-mes de stock y 0,01 USD/GB servido | Standard Europa/Norteamérica, una región y codificación estándar; mínimo de cuenta de 1 USD/mes. No se presupone la tarifa Volume sin elegirla. |
| Correo adicional, observabilidad y copias | Provisión incremental de 0/15/40/100 EUR/mes por población | Reserva de planificación; no representa servicios contratados. Copias SQL no equivalen a una copia de todos los vídeos/archivos. |
| Push | Transporte Firebase FCM sin coste | Las funciones y consultas que preparan el envío consumen servidor. No se añade otra base de datos Firebase. |
| Publicación automática | Minutos de ejecutores estándar públicos GitHub sin coste | Vigilar almacenamiento y cambios de modalidad. No afirmar que todos los recursos de Actions son ilimitados. |
| Apple Developer | 99 USD/año de referencia, unos 7,40 EUR/mes prorrateados | Se modela la futura distribución. La renovación sigue aplazada; importe local pendiente. |
| Google Play | Alta única de 25 USD, unos 22,42 EUR | No se vuelve a sumar cada mes. Comisiones de compras separadas. |
| Garmin | Sin licencia/mantenimiento por acceso base según FAQ pública | No presupone métricas especiales gratuitas ni sustituye condiciones de cada acuerdo o proveedor de relojes futuro. |
| IA de programación y otros gastos | Importe pendiente | Incluir la suscripción realmente imputable, gestoría/legal, marketing, soporte adicional, salarios y amortización de equipos cuando corresponda. No tratarlos como cero por faltar el dato. |

Fuentes: [Supabase y cómputo](https://supabase.com/pricing),
[Bunny y sus regiones/derivados](https://bunny.net/docs/stream/pricing),
[Firebase](https://firebase.google.com/pricing),
[GitHub](https://docs.github.com/en/actions/concepts/billing-and-usage),
[Apple](https://developer.apple.com/programs/enroll/),
[Google Play](https://support.google.com/googleplay/android-developer/answer/6112435),
[Garmin](https://developer.garmin.com/gc-developer-program/program-faq/).

### Supuestos reproducibles de crecimiento

Se comparan cuatro poblaciones simultáneamente, con un único cálculo por
columna y los mismos precios unitarios. No son una previsión comercial de ventas.

- Preparadores: 5, 20, 100 y 300; alumnos activos medios por preparador:
  10, 20, 25 y 30. Se presupone que no comparten alumnos ni cuentas; el escenario
  cuenta también a los preparadores como activos. En la realidad una identidad
  compartida no consume dos MAU, aunque sí pueda generar más asignaciones/uso.
- Se añaden 100, 1.000, 5.000 y 20.000 deportistas activos sin preparador. La
  primera revisión incluía su consumo pero dejaba fuera todos sus ingresos Pro.
  COST-004 incorpora esos ingresos por separado, sin volver a sumar usuarios
  al gasto: los suscriptores son un subconjunto de esta misma población.
- Se estima el stock al mes 12 manteniendo esa población todo el período, con
  2 clips técnicos originales de 20 MB por alumno/mes y multiplicador de
  almacenamiento 3 por resoluciones/derivados, sin borrado automático. Se añaden
  2 GB codificados de demostraciones por preparador y 50 GB de catálogo oficial.
  El historial de alumnos que se marchen puede seguir ocupando espacio: ese
  crecimiento adicional debe medirse; no desaparece al liberar una plaza.
- Entrega mensual: 1 GB de demostraciones por cuenta activa, tras el efecto de
  la caché, más dos reproducciones de cada clip técnico. Enlaces externos
  alojados por terceros no generan la misma factura Bunny.
- SQL al horizonte: 2 MB por cuenta; transferencia sin vídeo: 20 MB por
  cuenta/mes; 100 invocaciones Edge por cuenta/mes; imágenes: 10 GB base más
  2 MB por cuenta. Son hipótesis medibles, no telemetría actual.
- Cómputo elegido para presupuestar: Micro/Small/Medium/Large, con tarifas de
  referencia de 10/15/60/110 USD/mes antes del crédito. **No son umbrales de
  capacidad por número de usuarios**. Validar consultas, concurrencia, caché y
  pruebas de carga antes de decidir el tamaño. El polling también carga SQL.
- Se calculan excesos de producción sobre las cuotas publicadas Pro: 8 GB de
  disco; 250 GB de transferencia no caché; 100.000 MAU; 2 millones de funciones;
  100 GB de archivos. El consumo de Dev en una organización de pago comparte
  las cuotas de organización cuando aplique; el modelo explicita su cómputo y
  necesita añadir su uso real a las demás métricas al consolidar las facturas.

El gasto técnico suma Supabase, Bunny, hosting/SMTP, dominio prorrateado,
Apple prorrateado y provisión operativa. La reserva presupuestaria añade
el 30 % a ese gasto; **no es otro cargo del proveedor**.

| Preparadores | Alumnos vinculados | Deportistas independientes | Cuentas activas totales | Gasto técnico modelado/mes | Presupuesto con reserva del 30 %/mes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 50 | 100 | 155 | 46,10 EUR | 59,93 EUR |
| 20 | 400 | 1.000 | 1.420 | 81,97 EUR | 106,56 EUR |
| 100 | 2.500 | 5.000 | 7.600 | 242,59 EUR | 315,37 EUR |
| 300 | 9.000 | 20.000 | 29.300 | 667,90 EUR | 868,28 EUR |

Importes sin impuestos de proveedores, cambio bancario, IA de programación,
gestoría/legal, marketing ni salarios. Las comisiones de cobro y la producción
inicial de vídeos se añaden por separado. No se considera beneficio el dinero
que quede antes de remunerar mantenimiento/soporte.

Sensibilidad: cambiar la reproducción de 1 a 5 GB por cuenta/mes en la última
población suma unos 1.366,46 EUR/mes, incluida la reserva, y eleva el presupuesto
a unos **2.234,73 EUR/mes**. Doblar archivos fuente, resoluciones o años de
historial también eleva el stock. Usuarios, ejercicios y vídeos no son unidades
intercambiables de facturación. Las reservas técnicas actuales de medios no
son GB efectivamente facturados ni una cuota comercial prometida; vender los
tramos requiere definir almacenamiento/transferencia y revisar esos límites.

### IA para crear vídeos y desembolso de preparación

Se añade **100 EUR de provisión para un mes**, con rango orientativo de
50–150 EUR según modelo, créditos y repeticiones. No es una suscripción
contratada ni el precio garantizado de producir el catálogo completo.
[Runway](https://runway.com/pricing) publica como referencia mensual 15 USD
Standard, 35 USD Pro y 95 USD Max; los 12/28/76 USD anunciados junto a ellos
son equivalentes con facturación anual. No contratar un año para esta prueba.
Los segundos/créditos varían por modelo; descartar intentos consume presupuesto.

Conviene ensayar primero varios movimientos y revisar la técnica de los clips
antes de producir en serie. El objetivo es un catálogo útil, no acumular vídeos
generados que luego haya que reemplazar. Si este mes se paga en preparación,
se registra una vez y no se vuelve a sumar al llegar al lanzamiento. Conservar
la suscripción después sería una decisión adicional y un gasto recurrente.

Para el piloto, el presupuesto comparable del primer mes sería unos **263,74
EUR**: 59,93 EUR de presupuesto técnico + 100 EUR de IA + 22,42 EUR de alta
Google Play + 81,39 EUR para completar el pago anual de Apple, cuya prorrata del
mes ya está incluida. Es una planificación futura de lanzamiento, no un cargo
actual: Apple sigue aplazada y las renovaciones anticipadas de hosting/dominio
pueden cambiar la caja real de ese mes. No incluye los gastos aún sin importe.

### Cobros y precios para estudiar, sin activarlos

Son tres circuitos distintos:

1. Preparador a EntrenaOP por web: como hipótesis, tarjeta estándar EEE de
   [Stripe Payments](https://stripe.com/es/pricing), 1,5 % + 0,25 EUR/cobro;
   si se usa [Billing por consumo](https://stripe.com/es/billing/pricing),
   añadir 0,7 %. La comisión se calcula sobre el dinero efectivamente cobrado,
   incluyendo IVA si lo lleva. No se elige ni configura el proveedor aquí.
2. Pro del deportista en tiendas: comisión según contrato, región y programa;
   para estudiar sensibilidad usar 15–30 %, verificando las condiciones antes
   de activarlo. [Apple Small Business](https://developer.apple.com/app-store/small-business-program/)
   requiere aceptación; [Google Play](https://support.google.com/googleplay/android-developer/answer/112622)
   diferencia canales/regiones. [RevenueCat](https://www.revenuecat.com/pricing)
   es gratuito bajo 2.500 USD MTR y su referencia al alcanzar el umbral es el
   1 % del total registrado, antes de impuestos/comisiones. No sumar estas
   tarifas de tiendas/RevenueCat a cualquier cobro web indiscriminadamente.
3. Alumno a su preparador: no es ingreso íntegro de EntrenaOP; el circuito de
   [reparto de fondos](https://stripe.com/es/connect/pricing), comisiones,
   reembolsos/disputas y facturación necesita presupuesto propio.

Como **propuesta sin aprobar**, estudiar estos precios mensuales por entrenador:

| Plazas de alumnos activos | Precio sin IVA/mes |
| ---: | ---: |
| 5 | 19 EUR |
| 15 | 29 EUR |
| 30 | 49 EUR |
| 60 | 79 EUR |
| 100 | 119 EUR |

No incluyen vídeos ilimitados ni aumento de creación personal del alumno.
Mantener la capacidad de consumir lo pautado sin otra compra obligatoria y
separar cuotas de medios, plazas, Pro y permisos. No aplicar descuentos anuales
ni precio vitalicio antes de medir uso y soporte. Invitaciones pendientes y
el propio entrenador no ocupan plaza; historial archivado puede seguir teniendo
coste de almacenamiento.

Ejemplo calculado, todavía sin ingresos Pro: 20 entrenadores a 49 EUR sin IVA
generan 980 EUR/mes. Con IVA ilustrativo del 21 %, la comisión conjunta del
ejemplo web sería 31,09 EUR/mes y el gasto técnico medio modelado, 81,97 EUR.
Quedan **866,95 EUR antes de IA de programación, otros gastos e impuestos**.
Apartar 24,59 EUR de reserva deja 842,36 EUR disponibles; la reserva sigue
siendo dinero de Javier, no una factura ni un gasto consumido.

Los **375 EUR de trabajo valorado no se pagan a ningún proveedor**: eran
10 horas/mes de mantenimiento más 15 minutos de soporte por entrenador,
valoradas a 25 EUR/h. Mientras Javier haga ese trabajo, no se descuentan del
saldo operativo como un pago externo. Tampoco representan una tarifa adicional
del asistente. La suscripción real de IA de programación se imputa por separado,
una sola vez, con su importe efectivo. Si se contrata personal en el futuro,
su coste contratado sustituirá la hipótesis correspondiente y habrá gasto real.

Con cinco entrenadores del escenario inicial, 145 EUR de ingresos menos
46,10 EUR de gasto técnico medio y 5,11 EUR de comisiones dejan 93,79 EUR antes
de herramientas, otros gastos e impuestos, todavía sin Pro. La cifra negativa
de la primera hoja después de valorar el trabajo propio no acreditaba una
pérdida de caja. Tampoco se garantiza rentabilidad: sin ingresos hay gastos,
y herramientas/obligaciones aún sin cuantificar pueden consumir ese saldo.

El [21 %](https://www3.agenciatributaria.gob.es/Sede/iva/calculo-iva-repercutido-clientes/tipos-impositivos-iva.html)
es la referencia general usada para el ejemplo, no una resolución del tratamiento
fiscal de cada venta o del dinero que corresponda ingresar. Los costes medios
incluyen anualidades prorrateadas; no describen los movimientos exactos del banco
en cada mes.

### Caja, ingresos Pro y comparación comercial · COST-004 · 27/10/2026

Javier pide distinguir lo que sale realmente de su bolsillo del valor de su
trabajo y recuerda la otra fuente de ingresos: Pro a **3,99 EUR/mes y 29,99
EUR/año**, precios vigentes del [catálogo](PRO_LAUNCH.md). No se cambia la tarifa.
Se corrige la presentación anterior: gastos externos estimados, reserva sin
gastar, trabajo propio valorado e ingresos de cada canal quedan separados.

La hoja añade `Ingresos Pro` con estos cálculos:

- Ventas brutas del período = suscriptores mensuales que pagan × 3,99 + altas
  o renovaciones anuales que se cobran en ese período × 29,99. Los anuales
  activos que ya pagaron no vuelven a pagar cada mes.
- Equivalente mensual bruto = mensuales activos × 3,99 + anuales activos ×
  29,99 / 12. Sirve para comparar el ingreso económico entre meses, pero no se
  suma otra vez a las ventas ni se presenta como depósito bancario mensual.
- Se descuenta IVA ilustrativo del 21 % y una comisión de tienda configurable,
  inicialmente 15 % de la base sin IVA como hipótesis. La elegibilidad, región
  y contrato deben contrastarse; se comprueba también la sensibilidad al 30 %.
- [RevenueCat](https://www.revenuecat.com/docs/welcome/set-up-revenuecat/account-management)
  factura por MTR bruto del período, antes de impuestos/comisiones, distinto del
  MRR. Una anualidad entra completa cuando se compra/renueva; no se divide por
  doce para decidir si supera el umbral. Se aplica la tarifa publicada del 1 %
  del total registrado al alcanzar 2.500 USD, suponiendo que la cuenta solo
  registra las ventas del ejemplo. Otras apps/ventas podrían activarla antes.
- Las ventas Pro netas se agregan a los ingresos sin IVA de los entrenadores.
  Las comisiones de tienda y RevenueCat ya descontadas no se vuelven a sumar
  como Stripe. Las tiendas pueden liquidar después: el saldo operativo del
  modelo no acredita una transferencia bancaria recibida.
- Los usuarios Pro del ejemplo ya están incluidos entre los deportistas sin
  entrenador del escenario. Se comprueba que los recuentos no excedan esa
  población y que no se cobren más anualidades que suscriptores anuales activos.
  Los alumnos con preparador no están obligados a contratar Pro para consumir
  lo asignado. Un vínculo tampoco se presenta como una suscripción Pro pagada.

Ejemplo de escala de ingresos, antes de IVA y comisiones: 100 mensuales aportan
399 EUR/mes. Cien anualidades aportan 2.999 EUR cuando se cobran y equivalen a
249,92 EUR/mes durante doce meses. Juntas equivalen a 648,92 EUR brutos/mes;
con IVA ilustrativo del 21 % y comisión del 15 %, unos 455,85 EUR mensuales
equivalentes antes de RevenueCat. Eso no significa cobrar 648,92 EUR cada mes
en el banco ni acredita cien ventas reales de cada modalidad.

Para que la hoja muestre ambas fuentes, se incluyen estas muestras editables,
**no previsiones de conversión ni usuarios de pago confirmados**:

| Entrenadores del escenario | Pro mensuales | Pro anuales activos | Anualidades cobradas en el mes | Ventas Pro netas del mes | Saldo operativo conjunto antes de otros gastos |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 10 | 10 | 1 | 49,10 EUR | 142,89 EUR |
| 20 | 50 | 50 | 4 | 224,41 EUR | 1.091,36 EUR |
| 100 | 250 | 250 | 20 | 1.122,07 EUR | 5.624,04 EUR |
| 300 | 1.000 | 1.000 | 80 | 4.424,39 EUR | 17.990,17 EUR |

El saldo no resta trabajo propio ni reserva. Sí descuenta gastos técnicos
medios y las comisiones modeladas de cada canal. Sigue pendiente el importe
real de IA de programación, otros gastos e impuestos. Con cero suscripciones
Pro el modelo vuelve a mostrar solo el ingreso de entrenadores; no transforma
usuarios gratuitos en pagos por defecto.

La comparación con [Harbiz](https://www.harbiz.io/tarifas), comprobada el
27/10/2026, muestra 19 EUR/mes por hasta cinco clientes y 119 EUR/mes por hasta
50 en sus planes mensuales, sin IVA. Los 14 EUR/mes por cinco son el equivalente
con pago anual. La propuesta EntrenaOP de 19 EUR por cinco coincide en entrada;
la de 79 EUR por 60 no supera ese Pro mensual por 50. Esto no compara todas las
funciones ni acredita el precio de cada opción de sus desplegables. Los precios
EntrenaOP continúan sin aprobar; no se cambian tarifas por esta comparación.

La corrección conserva 263,74 EUR como presupuesto de primer mes con reserva
del piloto. Su componente de coste estimado sin reserva es 249,91 EUR; incluye
IA de vídeo y las altas futuras ya indicadas, no un nuevo pago de 375 EUR.
Las anualidades y fechas de contratación reales siguen determinando la caja.

### Hoja editable y verificación

Se entrega a Javier una hoja XLSX con tarifas/fuentes y un único cálculo por
población. La hoja permite cambiar usuarios, reproducción, stock, precio medio,
suscripciones Pro, renovaciones anuales y gastos. Los importes ausentes de IA de programación/otros gastos mantienen
el total completo como pendiente; escribir cero es confirmar coste imputado nulo.
La hoja y los futuros datos privados no se incorporan al repositorio público.

Verificados los cuatro resultados mediante cálculo independiente, la variación
de vídeo a 5 GB, la diferencia entre gasto cero y pendiente y ausencia de errores
de fórmula. La corrección añade comparación independiente de Pro, comisión al
30 %, anualidad activa sin cobro este mes y población inválida. Se revisan las
vistas modificadas y la nueva hoja, y se exporta con fórmulas.
La comprobación usa el motor de la herramienta de hojas; no acredita apertura
ni recálculo físico en Excel de escritorio. No se modifica código, base de datos,
suscripciones ni producción; no procede ejecutar Flutter en este cambio documental.
