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
contratar una pasarela. La primera carencia comprobada es que Trainer ofrece
solo inicio de sesión y remite al móvil para registro y recuperación.

El recorrido objetivo es registro web → confirmación de correo → contratación
o concesión manual vigente → MFA → panel. La cuenta EntrenaOP es única para web
y deportista. Crear cuenta no concede acceso profesional, Pro ni permisos ADMIN.
El control del cupo y de los pagos continuará en servidor. La implementación del
registro, los retornos web y la recuperación todavía está pendiente: la revisión
no los presenta como disponibles. Los precios profesionales y el proveedor de
cobros siguen abiertos; el criterio de no activar cobros reales se conserva.

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
