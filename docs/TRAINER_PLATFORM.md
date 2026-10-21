# Plataforma para preparadores · alcance acordado · 21/10/2026

## Ampliación TRN-020 en curso

El alcance vigente incluye los dieciséis recorridos de
[la coordinación profesional](PROFESSIONAL_DELIVERY_COORDINATION.md). El código
local conecta inicio, ficha, agenda editable, adaptación individual, grupos,
copia semanal, recurrencia finita, evolución/CSV, revisión de resultados,
formularios, conversaciones y medios privados. La app recibe formularios,
conversaciones, técnica y baterías de pruebas; su sección de formularios/pruebas
aparece solo cuando existen entregas propias. Las baterías son un circuito
versionado de marcas, sin crear ejecuciones ficticias ni puntos oficiales.

Los creadores conservan composición única y adaptadores de cada portal. ADMIN
recibe búsqueda y creación contextual, duplicación y herramientas de vídeo;
solo permite subir vídeos, mientras Trainer admite además enlaces HTTPS.
El seguimiento, las conversaciones y el contenido profesional no se vuelven
administrativos por compartir editor.

La implementación y las evidencias de integración están en
[el contrato operativo](TRAINER_OPERATIONAL_WORKFLOW.md) y en los contratos
específicos que enlaza. Las diez migraciones y veinticuatro contratos han pasado
juntos en Dev con ROLLBACK, se han aplicado las migraciones y se han repetido
los 24 contratos sobre el esquema real aplicado. Publicación web y aceptación
móvil se acreditan por separado. El núcleo comercial tiene únicamente un ensayo
tipado con proveedor ficticio: no hay cobros reales. Favoritos/recientes se integran en los mismos creadores; recuperación persistente
de borradores, motor profesional y conexión de relojes
con la app principal requieren sus siguientes entregas y comprobaciones.

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
programas versionados y agenda. TRN-019 incorpora ejercicios profesionales
versionados, imágenes privadas y acceso del alumno, reutilizando el formulario
de ADMIN. Su publicación y validación se acreditan en
[el contrato específico](TRAINER_PRIVATE_EXERCISES.md).

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

La ampliación local añade una bandeja persistente de revisión, conversaciones,
formularios y consulta longitudinal del servicio. El inicio declara sus periodos
y paginación; no afirma detectar a todos los alumnos sin pauta ni enviar alertas
push. Abrir un resultado no lo marca automáticamente como revisado. Véanse los
contratos específicos antes de interpretar una cifra parcial como total.

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
medios infinitos, ni se reutiliza por accidente la cuota personal Free. TRN-019
concreta el piloto confirmado: 500 ejercicios/versiones y 1.000 reservas de imagen
de hasta 500 KB. Son límites técnicos configurables, no planes de pago. Los
archivos de vídeo profesionales se añaden en la ampliación local descrita en
[TRAINER_PRIVATE_VIDEOS.md](TRAINER_PRIVATE_VIDEOS.md), con límites propios;
los enlaces externos HTTPS siguen disponibles sin realojarlos.

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
