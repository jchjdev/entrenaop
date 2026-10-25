# Escritorio profesional · TRN-030 · 25/10/2026

## Acuerdo y alcance

Javier aprueba implementar en Trainer y ADMIN la propuesta de escritorio y sus
recorridos, con arrastrar y soltar y componentes compartidos. Se conserva Flutter,
el creador único y los adaptadores de autoría. Los portales y sus permisos siguen
separados; no existe un selector que conceda acceso de uno al otro. El selector
del prototipo solo servía para explorar ambos diseños.

Firebase, recepción push y cobros reales continúan pospuestos. Los datos,
ventanas y estados ficticios del prototipo no son contratos nuevos ni funciones
que puedan darse por implementadas en el producto.

El trabajo se realiza sin agentes ni coordinación con otros chats, sobre main,
preservando cambios existentes. La publicación se limita a Dev y requiere
validación y comprobación de la versión servida.

## Composición y comportamiento

- Marco de escritorio, navegación y distribución reutilizables en `entrena_ui`.
  Cada consumidor aporta destinos y comprobaciones. La navegación por teclado,
  semántica y tamaño de ventana también forman parte del recorrido.
- Las pantallas de gestión ocupan el área disponible mediante listas, rejillas
  y paneles complementarios. Acceso, TOTP y formularios cortos conservan una
  anchura cómoda; no se estiran sus campos por el mero tamaño del monitor.
- La ficha del alumno reúne planificación, resultados, técnica, evolución,
  formularios, conversación, notas privadas e historial mediante URLs
  recuperables. Una pestaña no omite los guards de trabajo sin guardar.
- El creador común mantiene catálogo, composición y propiedades accesibles en
  escritorio sin duplicar modelos ni controladores. Carrera conserva sus bloques
  y recuperaciones; fuerza conserva identidad, variantes y series.
- Los arrastres del editor modifican el borrador; los de calendario preparan una
  intención que reutiliza previsualización y confirmación existentes. Ningún
  arrastre aplica una asignación sin revisión ni confirma por su cuenta un cambio
  de fecha, destinatario o receta.
- Las fases y posiciones de programa conservan sus UUID, referencias y trabajos
  hijos. No se pierden checkpoints o enlaces pendientes al reordenar.
- Las pautas compartidas del otro preparador son de solo lectura. Ver el
  calendario de un alumno no permite acceder a otras carteras ni editar su autoría.
- Se conserva una alternativa mediante botones/teclado para los gestos de
  arrastre. Una operación ocupada, incierta o desautorizada impide otro envío.

## Implementación y evidencia

Estado: implementado, validado y publicado en ambos portales Dev;
acabado compartido `e57c55ac` y limpieza adicional de Trainer `007d7f3b`.
Aceptación humana del recorrido pendiente; evidencia de la primera entrega abajo.

- [x] Marco y distribución comunes; catálogos y gestión en ambos portales.
- [x] Ficha profesional y accesos visibles a conversación, técnica e informes.
- [x] Creadores compartidos de fuerza/carrera y programas con sus arrastres.
- [x] Agenda y biblioteca contextual con asignación y movimiento revisados.
- [x] Revisión del resto de pantallas y diálogos, ventana estrecha y texto ampliado.
- [x] Análisis, regresiones, baterías de consumidores, compilación y publicación Dev.

Los guards, modelos y RPC existentes son la fuente de verdad. Si una integración
necesita ampliar su contrato o servidor se explicará antes y se añadirá su prueba
SQL transaccional. No se ensancha RLS para facilitar una interfaz.

## Verificación prevista

Raíz, ADMIN y Trainer: análisis y baterías completas al cerrar la entrega.
`workout_editor_ui` y los nuevos componentes comunes: pruebas de interacción
relevantes. Se comprueban arrastre con cancelación/confirmación, identidad y
conservación de campos, navegación con trabajo pendiente, solo lectura de pautas
compartidas y composición en escritorio/ventana estrecha. Se verifica publicación
por revisión, entorno, archivos y HTTPS; recepción push, pagos e instalación iOS
no forman parte de esta aceptación.

## Verificación local completada · 25/10/2026

- Análisis sin incidencias en raíz, ADMIN, Trainer, `workout_editor_ui` y
  `entrena_ui`; formato y diff comprobados.
- 1.349 pruebas del deportista, una omisión previa; 315 de ADMIN, dos omisiones
  previas; 205 de Trainer; 217 del editor compartido y 27 de interfaz común.
