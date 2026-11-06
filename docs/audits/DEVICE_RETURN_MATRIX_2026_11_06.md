# Recepción y cierre de actividades · revisión del 06/11/2026

## Petición y alcance

Javier pide ampliar la revisión tras una carrera Garmin recibida y vinculada
que no había completado su cita. También indica que cree haber registrado un
RPE de 4 y las zapatillas; el valor concreto y la pantalla de registro no quedan
confirmados. Esa memoria no se convierte en un resultado guardado.

Se revisan los conectores implementados y sus fronteras: cuenta/envío/recepción
Garmin, carrera y fuerza FIT, retorno Apple Watch por WorkoutKit/HealthKit y
lectura privada de carreras de Salud. Se contrastan los contratos compartidos
de historial, consulta profesional, permisos y cierre. Health Connect está en
el ensayo Android, deshabilitado en la app principal; las otras marcas están
en estudio. No se acredita su funcionamiento por probar Garmin o Apple.

El trabajo conserva los cambios locales previos de dominadas, sus versiones y
documentación. Solo cambia servidor, SQL de Dev y pruebas/documentación propias;
no requiere una compilación Flutter nueva ni modifica producción.

## Hallazgos corregidos

| Caso reproducido | Comportamiento anterior | Corrección |
| --- | --- | --- |
| Bucle con última recuperación omitida | La receta coincidía, pero los índices previstos desde el envío no coincidían con el cuerpo y el trabajo final separados en FIT. | Se conserva la secuencia expandida de índices físicos del propio FIT, junto a su referencia deportiva exacta. |
| Mismo número de vueltas por tiempo e índices contradictorios | La candidatura por estructura podía ignorar esos índices. | Un índice explícito incompatible mantiene revisión. No basta con que coincida la cantidad. |
| Series de fuerza con índices nativos repetidos | Se buscaba un índice expandido único por serie. | Cada SET activo se corresponde en orden con su serie, con secuencia completa e identidad de ejercicio verificadas. |
| RPE informado en FIT | El lector lo descartaba y el cierre automático utilizaba NULL. | Se normaliza y conserva la declaración; el cierre y la propuesta manual la utilizan cuando es compatible con el historial. |
| Contexto de cierre incompleto | Podía terminar el trabajador sin registrar un motivo de revisión. | Se solicita explícitamente `review_required`; los fallos de conciliación/checkpoint generan diagnósticos sin datos personales ni secretos. |

La referencia y sus índices se calculan a partir de los mismos mensajes FIT,
sin cambiar receta ni mediciones. Las observaciones antiguas sin esa secuencia
conservan la proyección de compatibilidad del envío. No se reconstruyen FIT
consumidos ni se enriquecen retrospectivamente con valores recordados.

## Matriz de carrera y fuerza

La matriz de carrera materializa el workout del exportador en FIT mediante el
SDK oficial: doce recetas, forma expandida/compacta y una vuelta/Auto Lap por
paso. Son 48 combinaciones, más la regresión de índices contradictorios.

Incluye series por distancia y tiempo, descansos pasivos, andando y trotando,
recuperación por distancia, recuperación final presente/omitida, repeticiones
sin descanso, dos elementos iguales, tandas diferentes, patrón compuesto,
calentamiento/enfriamiento manuales, rodajes y transiciones explícitas.
Comprueba cierre, mapa completo y conservación de la evidencia. Una combinación
ambigua de índices repetidos consecutivos y Auto Lap se mantiene en revisión.

La matriz de fuerza cubre banca, flexiones y dominadas, por tiempo/repeticiones,
con/sin descanso y forma expandida/compacta: 24 combinaciones y la negativa por
repeticiones, carga o identidad ausentes. Las cargas y repeticiones reales
difieren deliberadamente de las pautadas. Los ejercicios privados sin
equivalencia siguen necesitando correspondencia explícita; no se inventa una.

Las pruebas previas completan CRC, archivo corrupto, otros deportes, SSRF y
redirecciones, duplicados, identidad cambiada, permisos retirados, renovación
incierta, versión retirada, recetas ambiguas, vueltas ausentes/sobrantes,
grabaciones sin desplazamiento y ventana civil de siete días.

## RPE y zapatillas

