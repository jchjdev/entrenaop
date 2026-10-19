# Vista previa y revisión editorial ADMIN · UI-058 · 19/10/2026

## Acuerdo y alcance

Javier pide revisar sesiones y programas antes de publicarlos y subir la mejora
validada al subdominio de desarrollo. Añade el favicon del admin. Se mantiene el
catálogo común: una sesión general puede usarse suelta o en varios programas;
publicarla y publicar el programa son operaciones distintas.

La implementación modifica solo ADMIN y sus recursos web. No cambia esquema,
RPC, RLS, autenticación, datos deportivos, dependencias ni la app del deportista.
La publicación del código usa WEB-006; publicar contenido sigue siendo una acción
expresa del propietario, sin hacerlo como parte de esta comprobación.

## Recorrido

- Sesiones conserva su ruta estable y la revisión anterior, ahora con lector de
  bloques reutilizado desde la vista del programa, resumen y panel editorial.
- Un programa guardado ofrece **Revisar y publicar** si es borrador y **Vista
  previa** si está publicado o retirado. Abrirlo no cambia su estado.
- El editor ofrece **Guardar y revisar**: usa exactamente el guardado existente,
  incluida su finalización idempotente y reintento, y abre el ID devuelto por el
  servidor. No publica ni crea una segunda versión para mostrar la revisión.
- `/guided-programs/:guidedId/review` se puede recargar. El router vuelve a
  verificar acceso administrativo y la pantalla lee el programa y sus catálogos.
- La vista muestra composición de tarjeta compartida, portada disponible,
  clasificación, descripción, público, material, fases, duración, condiciones de
  avance y orden de sesiones. La ficha es una vista de contenido; no un ejecutor.
- Al desplegar una sesión se leen sus bloques, series o tramos, objetivos,
  descansos, RIR y calentamiento adjunto opcional. Las lecturas se conservan por
  identidad durante esa revisión: reutilizar una sesión no vuelve a descargarla.
  Los detalles se leen al desplegarlos, evitando cargar todas las plantillas de
  un programa grande al entrar. Actualizar invalida esta memoria.
- La publicación exige confirmación final que identifica nombre, versión,
  destino y efecto. El programa aparece en Biblioteca y cada deportista debe
  iniciarlo; la sesión respeta su destino general o preparación. No crea citas,
  seguimientos ni cambia agendas existentes.

## Comprobaciones y errores

Programa: reutiliza `validateGuidedProgram` y comprueba las referencias actuales
contra sesiones generales y calentamientos publicados. Bloquea referencias
retiradas o ausentes, calentamiento duplicado y ajuste genérico de descanso en
un formato que no lo admite. La carga fallida de catálogos no equivale a revisión
correcta. Si falla un detalle que se haya desplegado, lo señala y bloquea
publicar hasta reintentar o actualizar. No exige abrir todas las sesiones como
un trámite adicional.

Sesión: bloquea contenido estructuralmente vacío. Después de confirmar vuelve a
leer la plantilla y compara su contenido con el revisado. Si cambió o desapareció,
no solicita publicación y muestra la lectura actual o permite recuperarla.
Se corrige además el reintento anterior, cuyo callback de `setState` devolvía
una Future e impedía recuperar la pantalla en modo debug.

Los campos editoriales opcionales incompletos generan sugerencias, no nuevos
requisitos. No se inventan reglas de dosis ni se acredita revisión deportiva
automática. La operación final continúa usando los RPC que validan permisos e
integridad en servidor.

Después de confirmar un programa se releen contenido, categorías, portada y
referencias. Cambios observados en contenido/versión/clasificación/portada o una
referencia que ya no esté publicada obligan a revisar otra vez. Este contraste
cliente no es un bloqueo transaccional entre lectura y escritura: el RPC actual
no recibe la firma editorial esperada. No se promete eliminar esa ventana de
concurrencia. Los controles de integridad y autorización del servidor se conservan.

Publicación en curso bloquea acciones simultáneas y salida por router. Error de
red o servidor conserva el borrador y la revisión con reintento; abrir, cancelar
y consultar publicaciones no provocan escrituras.

## Iconos

Se reutilizan `web/favicon.png` y los cuatro PNG de `web/icons/` de EntrenaOP en
ADMIN, sustituyendo los recursos de Flutter. No se redibuja la marca. El índice
y el manifiesto existentes ya los referencian; WEB-006 los publica con un prefijo
de versión que evita reutilizar el favicon de una publicación anterior.

## Verificación y estado

- Análisis ADMIN sin incidencias y 193 pruebas correctas; las dos capturas
  optativas anteriores permanecen omitidas en la batería ordinaria.
- Regresiones nuevas de guardado/revisión, publicación explícita/cancelación,
  calentamiento y descansos, contenido fallido y reintento, cambios desde otra
  pestaña, referencia retirada al confirmar, permisos, bloqueo de salida,
  estructura vacía y recuperación de la lectura de sesión.
- Capturas de widgets reales con datos sintéticos: escritorio, sesión desplegada,
  móvil con texto 2× y confirmación a 320 px. Conservadas en
  `docs/visual-audit/admin-publication-review-2026-10-19/` tras revisión visual.
- Compilación web release Dev comprobada. La publicación y el recorrido remoto
  se registrarán cuando termine GitHub Actions; no se presenta esa parte como
  realizada antes de comprobarla.
