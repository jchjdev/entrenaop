# Precios y cupos profesionales · borrador del 31/10/2026

Estado: **catálogo provisional autorizado solo para pruebas**, sin precios
comerciales definitivos ni cobros reales. Javier autoriza el 31/10 convertir la
tabla en ofertas sandbox para probar registro, pago y habilitación del cupo.
Directorio incluido en Profesional/Completo y extra opcional en Básico conserva
su acuerdo de producto; **su concesión comercial y Pro aún no están conectados**.

## Hipótesis mensual para debatir

**Maqueta web autorizada · 31/10/2026:** Javier pide mostrar estos importes y
prestaciones como provisionales en la presentación local de Trainer. Autoriza
su comparación orientativa, no su conversión en ofertas definitivas. El registro
y la contratación enlazan al portal existente, cuyo catálogo de ensayo conserva
su propio estado. No se activan cobros reales ni un algoritmo profesional, ni
se duplican el registro o el panel. Detalle en [WEBSITE.md](WEBSITE.md).

Importes en EUR usados como propuesta comercial de simulación; no se anuncian
como PVP final ni se fija su tratamiento fiscal. No son un cálculo de coste ni
una garantía de rentabilidad. Cruzar almacenamiento/transferencia y presupuesto
antes de decidir venta, anualidad o descuentos.

| Alumnos activos contratados | Básico | Profesional | Completo |
| --- | ---: | ---: | ---: |
| 5 | 12,90 | 19,90 | 24,90 |
| 10 | 19,90 | 26,90 | 36,90 |
| 20 | 29,90 | 36,90 | 56,90 |
| 50 | 59,90 | 66,90 | 116,90 |
| 100 | 99,90 | 106,90 | 206,90 |

Hipótesis comerciales de la tabla; sus prestaciones siguen pendientes:

- Profesional suma 7 EUR a Básico e incluiría directorio y Pro personal.
- Completo suma a Profesional 1 EUR por **plaza contratada**, no un cargo variable
  calculado por cada alta. Pro se concedería solo a alumnos activos elegibles.
  El suplemento es una hipótesis comercial, no el coste estimado de dar Pro.
- Básico podría añadir directorio por 4,90 EUR/mes. Proponer una contratación y
  renovación conjunta del plan/complemento, evitando dos pagos o renovaciones
  desconectadas. El detalle de ofertas y cambios requiere diseño posterior;
  este borrador no impone una integración Stripe de múltiples líneas.
- No cobrar aún un suplemento por algoritmo profesional: no está implementado.
  Mantenerlo como propuesta futura revisable y distinguirlo del algoritmo
  personal que ya forma parte de la app Pro.
- La tabla no aprueba cobertura Pro comercial, acumulación con tiendas, nuevas
  cuotas de vídeo ni una anualidad. Concretar esos contratos antes de ofrecerlos.

## Reglas ya acordadas y límites

Cupo por alumnos externos activos de cada preparador. «Para mí», inactivos,
archivados e invitaciones pendientes no ocupan plaza. Un alumno con dos
preparadores ocupa una plaza en cada servicio, sin duplicar cuentas. Recibir y
realizar lo pautado no exige Pro del alumno. Concesiones de ADMIN, Pro personal,
vínculo deportivo y fuente pagada siguen separados.

La cancelación conserva el periodo pagado; una reducción no expulsa alumnos ni
borra datos. Falta decidir fechas/prorrateo para cambios, gestión de exceso,
impagos/cortesía, reembolsos, condiciones e impuestos. No se activan políticas
por inferencia de esta tabla. Los límites técnicos de medios permanecen propios;
no se promete almacenamiento o vídeo ilimitado.

Referencia: [contrato comercial](TRAINER_COMMERCIAL_CONTRACT.md),
[directorio y observaciones de uso](TRAINER_PLATFORM.md),
[control de costes](COST_CONTROL.md).

## Catálogo de ensayo conectado · 31/10/2026

Veinte precios mensuales inmutables en el entorno de prueba de EntrenaOP:
cinco cupos por cada nivel y cinco ofertas conjuntas Básico + directorio.
El suplemento de 4,90 EUR se integra en una oferta única, con una renovación.
El servidor conserva importe, moneda, precio Stripe y capacidad; el cliente
solo elige el identificador de oferta. Un pedido pendiente mantiene esa oferta.
El pago acreditado concede acceso profesional y cupo, **no concede todavía Pro
ni publica/habilita comercialmente una ficha de directorio**. La pantalla avisa
del alcance limitado. El ensayo antiguo de 1 EUR sigue disponible para pedidos
anteriores; el selector moderno no lo mezcla con las nuevas tarifas.

Antes de venta real hay que estudiar una curva por alumnos adicionales y su
coste marginal. Los saltos 5/10/20/50/100 sirven para validar cupos, no aprueban
que añadir un alumno obligue a saltar a una tarifa desproporcionada. No se crean
cargos automáticos por alta, ni se asume la curva o los precios de Harbiz.
Impuestos y Stripe Tax quedan por configurar tras concretar la fiscalidad; el
ensayo no aprueba PVP con/sin IVA ni activa cálculo fiscal automático.

Validación: pruebas SQL transaccionales de las veinte ofertas, sin altas ni
pagos persistentes de fixtures; regresiones de identidad, MFA, pago, regalos e
idempotencia. Posteriormente se acredita una compra de Completo/cinco plazas por Checkout,
sin regalo manual: véase el contrato comercial. No se confunde ese caso con
veinte pagos por tarjeta ni con las simulaciones SQL.
