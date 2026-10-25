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

Estado: implementado y validado localmente. Publicación Dev pendiente de verificar.

- [x] Marco y distribución comunes; catálogos y gestión en ambos portales.
- [x] Ficha profesional y accesos visibles a conversación, técnica e informes.
- [x] Creadores compartidos de fuerza/carrera y programas con sus arrastres.
- [x] Agenda y biblioteca contextual con asignación y movimiento revisados.
- [x] Revisión del resto de pantallas y diálogos, ventana estrecha y texto ampliado.
- [ ] Análisis, regresiones, baterías de consumidores, compilación y publicación Dev.

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
  previas; 205 de Trainer; 217 del editor compartido y 26 de interfaz común.
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
