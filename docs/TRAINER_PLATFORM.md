# Plataforma para preparadores · alcance acordado · 21/10/2026

## Objetivo y propiedad del contenido

Javier concreta que el portal debe ser una herramienta de trabajo profesional
para preparadores de oposiciones. El preparador crea ejercicios, sesiones y
programas propios, reutiliza su biblioteca con cualquiera de sus alumnos y
elige qué pautar a cada persona. Una sesión puede ser suelta o formar parte de
varios programas. Nada se publica en el catálogo oficial por ese motivo.
Los creadores se comparten con ADMIN mediante adaptadores; no se mantienen dos
implementaciones del mismo creador.

El portal necesita agenda conjunta y planificación por alumno, consulta de
resultados y evolución. El alumno utiliza la app existente y recibe el contenido
que le han pautado, sin una segunda compra obligatoria ni aumento de sus cuotas
personales. ADMIN gestiona cuentas, acceso profesional y cupos sin adquirir por
ello lectura general de bibliotecas y resultados privados. Identidad, permiso
ADMIN, Pro, acceso profesional, servicio con el alumno y pago siguen separados.

TRN-016 implementa sesiones privadas, pautas y resultados. TRN-017 amplía a
programas versionados y agenda. **Los ejercicios profesionales propios y sus
medios aún no están implementados**; el creador profesional usa ejercicios
públicos. Los documentos de cada recorrido acreditan código y verificación.

## Dos circuitos comerciales

1. El preparador contrata EntrenaOP con un cupo de alumnos activos. Los tramos
   deben ser configurables; 5, 7 o 100 son ejemplos de capacidad, no tarifas ni
   planes de venta aprobados. El servidor debe hacer cumplir el cupo y permitir
   concesiones manuales auditadas, separadas de la compra.
2. El alumno paga a su preparador por el servicio. El portal debe ayudar a
   gestionar esos cobros, aparte de lo que el preparador paga a EntrenaOP.

Javier vuelve a incluir expresamente ambos circuitos en el alcance de la
plataforma. No ha elegido proveedor, precios, comisiones, periodicidad ni reglas
de impago/reducción de cupo. No hay cobros profesionales reales implementados.
No sustituirlos por un botón de pago sin conciliación de servidor.

Para desarrollar los cobros se propone catálogo de planes/capacidad, estado
canónico del proveedor, eventos idempotentes, conciliación y auditoría; después
suscripciones del alumno a su preparador, recibos/estado de pago y devoluciones
según el proveedor y contrato elegidos. La interfaz no concede derechos por una
redirección exitosa del navegador. No se suspende ni archiva automáticamente al
alumno por un estado comercial cuya regla todavía no esté acordada.

## Seguimiento que debe aportar valor

El resultado individual ya muestra prescrito frente a realizado, RPE, comentarios
y formatos de carrera/fuerza. La siguiente ampliación de seguimiento propuesta
es cumplimiento en un periodo, sesiones realizadas/pendientes, últimas marcas y
evolución por prueba o ejercicio. Las métricas deben explicar su periodo, origen
y tratamiento de sesiones omitidas/retiradas. No contar una sesión futura como
incumplimiento ni convertir rondas AMRAP en series inventadas.

Para la jornada profesional se proponen accesos a alumnos sin pauta próxima y
resultados recientes por revisar. Aún no existe marca persistente de revisión,
alertas, mensajería, formularios ni gráficos comparativos profesionales. Añadir
un indicador requiere datos completos o señalar expresamente su paginación.

La planificación debe permitir adaptar una receta para una persona conservando
la biblioteca reutilizable, revisar fechas y avisar de coincidencias con el plan
automático sin sustituirlo. TRN-017 permite fechas explícitas, fases y repetición
finita de una pauta; no implementa arrastrar citas, recurrencia indefinida ni
adaptación automática del algoritmo profesional.

## Recursos, continuidad e integraciones

Los cupos de alumnos no sustituyen los límites técnicos de contenido y medios.
Antes de habilitar ejercicios propios con imágenes o vídeo se necesitan propiedad
profesional, acceso del alumno por recurso asignado, revisión versionada y cuotas
de almacenamiento/subida verificadas en servidor. No se acuerdan creaciones ni
medios infinitos, ni se reutiliza por accidente la cuota personal Free.

La baja conserva la cartera e historial del servicio y libera la plaza conforme
a TRN-015/016. Retornar requiere nueva aceptación. El archivo es recuperable;
una futura purga no se confunde con desactivar una cuenta o cancelar un pago.

Javier lleva la conexión de relojes en otro chat. Este trabajo no implementa
integraciones de Garmin u otros fabricantes ni presupone sus condiciones de
API. Los futuros datos deberán conservar origen, unidades y referencias de
actividad para evitar duplicar entrenamientos o alterar resultados históricos.

## Criterio de entrega

Se valida el recorrido completo: crear contenido privado → asignarlo a otro
usuario → verlo y realizarlo en la app → consultar resultados autorizados →
revisar contenido → comprobar que el historial anterior no cambia. Añadir
aislamiento entre profesionales, MFA, reintentos, concurrencia, baja/vuelta,
cuotas, móvil estrecho y recuperación de errores. La publicación web Dev, la
distribución de la app móvil y el lanzamiento comercial son hitos distintos.
