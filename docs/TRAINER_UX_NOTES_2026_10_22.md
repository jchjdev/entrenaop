# Notas de uso de Trainer · 22/10/2026 · TRN-026

Javier ha conseguido asignar entrenamientos y considera el recorrido demasiado
complejo. Quiere dejar estas observaciones registradas antes de olvidarlas y
pide expresamente no cambiar código todavía. Ninguna propuesta de esta nota se
presenta como implementada ni autoriza comenzar ahora una migración.

## Asignación más fluida

Javier describirá por escrito el recorrido concreto y cómo quiere perfeccionarlo.
Se registra la fricción observada, sin decidir de antemano nuevos pasos, menús,
selectores o atajos ni sustituir el recorrido existente por una interpretación.

## Reordenar dentro del creador

Poder coger y arrastrar un ejercicio o bloque/serie de carrera para cambiar su
posición, por ejemplo mover el cuarto al primero. La observación se refiere al
orden del entrenamiento durante la creación, no a reordenar el catálogo global.
La ubicación exacta en los creadores se contrastará al concretar el cambio.
Conservar contenido, prescripción y capacidades del editor compartido.

## Revisión de carrera

El creador de carrera necesita una revisión de uso. No se ha definido todavía
el diseño nuevo, ni se cambian formatos, unidades, series o reglas deportivas.

## Dos preparadores activos por alumno

Nuevo criterio de producto confirmado: admitir dos vínculos profesionales
activos simultáneos. Caso de uso: una misma alumna tiene un preparador de fuerza
y otro de carrera. El ejemplo no impone una exclusividad técnica por disciplina
ni decide que se admitan vínculos ilimitados.

Sustituye el criterio anterior de preparador único de TRN-008. Actualmente siguen
vigentes en código y SQL las restricciones de un solo preparador activo: no se
ha modificado el contrato ni habilitado un segundo vínculo mediante esta nota.

Al implementarlo habrá que revisar sus fronteras de forma conjunta dentro de
este trabajo: aceptación/concurrencia, consultas que hoy eligen un vínculo,
identificación del preparador en agenda/conversación/avisos/formularios/técnica,
finalización e historial y servicio/pagos. Cada preparador conserva su cupo y
los permisos sobre su propio servicio; añadir otro no abre automáticamente sus
contenidos privados ni sus resultados a terceros. La planificación conserva
origen y coexistencia, sin sustituirse automáticamente.

## Aclaración: preparación conjunta como equipo

Javier confirma que fuerza y carrera se preparan conjuntamente: necesita ver
las series intensas pautadas por el otro profesional para ajustar su propia
sesión de fuerza. El caso prioritario es un equipo que coordina una misma
preparación, además de admitir dos identidades profesionales.

Se recomienda una agenda conjunta para el alumno y una vista de planificación
compartida para los preparadores autorizados, conservando autor y origen de
cada sesión. Cada uno debe poder consultar lo pautado dentro de ese ámbito;
no implica permiso automático para modificar sesiones del otro ni consultar
notas privadas, catálogos o datos de otros servicios.

Como propuesta posterior, se pueden indicar foco e intensidad prevista de las
sesiones para facilitar la coordinación. No se ha acordado ni implementado un
algoritmo que detecte interferencias o cambie automáticamente entrenamientos.
Quedan por definir membresía, permisos de edición cruzada, conversación conjunta
o individual y servicio/cupos/pagos. No se decide que dos preparadores siempre
pertenezcan al mismo equipo. Sigue vigente en código y SQL el límite anterior.

## Estado y comprobación

Solo documentación. Se revisan diff y formato; no se ejecuta Flutter, SQL ni se
publican aplicaciones. No se emplean agentes ni coordinación entre chats.
