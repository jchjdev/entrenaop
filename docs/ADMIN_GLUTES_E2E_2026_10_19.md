# Programa de glúteos: recorrido real de autoría y publicación

Comprobación del 19/10/2026, solicitada por Javier. Entorno: EntrenaOP Dev.
La creación se ha realizado en Chrome, desde `https://admin.entrenaop.es`,
usando sus formularios, revisiones y confirmaciones. No se han insertado datos
por SQL ni publicado contenido en producción.

## Resultado

Programa **Dev · Glúteos · 4 sesiones**, rutina, versión 1, publicado.
Identidad: `8335135f-15de-4d57-a938-7d949cd1b633`.
Categorías: Hipertrofia (principal) y Fuerza. Secuencia repetible sin calendario
semanal obligatorio. La descripción identifica el contenido como demostración
de desarrollo, no como programación individual.

Se han creado cuatro sesiones nuevas desde **Crear nueva sesión** dentro del
programa. Cada una se ha guardado, revisado y publicado expresamente en la
biblioteca general; al terminar vuelve al programa y queda vinculada por su ID.
Se reutilizan ejercicios existentes del catálogo. Cada sesión contiene un bloque
convencional con dos ejercicios, tres series por ejercicio y descanso de 1:00.
No se fija carga ni RIR. Las sugerencias opcionales de duración/descripción no
bloquean la publicación.

| Sesión | ID | Contenido revisado |
| --- | --- | --- |
| A · Empuje de cadera | `840122a1-5ad7-4c13-9d97-e41f5973f25e` | Hip thrust con barra 3×10; step-up 3×10 |
| B · Sentadilla | `bcdef2cd-f2dd-4f84-b83e-388fa07c59cd` | Sentadilla trasera con barra 3×10; zancada alterna 3×10 |
| C · Bisagra | `cc709a87-726a-40d8-8277-7ba85db9f6c4` | Peso muerto rumano 3×10; puente de glúteos 3×12 |
| D · Unilateral | `f299a802-9aef-4581-b8b7-b47e8a7bffeb` | Split squat 3×10; step-up 3×10 |

Se verifican las cuatro referencias publicadas en la revisión conjunta y se
publica el programa mediante **Publicar en Biblioteca**. El catálogo ADMIN pasa
a mostrar tres programas publicados, incluido este con cuatro sesiones. No se
inicia ningún seguimiento ni se modifica ninguna agenda.

**Javier confirma en este chat que ha entrado desde el iPhone y el programa se
ve en la app.** Esta es la evidencia de visibilidad en el deportista; no se
atribuye al agente una comprobación independiente de ejecución o registro de
resultados en ese dispositivo.

Captura real del catálogo tras publicar:
[admin-publicado.png](visual-audit/admin-glutes-e2e-2026-10-19/admin-publicado.png).

## Incidencia detectada y corregida

Al volver de **Editar borrador → Guardar y revisar** con el mismo ID, el router
puede conservar el estado de la revisión anterior. Los datos estaban guardados,
pero la pantalla solo mostraba su lectura actual al pulsar **Actualizar revisión**.
La prueba real se completa usando ese botón antes de confirmar publicación.

La revisión renueva su lectura y sus detalles de sesiones cuando el router
actualiza la página activa, también si conserva el ID. Se invalidan los detalles
y errores de lectura anteriores. No cambia el guardado, el editor, los permisos,
las comprobaciones deportivas ni la confirmación de publicación.

La prueba de regresión recorre el router real: abre un borrador desde su
revisión, edita sus indicaciones, guarda sobre el mismo ID y exige ver el texto
nuevo sin actualizar manualmente y sin publicar. Falla antes de la corrección y
pasa después.

Verificación: `flutter analyze` de ADMIN sin incidencias; batería ADMIN completa
**221 pruebas correctas, 2 omitidas** (capturas opcionales). Sin cambios en
paquetes compartidos, base de datos ni app del deportista en este bloque.

## Convivencia con Compacto

La prueba real del navegador empieza sobre el admin publicado de UI-058,
revisión `7cca2bc699c548a1ea044890352e3ba9dfe24d34`.
Los cambios concurrentes de formularios se preservan; el otro chat los guarda en
`6e32099` sobre `main`. La corrección de esta tarea modifica exclusivamente la
pantalla de revisión y su prueba, y se verifica con esa integración ya presente.
La prueba de contenido no constituye aceptación visual de Compacto en iPhone.

El circuito profesional de entrenadores continúa en otro chat por indicación de
Javier. No se implementan aquí perfiles, clientes, asignaciones ni permisos
profesionales.
