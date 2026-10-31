# Precios y cupos profesionales · borrador del 31/10/2026

Estado: propuesta para ensayar, **importes y cupos no aprobados**. El único
acuerdo nuevo es directorio incluido en Profesional/Completo y extra opcional
pagado en Básico. No se crean productos/precios de Stripe ni ofertas de servidor,
no se cambia el ensayo vigente de 1 EUR/cinco plazas ni se concede Pro por este
borrador. Todo continúa en sandbox/Dev; producción y cobros reales quedan fuera.

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

Hipótesis para explicar la tabla, todas pendientes:

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