- Compilaciones web Release de ambos portales con CSP, recursos locales,
  sin mapas de fuentes y configuración exclusiva de Dev.
- Siete pruebas del paquete Trainer y 36 de publicación/operaciones de ADMIN.
  No hay cambios de dependencias, esquema, migraciones ni configuración push.
- Gestos de ratón reales en pruebas: cancelar un arrastre conserva la receta;
  añadir ejercicio conserva dosis anterior y espera guardado; fases y sesiones
  se componen desde el catálogo; soltar en agenda abre elección y revisión;
  cancelar no asigna. Mover fecha pasa por el callback de revisión existente.
- Las pestañas conservan controladores/notas y el guard impide abandonarlos
  sin decidir. El scroll de biblioteca y el del editor son independientes.
  Cambiar a ventana estrecha conserva el editor embebido montado.
- Capturas de widgets reales con datos de ensayo, revisadas a 1.920×1.100:
  `trainer_app/build/performance_v2_review/trainer-desktop-{library,program,agenda}.png`.
  Son evidencia local de presentación; no se publican clientes ficticios.

## Límites de esta entrega

Las búsquedas y filtros identifican el catálogo o alumnos ya cargados y conservan
la paginación. La semana tiene desplazamiento horizontal cuando siete columnas
legibles no caben. En ventana estrecha y con texto ampliado continúan los botones
alternativos y el flujo vertical. Los metadatos del programa se despliegan a
petición en escritorio. Las sesiones con enlaces pendientes no se trasladan entre
fases; se resuelve primero su guardado, conservando los trabajos hijos.

Conversaciones e informes son accesos a los alumnos autorizados y al historial
del servicio, no una bandeja nueva con contadores de mensajes inventados. Las
fichas y conversaciones se identifican por cuenta y recurso para no reutilizar
el estado de otro alumno. La evolución se carga al entrar en su área, sin
consultarla también al abrir solo notas o etapas.

Los permisos y la autoría son los existentes. El calendario compartido sigue
siendo de lectura respecto a otro preparador. No se crean cobros, avisos push,
notificaciones simuladas ni cambios de cuotas a través de la interfaz. La
aceptación humana del recorrido publicado queda para Javier.

### Revisión de accesibilidad tras publicar el primer paquete

La comprobación real con la sesión Dev detectó que el `Navigator` ocultaba en
semántica las pestañas pintadas antes, aunque funcionaban visualmente. El marco
común y la navegación de alumno pintan ahora primero la ruta y después su
cabecera, con el mismo orden visual. Se añaden regresiones de recorrido semántico
para las ocho áreas y las acciones del marco. La revisión `527f2c5d` publicada
en Trainer acredita también esta corrección; la primera fue `a2162024`.

## Primera publicación y recorrido comprobado · 25/10/2026

Trainer Dev sirve la revisión `527f2c5d067d3f444d2cf0497eb55214e21ad74c`,
publicación `527f2c5d067d3f444d2cf0497eb55214e21ad74c-20261025-1`.
El publicador contrasta manifiesto, entrada, SHA-256 del JavaScript, cabeceras
de acceso y MIME de WebAssembly por HTTPS. ZIP:
`450aa3ebc91e78498fc5f786376ff75c817edb41e89c4845467f0d3db7563394`.
Los recursos se copiaron completos antes de activar entrada y manifiesto;
se conservan las publicaciones anteriores.

Con la sesión profesional Dev existente se comprobó el catálogo de sesiones,
la revisión de una receta y la ficha real del alumno: ocho áreas accesibles,
planificación en rejilla, resultados filtrados, conversación dentro de la ficha
y evolución cargada en su pestaña. Estas comprobaciones no asignaron sesiones,
no guardaron recetas ni enviaron mensajes. También se arrastró una sesión de
la biblioteca a un día de la semana en Chrome: abrió la elección de alumno,
con revisión deshabilitada hasta elegirlo; cancelar volvió a la agenda sin
asignar. Las demás variantes se ensayaron en las pruebas de widgets; queda la
aceptación humana del trabajo real publicado.

