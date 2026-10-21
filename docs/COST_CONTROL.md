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
