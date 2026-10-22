# Trainer y app del alumno: revisión · 22/10/2026

## Alcance de esta revisión

Javier confirma continuar sin agentes ni coordinación con otros chats. Aporta
un vídeo de la app: Inicio muestra el aviso y las tarjetas de sesiones,
formularios, conversación y técnica; al abrir el seguimiento se repiten esos
accesos y se añade la lista de avisos. Solicita una distribución más clara y
plantea mover Perfil arriba, un acceso inferior al preparador o integrarlo en
Mi plan, además de una ubicación para pagar el servicio.

Se revisan el vídeo, el mapa original de dieciséis puntos y el código relacionado
con Inicio, navegación y seguimiento. No se ejecutan hoy contratos SQL remotos ni
una nueva aceptación deportiva de todos los recorridos. Se distingue la evidencia
de las entregas guardadas de las propuestas nuevas. No se modifica la app en esta
revisión: las alternativas de navegación necesitan decisión de producto.

## Estado de los dieciséis puntos

| Punto | Base disponible | Qué queda para cerrarlo |
| --- | --- | --- |
| 1. Inicio profesional | Resumen operativo publicado en Trainer Dev | Pulido y aceptación del trabajo diario; la lista de avisos no sustituye push. |
| 2. Ficha del alumno | Cartera, etapas, notas privadas y accesos a seguimiento | Pulido de presentación y aceptación con alumno real. |
| 3. Calendario editable | Consultar, mover y pautar con previsualización y protección de concurrencia | Pulido del recorrido de fechas y comprobación física completa; no se acredita arrastrar citas. |
| 4. Adaptación individual | Modificación manual de la receta individual sin cambiar biblioteca | Terminar recuperación de ese contexto; no hay motor profesional automático. |
| 5. Creador ágil | Creadores compartidos, creación contextual y recuperación de programas y sesiones de biblioteca | Recuperación de sesiones hijas de programa y del contexto de adaptación. La afirmación anterior de que toda recuperación de sesiones faltaba queda superada por TRN-022. |
| 6. Biblioteca eficiente | Búsqueda, duplicación, favoritos y recientes | Etiquetas no acreditadas; pulido y aceptación de bibliotecas con volumen. |
| 7. Grupos y envío conjunto | Grupos, destinatarios, envío y copia semanal | Aceptación completa con varios alumnos y comprobación del resumen por destinatario. |
| 8. Evolución | Métricas del servicio, periodo y consulta longitudinal | Pulido de lectura, filtros y aceptación; no completar ausencias con ceros. |
| 9. Bandeja de revisión | Resultados y revisión persistente ligada a versión | Pulido y aceptación del circuito completo de respuesta y corrección. |
| 10. Vídeos en ambas direcciones | Subida propia, enlaces, selección de demostraciones, técnica y correcciones; vídeo real propio reproducido y clip del alumno visible | Pulido de estados/reservas incompletas y aceptación móvil del recorrido completo; TRN-023 facilita encontrar los clips. |
| 11. Formularios | Plantillas, asignación y respuestas | Mejor descubrimiento en el deportista y aceptación completa. |
| 12. Comunicación | Conversación y avisos dentro de la app | Descubrimiento, estado de lectura comprensible y notificaciones push reales. |
| 13. Automatizaciones controladas | Recurrencias finitas de hasta doce semanas | Automatizaciones profesionales adicionales y motor adaptativo pendientes; no inventar envíos automáticos ya operativos. |
| 14. Cobros y servicio | Acceso/cupo manual y núcleo comercial de ensayo | Ambos cobros reales, proveedor, precios, condiciones, conciliación, incidencias y derechos comerciales. No hay pasarela real. |
| 15. Informes | Informe por periodo y CSV | Pulido de lectura/exportación y aceptación; formatos adicionales serían ampliaciones, no hechos de esta entrega. |
| 16. Preparación específica y relojes | Pruebas/marcas privadas e historial personal de Salud de entregas anteriores | Contexto/puntuación oficial completo, motor profesional y asociación autorizada de actividades externas a resultados. Conectores y su aceptación no se desarrollan en esta revisión. |

No se presenta una cifra de «puntos terminados»: varios tienen implementación y
evidencia técnica pero aún conservan ampliaciones o aceptación física pendientes.
La entrega visual actual de Trainer es TRN-023, publicada en Dev con revisión
`8513ecd31b7b9d5eb15ed2dd769970b5b6a8c85b`, release terminada en `-16`.

## Propuesta principal, pendiente de elegir

- Perfil pasa al avatar superior para todos los usuarios.
- Barra inferior: Inicio, Mi plan, Biblioteca, Evolución y Preparador para quien
  tenga seguimiento profesional relevante. Sin preparador, se conservan los
  cuatro destinos generales, sin un anuncio comercial ocupando esa quinta plaza.
- Al terminar el vínculo se mantiene acceso al historial del servicio; no se
  hace desaparecer por defecto. La condición exacta de presencia de la pestaña
  debe usar el estado autorizado y resolver carga, cambio de cuenta y contenido
  histórico, sin destellos ni inferir acceso de una preferencia local.
- Inicio conserva el día, el entrenamiento y un resumen compacto de novedades;
  elimina la repetición completa de módulos profesionales. Cero novedades no
  crea una tarjeta vacía. Los avisos también se consultan desde la campana y el
  espacio profesional. Este diseño no implementa push.
- Preparador agrupa resumen, conversación y avisos, con entrenamiento,
  seguimiento (formularios, pruebas, técnica) y servicio/pagos. Los módulos sin
  contenido no se expanden en listados vacíos. Una vinculación nueva debe tener
  un estado inicial claro y permitir contactar según sus permisos.
- Mi plan conserva la agenda común y distingue el origen de cada pauta. No
  sustituye el plan automático por el del preparador ni oculta coincidencias.

Alternativa conservadora: mantener la barra actual y añadir «Mi preparador»
dentro de Mi plan, conservando Inicio compacto. Reduce el cambio global, pero
agrupa conversación, formularios y pagos bajo una sección de planificación.
Las dos alternativas se representan en una propuesta interactiva; ninguna está
implantada ni elegida todavía.

## Servicio y pagos

La ubicación propuesta es Preparador → Servicio y pagos, separada de Perfil →
suscripción personal EntrenaOP. Allí encajarían el servicio contratado, precio,
periodicidad, próximo vencimiento e historial/recibos cuando existan datos reales.
La pasarela no necesita convertirse en otra pestaña inferior.

Un pago externo acordado con el preparador (por ejemplo Bizum o transferencia)
puede ser una modalidad futura: su registro manual no se presentaría como cobro
verificado por un proveedor. No se introduce ahora ese registro ni se desactiva
el entrenamiento automáticamente. La pasarela integrada mantiene las decisiones
de TRAINER_PAYMENTS.md pendientes; esta propuesta de ubicación no elige proveedor
ni compromete condiciones de cobro o compatibilidad con las tiendas móviles.

## Verificación y siguiente paso

El vídeo se inspecciona mediante fotogramas locales, sin incorporarlos a Git ni
publicarlos. Se comprueba la propuesta interactiva de Inicio → Preparador →
Servicio y pagos y su alternativa en Mi plan. Los datos del ejemplo son
demostrativos, no una nueva asignación real ni una oferta comercial.

El siguiente cambio recomendado es concretar esta navegación y sustituir el
bloque extenso de Inicio por el resumen compacto, preservando rutas, avisos,
contenidos, historial y aislamiento por usuario. Esta revisión solo cambia
documentación; no requiere ejecutar Flutter ni publicar Trainer otra vez.