El perfil del SDK FIT fijado en `21.218.0` define `session.workoutRpe` en décimas
de CR10; su escala de decodificación es 1. El adaptador convierte 40 en 4, no
en 40. Se conserva `perceivedExertion` de 0 a 10 en la observación. Un metadato
accesorio inválido se omite sin invalidar por ello una actividad utilizable.
Fuente: [perfil del SDK oficial Garmin](https://github.com/garmin/fit-javascript-sdk/blob/main/src/profile.js).

El historial vigente utiliza enteros 1–10. Solo una declaración exactamente
compatible pasa a `final_rpe`; un decimal se conserva en evidencia sin
redondearlo y cero no se convierte en una valoración válida del historial.
La propuesta manual aprovecha el campo ya entendido por Flutter. Una revisión
posterior solo añade RPE a una ejecución de dispositivo completada con valor
vacío y la misma evidencia deportiva. Nunca sobrescribe una valoración
existente ni usa un `rpe` inventado por el transporte.

Apple ya utilizaba esta política de entero exacto y esfuerzo tardío; no se cambia
su contrato. Sus pruebas comprueban además distancia ausente, intervalos
parciales, conflictos, pruebas y enriquecimiento posterior sin duplicar.

Las observaciones antiguas de la carrera reparada carecen de RPE; el FIT original
no se conserva. Esto no acredita que Javier no lo registrara en Garmin. No se
recupera el supuesto 4 ni se consume otra vez un callback antiguo. El contrato
Activity API 2.0 disponible para esta integración no acredita la entrega de
zapatillas/material; tampoco hay un campo de ese tipo en el DTO recibido.
Su lectura desde Garmin Connect no está implementada y no se promete.

## Revisión real y límites

La carrera reparada conserva su única ejecución/confirmación. La otra recepción
medida de la cuenta de Javier comprobada en esta tarea no aporta índices de
vuelta suficientes y sigue requiriendo revisión. La grabación sin desplazamiento
no se convierte en entrenamiento realizado. No se completan otras citas reales.

La consulta de evidencia se limita a esa cuenta. La revisión automática rechazó
una consulta de observaciones de otras cuentas; no se ejecutó. Las variantes
restantes se verifican con fixtures sintéticas y contratos con ROLLBACK.

La revisión legítima sigue existiendo: receta ausente/ambigua, versiones
retiradas, intervalos sin identidad, ejercicios sin equivalencia, pruebas,
actividad incompatible o ejecución fuera de ventana no autorizan forzar un
cierre. La aceptación física de nuevos retornos y el RPE emitido por el reloj
siguen necesitando una recepción nueva después del despliegue. La matriz no
acredita todos los relojes, firmwares o formatos FIT externos posibles.

## Validación y publicación

Resultados locales y Dev: 354 pruebas de servidor, incluidas 80 nuevas; tipos
TypeScript estrictos; análisis Flutter limpio; 1.880 pruebas raíz con una omisión
previa; 16 pruebas del puente `device_health`; 56 del dominio `device_activity_core`;
16 contratos SQL transaccionales de Garmin, Apple, Salud, ventana, bandeja y consulta
profesional. La concurrencia usa PostgreSQL local sintético para comprobar
callbacks, identidad, retirada, envío manual/automático y descarga/confirmación
simultáneas sin duplicación.

La migración `20261106112035_garmin_observed_effort.sql` se ensaya primero con
ROLLBACK y después se aplica exclusivamente en Dev. Los 310 identificadores
de migración coinciden. Los asesores conservan los mismos 151 avisos de seguridad
previos, sin hallazgos nuevos. Los auxiliares de RPE son privados, con privilegios
revocados para los roles de cliente y `service_role`; no añaden permisos.

Publicadas y activas en Dev `garmin-activity-ingest` v23 y `garmin-activities` v24.
Los 23 archivos descargados coinciden con la fuente validada; se conserva la
autenticación HTTP y ambas funciones rechazan con 401 una petición sin autorización.
El siguiente paso recomendado es una recepción física nueva, con
series y RPE marcado, para contrastar el resultado visible en el iPhone y su
lectura por el preparador. No abre otro conector ni exige reinstalar para esta
corrección del servidor.