ADMIN Dev sirve la misma revisión de fuentes, publicación
`527f2c5d067d3f444d2cf0497eb55214e21ad74c-40186938110-1`. El run
`40186938110` terminó correctamente: validación, publicación y retención de
paquetes. Se repitió la verificación HTTPS del manifiesto, entrada, cabeceras,
WebAssembly y JavaScript; SHA-256:
`2a7a6a8988a7bbcaa637051aef218880662d4761cc67324d3cce25c583d6efe3`.
El primer intento `40185961549` había restaurado la publicación anterior al
fallar su comprobación; no se tomó ese intento por entrega. El paquete local
de contingencia no se activó: la publicación final de ADMIN procede de CI.
Con la sesión administrativa existente se comprobó la carga de Pendientes y
la navegación al catálogo de programas guiados, con rejilla, cabecera y
barra lateral accesibles. No se editó ni publicó contenido durante la revisión.

Los cambios ajenos de `.gitignore` y `devtools_options.yaml` se conservan sin
incluirlos en esta entrega. Sin modificaciones de datos, permisos, cuotas,
dependencias ni migraciones.

Siguiente recorrido único: aceptación con Javier de crear/reordenar una receta,
componer un programa, revisar una asignación desde agenda y consultar resultado,
técnica y notas en los portales publicados. Push y cobros continúan fuera de este
bloque; no se acredita recepción física ni instalación iOS.

## Ajuste visual solicitado tras probar la publicación

Javier señala que la primera entrega reproduce la estructura pero todavía no
el acabado de la preview. Se aproxima la apariencia profesional mediante un
tema de escritorio compartido: superficies planas sin el adorno de las tarjetas
táctiles, radios menores, títulos y acciones ligeros, navegación por grupos y
pestañas subrayadas. Biblioteca y detalle reservan menos ancho; la semana
ajusta el mínimo de columna al texto para mostrar más días sin recortar datos.
El tema solo se aplica desde el marco profesional y sus editores. El cambio a
ventana estrecha conserva el editor y recupera las medidas táctiles. No cambian
permisos, rutas, guardados, operaciones de agenda ni estados del servicio.

Estado de esta revisión: publicada y verificada en ambos portales Dev.
Análisis limpios de raíz, Trainer, ADMIN e interfaz común. Baterías: 1.349,
205, 315 y 27 pruebas respectivamente (omisiones previas sin cambios). Se
mantienen las regresiones de arrastre, cancelación, semántica y controladores
al redimensionar. Capturas actualizadas de widgets reales con fuente cargada,
sin datos personales ni imágenes del prototipo usadas como interfaz.

La comprobación en Chrome detecta además cabecera y accesos heredados de móvil
duplicados en Alumnos. En escritorio se elimina ese segundo logo y el atajo de
sesiones ya disponible en la navegación; se conserva Actualizar en la cabecera
de página y Cerrar sesión en Mi cuenta. El estado de acceso activo utiliza una
superficie discreta. La ventana estrecha conserva sus accesos anteriores.
Análisis Trainer limpio y 205 pruebas correctas tras este ajuste localizado.

### Publicación comprobada del ajuste visual · 25/10/2026

ADMIN: fuentes `e57c55ac3d131f984600d2afb66bed0a45b81463`, publicación
`e57c55ac3d131f984600d2afb66bed0a45b81463-40188943836-1`. El run
`40188943836` completa validación, despliegue y retención con éxito. HTTPS
contrasta manifiesto, entrada, cabeceras, WebAssembly y SHA-256 de JavaScript:
`7e9b4b01f36449aabb5ef76ab6da95c3ff1af6f4c93003f2207f7aa7623fc49d`.
El catálogo real de programas carga con navegación y acciones accesibles.

Trainer: fuentes `007d7f3ba9684d57440294a1b5d575b18b62809c`, publicación
`007d7f3ba9684d57440294a1b5d575b18b62809c-20261025-1`. Mismas comprobaciones
HTTPS; SHA-256 JavaScript
`7c83cfe248b54d20b564ae8e6fba89cb832a3092e8fdcbf047c081f72ad0038e`.
ZIP `0a7781c6b2cebde884e6fe796458a3985a7151b02a6fe4f88c386f0f7007e41c`.
La limpieza propia de Trainer no cambia los componentes ya publicados en ADMIN;
se sube a main después de terminar el despliegue administrativo.

Chrome acredita las tarjetas y pestañas reales de alumno, el tablero con los
siete días visibles a 1.646 px y la página Alumnos sin logo/atajos duplicados,
con Actualizar e invitaciones disponibles. No se guardan recetas ni pautas ni
se envían mensajes. La revisión visual aproxima la preview; no supone aceptar
por Javier cada detalle estético ni cerrar futuras mejoras de fluidez.
