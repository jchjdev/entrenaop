# Cobro del servicio del preparador · TRN-012 · 21/10/2026

**28/10/2026 · COM-022:** servidor y persistencia de contratación propia aplicados
en Dev, con Checkout, webhooks, conciliación y proyección del cupo pagado sin
perder regalos manuales. Trainer añade compra propia tras MFA y portal de
cancelación al final del periodo. Oferta de ensayo: 1 EUR simulado/mes y cinco
plazas; no fija tarifas. Pro personal conserva tiendas/RevenueCat. Cobro alumno
→ preparador y modo activo siguen pendientes. La aceptación completa del pago
sandbox se registra separadamente de la validación automatizada.
[Estado vigente](TRAINER_COMMERCIAL_CONTRACT.md#contratacion-propia-en-dev--28102026).

## Criterio confirmado por Javier

El alumno paga a su preparador por el servicio de entrenamiento. El preparador
paga a EntrenaOP por sus herramientas y capacidad de clientes. El acceso incluido
del alumno significa que no necesita otra suscripción de EntrenaOP para recibir,
consultar y realizar lo asignado; no significa que el entrenador trabaje gratis.

Javier pide una pasarela en el espacio profesional para que los alumnos paguen
a los entrenadores. Es un objetivo de producto confirmado; este bloque publica
el piloto de acceso y clientes, sin implementar ni activar cobros.

## Circuitos separados

1. **Preparador → EntrenaOP:** contratación del acceso profesional y su cupo.
2. **Alumno → Preparador:** precio y cobro del servicio profesional.

Cada circuito necesita su estado y sus referencias de pago. La suscripción
personal Pro conserva su contrato independiente. Un alumno Free puede recibir
servicio profesional sin comprar Pro; ser alumno no amplía sus cuotas personales.
Ni un cobro ni un vínculo deben conceder permisos administrativos.

## Decisiones necesarias antes de implementar

- Proveedor y modelo de cuentas del preparador que reciben el dinero.
- Quién fija el precio, periodicidad y condiciones del servicio.
- Comisión de EntrenaOP, si la hubiera, y tratamiento de los costes del proveedor.
- Facturación, reembolsos, incidencias y responsabilidades contractuales.
- Activación del servicio y efectos del impago o la cancelación, conservando el
  historial conforme al contrato y sin confundirlo con el cupo del preparador.
- Conciliación e idempotencia de eventos de servidor; una pantalla de pago
  completada no acreditará por sí sola derechos o movimientos de dinero.

No se ha elegido proveedor, fijado tarifas ni aceptado términos de pago. No se
crean cuentas financieras, se contratan servicios ni se solicitan datos bancarios.
La pasarela se abordará como bloque propio después del recorrido de entrenamiento
y resultados. [Acceso profesional](TRAINER_APP.md).


## Prioridad posterior y referencia aportada · 21/10/2026

Javier confirma que todavía no tiene proveedor ni precios y prefiere terminar
la infraestructura general antes de decidirlos. No bloquea clientes, autoría,
asignaciones y resultados. No se contrata una prueba de Harbiz.

La captura aportada muestra BASIC 19 €/mes hasta cinco clientes, PRO 119 €/mes
hasta cincuenta y APP 199 €/mes hasta cincuenta con aplicación personalizada.
Son importes de esa pantalla con cupos distintos; impuestos, periodicidad y
otras condiciones no se acreditan con la captura. No se fijan tarifas nuestras
ni se presume que copiar esos tramos sea adecuado.
