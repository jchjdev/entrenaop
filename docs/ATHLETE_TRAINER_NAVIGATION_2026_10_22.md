# Navegación del alumno y preparador · TRN-025 · 22/10/2026

## Revisión global abierta · 01/11/2026

Javier indica que la incoherencia alcanza más recorridos y botones que los dos
ejemplos de la revisión transversal. El acceso a Perfil en la cabecera no le
gusta y se reabre su ubicación. La elección del 22/10 describe la implementación
actual y el acuerdo anterior; ya no debe interpretarse como aceptación definitiva
de la posición superior de Perfil.

El código actual confirma solapamientos: Perfil incluye preparaciones,
herramientas y Mi preparador; el hub Preparador y la gestión del vínculo ofrecen
accesos a formularios y conversación; Inicio y Mi plan presentan semana y
preparaciones. Mi plan utiliza como primera referencia el programa automático
aunque las pautas profesionales también sean el entrenamiento del usuario.
En las cuentas profesionales, el selector superior añade además el acceso al
trabajo con alumnos propios. El código separa esos espacios, pero hay que revisar
si esa diferencia se entiende en la interfaz.

### Propuesta inicial pendiente de revisión con Javier

Repartir las tareas entre cinco entradas inferiores, con un destino principal
por tarea. Los accesos contextuales pueden llevar a ese mismo destino conservando
fecha, pauta y origen; no deben crear otro resumen independiente.

| Entrada propuesta | Contenido principal |
| --- | --- |
| Inicio | Sesión de hoy y asuntos pendientes. Acceso directo a la pauta concreta. |
| Entrenar | Calendario personal común, historial y progreso; objetivos y configuración del programa en un área propia. El origen distingue pautas del preparador, automáticas y personales. |
| Biblioteca | Descubrir, consultar y crear sesiones y ejercicios; programas guiados. |
| Preparador | Personas con quienes se entrena, conversaciones, formularios, citas y gestión de vínculos. Las pautas abren el calendario personal común. |
| Perfil | Identidad, foto, cuenta, preferencias, conexiones, suscripción y ajustes. |

Esta propuesta devuelve Perfil abajo y retira su acceso repetido de la cabecera.
El coste es que Evolución deja de ser una entrada inferior independiente y pasa
al área de progreso de Entrenar. Esa pérdida de acceso directo debe valorarse
con Javier antes de aceptar la distribución. Los nombres también son provisionales.

El trabajo con alumnos propios mantendría un espacio profesional con agenda,
alumnos y mensajes. Su entrada y retorno deben ser explícitos y conservar el
contexto. «Mi preparador» describe el servicio que recibe la persona;
«Espacio de entrenador» describe su actividad profesional. La posición final
del cambio de espacio sigue abierta, especialmente por la frecuencia de uso.

Revisar después los botones con la misma regla: tocar una sesión permite
consultar su receta; empezar requiere una acción explícita. Este comportamiento
se propone y todavía no está implementado. Cada pantalla debe distinguir su
acción principal de editar, añadir, gestionar o configurar.

El siguiente paso es validar el reparto con los recorridos de un usuario sin
preparador, un alumno con pautas y una cuenta que también trabaja con alumnos.
La implementación transversal comienza después de concretar esa estructura.
Esta revisión documental no modifica Flutter, datos, permisos ni rutas.

## Elección de Javier

Preparador abajo, Perfil arriba e Inicio despejado. La campana se oculta por
completo con cero avisos sin leer, para que no parezca un control de sonido.
Mantener avisos, historial y las planificaciones coexistentes. Sin agentes ni
coordinación con otros chats.

## Implementación

- El shell conserva Inicio, Mi plan, Biblioteca y Evolución. Añade Preparador
  ante vínculos actuales/anteriores o recursos/avisos profesionales propios.
  No muestra una quinta pestaña comercial o vacía a usuarios sin seguimiento.
- Perfil sale de las ramas inferiores y conserva `/profile`, preferencias,
  vínculo y actividades como rutas raíz. El icono superior abre Perfil con
  retorno al origen; una entrada directa puede volver a Inicio.
- Los cuatro destinos y Preparador incorporan el mismo acceso superior a Perfil
  y la campana condicional. La campana abre `/my-trainer?view=notices`.
- Inicio conserva entrenamiento, calendario, preparaciones y contenido general.
  Sustituye las tarjetas profesionales repetidas por una tarjeta compacta con el
  total de novedades del servidor. Sin novedades, tampoco aparece esa tarjeta.
- Preparador separa Resumen y Avisos. Resumen conserva sesiones, formularios,
  conversación, pruebas y técnica cuando existen, y siempre permite consultar
  vínculo e historial, incluso sin recursos. Avisos conserva filtros, paginación,
  destino autorizado y confirmación explícita de lectura.
- Se mantienen las URLs de formularios, conversación, técnica y agenda. Las
  tareas continúan sin barra cuando corresponde. No cambia el ejecutor ni la
  convivencia del plan automático con pautas profesionales.

## Carga e identidad

`StudentNavigationController` comparte el resumen de avisos entre cabecera,
Inicio y pestaña. Consulta vínculos mediante el repositorio existente; solo busca
los terminados si no hay uno activo. No descarga respuestas, vídeos ni todas las
páginas del historial para decidir si mostrar una pestaña.

Agrupa refrescos simultáneos y actualiza al reanudar, refrescar Inicio o volver
de gestionar el vínculo. El hub incorpora sus nuevos totales tras consultar o
marcar avisos. Una respuesta antigua no revierte una lectura posterior. Un fallo
de conexión conserva lo ya conocido en esa sesión; no simula que no quedan
avisos. No hay sondeo continuo ni nueva sincronización en segundo plano.

El estado pertenece a una identidad y se descarta al cambiar de cuenta o salir.
La renovación transitoria de sesión conserva las ramas, sus filtros y scroll;
la prueba existente de Evolución detectó y permitió corregir esa regresión.
La visibilidad de navegación no concede permisos: los destinos siguen validando
sus recursos en servidor.

## Comprobación

- Pruebas focales de shell, rutas, avisos e identidad correctas; incluye volver
  de Resumen a Avisos y seleccionar Preparador desde la campana.
- Seis pruebas de rutas de Evolución correctas tras la corrección de renovación.
- Batería completa final de raíz: **1.270 correctas, una omisión previa**.
- Análisis focal y análisis global final de Flutter limpios, incluido el
  generador de capturas. Los avisos temporales de trabajo ajeno observados durante
  el desarrollo ya no aparecen en el análisis final.
- Cinco escenarios visuales con widgets reales, datos ficticios y sin red:
  Inicio con/sin avisos, 320 px con texto 2×, Preparador e historial sin recursos.
  `tools/athlete_navigation_visual_test.dart` los reproduce. Perfil se comprueba
  accesible en cabecera y la campana ausente a cero.

No cambia ADMIN, creadores compartidos, dependencias, Supabase ni producción.
No implementa push ni pagos. Este cambio es de la app del deportista y no requiere
publicar otra vez `trainer.entrenaop.es`.

## Distribución y siguiente paso

Pruebas y capturas no acreditan instalación en el iPhone. El siguiente paso es
compilar e instalar la revisión nueva y aceptar inicio, campana, pestaña,
conversación e historial con la cuenta vinculada. Los otros pendientes de los
dieciséis puntos mantienen su estado en `TRAINER_STUDENT_UX_2026_10_22.md`.

![Inicio con novedades](visual-audit/athlete-navigation-2026-10-22/inicio.png)
![Inicio sin campana](visual-audit/athlete-navigation-2026-10-22/sin-avisos.png)
