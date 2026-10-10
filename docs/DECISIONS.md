# Registro de decisiones vigentes

Este archivo es el índice de las decisiones de producto, dominio y arquitectura
que deben sobrevivir a una conversación concreta. No sustituye a los documentos
especializados: indica qué está acordado, su estado real y dónde se explica.

## Cómo utilizarlo

- **Acordada:** Javier y el equipo han confirmado el criterio, aunque todavía
  no exista implementación.
- **Implementada:** el criterio está reflejado en código o migraciones y se ha
  verificado.
- **Pendiente:** se ha identificado la pregunta, pero todavía no existe una
  decisión que pueda convertirse en regla.
- **Sustituida:** dejó de estar vigente; se conserva la referencia a la decisión
  que la reemplaza para no recuperar accidentalmente el criterio antiguo.

Cuando una conversación confirme o corrija una decisión relevante, esa misma
tarea actualizará este índice y el documento especializado correspondiente
antes de considerarla cerrada. Una omisión en el código no anula una decisión
acordada que todavía esté pendiente de implementación.

## Decisiones

La selección de nuevas semanas de carrera se revisa en PLAN-022, sobre PLAN-020/021. PLAN-006/009/014–016 describen versiones piloto sustituidas; sus decisiones históricas conservan versión.

| ID | Fecha | Área | Estado | Decisión | Documento de detalle |
| --- | --- | --- | --- | --- | --- |
| COM-004 | 2026-10-10 | Precio de lanzamiento de Pro | Acordada; contratación pendiente de implementación | Javier confirma 3,99 €/mes y toma 29,99 €/año como precio para diseñar la oferta inicial, con el mismo acceso Pro. Doce mensualidades suman 47,88 €: el anual ahorra 17,89 € (37,36 %) y equivale a unos 2,50 €/mes. Son precios de lanzamiento; viabilidad económica, condiciones de renovación y protección de tarifas, proveedor de cobro y diseño definitivo siguen pendientes. No se implementan cobros, derechos ni restricciones. | `docs/PRODUCT.md`, `docs/VISUAL_DESIGN.md` |
| COM-005 | 2026-10-10 | Posible descuento militar | Pendiente de valoración por Javier | Javier propone estudiar un descuento acreditando la condición militar con TMI, por ejemplo mediante cupón, pero precisa que aún debe valorarlo. No están aprobados el descuento, sus importes, beneficiarios, vigencia ni procedimiento. Se recomienda contacto sin documentos por correo y, si se aprueba, verificación mínima por un canal seguro y oferta vinculada a la cuenta. No existe verificación oficial, integración con Defensa ni recogida de documentos implementada. | `docs/PRODUCT.md` |
| UI-026 | 2026-10-10 | Accesos claros y mensajes en castellano | Implementada y comprobada | Javier confirma una única entrada «Ver preparación» en las tarjetas de Inicio/Mi plan. El detalle mantiene programa, fecha, marcas y resultados; el programa activo conserva su acceso contextual. Fotografías, estados y reglas deportivas intactos. Favoritos limitados a Mis sesiones, Mis ejercicios y Disponibilidad: se retiran destinos repetidos en calendario, herramientas o pestañas, se convierte el antiguo Crear ejercicio y se conserva orden/selección por cuenta sin rellenar huecos. Inicio usa Herramientas y retira Ver todas y la tarjeta duplicada de Biblioteca; esta conserva su pestaña. Biblioteca retira Perfil duplicado. El adaptador de autenticación traduce códigos y evita exponer errores técnicos; confirmación/recuperación conservan sus estados. Análisis limpio, 153 pruebas relacionadas y 717 completas correctas con la omisión web existente. Sin cambios SQL, dependencias, motores, negocio, admin o producción. | `docs/UX_REVIEW_2026_10_09.md`, `docs/VISUAL_DESIGN.md`, `docs/PLAN_COHERENCE_2026_10_08.md` |
| UI-025 | 2026-10-09 | Refresco de Inicio y Mi plan | Implementada y comprobada | Javier confirma quitar el botón circular de las cabeceras en la vista móvil, conservarlo en escritorio y mantener Reintentar ante errores. Se utiliza el mismo umbral de 840 px que la navegación actual para distinguir vista compacta y amplia. Tirar hacia abajo y regresar desde otra sección mantienen su recarga existente; no cambia la carga, los datos ni las rutas. Análisis limpio y 687 pruebas de raíz correctas con la omisión web existente. | `docs/UX_REVIEW_2026_10_09.md` |
| UI-024 | 2026-10-09 | Gesto de volver | Implementada y verificada | Javier pide aplicar el gesto desde el borde manteniendo la flecha. Las páginas explícitas de Flutter corrigen la detección de MaterialApp por go_router 18. Android/iOS/web usan Cupertino en consultas; con onExit o PopScope el borde solicita la misma salida protegida, antes de mover la pantalla. Cancelar permite repetir sin perder campos; fallo de borrador/guardado ocupado conserva la tarea. Sesión con series sale para retomar sin abandono; Disponibilidad vuelve a Perfil en las rutas reales. Javier precisa que Android también debe ofrecer el gesto propio con navegación de tres botones: implementado, conservando atrás del sistema. Análisis limpio, 706 pruebas correctas y una omisión web existente; 51 regresiones relacionadas incluyen iOS/Android. La primera verificación acreditó nueve regresiones correctas en Chrome con las rutas del banco Windows normalizadas en memoria. Requiere hot restart. Sin paquetes nuevos, cambios de datos, motores, fotografías, admin o producción. Javier confirma el 09/10/2026 que el gesto va muy fluido en Android físico con la configuración profile de VS Code; el tirón de debug no se reproduce, sin medición de fotogramas. iPhone físico y un recorrido autenticado completo pendientes; Javier sigue revisando preparación → Mi plan → Hoy. | `docs/VISUAL_DESIGN.md`, `docs/ARCHITECTURE.md` |
| UI-023 | 2026-10-09 | Un único acceso para añadir en Mi semana | Implementada y comprobada | Javier confirma conservar el acceso dentro de la card cuando el día está vacío y mostrar el botón flotante cuando ya tiene sesiones, sin ambos a la vez. El control cambia al añadir y al seleccionar otro día, con o sin programa en curso; el día de descanso conserva su mensaje y aloja el mismo acceso antes flotante. Se mantienen diseño, selector de sesiones, fecha elegida, agenda y reglas del programa. Análisis limpio, 15 pruebas de Mi semana y 687 pruebas de raíz correctas con la omisión web existente. Capturas de widgets actuales con agenda ficticia; sin nueva prueba autenticada ni física. | `docs/UX_REVIEW_2026_10_09.md` |
| UI-022 | 2026-10-09 | Uso cotidiano y descarte de sesión | Implementada y comprobada en desarrollo | Javier autoriza descartar también series registradas en una ejecución en curso. Flecha y botón inferior ofrecen Salir sin guardar con confirmación; cancelar/fallar conserva series, borrador y descanso. La RPC valida identidad, propiedad, confirmación y estado, elimina los resultados de esa ejecución y devuelve su cita a pendiente conservando pauta/preparación. Historial cerrado protegido; IDs privados reconocen reintentos y colas tardías, sin resultados deportivos ni borrado directo del cliente. Retirado Perfil duplicado en Inicio; Mi semana usa Añadir entrenamiento. Disponibilidad separa días/minutos con texto ampliado. FAS acota lecturas a 15 segundos y corrige errores rápidos anteriores al montaje del aviso; reintento y respuestas antiguas comprobados, sin cambiar baremo/guardado. Análisis limpio, 685 pruebas de raíz correctas y una omisión web existente. Migración 20261009000000 aplicada solo en desarrollo: 134 coincidentes, tres pruebas SQL con ROLLBACK correctas. Sin cambios de motores, fotografías, admin, dependencias, negocio o producción. Siguiente: revisión pausada de preparación/Mi plan/Hoy; gimnasio e iPhone físico pendientes. | `docs/UX_REVIEW_2026_10_09.md` |
| UI-021 | 2026-10-08 | Coherencia de Mi plan y formularios | Implementada y comprobada; recorrido autenticado posterior | Javier aporta diez fotografías y un vídeo de solapamientos, bloqueo de cambio por sesión abierta y confusión entre preparación guardada y programa iniciado. Confirma Preparaciones como nombre y Elige una preparación sin programa en curso; entiende disponibilidad/material como datos compartidos de la cuenta. Se conserva el diseño fotográfico y se distingue elección, programa, agenda y contexto. Mi plan vacío no asigna las marcas de la primera preparación; Inicio con varias y sin programa invita a elegir. El aviso abre la ejecución propia concreta aunque sea de otra semana/preparación; volver actualiza la propuesta conservando el asistente y no activa nada. Salir para retomar mantiene el bloqueo, fallo conserva pantalla y sesión cerrada fuera permite recalcular. Selectores completos, separación de campos y ayudas sin recorte; unidades, calibración y motores conservados. Análisis limpio, 671 pruebas correctas con la omisión web existente y capturas de widgets con fixtures. Desarrollo tiene 133 migraciones coincidentes; no se cambia SQL, RLS, admin, dependencias, negocio o producción. Amplía expresamente el recorrido UI-010 por petición de Javier, sin retomar Free/Pro. Revisión pausada de incoherencias es el siguiente bloque; gimnasio e iPhone físico quedan pendientes sin bloquearla. | `docs/PLAN_COHERENCE_2026_10_08.md` |
| HAPT-001 | 2026-10-08 | Vibración del temporizador en Android | Vibración física confirmada; primera oferta implementada y pendiente de prueba física | Javier aclara que usa la app nativa Samsung desde F5 y no percibe los toques, aunque oye el sonido. Flutter traduce los efectos anteriores a respuesta de teclado/reloj, sujeta al ajuste táctil del sistema. Se sustituyen solo en Android por pulsos finitos de 60/120/200 ms y doble pulso de final, con permiso normal VIBRATE, clasificación de notificación y cancelación al salir de primer plano, sin paquetes nuevos. El diálogo permite probar vibración sin sonido ni guardar ajustes; errores aislados. iOS/web conservan sus efectos. Permiso y adaptador incluidos en APK; diálogo/prueba comprobados en banco iOS. Windows seguía en d79dde3; Javier confirma pull hasta b38d974 y comunica que al relanzar sigue sin vibrar. Confirma motor funcional en ajustes y vibración activada. Se añaden trazas de desarrollo EntrenaOPVibration sobre la ruta, permiso, motor, visibilidad y condiciones de Android, sin cambiar patrones ni ajustes; diagnóstico fallido no bloquea el aviso. Análisis limpio, 653 pruebas correctas con omisión web y compilaciones Android/iOS correctas. Javier aporta dos pruebas en SM-A326B/SDK 33: motor y permiso presentes, actividad visible, modo sonido normal, interrupciones permitidas y solicitud workFinished enviada sin excepción. La ausencia de control de amplitud no impide el patrón básico. El log de Samsung cancela el patrón correcto porque las notificaciones de EntrenaOP están desactivadas; AppOps permitido y ajustes globales activos. Javier identifica la ausencia de petición de permiso. Se declara POST_NOTIFICATIONS y la prueba manual Android 13+ espera su concesión; denegación sin aviso alternativo, sin pedir cámara ni abrir diálogos durante el reloj. Se comprueba areNotificationsEnabled antes de enviar, se añade diagnóstico y ayuda en ajustes. Cancelar el borrador no revoca permisos del sistema. Javier confirma vibración física tras conceder el permiso en Samsung; percibe un pequeño adelanto sobre el sonido, aceptable y sin medición. No se compensa con un retardo fijo. Javier pide continuar con el primer uso: la primera sesión activa ofrece el permiso si falta en Android 13+ y la vibración está activada, con explicación, Permitir avisos o Ahora no. Marca local para no repetirlo, también tras la prueba manual; denegación sin bloquear la sesión ni alterar preferencias. No se pide en descarga, arranque global, pantallas cerradas o hitos del reloj. Primera entrada automática verificada en pruebas, pendiente de Android físico sin permiso; se conserva la confirmación física de la petición manual. Javier aclara que el recorrido Android está parcialmente comprobado; gimnasio e iPhone físico quedan como validaciones posteriores y no bloquean revisar las incoherencias que quiere mostrar. Sin acreditar auriculares, uso real entrenando o segundo plano ni modificar producción. | `docs/WORKOUT_AUDIO_2026_10_08.md` |
| IOS-002 | 2026-10-08 | Audio nativo en simulador | Compilación, reproducción y escucha comprobadas | Javier autoriza coordinar «Prepara EntrenaOP para iOS» en EntrenaOP MacOS. La copia y app instalada seguían en 98e037e, antes del plugin y los WAV. Se revisa el diff, avanza la copia limpia hasta 774361b con lockfile y reconstruye la ejecución. Banco sin cuenta compila en iPhone 17 Pro/iOS 26.3.1; cinco WAV idénticos al repositorio y audioplayers_darwin registrado por SPM. Reproductor confirma preparación, inicio, mitad, diez segundos, 3/2/1, final y descanso; Javier confirma «Sí, ahora suena». Análisis limpio y 621 pruebas correctas con omisión web; app principal relanzada con Supabase de desarrollo y árbol limpio. No cambia código ni sesión playback/mixWithOthers. Vibración activada y llamadas sin errores, pero su sensación física, volumen/silencio, música y auriculares quedan para dispositivos reales. | `docs/IOS_DEVELOPMENT.md`, `docs/WORKOUT_AUDIO_2026_10_08.md` |
| UI-020 | 2026-10-08 | Tiempo realizado y opciones al salir | Implementada y comprobada; audio iOS contrastado en IOS-002 | Javier muestra que el reloj escribe 20 en un campo que exige min:seg y que la flecha no permite abandonar. Las escrituras programáticas se convierten desde segundos reales (20 → 0:20; 90 → 1:30), sin alterar el formato de escritura manual ni el contrato de resultados. La flecha ofrece seguir, retomar o abandonar conservando lo realizado; reutiliza motivo y operación existentes. Cancelar o fallar mantiene sesión y borrador; el cierre encolado conserva las series. Diálogos desplazables con texto grande. Se amplía opcionalmente el guard compartido, conservando go_router y la salida predeterminada de los formularios. Análisis limpio app/admin/entrena_ui, 630/91/6 pruebas correctas con las omisiones existentes y 30 específicas. No añade descarte de resultados ni cambia motores, datos, fotografías, negocio o producción. Javier confirma audio en navegador Android y silencio en simulador iOS; autoriza coordinar el chat del Mac para investigar la compilación nativa. | `docs/SESSION_CONTROLS_2026_10_08.md`, `docs/WORKOUT_AUDIO_2026_10_08.md` |
| UI-019 | 2026-10-08 | Controles de sesión y semana | Correcciones implementadas; salida ampliada en UI-020 | Javier muestra abandono inaccesible esperando el cierre final y días de Mi semana con ancho fijo; se reproducen con regresiones y corrigen conservando datos y diseño. Abandonar depende de la ejecución en curso, admite motivo y conserva resultados; salir permite retomar. La semana ocupa el ancho disponible con desplazamiento cuando lo exige la legibilidad. Javier confirma pitidos en 3, 2, 1 segundos antes del final del trabajo, además de los hitos anteriores; sin replay al restaurar ni solapar avisos. Análisis limpio, 621 pruebas completas con la omisión web existente, capturas y banco web compilado; ocho reproducciones del intervalo de cinco segundos aceptadas en Chromium sin errores. UI-020 amplía las opciones de salida; eliminar datos registrados sigue pendiente de contrato; no se cambian planes, SQL, permisos, admin, dependencias o producción. Escucha en simulador acreditada después en IOS-002; dispositivo físico pendiente. | `docs/SESSION_CONTROLS_2026_10_08.md`, `docs/WORKOUT_AUDIO_2026_10_08.md` |
| UI-018 | 2026-10-08 | Sonidos del ejecutor | Implementada; simulador contrastado en IOS-002; físico pendiente | Javier comunica silencio en localhost, Android físico e iOS simulador y confirma avisos a mitad y diez segundos. SystemSound.alert se ignora en esas plataformas: se sustituye por cinco WAV originales locales y audioplayers 6.8.1, sin actualizar paquetes anteriores. Sonido/vibración independientes, prueba explícita sin guardar preferencias, fallos aislados y avisos sin acumulación. Coincidencias y tiempos cortos evitan duplicados; restaurar descanso conserva su duración original. Análisis app/admin limpio, 606 y 91 pruebas completas correctas con sus omisiones existentes, 27 específicas, web real y APK debug correctos. Compatibilidad SPM del paquete resuelto revisada; la compilación/escucha en simulador se acredita después en IOS-002; Android/iPhone físicos permanecen pendientes, sin garantizar segundo plano. Javier comunica revisión superficial de guardado/Evolución/fotos en simulador, sin acreditar auditoría completa. Recuperación nativa no se fuerza. Diseño, motores, derechos comerciales, SQL y producción se conservan. | `docs/WORKOUT_AUDIO_2026_10_08.md`, `docs/IOS_DEVELOPMENT.md` |
| IOS-001 | 2026-10-08 | Desarrollo iOS en Mac | Implementada y comprobada en simulador | Javier autoriza preparar y actualizar las herramientas necesarias del Mac. Se instala Flutter 3.47.5/Dart 3.13.4, conservando el SDK anterior y los lockfiles. Las migraciones del SDK establecen mínimo iOS 15, ciclo UIScene y plugins mediante Swift Package Manager. Se mantiene el callback es.entrenaop gestionado por Supabase/app_links y se usa solo desarrollo. Compilación y arranque comprobados en iPhone 17 Pro/iOS 26.3.1, Supabase inicializado, análisis limpio y 591 pruebas correctas (una exclusiva web omitida). Login, correo real iOS y firma/dispositivo físico no quedan acreditados. | `docs/IOS_DEVELOPMENT.md` |
| UI-017 | 2026-10-08 | Pulido de formularios | Tramo localizado implementado y comprobado | Continuación autorizada de UI-008 tras guardar UI-016. Se reproducen y corrigen desbordamientos con texto doble en el tipo de nuevo programa y los selectores de ejercicio compartidos. Las selecciones se muestran completas; poco ancho/texto ampliado coloca los controles de foto bajo la vista previa sin cambiar proveedor, proporción o encuadre. Ambos tipos de programa conservan nombre/tipo tras fallo y reintento, creando solo borradores. Análisis limpio en app/admin/paquete y baterías completas: 591, 91 y 8 correctas, con las omisiones existentes. Seis recorridos y 12 capturas actuales revisadas. No cambia datos, permisos, navegación, motores, negocio, portadas de Inicio/Mi plan o producción. No cierra todo el pulido ni el recorrido autenticado. | `docs/REFRESH_FORMS_2026_10_08.md`, `docs/VISUAL_DESIGN.md` |
| UI-016 | 2026-10-08 | Evolución: tipo histórico de sesión | Implementada y comprobada en desarrollo | Javier autoriza continuar el filtro pendiente. Se explica antes de aplicar el contrato: el servidor conserva Carrera, Fuerza/acondicionamiento o Mixta al iniciar, según bloques de trabajo y política block_format_v1; calentamiento/vuelta a la calma no hacen mixta una carrera. Tipo y política son inmutables; las ejecuciones anteriores siguen Sin clasificar, sin inferencia ni backfill. El filtro se combina con preparación, fechas y estado antes de paginar, conservando consulta al refrescar/fallar. Selectores completos con texto ampliado. Análisis limpio, 591 pruebas de raíz y 25 específicas correctas; una exclusiva web omitida. Tres recorridos y 15 capturas de widgets actuales revisadas. Migración aplicada solo en desarrollo: 133 coincidentes y cuatro pruebas SQL con ROLLBACK correctas. No cambia Inicio/Mi plan, fotografías, código admin, motores, negocio, paquetes o producción. Comparación configurable y recorrido autenticado global permanecen abiertos. | `docs/HISTORY_SESSION_TYPE_2026_10_08.md`, `docs/ARCHITECTURE.md`, `docs/VISUAL_DESIGN.md` |
| UI-015 | 2026-10-08 | Evolución: comparación de marcas | Implementada y comprobada en desarrollo; filtro deportivo y comparación configurable pendientes | Javier pide continuar Evolución. Se explica y aplica comparación de mediciones originales dentro de la misma prueba y versión: Tropa conserva columna/hito/unidad/dirección, FAS usa exclusivamente su catálogo versionado compatible y los controles válidos de 2 km se mantienen separados de evaluaciones oficiales. Prueba y fechas conservadas al refrescar/fallar; diferencias precisas y tarjetas con expansión propia por resultado. El comparador anterior de Tropa también descarta versiones o contextos incompatibles. Los programas configurables conservan sus snapshots e informan de los datos históricos que faltan para comparar, sin reconstruirlos desde una definición actual. Análisis limpio, 579 pruebas de raíz correctas y seis recorridos de captura; una prueba exclusiva web omitida. Sin cambios en motores, negocio, fotografías, Inicio/Mi plan, admin, SQL o producción. No cierra toda Evolución ni el recorrido autenticado. | `docs/MEASUREMENT_COMPARISON_2026_10_08.md`, `docs/PHYSICAL_ASSESSMENT_DOMAIN.md`, `docs/ARCHITECTURE.md` |
| UI-014 | 2026-10-08 | Organización del detalle admin | Implementada y comprobada en desarrollo | Javier pide avanzar con el refresh mientras no puede probar el correo desde el móvil. Se adelanta este tramo del pulido UI-008: índice fijo de Contenido, Evaluación y Entrenamiento dentro del detalle, conservando secciones montadas, pruebas desplegadas y formularios retenidos. Portada/publicación en Contenido, calificación/pruebas/baremos en Evaluación y sesiones/vínculos en Entrenamiento. Los destinos siguen usando go_router; el índice solo desplaza la misma página. Baremo publicado ofrece «Ver», los errores de módulos/fuerza permiten reintentar y una prueba ya vinculada no se presenta como inexistente. Acciones y selectores admiten pantalla estrecha y texto grande. Análisis admin limpio, 89 pruebas y seis recorridos de captura correctos; una captura optativa existente omitida. No cambia deportista, portadas/encuadres, motores, contratos, SQL, permisos, negocio ni producción. Correo real y revisión autenticada siguen pendientes; el resto del pulido transversal no se considera terminado. | `docs/REFRESH_ADMIN_2026_10_08.md`, `docs/VISUAL_DESIGN.md` |
| MAIL-001 | 2026-10-08 | Correo de recuperación | SMTP y plantilla comprobados; recepción en Gmail y recuperación web confirmadas por Javier | Javier confirma `acceso@entrenaop.es` como dirección propia de acceso, separada de su correo personal de empresa, y autoriza configurarla. Completa la creación del buzón en Hostinger y guarda su SMTP en Supabase. Confirma después haber cambiado la contraseña y guardado los cambios: la credencial vigente es distinta de la vista en la captura y la rotación deja de estar pendiente. Consulta remota acredita la configuración de envío y el asunto/HTML españoles versionados, con el enlace de Auth conservado. Solo recuperación está personalizada; la API activa sus indicadores derivados y el verificador protege los de otros correos. Segunda aplicación idempotente y cinco regresiones locales correctas. Supabase mantiene la cuota inicial de SMTP propio de 30 correos/hora y 60 segundos por usuario; se combina con los 100 diarios de Hostinger. Javier aporta el correo real recibido en la bandeja de Gmail, con remitente, asunto español y logotipo visibles. Solicita desde Chrome de F5 y abre en Chrome habitual: se comprueba que Flutter usa un perfil temporal distinto en localhost:55554, lo que explica el rechazo esperado de PKCE. Al repetir desde el mismo perfil y origen confirma «funciona perfectamente». La firma/alineación del mensaje, prueba nativa y comprobaciones adversas contra Auth real siguen pendientes; el agente no accede a su contraseña ni acredita producción. No se amplían cuotas ni se cambian confirmación, MFA, otras plantillas, DNS o planes. | `tools/account_access_dev/README.md`, `docs/REFRESH_ACCOUNT_2026_10_08.md` |
| UI-013 | 2026-10-08 | Cuenta: recuperación y confirmaciones | Implementada y comprobada con pruebas; recuperación web confirmada por Javier; revisión nativa pendiente | Javier autoriza continuar Cuenta y pide seguridad del recorrido. El SDK distingue recuperación del acceso normal y Supabase Auth autoriza el cambio. Pantallas persistentes de solicitud, confirmación, enlace rechazado y contraseña actualizada; reintento conserva campos. Un marcador por propietario conserva solo el recorrido local, sin conceder derechos. Respuestas tardías no trasladan identidad ni confirmación a otra cuenta. Callback web/móvil y lista de retornos comprobada únicamente en desarrollo, conservando confirmación de correo, límites y MFA remotos. MAIL-001 acredita recepción y recuperación web confirmadas por Javier. Revisión localizada posterior: 24 regresiones correctas; persistencia móvil predeterminada en SharedPreferences y ausencia de accesos a eliminación de cuenta/política de privacidad en la app. Keychain se recomienda para estudiar, sin aplicarlo; eliminación y política son requisitos de publicación citados de Apple. No acredita auditoría integral del login, prueba iOS ni producción. | `docs/REFRESH_ACCOUNT_2026_10_08.md`, `docs/ARCHITECTURE.md`, `docs/VISUAL_DESIGN.md` |
| VID-001 | 2026-10-08 | Gestión de vídeos | Diseño aplazado por Javier a otro chat | La consulta actual utiliza la URL HTTPS del ejercicio; guardar el enlace no sube ni aloja el archivo. Javier decide tratar en otro chat el alojamiento, las subidas y la gestión de vídeos de EntrenaOP. El reproductor y la apertura del enlace original implementados en UI-012 no implican un proveedor ni un sistema de carga acordados. | `docs/PRODUCT.md` |
| UI-012 | 2026-10-08 | Biblioteca y conservación de fotografías | Implementada y comprobada en desarrollo | Javier confirma conservar el aspecto de Inicio/Mi plan y pide resolver las fotos que desaparecen al navegar y continuar Biblioteca. Las portadas web usan el proveedor de Flutter para evitar la redecodificación del elemento HTML compartido; móvil conserva caché en disco. Biblioteca reproduce vídeo bajo demanda y abre referencias externas; los ejercicios personales privados tienen edición con borrador protegido, error persistente, foto conservada/sustituida/retirada y retorno con búsqueda conservada. `update_personal_exercise` valida autoría, contenido y ruta privada en servidor y guarda contenido e imagen en una transacción. Las ejecuciones anteriores conservan sus instantáneas. Sin rediseño de tarjetas, negocio Free/Pro, cambios deportivos ni producción. Borrado/archivado de ejercicios no forma parte de este cierre. | `docs/REFRESH_LIBRARY_2026_10_08.md`, `docs/VISUAL_DESIGN.md`, `docs/ARCHITECTURE.md` |
| UI-011 | 2026-10-07 | Resultados y consulta del historial | Implementada y comprobada en desarrollo | Continuación autorizada de UI-010: Marcas abre resultados propios de la preparación, con registro explícito mediante los formularios existentes. El historial permite filtrar por preparación, fechas y estado y consultar sesiones antiguas por páginas, conservando criterios y profundidad al volver. Las consultas se renuevan por cuenta y descartan respuestas anteriores; los errores permiten reintentar conservando resultados. Se mantienen snapshots, versiones y cálculos existentes. No incorpora comparativas nuevas ni cambia Inicio, Mi plan, portadas, catálogo, gestión de preparaciones, motores o negocio. | `docs/REFRESH_EVOLUTION_2026_10_07.md`, `docs/ARCHITECTURE.md`, `docs/VISUAL_DESIGN.md` |
| UI-010 | 2026-10-07 | Separación del refresh y del negocio | Confirmada por Javier; continuidad acotada en UI-011 | Tras COM-003 se conserva la base restaurada: Inicio/Mi plan cerrados, tarjetas fotográficas, catálogo y gestión de preparación actuales. Javier autoriza continuar por resultados, filtros e historial, implementados en UI-011. Descubrimiento comercial, fichas de venta, cuotas, derechos y suscripciones se tratarán en otro chat; los motores siguen aparte. Las ideas útiles de la maqueta no autorizan recuperar composiciones descartadas ni el selector COM-002. Cada tramo delimita archivos y recorridos, contrasta imágenes del código real y se valida antes de guardarlo. Si necesita cambiar áreas apartadas, se explica primero la ampliación de alcance. La delimitación inicial fue documental. | `docs/REFRESH_STATUS_2026_10_07.md`, `docs/VISUAL_DESIGN.md`, `docs/ROADMAP.md` |
| COM-003 | 2026-10-07 | Retirada de la simulación comercial | Confirmada por Javier; reversión aplicada | Javier pide recuperar el estado anterior al bloque `308ae18` y tratar el negocio en un chat aparte. Se revierte el bloque completo, incluida la reorganización de accesos y la ficha básica, conservando el historial de Git y recuperando código y pruebas de `82d74df`. UI-009 permanece pendiente; no se continúa su implementación en este bloque. La futura cuenta Free/Pro debe derivar sus derechos de servidor y del ciclo real de pago/suscripción, con recorridos acordados que conserven identidad visual, datos e historial. No se modifica Supabase ni producción. | `docs/PRODUCT.md`, `docs/VISUAL_DESIGN.md`, `docs/ROADMAP.md` |
| COM-002 | 2026-10-07 | Selector temporal Free/Pro | Retirada por COM-003 | El selector de Perfil y sus guardas locales se implementaron en `308ae18` como simulación de desarrollo. Javier descarta continuar con ese enfoque y se retira la implementación completa. No representa derechos comerciales vigentes ni una autorización para recuperar el selector en una tarea posterior. | `docs/PRODUCT.md`, `docs/ARCHITECTURE.md` |
| COM-001 | 2026-10-07 | Free/Pro y descubrimiento | Reparto confirmado por Javier; diseño e implementación pendientes | Free incluye ritmos, calculadora PAEF/PAFAS, sesiones propias limitadas (dos o tres, cifra pendiente), un límite de ejercicios por concretar y algunas sesiones de EntrenaOP. Los programas que generan/adaptan entrenamiento con los algoritmos son Pro. Oferta, cuotas definitivas, precios, contratación y derechos de servidor no están implementados. El catálogo y Tus preparaciones se revisarán sin presentar programas futuros como publicados; tarjeta «+ Añadir» naranja translúcida y descubrimiento visible son propuestas de composición. «Herramientas» es el nombre preferido; retirar el acceso grande de Biblioteca sigue en revisión. Los otros puntos del borrador comercial anterior no se consideran aprobados por esta confirmación. | `docs/PRODUCT.md`, `docs/VISUAL_DESIGN.md` |
| UI-009 | 2026-10-07 | Descubrimiento de programas | Alcance corregido por Javier; implementación pendiente | La prioridad es descubrir otro programa desde la vista actual con acceso completo, futuro Pro. El alcance es reorganizar accesos, conservando el aspecto actual: tarjetas fotográficas, encuadres, estados, nombres, fechas y «Gestionar preparación». Javier rechaza sustituirlas por una tarjeta genérica de programa en curso y duplicar «Añadir preparación» con un bloque «Explora programas». Se plantea una única entrada al catálogo dentro de Tus preparaciones, con la tarjeta «+ Añadir» antes solicitada; su colocación concreta sigue siendo propuesta. Para quien ya tiene acceso, la ficha ofrece preparar/empezar, no una nueva venta de Pro. Se respeta STR-026/027: varias preparaciones guardadas, un único generador; explorar o añadir no pausa el actual y activar otro explica el cambio, conserva progreso y retira las prescripciones pendientes sin empezar. Las maquetas no acreditan implementación ni suscripciones. | `docs/PRODUCT.md`, `docs/VISUAL_DESIGN.md`, `docs/PROGRAMA_ADAPTATIVO.md` |
| DEV-002 | 2026-10-06 | Git y colaboración | Confirmada por Javier | El árbol local actual es la referencia de esta consolidación; los chats/ramas anteriores aportan contexto, no sustituyen archivos. Javier autoriza guardar y subir cada bloque terminado y validado, sin repetir autorización. No incluye despliegues, producción ni reescritura de historial. | `AGENTS.md`, `docs/AUDIT_2026_10_06.md` |
| STR-033 | 2026-10-06 | Contexto de entrenamiento | Implementada en desarrollo | Perfil y Mi programa usan el mismo contexto de días, minutos y material exacto del coordinador. Las preferencias antiguas solo ayudan a completarlo; guardar no reinicia ni borra resultados. | `docs/PROGRAMA_ADAPTATIVO.md` |
| UI-007 | 2026-10-06 | Navegación de tareas | Confirmada por Javier e implementada | Consulta conserva la posición de cada sección; configuración y entrenamiento se abren sin barra. Salidas según cambios pendientes, borradores recuperables y series confirmadas, sin confundir salir con abandonar. | `docs/VISUAL_DESIGN.md` |
| UI-008 | 2026-10-06 | Fiabilidad y claridad de recorridos | Refresh aprobado; primer tramo implementado y validado | Javier aprueba el informe de UX: conservar formularios hasta guardar, refrescar sin perder estado, retorno contextual y resultado, recuperación de cuenta, Mi plan centrado en programa/semana, Evolución con datos comparables e historial, Biblioteca operativa y admin ordenado. Todas las pantallas usan go_router; StatefulWidget sigue siendo válido para estado temporal de interfaz, sin trasladar reglas ni acceso a Supabase al widget. Primer tramo: router admin por URL, protección de evaluaciones/editor, guardado retenido en referencias/programas/ejercicios, cierre de sesión accesible y búsquedas admin. El resto permanece pendiente y no se modifican algoritmos. | `docs/VISUAL_DESIGN.md`, `docs/ARCHITECTURE.md` |
| DOC-001 | 2026-09-25 | Colaboración | Implementada | Las decisiones relevantes no permanecerán únicamente en un chat: se registran aquí y se desarrollan en el documento de dominio correspondiente. | `AGENTS.md` |
| ARCH-001 | 2026-10-03 | Arquitectura | Reafirmada por Javier | Clean Architecture es el criterio permanente del proyecto: dominio independiente de Flutter/Supabase, adaptación de datos en la capa de datos y presentación mediante los contratos y casos de uso pertinentes. Los paquetes compartidos separan entidades/reglas de sus codecs; se mantienen capas con valor real, sin boilerplate por plantilla. | `docs/ARCHITECTURE.md` |
| UI-001 | 2026-10-04 | Identidad visual | Aplicada en desarrollo a ambas apps; pulido por recorridos | Material 3 se mantiene como infraestructura y EntrenaOP añade un sistema visual centralizado propio. Javier confirma que también debe aplicarse al admin, conservando su densidad funcional. El paquete local de presentación `entrena_ui` comparte tema, tokens, tarjetas y wordmark oficial sin corredor ni eslogan; no conoce dominio, permisos ni persistencia. Ambas apps heredan superficies y controles comunes. Portada, acceso, Mi plan, perfil y panel admin tienen composición de marca; se retiran excepciones neutras locales en el resto de recorridos sin borrar significados de estados. | `docs/VISUAL_DESIGN.md` |
| UI-002 | 2026-10-05 | Organización visual | Inicio y navegación auxiliar aplicados en desarrollo; Evolución ampliada parcialmente | Javier aprueba la maqueta y su implementación. Inicio conserva el calendario arriba, muestra la sesión de la fecha o el siguiente paso necesario y mantiene Tus preparaciones como bloque central. Ritmos y PAEF/PAFAS son tarjetas visibles; Biblioteca tiene acceso propio y Mis sesiones abre su pestaña directamente. Los favoritos personalizan hasta cuatro destinos y su orden, guardados por cuenta en el dispositivo, sin esconder funciones ni cambiar el diseño. Disponibilidad pertenece a Perfil; se conservan formulario, datos y consumidores. Evolución muestra actividad registrada y accesos a marcas por preparación, conservando los historiales personales. Los indicadores de tendencia quedan pendientes. La navegación inicial de cuatro pestañas se amplía mediante UI-003. UI-026 depura después los favoritos a tres destinos personales sin duplicados. No se modifican algoritmos en este chat. | `docs/VISUAL_DESIGN.md` |
| UI-003 | 2026-10-05 | Biblioteca central | Implementada en desarrollo | Javier confirma la maqueta «Por contenido»: Biblioteca ocupa la tercera de cinco pestañas (Inicio, Mi plan, Biblioteca, Evolución, Perfil). Agrupa sesiones y ejercicios, separando EntrenaOP de contenido propio, con botones explícitos de creación en las tarjetas personales. Mi plan conserva planificación y prescripción; herramientas y baremos no se mezclan con la Biblioteca. Se reutilizan casos de uso, repositorios y editores actuales; la nueva lectura de ejercicios tiene Cubit de presentación y respeta autoría/origen sin sustituir RLS. Se conservan los enlaces anteriores de sesiones. Sin cambios de algoritmos, datos, permisos ni dependencias. | `docs/VISUAL_DESIGN.md` |
| UI-004 | 2026-10-05 | Búsqueda en Biblioteca | Implementada en desarrollo | Javier solicita búsqueda y filtros para sesiones y ejercicios. Texto visible y filtros adicionales desplegables; sesiones por tipo y duración disponible, ejercicios por grupo muscular, tipo/medición, material y dificultad, con opciones del catálogo real. Criterios combinables, recuento, limpieza y vacío de búsqueda distinto del vacío de colección. Cada pestaña conserva sus criterios sin mezclar autorías; filtrar no cambia ni vuelve a consultar los datos. No se inventan formatos de sesión ausentes del resumen. Presentación separada de casos de uso, repositorios y algoritmos. | `docs/VISUAL_DESIGN.md` |
| UI-005 | 2026-10-06 | Icono de aplicación | Recursos corregidos en desarrollo | Javier entrega el icono OP para Android, iOS y favicon web y descarta expresamente el marco blanco tras verlo en navegador. Se conserva el original como referencia, pero los recursos se generan desde un maestro con fondo oscuro hasta los bordes; los márgenes adaptables también son oscuros. Una comprobación detecta el marco del original y verifica su ausencia en todas las variantes, junto con tamaños, opacidad y zonas seguras. Sin nuevas dependencias ni cambios del wordmark interior, admin o algoritmos. | `docs/VISUAL_DESIGN.md` |
| UI-006 | 2026-10-06 | Portadas de preparaciones | Acordada; implementada en desarrollo | Javier aprueba el editor en el admin web y confirma Supabase Storage con imágenes optimizadas y caché, sin portadas hardcodeadas. Fotografía velada y previsualización del deportista en móvil/escritorio; el tratamiento pertenece al tema compartido. Tras probarlo, pide encuadres independientes para tarjeta y cabecera, manteniendo la misma foto. El editor permite seleccionar qué formato ajustar y guarda ambos puntos de interés; las portadas anteriores conservan su posición. Metadatos editoriales independientes de pruebas y algoritmos, escritura administrativa en servidor, rutas inmutables y control de revisión. Admin, tarjetas y cabecera conectados; migraciones y pruebas SQL comprobadas solo en desarrollo. Pendiente comprobación autenticada en dispositivos; producción no se modifica. | `docs/VISUAL_DESIGN.md` |
| DEV-001 | 2026-10-03 | Desarrollo | Autorizada por Javier | En desarrollo, los datos de ensayo, incluidos historiales, pueden corregirse, sustituirse o borrarse cuando el diseño lo necesite; no condicionan la nueva arquitectura. Se elige la operación necesaria y comprobable, sin extender esta autorización a producción. Incluye sustituir la plancha ambigua por una variante definida. Amplía PLAN-019 a los datos de ensayo del resto del producto. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| RUN-001 | 2026-09-29 | Carrera | Acordada | Si la preparación ya tiene un 2.000 m oficial reciente y compatible, su marca basta como referencia inicial provisional: no se exige además Cooper ni VAMEVAL. Si necesita otro test de referencia, Cooper (distancia en doce minutos) será la opción principal y VAMEVAL continuo en pista la alternativa; el usuario elegirá solo uno. Ambos podrán ofrecerse después como calibración opcional. Se recomendará medir en pista por precisión y familiaridad con la prueba, sin exigir acceso a ella para comenzar. El 2.000 m oficial conserva su función y baremo propios. | `docs/ALGORITMO_CARRERA_V1.md` |
| RUN-002 | 2026-09-29 | Carrera | Pendiente | Falta cerrar la versión exacta del protocolo VAMEVAL (audio, velocidad inicial, incrementos, criterio de finalización y etapa computada) y la calibración de la prescripción. La velocidad media de Cooper no se presentará como VAM ni el 2.000 m se etiquetará como VAM por su distancia. La ventana temporal acordada se documenta en RUN-005. | `docs/ALGORITMO_CARRERA_V1.md` |
| RUN-003 | 2026-09-25 | Carrera | Implementada | El control específico de 2.000 m registra intentos fechados, RPE y datos opcionales; todavía no recalcula automáticamente una semana. | `docs/ROADMAP.md` |
| RUN-004 | 2026-09-29 | Carrera | Acordada | El test elegido sitúa el punto de partida, pero no fija por sí solo ritmos, umbrales ni una semana. La primera pauta usa disponibilidad, carga reciente, fuerza y estado de salud; puede empezar solo con carrera fácil cuando falte base. La adaptación posterior atiende a sesiones realizadas, esfuerzo, molestias y nuevas marcas comparables del mismo protocolo. | `docs/ALGORITMO_CARRERA_V1.md` |
| RUN-005 | 2026-09-30 | Carrera | Selección inicial implementada en desarrollo | Una medición de carrera del mismo programa y protocolo compatible se puede sugerir directamente hasta el día 30 inclusive. Del día 31 al 45 inclusive exige confirmación explícita de continuidad y cuatro semanas actuales sin interrupción de carrera ni molestias para elegirla. Desde el día 46 permanece en historial, pero no se usa para fijar ritmos; se pide control nuevo. Una fecha futura se rechaza. La elección guarda solo el origen y el intento, se vuelve a resolver y puede caducar después de guardada. Son días civiles desde la realización y una regla de producto, no una garantía fisiológica. Solo el piloto FAS consume hoy la selección para publicar sesiones de carrera. | `docs/RECORRIDO_CARRERA_2K.md` |
| RUN-006 | 2026-10-01 | Carrera | Criterio acordado; margen pendiente | La meta deportiva puede ser mejorar sin cifra, alcanzar una marca elegida o superar el mínimo oficial del programa con una holgura. El 7:45 propuesto para el caso de 7:58 es un ejemplo personal, no una regla general. No se impondrá un margen universal de diez segundos: debe decidirse por programa y prueba antes de convertirlo en prescripción. | `docs/ESPECIFICACION_CEREBRO_CARRERA_2K.md` |
| EVAL-001 | 2026-09-25 | Evaluación | Acordada | La evaluación inicial se inicia dentro del programa elegido y solicita solo información pertinente para planificarlo. No existe una batería física general obligatoria fuera de los programas. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-002 | 2026-09-25 | Evaluación | Acordada | El usuario introduce manualmente lo que ha hecho. Una marca anterior solo se sugiere si es pertinente para el programa, tiene protocolo compatible y sigue vigente; se muestra su fecha y el usuario decide si usarla. No se autocompletan evaluaciones ni se trasladan puntuaciones entre programas. En Tropa se retiró el bloque que mostraba automáticamente un antecedente general solo por coincidir el catálogo. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-003 | 2026-09-25 | Evaluación | Implementada | La calculadora FAS sigue accesible sin preparación; guardar un test es explícito. Un test guardado desde ella solo puede alimentar su propio programa, Mejora FAS, mediante asociación manual. No puede alimentar ningún otro programa. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-004 | 2026-09-25 | Evaluación | Pendiente | La asociación de un test personal a Mejora FAS usa provisionalmente 30 días. Falta validar la vigencia por tipo de prueba para futuras sugerencias en otros programas; este plazo no es una regla universal. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-005 | 2026-09-25 | Evaluación | Implementada en desarrollo | El administrador define pruebas propias de cada programa borrador con nombre, unidad, dirección favorable, protocolo y política de intentos. Un programa completo puede publicarse; el deportista registra su evaluación dentro de la preparación correspondiente. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-006 | 2026-09-26 | Evaluación | Implementada | Un borrador de programa admite ejercicios comunes o específicos de la columna H/M del baremo, tramos de marcas y puntos por columna, fuente y versión, y una regla global de media o suma con mínimos por ejercicio y total. La columna se selecciona expresamente en la simulación; no se deduce de la identidad del perfil. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-007 | 2026-09-26 | Evaluación | Implementada en desarrollo | Las tablas de marcas y puntos del anexo II de BOE-A-2026-15055 están en el borrador CNP 2026: agilidad y 1.000 m para ambas columnas, dominadas H y suspensión M, cero eliminatorio y media mínima de cinco. Agilidad admite segundo intento solo si el primero es nulo; el cálculo registra los nulos y da cero si no hay marca válida. El borrador no se publica automáticamente. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-008 | 2026-09-26 | Evaluación | Implementada en desarrollo | El administrador puede crear, editar y borrar pruebas y tramos de baremo en borradores. Cada tramo define desde/hasta y puntos por columna; los umbrales mínimos y de máxima puntuación se derivan de esos tramos y de la regla general, evitando límites duplicados. Cambiar la unidad, dirección, columna o resolución con tramos existentes exige confirmar su borrado. Las pruebas publicadas permanecen inmutables. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-009 | 2026-09-27 | Evaluación | Recorrido de evaluación implementado en desarrollo | Javier crea y modifica en ADMIN reglas, pruebas H/M y edad, mínimos o tramos, vigencia, edad oficial y política de intentos. Puede pegar tablas extensas, revisar cobertura y publicar el borrador completo. El deportista introduce manualmente sus marcas e intentos nulos dentro de su preparación, consulta aptitud, puntos y margen y guarda un historial ligado al programa y versión. Los baremos publicados son inmutables; ADMIN puede copiarlos a un borrador con versión nueva sin alterar historiales. Una modalidad normativa distinta se configura como programa distinto. Falta consumir esta evaluación genérica en el algoritmo semanal y decidir cómo se ofrece una nueva edición a preparaciones ya activas. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-010 | 2026-09-29 | Evaluación | Implementada en desarrollo | Tropa registra sus cuatro marcas oficiales desde su preparación con el catálogo vigente ya publicado. Los nuevos intentos se vinculan expresamente a esa preparación y allí se muestra el último. El historial general antiguo queda consultable, pero ya no ofrece crear intentos nuevos desde la app ni se vincula automáticamente; su posible reutilización requerirá confirmación del usuario. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-011 | 2026-09-29 | Evaluación | Implementada en desarrollo | El inicio comprueba por separado si cada preparación activa tiene una evaluación vinculada. Una evaluación de Tropa, Mejora FAS u otro programa no completa otra preparación. La evaluación configurable resuelve el programa desde la preparación activa, no desde un parámetro de URL. Esta comprobación indica si hay un intento guardado; todavía no acredita vigencia deportiva ni habilita la prescripción. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| EVAL-012 | 2026-09-29 | Evaluación | Integración visual y piloto FAS en desarrollo | Cada preparación tendrá un único recorrido visible de evaluación inicial y contexto de entrenamiento, compuesto por sus pruebas oficiales y las mediciones pertinentes. Una marca oficial de 2 km reciente y compatible puede iniciar una pauta provisional sin repetir la carrera ni copiar su puntuación; la ventana temporal es RUN-005. La pantalla común muestra marcas candidatas, disponibilidad, carrera reciente y salud. Solo Mejora FAS puede hoy publicar desde ella semanas de carrera. Permanecen las evaluaciones propias de Tropa, FAS y programas configurables sin trasladar puntos. | `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| PLAN-001 | 2026-09-24 | Planificación | Acordada | Fuerza y carrera aportarán propuestas especializadas, pero una única coordinación semanal resolverá disponibilidad, carga y preparaciones simultáneas. | `docs/ARCHITECTURE.md` |
| STR-001 | 2026-10-03 | Fuerza y rendimiento | Acordada; base editorial y persistencia en desarrollo | Javier confirma comenzar por el contrato deportivo y el catálogo a partir de sus dos textos, conservando su alcance completo. Se distinguen ejercicio/variante, objetivo, prescripción, ejecución y protocolo; se reutilizan los baremos y el ejecutor. Las 63 variantes tienen dominio compartido, pruebas y persistencia versionada en desarrollo. Las nuevas mediciones del ejecutor y reglas adaptativas siguen pendientes; la semana tendrá la coordinación única de PLAN-001. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`, `docs/CATALOGO_FUERZA_RENDIMIENTO_V1.md` |
| STR-002 | 2026-10-03 | Datos deportivos | Implementada en desarrollo dentro del tramo autorizado | Los perfiles oficiales son inmutables por código/versión y opcionales en ejercicios de sistema. Solo ADMIN administra los vínculos; los ejercicios personales conservan el flujo simple. Los enlaces a pruebas requieren revisión expresa y compatibilidad de unidad/medición: un protocolo borrador cambiado invalida el enlace, un publicado lo conserva y una copia traslada el mismo vínculo al borrador nuevo. La lectura del deportista se limita a perfiles de ejercicios públicos o pruebas publicadas. Los 63 perfiles del catálogo están enlazados a ejercicios oficiales públicos; los dos vínculos CNP borrador son asociaciones opcionales de evaluación, sin duplicar baremos. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| STR-003 | 2026-10-03 | Fuerza y biblioteca | Corregida y reafirmada por Javier; biblioteca aplicada en desarrollo | El catálogo debe estar materializado en la aplicación como ejercicios propios de EntrenaOP, no solo como inventario de metadatos. Se han creado las 60 entradas pendientes, completando las 63 variantes públicas de sistema. El futuro motor de fuerza/rendimiento será general: no requiere CNP, oposición, programa ni prueba oficial. Los adaptadores de evaluación podrán aportar referencias comparables al motor; no definen su existencia ni controlan la disponibilidad de los ejercicios. La biblioteca y las mediciones especializadas del ejecutor son alcances distintos: publicar una variante no acredita que todos sus modos de registro estén implementados. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`, `docs/CATALOGO_FUERZA_RENDIMIENTO_V1.md` |
| STR-004 | 2026-10-03 | Selección deportiva | Prioridad confirmada por Javier; reglas de selección pendientes | EntrenaOP prioriza mejorar las pruebas de la preparación activa. Un motor general no implica un plan genérico: el adaptador traduce las pruebas y protocolos del plan a objetivos deportivos, y el dominio selecciona ejercicios pertinentes a esos objetivos. Un objetivo específico de repeticiones o carga máxima puede aportar la misma entrada sin oposición. Los ejercicios complementarios son admisibles, pero no tienen prioridad por mejorar condición general. Falta una relación revisada objetivo–variante con función, condiciones y motivo; no se infiere transferencia por compartir músculos ni se codifica por el nombre de una oposición. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| STR-005 | 2026-10-03 | Autoría y motor | Reparto general confirmado por Javier; detalle e implementación pendientes | Javier respalda mantener la creación de programas en ADMIN y reutilizar estrategias deportivas. ADMIN configurará objetivos reconocidos y condiciones de las pruebas; las políticas versionadas relacionarán objetivos, variantes y dosis; el motor adaptará al usuario y un coordinador común encajará fuerza/carrera. Preferencias/exclusiones, flujo concreto y contrato de integración siguen por especificar. Un programa con objetivos compatibles no exige código nuevo; una capacidad no cubierta exige revisar su política. No interpretar texto libre como contrato ni confundir publicación de baremos con cobertura de entrenamiento. Las referencias públicas de producto orientan responsabilidades, sin acreditar sus algoritmos internos o eficacia deportiva. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| STR-006 | 2026-10-03 | Personalización deportiva | Criterio confirmado por Javier; primera simulación en STR-007 | La misma preparación puede producir variantes, dosis y evolución distintas según capacidad, experiencia, material, agenda y respuesta de cada usuario. La personalización debe tener un motivo deportivo explicable: no introducir diferencias aleatorias para aparentar exclusividad. Contextos equivalentes pueden recibir prescripciones iguales; compartir una rutina no sustituye el contexto, historial y adaptación de otra persona. El nuevo texto teórico se incorpora como material de revisión, no como fórmulas ya validadas: se separan evidencia, interpretación y política provisional versionada. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| STR-007 | 2026-10-03 | Primera estrategia | Cálculo experimental y revisión ADMIN implementados; dosis y activación pendientes | Javier autoriza investigar y comenzar la implementación; «minimotores» es solo un nombre informal. Se añade dominio puro y un laboratorio ADMIN para `push_up_reps_draft_v1`, que distingue práctica específica/apoyo calibrado, encaje temporal y adaptación según resultados comparables simulados. Las constantes de dosis son hipótesis pendientes de revisión, no reglas científicas aprobadas ni planes publicados. El ejecutor deja RIR/RPE reales ausentes hasta declaración expresa. Los doce recorridos, objetivos del programa, decisiones de servidor y coordinación completa siguen siendo requisitos para activar planificación real. | `docs/ESTRATEGIA_FLEXIONES_V1.md`, `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| STR-008 | 2026-10-03 | Recorrido y coordinación | Criterio de interfaz y automatización solicitado por Javier; diseño desarrollado, implementación pendiente | La preparación se configura mediante pasos breves con progreso y navegación atrás/continuar, contexto común capturado una vez y preguntas pertinentes a los objetivos y protocolos del programa. Los minutos que EntrenaOP destine a carrera/fuerza no los reparte manualmente el deportista: corresponden al coordinador común de PLAN-001, incluyendo sesiones completas, carga y recuperación. El laboratorio ADMIN conserva su función experimental. Los grupos de ejercicios desarrollan relaciones objetivo–variante revisadas; compartir patrón no implica equivalencia ni cobertura de entrenamiento. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`, `docs/PHYSICAL_ASSESSMENT_DOMAIN.md` |
| STR-009 | 2026-10-03 | Cobertura general y módulos | Alcance reafirmado y bloques aclarados por Javier; contrato inicial implementado en STR-010, activación pendiente | Se diseña desde ahora la cobertura completa del catálogo y sus objetivos, no solo carrera/flexiones ni un algoritmo independiente por cada una de las 63 variantes. El recorrido avanza por bloques relacionados completos (carrera, empujes, tirones, isométricos, cuerda, saltos/agilidad…), con preguntas pertinentes y «Continuar», no por cada respuesta. Los módulos conservan entradas/protocolos propios y aportan propuestas y restricciones a un único coordinador; las reglas comunes se reutilizan y los apoyos se cuentan una vez. Javier aclara que carrera puede evolucionar para integrarse, conservando su comportamiento comprobado: no se congela ni se reescribe incidentalmente para uniformar pantallas. Cualquier cambio de comportamiento se explica y acuerda antes, con las regresiones pertinentes. Diseñar cobertura completa no acredita dosis, políticas o ejecutores ya disponibles para todas las pruebas. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| STR-010 | 2026-10-03 | Intercambio entre módulos | Contrato de dominio e integración experimental ADMIN implementados; coordinación y publicación pendientes | El núcleo compartido representa objetivos con tarea/protocolo, capacidad y bloque explícitos; separa representación de catálogo y cobertura adaptativa; recoge pendientes y propuestas versionadas sin omitir objetivos no cubiertos ni duplicar trabajo compartido. El ensayo de flexiones aporta su decisión mediante un adaptador que conserva dosis y versión experimental. Ningún estado de revisión autoriza publicación. No se modifica el motor ni el recorrido de carrera, sus funciones SQL o sus sesiones; su adaptador operativo queda pendiente. | `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`, `docs/ESTRATEGIA_FLEXIONES_V1.md` |
| STR-011 | 2026-10-03 | Progresión y planificación deportiva | Planteamiento general respaldado por Javier; primera revisión ejecutable en STR-012 | Javier pide principios, progresión por resultado, mantenimiento/reducción, descarga y evolución temporal antes de ampliar dosis; tras la explicación respalda avanzar con esa base. Se conservan horizontes de 1/2/3/4/6/12 meses y bloques revisables, separando evidencia, interpretación y parámetros operativos. La revisión usa fuentes pertinentes de distintas instituciones, incluidos entrenamiento militar y CrossFit; ACSM no es fuente exclusiva ni PubMed un método deportivo. El acuerdo general no convierte constantes provisionales en óptimas ni modifica carrera. | `docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md` |
| STR-012 | 2026-10-03 | Progresión y recorrido ADMIN | Implementada como revisión experimental; planificación real pendiente | Dominio puro compartido para progresión de repeticiones, doble progresión carga/repeticiones y segundos isométricos desde dosis de trabajo calibradas. Dos exposiciones recientes comparables permiten cambiar una serie; dificultad repetida reduce o pide recalibrar, datos insuficientes mantienen, y se respetan variante/protocolo, material, fechas, esfuerzo y contexto. ADMIN ofrece un laboratorio por bloques con ejemplos de flexiones, dominadas, plancha, suspensión y banca, respuestas conservadas y objetivos sin dosis visibles. Parámetros experimentales explícitos y versionados; no infiere RM ni dosis desde máximos oficiales. No publica, coordina carrera/fuerza ni implementa evolución mensual. | `docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`, `docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md` |
| PLAN-002 | 2026-09-29 | Planificación | Implementada parcialmente en desarrollo | ADMIN vincula el módulo `running_2000m_v1` a una prueba de programa borrador declarada como carrera continua de 2.000 m, cronometrada en segundos y con mejor marca baja. El vínculo no comparte baremos ni marcas entre programas y todavía no genera semanas. La tarjeta informativa del vínculo se retiró de la app del deportista hasta que exista una acción real. Tropa y Mejora FAS conservan sus recorridos independientes. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-003 | 2026-09-29 | Planificación | Acordada | El plan automático de usuarios ordinarios no depende de un entrenador ni del modo Pro. La bandera existente de lesión o limitación es un bloqueo de seguridad de la prescripción automática, no una solicitud de aprobación a un profesional de EntrenaOP. Su nombre técnico y el flujo de reanudación quedan pendientes de revisión. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-004 | 2026-09-30 | Planificación | Contrato de lectura ampliado en desarrollo | El lector de referencias de 2 km recibe una preparación activa y devuelve mediciones candidatas con programa, intento, fecha, protocolo si se conoce y versión de baremo; no recibe puntos oficiales como ritmo. Lee evaluación oficial y control de Tropa, evaluación periódica ligada a Mejora FAS y pruebas vinculadas por ADMIN al módulo `running_2000m_v1` en programas configurables. Los catálogos oficiales antiguos no conservan versión de protocolo deportivo: el dato queda ausente, sin inventarlo. RUN-005 clasifica la antigüedad y la selección del intento; la dosificación prescriptiva sigue pendiente. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-005 | 2026-09-30 | Planificación | Entrada elegida implementada en desarrollo | El usuario elige expresamente un intento de carrera de su preparación. La selección conserva origen e identificador, no copia segundos ni puntos. En cada lectura se resuelve el intento y se comprueban ventana 30/45, continuidad confirmada cuando procede, cuatro semanas actuales, interrupciones y molestias. Una selección guardada puede dejar de ser utilizable sin borrar el historial. La RLS limita lectura y cambios al propietario y a preparaciones activas para escribir. Estar lista como entrada no equivale a una semana publicada. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-006 | 2026-09-30 | Planificación | Vista previa general y piloto FAS en desarrollo | La propuesta usa marca elegida y contexto actual. Con continuidad y espacio suficiente incluye una calidad controlada y el resto fácil; de otro modo, solo fácil o retorno gradual. Limita minutos por carga reciente y disponibilidad, reserva fuerza y evita días ocupados. La intensidad es por esfuerzo, sin deducir ritmo del 2 km. Fuera de FAS sigue siendo una vista previa local que no crea agenda; FAS calcula y publica en servidor según PLAN-007/008. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-007 | 2026-09-30 | Planificación | Piloto FAS implementado en desarrollo | Cero carrera en las cuatro semanas no equivale a ser principiante. Se pregunta por minutos actuales de carrera cómoda (valor ausente distinto de cero) y se distingue retorno de inicio. En FAS, con cuatro semanas de cero y capacidad declarada de al menos 30 min, la primera semana ofrece hasta dos carreras fáciles separadas; con 15 min, caminar/trotar. Sin capacidad declarada no pauta. El formulario reutiliza la duración normal del perfil, pide días concretos y deja ajustes por día y reservas de fuerza en una sección desplegable. La marca de 2 km se conserva separada de la tolerancia semanal. Es dosis piloto, no equivalencia fisiológica validada. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-008 | 2026-09-30 | Planificación | Piloto FAS implementado en desarrollo | El servidor publica semanas y conserva entrada, referencia, política y motivos en `running_week_decisions`, con sesiones de agenda y plantillas del ejecutor existente. Al calcular la siguiente semana cerrada: una sesión difícil mantiene carga; dos por dificultad, RPE alto o duración inferior al 70 % reducen; una semana completa y tolerada progresa una variable. Falta de tiempo no se cuenta como sobrecarga y una semana incompleta mantiene; molestias detienen. La semana publicada es idempotente y el historial no se reescribe. Es v1 para carrera FAS; faltan fuerza y coordinación multideporte. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-009 | 2026-09-30 | Planificación | Corrección v2 aplicada en desarrollo | Javier aclaró que los minutos de las cuatro semanas son carga realmente corrida y los 45 minutos de un día disponible son capacidad de agenda, no un límite semanal. El piloto FAS v2 toma la carga histórica como punto de partida: con dos días y 50 minutos recientes, 45 minutos disponibles por día y 60 minutos cómodos propone dos carreras fáciles de 30 minutos, sujetas a revisión tras ejecutarlas. Si una semana v1 ya publicada comprimió esos datos en una sola carrera y hubo una sesión difícil, la siguiente recupera dos salidas de 25 minutos sin añadir intensidad. La dosis es criterio conservador de producto, no un porcentaje de progresión universal respaldado por evidencia. Las decisiones publicadas conservan su versión. La entrada explica explícitamente que los minutos históricos son el total semanal y muestra la propuesta antes de publicar. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-010 | 2026-09-30 | Planificación | Simulación aplicada en desarrollo | Una semana FAS ya publicada conserva las sesiones y ejecuciones que generó. El deportista puede calcular una simulación de semana inicial con la política vigente y su contexto actual para comparar reglas sin escribir ni reemplazar historial. El cálculo normal y la simulación comparten el motor servidor; la simulación ignora únicamente la decisión y las sesiones automáticas de esa misma preparación y semana. Su resultado no predice la adaptación posterior a sesiones registradas. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-011 | 2026-10-01 | Planificación | Simulación de adaptación implementada en desarrollo | El deportista puede prever la semana posterior a su última semana FAS publicada cuando todas sus sesiones tienen estado final. La vista usa el mismo motor y los resultados realmente registrados, pero omite únicamente la espera cronológica hasta el cierre; no guarda decisiones ni sesiones y no habilita su publicación anticipada. Si se modifican registros o contexto antes del cierre, la propuesta real puede cambiar. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-012 | 2026-10-01 | Planificación | Salvaguarda v3 aplicada en desarrollo | Un RPE final de 8 o más en carrera fácil impide progresar esa semana; dos sesiones difíciles reducen minutos, conservando la frecuencia mientras haya días disponibles. Si el esfuerzo persiste en la dosis mínima, el motor pide actualizar el contexto tras las ejecuciones en vez de repetir o recortar el plan indefinidamente. No deduce por qué fue difícil ni prescribe tratamiento. Las semanas ya publicadas mantienen su versión. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-013 | 2026-10-01 | Planificación e IA | Acordada; modelo de lenguaje aplazado | La prioridad es un motor deportivo propio, versionado y comprobable, sin API externa facturada por cada planificación ni requisito de GPU. Un modelo de lenguaje queda fuera del bloque actual; no es necesario para seleccionar y adaptar sesiones. Se conserva el ejecutor existente. | `docs/ESPECIFICACION_CEREBRO_CARRERA_2K.md` |
| PLAN-014 | 2026-10-01 | Planificación | Corrección v4 aplicada en desarrollo | En el piloto FAS, dos semanas de carrera fácil completadas y toleradas permiten introducir una única calidad controlada de 4 × 2 min cuando hay al menos dos salidas y cabe una sesión de 32 min; el resto sigue fácil. Es una regla provisional de producto, no un umbral fisiológico validado. Se conserva el bloqueo por salud y esfuerzo alto. Los tramos publicados de esa calidad suman ahora la duración anunciada. Esta corrección no constituye aún el selector E/T/V/S/R ni decide entre series de 200 y 400 m. Las semanas anteriores mantienen su versión. | `docs/RECORRIDO_CARRERA_2K.md` |
| PLAN-015 | 2026-10-01 | Planificación | Catálogo piloto v5 aplicado en desarrollo | El servidor identifica cuatro variantes versionadas y conserva la variante e intención de cada sesión nueva. Dos calidades 4 × 2 completadas y toleradas en ocho semanas, una semana previa que progresa y al menos 36 min de capacidad y agenda permiten pasar a 5 × 2, añadiendo una repetición sin subir ritmo ni reducir recuperación. La sesión se materializa en el ejecutor existente y se comprueba la suma de tramos. Es una hipótesis deportiva provisional; aún faltan parciales comparables y el selector E/T/V/S/R. Las decisiones previas mantienen su versión. | `docs/ESPECIFICACION_CEREBRO_CARRERA_2K.md` |
| PLAN-016 | 2026-10-01 | Planificación | Salvaguarda v6 aplicada en desarrollo | Para progresar de 4 × 2 a 5 × 2, cada una de las dos calidades anteriores debe conservar los cuatro tramos de dos minutos completados. El RPE final y el 70 % de duración total por sí solos no acreditan esos tramos. La v6 no deduce todavía la intensidad real ni selecciona estímulos T/V/S/R. | `docs/ESPECIFICACION_CEREBRO_CARRERA_2K.md` |
| PLAN-017 | 2026-10-01 | Planificación | Acordada; especificación en curso | El documento deportivo de Javier con 26 puntos es la guía completa para diseñar el cerebro de 2 km, no una lista informal de ejemplos. Las v5/v6 son un piloto técnico, no el algoritmo deportivo final. Antes de ampliar la política de sesiones se resolverán de forma revisable los estímulos, escalado, mesociclos, descargas, adaptación por respuesta y casos longitudinales; los entrenos aportados por Javier se incorporarán como candidatos con finalidad, dosis y límites explícitos. | `docs/MATRIZ_CEREBRO_CARRERA_2K.md` |
| PLAN-018 | 2026-10-01 | Planificación | Acordada; pendiente de contrato operativo | Las sesiones de carrera se incorporarán a un catálogo interno con finalidad, requisitos, dosis y límites. El motor elegirá según el estado y la respuesta del corredor, no por el número de la sesión. 3 × 800 m y el 2 km fraccionado requieren tolerancia previa a trabajo específico; no son sesiones de entrada. La cantidad y el criterio exactos de esa tolerancia siguen pendientes de validación. | `docs/CATALOGO_CANDIDATO_CARRERA_2K.md` |
| PLAN-019 | 2026-10-01 | Planificación | Acordada | Las marcas, semanas y sesiones actuales usadas para probar el piloto son ficticias o históricas de ensayo y Javier autoriza descartarlas si el diseño lo necesita. Su conservación no condiciona la arquitectura deportiva. Esta autorización no implica borrarlas de inmediato ni afecta a la separación entre entornos; cualquier migración debe ser explícita y verificable. | `docs/ESPECIFICACION_CEREBRO_CARRERA_2K.md` |
| PLAN-020 | 2026-10-01 | Carrera | Implementación v1; calibración provisional | Un único motor determinista de servidor sin LLM, GPU ni API de pago. Catálogo E/T/V/S/R, evidencias por intención, fases, descarga y simulación longitudinal. Retira selectores Dart y sustituye la política FAS v6 para decisiones nuevas; reutiliza agenda y ejecutor. Meta libre o explícita; margen oficial y adaptadores de otros programas pendientes. Detalle, constantes y límites en la especificación ejecutable. | `docs/MOTOR_CARRERA_2K_V1.md` |
| PLAN-021 | 2026-10-01 | Carrera | Implementada en desarrollo; calibración provisional | FAS es un caso de ensayo: cualquier programa con módulo 2 km y referencia propia compatible usa el mismo motor de servidor y ejecutor. Se añaden objetivos con umbral propio y margen explícito. Datos incompletos no son inactividad. RPE alto repetido sin dificultad objetiva mantiene volumen y pide aclarar la escala; no lo reduce automáticamente. La salida de reducción por dificultad consolida primero la dosis reducida. Laboratorio de 1.573 semanas, sin atribuir mejora humana a la simulación. | `docs/MOTOR_CARRERA_2K_V2.md` |
| PLAN-023 | 2026-10-01 | Carrera | Implementada en desarrollo; supervisión visual pendiente | La experiencia de series previa se declara por número de semanas recientes y se audita, pero no sustituye ejecuciones verificadas ni abre dos calidades por sí sola. El RPE alto persistente se explica con una referencia conversacional breve. El deportista puede reiniciar expresamente el plan automático de una preparación tras dos confirmaciones; se borran sus sesiones y resultados automáticos, se conservan marcas, contexto y sesiones personales, y se rechaza si hay una ejecución en curso. Las tarjetas completadas abren el historial existente. | `docs/MOTOR_CARRERA_2K_V5.md` |
| PLAN-025 | 2026-10-02 | Carrera | Aclaración de interfaz implementada; criterio deportivo sin cambios | Una fecha de prueba lejana se conserva como objetivo real. A partir de más de 365 días, la preparación aclara que el motor decide carrera semana a semana con datos actuales; no promete un plan fijo hasta esa fecha ni impone un límite nuevo al calendario. Se comprueba la propuesta semanal con fecha de 2029. El horizonte superior a un año sigue sin validación longitudinal. | `docs/RECORRIDO_CARRERA_2K.md` |
| WEB-001 | 2026-09-28 | Presencia web | Implementada | `entrenaop.es` sirve por ahora una página HTML estática de presentación y política de privacidad desde Hostinger, separada de las aplicaciones Flutter. El acceso futuro al panel administrativo y la integración Garmin se decidirán e implementarán aparte. | `docs/ARCHITECTURE.md` |
| WEB-002 | 2026-09-28 | Presencia web | Acordada | La web pública de EntrenaOP será la puerta de entrada a la aplicación del deportista y a espacios diferenciados para administración y entrenadores. Cada espacio podrá desplegarse de forma independiente bajo el mismo dominio, con permisos propios; las direcciones concretas y el acceso unificado se definirán al implementarlos. | `docs/ARCHITECTURE.md` |
| WEB-003 | 2026-10-09 | Presencia web | Borrador local | Javier pide una web minimalista que explique la app, anuncie iPhone y Android y muestre futuros accesos para administración y entrenadores. La propuesta queda en `website/next/`, sin publicación; los accesos permanecen desactivados hasta tener destinos públicos y permisos verificados. | `docs/ARCHITECTURE.md` |

## STR-013 · 03/10/2026 · Edición de series y siguiente frontera

Implementada en ADMIN. Javier revisa el laboratorio y descarta introducir
varias series en una cadena de números separados por espacios. Cada serie
tiene su campo numérico, unidad y controles para añadir/quitar, conservando
los valores entre bloques. No cambia dosis ni reglas deportivas. El siguiente
tramo sigue siendo el enlace de prescripción/referencia/resultados reales,
antes de activar planificación conjunta. La inspección localizada encuentra
pendientes de identidad de protocolo/montaje, validez técnica y conservación
del esfuerzo ausente en correcciones del historial. Detalle:
`docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md` y
`docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`.

## STR-014 · 03/10/2026 · Explicar la referencia y el esfuerzo

Javier señala que no se entiende qué ejecución se pide para obtener la
referencia. ADMIN explica ahora repeticiones realizadas y margen estimado
(RIR), con un ejemplo y distinción entre objetivo y declaración real. El
recorrido del deportista debe enseñar el concepto antes del registro y
ofrecer ayuda durante este; el esfuerzo desconocido permanece ausente.
Pedir RIR 3 no demuestra haberlo alcanzado ni permite aplicar esa escala a
isometrías. La calibración real sigue pendiente; esta entrega aclara el
ensayo sin modificar dosis. Detalle:
`docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`.

## STR-015 · 03/10/2026 · Alcance de asistencia técnica por cámara

Alcance acordado; viabilidad práctica e implementación pendientes. Javier
limita la asistencia por cámara en Android e iOS a flexiones y plancha, para
detectar recorrido incompleto y compensaciones visibles en flexiones, y
pérdida de postura en plancha. El resto de ejercicios queda fuera de este
alcance. No se ha elegido SDK ni cerrado umbrales, protocolo de captura o
tratamiento del tiempo/repeticiones dudosos. Detalle y propuesta de validación:
`docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`.

## STR-016 · 03/10/2026 · Registro explícito y comparabilidad v2

Implementado como revisión experimental de ADMIN. El laboratorio sustituye
la selección de respuestas prefabricadas por ejecuciones editables con fecha,
instantánea de dosis original y resultados declarados por serie. Mantiene
ausencia de repeticiones/segundos, técnica, RIR, carga, tolerancia y motivo;
los ejemplos se cargan mediante una acción explícita. El dominio
`performance_progression_draft_v2` exige confirmar condiciones comparables y,
en carga/repeticiones, kilos reales compatibles por serie (y masa corporal
cuando corresponda), antes de atribuir mejora o dificultad a la dosis. Las
referencias v1 no se reinterpretan. No modifica carrera, SQL ni resultados
guardados del deportista. El enlace del ejecutor/servidor sigue pendiente.
Detalle: `docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md` y
`docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`.

## STR-017 · 03/10/2026 · Cierre operativo de fuerza y coordinación

Implementado en desarrollo el recorrido integrado: contexto y referencias reales,
política de servidor `performance_v1_1`, coordinación con `running_2k_v5`,
publicación transaccional, ejecutor, historial y adaptación semanal. ADMIN
configura la estrategia por prueba; FAS/Tropa tienen adaptadores de catálogo.
Dosis y tareas conservan versiones y evidencia original. La coordinación limita
subidas simultáneas por región, cuenta una vez trabajo compartido y reserva
la agenda de otras preparaciones. No altera retrospectivamente decisiones ni
convierte pruebas de software en eficacia deportiva. El optimizador conjunto
de todos los programas activos sigue fuera de esta versión; los parámetros
numéricos requieren seguimiento. Contrato, validaciones y límites:
`docs/MOTOR_FUERZA_RENDIMIENTO_V1.md`.

## STR-018 · 04/10/2026 · Correcciones del recorrido observado por Javier

El vídeo evidencia `LocaleDataException` al presentar días en español: una
propuesta calculada no podía mostrarse. Se corrige la presentación y se añade
una regresión con sesiones, sin preparar artificialmente el locale en el test.
Una serie o intento basta para calibrar: no tiene descanso entre series; el
servidor conserva cero como ausencia de intervalo. Con varias series sigue
exigiendo el descanso real. Plancha explica segundos y postura, sin pedir RIR
de repeticiones. El protocolo seleccionado identifica condiciones estándar;
los cambios de material/superficie son opcionales, salvo variantes que necesitan
altura de apoyo, asistencia o instrumento para ser comparables.

Javier pide recalcular sin reiniciar toda la preparación. Implementadas vista
previa y sustitución explícita de la última semana publicada todavía sin
empezar: conserva decisiones, plantillas y vínculos anteriores, marca la
decisión sustituida y cancela sus pendientes al guardar otra. No sustituye
semanas con ejecuciones, sesiones omitidas/pasadas o decisiones posteriores
dependientes. Publicación atómica, comparación de propuesta, candados e
idempotencia; no cambia reglas deportivas de `running_plan_v5`. El acceso común
sirve también para solo carrera. La preparación tiene un único acceso; desde
él, carrera muestra marca/cuestionario y vuelve a la propuesta conjunta.
La ruta antigua se conserva para compatibilidad. Detalle y verificación en
`docs/MOTOR_FUERZA_RENDIMIENTO_V1.md`.

## STR-019 · 04/10/2026 · Revisión de sesiones reales y banco deportivo aportado

Javier rechaza la prescripción observada: calentamiento poco accionable,
circuito completo usado como entrenamiento general, referencia de capacidad
reutilizada como dosis y continuación semanal poco comprensible. La revisión
confirma que `performance_v1_1` copia la dosis declarada y adapta cifras; no
implementa todavía la selección de estímulos y descomposición de tareas descrita
en el contrato. STR-017 acredita integración técnica, **no cierra la programación
deportiva completa**. No inferir máximos sumando repeticiones y RIR, ni interpretar
retroactivamente referencias antiguas ambiguas como máximos válidos.

Corregidos en desarrollo los campos pertinentes del ejecutor, las explicaciones,
el acceso desde agenda con semana concreta y la oferta de la siguiente semana
sin publicar. Calentamiento `warm_up_v1_1`: guía vinculada al trabajo, conservada
en la instantánea de ejecución; mantiene la reserva aproximada de siete minutos.
Nuevos campos opcionales del protocolo declaran estímulos y penalizaciones;
las correcciones de resultados antiguos preservan sus datos adicionales.
Estos cambios **no sustituyen las dosis de `performance_v1_1`** ni automatizan
la publicación de nuevas semanas. Carrera v5 conserva sus reglas.

Recibidos y conservados los dos textos de 40 propuestas y composición modular.
Son material de revisión, no instrucciones operativas ni políticas aprobadas.
Se distingue estímulo elemental, receta compuesta, sesión y semana. La revisión
de porcentajes, entradas, duplicación de carga, temporización, priorización,
progresión, puesta a punto y evidencia queda en
`docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`.
Único siguiente tramo: cerrar ese banco parametrizable y las entradas de
capacidad/dosis antes de sustituir el selector deportivo de servidor.

## STR-020 · 04/10/2026 · Banco V2 y aprovechamiento de propuestas anteriores

Javier aporta la V2 y propone conservar lo útil del banco anterior. Se registra
como recomendación pendiente de cierre deportivo un único banco normalizado:
V2 como base editorial candidata, fichas anteriores como procedencia y recetas
reutilizables, sin sumar automáticamente 80 alternativas ni activar porcentajes
descartados. Se distingue resultado oficial, capacidad, serie realmente ejecutada,
dosis propuesta, estímulo y receta. Adaptar con resultados significa aplicar
reglas explicables y versionadas; no aprender reglas fisiológicas autónomas.

La V2 mejora la separación de estímulos y dosis, pero no cierra temporización,
entradas por capacidad, progresión, carga compartida ni modelos ausentes de
dominadas/suspensión/cuerda/RM. No se han aprobado o activado sus dosis.
Correspondencias, límites y fuentes contrastadas:
`docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`.
Sigue el tramo único de STR-019: banco parametrizable, contrato de entradas y
selector deportivo de servidor, conservando las reglas actuales de carrera.

### PLAN-022 · 01/10/2026 · Selección de carrera y disponibilidad


Implementada en desarrollo; calibración provisional. Redistribuir minutos y probar calidad
compatible antes de sustituirla por fácil. Recomendar disponibilidad sin
sobrescribirla ni confundirla con carga tolerada. Entrada alcanzable a dos
calidades con historial, dosis y recuperación, manteniendo parámetros
provisionales explícitos. No añadir caras como regulador de carga. El CSV
personal es ilustrativo. Aplazar el comparador HTML de días hasta corregir y
verificar la selección. Detalle: `docs/MOTOR_CARRERA_2K_V3.md`.

Actualización del mismo día: Javier pide regenerar el visor existente con v3.
Se mantienen los 13 perfiles y seis horizontes; esto no adelanta la ampliación
del comparador 2/3/4/5 días. La recomendación de 45 minutos expresa margen para
sesiones completas, no una garantía de mayor beneficio.
En la interfaz, la elección de 45 min lleva la etiqueta «recomendado» y la
explicación contigua se reduce a una frase breve; 30 min sigue siendo elegible.

### PLAN-023 · 01/10/2026 · Entrada gradual a dos calidades

Implementada en desarrollo como `running_2k_v4`. Al pasar a dos sesiones de
calidad se puede repartir trabajo ya tolerado entre dos variantes completas
T 2×4 y V 3×2 antes de exigir T 2×5 + V 4×2. Mantener la cota de trabajo,
exposiciones y recuperación de PLAN-022; no inferir tolerancia por la marca.
Los valores concretos son calibración provisional. Detalle:
`docs/MOTOR_CARRERA_2K_V4.md`.

### PLAN-024 · 01/10/2026 · Progresión fácil tras mantener dos calidades

Implementada en desarrollo como `running_2k_v5`. Mantener dos calidades con
familia, dosis y factor de ritmo iguales a la semana anterior no cuenta como
una progresión nueva. Si la respuesta fue buena y cabe en la agenda, se pueden
añadir cinco minutos a una salida fácil. Una nueva segunda calidad o cambio
de dosis o ritmo sí consume la progresión de esa semana. No se altera el
historial v4. Detalle: `docs/MOTOR_CARRERA_2K_V5.md`.

## STR-021 · 04/10/2026 · Selección v2 y sesiones conjuntas

Javier encarga completar el recorrido con referencias explícitas, banco
reutilizable, coordinación real y lenguaje comprensible. Aplicados en desarrollo
selector v2 y coordinador v2.1. Las referencias ambiguas se aclaran; no se
convierten en máximos ni dosis. Formatos cortos y reducciones de frecuencia son
explícitos. Se cubren objetivos antes de segundas exposiciones o apoyos.

Los días mixtos son una sesión con preparación compartida. Carrera v5 conserva
cálculo y tramos; su adaptador lee sus resultados y esfuerzo específico, sin
confundirlos con esfuerzo global mixto. La interfaz recoge datos por pasos y
tiempos legibles. El laboratorio local v1 de ADMIN queda como histórico.

Las referencias con carga conservan las repeticiones realizadas, aunque estén
fuera del rango que luego prescribe el servidor. La práctica técnica de
capacidad baja pide calidad, sin exigir un RIR numérico incompatible.

Migraciones `20261004003000` a `20261004006000`, solo desarrollo. Contrato,
parámetros operativos, evidencia, ejemplos y límites:
`docs/MOTOR_FUERZA_RENDIMIENTO_V2.md`. Sustituir el selector v1 no certifica
eficacia deportiva ni autonomía avanzada de cuerda/reactividad sin calibración.

## STR-022 · 04/10/2026 · Programa adaptativo y controles con propósito

Javier confirma un recorrido de programa, con fecha, metas y punto de partida;
carrera como bloque condicional y disponibilidad común. Autoriza preparar la
siguiente semana al resolver todas las sesiones, usando los resultados reales,
sin un calendario de semanas futuras que el usuario deba construir.

Rechaza imponer controles por periodicidad fija. Seguimiento, control específico,
descarga y puesta a punto son decisiones distintas. Cada control debe justificar
su utilidad, protocolo, coste y oportunidad; una transición de fase no obliga a
un máximo. Los parámetros operativos no se presentan como leyes científicas.

Implementación y límites verificables (incluida la selección automática de
controles todavía pendiente): `docs/PROGRAMA_ADAPTATIVO.md`. No cambia el motor
de carrera v5 ni convierte las nuevas metas de fuerza en capacidades observadas.
Aplicadas y verificadas en desarrollo las migraciones `20261004007000` a
`20261004009000`; recorrido de programa y continuidad automática operativos.

## STR-023 · Programa automático, no calculadora semanal · 04/10/2026

Javier reafirma el recorrido original: alta con objetivo, fecha y punto de
partida; sesiones prescritas; registro real; adaptación y continuación sin
recalcular semanas ni elegir un modo manual. La prueba adelantando ejecuciones
es válida para detectar fallos del recorrido; se reproduce con reloj de pruebas,
sin alterar el calendario real ni añadir un modo de simulación al deportista.

Se distinguen estrategias deportivas, coordinador de carga/agenda y gestor del
programa. Son responsabilidades del mismo servidor, no nuevos servicios ni
algoritmos duplicados en Flutter. Un programa iniciado abre su seguimiento;
el cuestionario queda para el alta o cambios. Inicio y agenda recuperan la
continuación y muestran el motivo de espera o revisión. Los enlaces antiguos de
cálculo exclusivo de carrera remiten al programa común. Fecha lejana conservada
según PLAN-025. Elimina la activación opcional de continuidad en programas ya
publicados y el acceso «Preparar esta semana» desde días vacíos.

Implementación y comprobaciones: `docs/PROGRAMA_ADAPTATIVO.md`. No confundir
la corrección del ciclo con el cierre deportivo de controles y metas numéricas.

## STR-024 · Cambiar datos y reiniciar ensayos son acciones distintas · 04/10/2026

Javier necesita aplicar sus nuevas entradas y volver a empezar los ensayos
completados por adelantado. Guardar datos conserva los entrenamientos realizados.
Si la última semana aún no tiene sesiones iniciadas, realizadas, omitidas o
pasadas, se puede revisar una propuesta nueva y sustituirla explícitamente;
la continuidad ordinaria sigue siendo automática. El servidor decide si esa
revisión es admisible, usando el mismo contrato que la publicación.

Se incorpora un reinicio administrativo de ensayos, visible en desarrollo:
requiere propietario, permisos de administrador y escribir `REINICIAR`. Borra
solo semanas, sesiones y ejecuciones automáticas de esa preparación, incluidas
revisiones y sesiones canceladas al combinar fuerza y carrera. Conserva entradas
actuales, marcas de pruebas y sesiones personales. Rechaza sesiones en curso y
plantillas reutilizadas fuera del programa. Después revisa una primera propuesta
antes de reactivar. No se ejecuta sobre los registros de Javier durante la tarea.

Implementación, permisos y comprobaciones: `docs/PROGRAMA_ADAPTATIVO.md`.
No es un modo manual de planificación ni cambia las dosis deportivas.

## STR-025 · Identidad de preparación y convivencia pendiente · 04/10/2026

Javier confirma que está probando FAS y pide resolver la aparición de Tropa en
su recorrido. Cambiar de preparación debe renovar pantallas, cuestionarios y
controladores asociados a su identificador; no reutilizar datos de la anterior.
La regresión se reproduce con el router real y preparaciones ficticias. Corrección
y comprobaciones: `docs/PROGRAMA_ADAPTATIVO.md`.

Archivar una preparación personal no elimina el programa del catálogo, sus
pruebas ni baremos. En esta tarea no se archiva ninguna preparación de Javier
ni se borran sus marcas. La propuesta de pausa reanudable y un único programa
generador de sesiones se confirma posteriormente en STR-026 y se implementa
con STR-027; no formaba parte de esta corrección de identidad.
La convivencia con prescripciones simultáneas requiere coordinación global;
los progresos separados por preparación no equivalen a esa coordinación.

## STR-026 · Pausar y retomar conservando el progreso · 04/10/2026

Javier acepta conservar varias preparaciones personales y tener una sola
generando entrenamientos. Activar otra pausa la anterior; retomarla pausa la que
esté activa. Se conservan objetivos, referencias, marcas, decisiones y resultados
propios de cada preparación, sin archivar el programa ni alterar el catálogo.
Retomar requiere adaptar a la fecha y situación actuales, no ejecutar la semana
antigua pendiente. La reevaluación puede solicitarse y será necesaria cuando las
entradas no sean utilizables; no implica siempre un test máximo.

**Implementado con STR-027 en desarrollo.** Política de agenda, continuidad y
revisión al retomar: `docs/PROGRAMA_ADAPTATIVO.md`. Javier propone además elegir
solo carrera, solo fuerza/rendimiento o el conjunto dentro de una preparación.
Se recomienda una selección explícita de objetivos entrenados, independiente
del catálogo de pruebas. La confirmación e implementación se registran debajo.

## STR-027 · Selección, cambio y continuidad de un programa · 04/10/2026

Javier confirma implementar el recorrido completo con Clean Architecture.
Cada preparación conserva su elección: preparación completa, solo carrera o
fuerza y otras pruebas. Se muestran y exigen únicamente los datos del alcance
elegido; las pruebas y baremos del catálogo se conservan. Ambos motores siguen
aportando propuestas al mismo coordinador, también cuando participa uno solo.

El servidor permite un solo generador por usuario. Activar o retomar requiere
aceptar una propuesta actual que indique qué otra preparación se pausará.
El cambio es atómico, conserva resultados, cancela únicamente sesiones
automáticas sin empezar y rechaza una ejecución en curso. Cambiar la selección
queda pendiente de aceptación; guardar ese borrador no cambia la pauta activa.
Retomar utiliza el calendario actual y comprueba vigencia/contexto; el historial
compatible de carrera de otras preparaciones aporta carga, no sustituye su marca.
La continuidad posterior conserva el alcance y sigue siendo automática.

Migración `20261004012000` aplicada solo en desarrollo. Contratos, comprobaciones
y límites deportivos: `docs/PROGRAMA_ADAPTATIVO.md`. No cierra la política
pendiente de controles específicos ni la priorización por metas de fuerza.

## STR-028 · Mi semana muestra el programa en curso · 04/10/2026

Javier confirma que «Mi semana» debe mostrar únicamente la tarjeta del programa
en curso, incluyendo el estado que requiere revisar datos. Los borradores,
preparaciones pausadas y terminadas se consultan desde «Mi plan»; no compiten
por espacio ni invitan a iniciar otro programa en la agenda. Si no hay programa
en curso, la agenda explica cómo activar o retomar una preparación.
El filtro de tarjetas conserva el historial y los entrenamientos extra.
Implementación y comprobaciones: `docs/PROGRAMA_ADAPTATIVO.md`.

## STR-029 · Completar estrategias por objetivo sobre el coordinador común · 05/10/2026

Javier aprueba avanzar con selección deportiva por objetivo, ejercicios
específicos/regresiones/apoyos, calibración guiada cuando falten datos, evolución
por bloques, adaptación de la estrategia y alternativas de dosis para el
coordinador. Se conservan estrategias de servidor, coordinación común y gestor
del ciclo; no se crea otro planificador deportivo en Flutter ni se duplican
reglas por ejercicio u oposición. Primera ampliación: flexiones, plancha y
agilidad, con regresiones de carrera y posterior extensión por el mismo contrato.

**Primer tramo implementado en desarrollo el 06/10/2026 (STR-032).** La v3
selecciona principal/apoyo calibrado y fases por respuesta; no activa todo
el banco ni cierra controles máximos o prioridades por déficit. El detalle y las condiciones de cierre están en
`docs/PROGRAMA_ADAPTATIVO.md`. Los 1/2/3/4/6/12 meses son horizontes de
preparación comprobados, no mesociclos obligatorios. La duración exacta de
bloques, controles y reducciones sigue requiriendo reglas por objetivo y
respuesta; no se aprueba una cadencia fija por esta conversación.

## STR-030 · Revisar la experiencia práctica de los bloques · 06/10/2026

Javier aclara que su preocupación por regresiones no descarta STR-029. Mantiene
la dirección de fases deportivas con sesiones adaptativas y pide comprenderla
mediante pantallas navegables, evolución ilustrativa y responsabilidades antes
de incorporar las reglas nuevas. La variedad debe tener finalidad deportiva y
permitir sesiones agradables sin perder especificidad ni comparabilidad.

La maqueta es una propuesta de experiencia, no una implementación del selector
ni aprobación de dosis o duraciones. El detalle está en
`docs/PROGRAMA_ADAPTATIVO.md`. Se conserva STR-029 como siguiente bloque.

## STR-031 · Omitir calentamiento sin alterar la progresión · 06/10/2026

Javier establece que el calentamiento guiado pueda omitirse y aclara que
completarlo tampoco debe modificar por sí solo la progresión. Esta elección no
penaliza la ejecución del trabajo principal ni cambia las rutinas
posteriores. Se registra separada de las series de entrenamiento y no se
convierte en calentamiento completado ni habilita aumentos de carga.
Los resultados e incidencias reales conservan su efecto en la adaptación.
**Implementado y comprobado en desarrollo, 06/10/2026.** El guiado de rendimiento
contiene pasos concretos con temporizador; omitirlos pasa al trabajo principal.
Una comparación con ejecuciones reales acredita igualdad de fase, dosis y
progresión posterior con guiado completado/omitido. Detalle del ejecutor en
`docs/PROGRAMA_ADAPTATIVO.md`.

## STR-032 · Estrategias, fases y calibración v3 · 06/10/2026

Javier autoriza implementar STR-029 y las pantallas propuestas, conservando
carrera. La v3 añade selección por objetivo, referencias independientes por
medición, principal/apoyo calibrado, alternativas sin accesorios, fase real y
previsión, comprobación submáxima que sustituye trabajo y guiado de rendimiento
omisible. No crea un motor en Flutter ni borra pautas/resultados anteriores.
`running_plan_v5` y su adaptador no se redefinen. Migración `20261006000000`
aplicada solo a desarrollo. Parámetros y alcance verificable en
`docs/ESTRATEGIAS_RENDIMIENTO_V3.md`; controles máximos y prioridades por déficit
siguen separados y pendientes. Los plazos operativos no se presentan como
mesociclos científicamente óptimos.

## STR-033 · Un único contexto de disponibilidad y material · 06/10/2026

Se corrige la duplicidad observada por Javier: Perfil y «Mi programa» editan el
mismo `performance_training_contexts`, que ya consume el coordinador. Días
concretos y minutos totales; material exacto del catálogo con selección y
retirada; confirmación de actualidad y limitaciones. Las preferencias antiguas
se conservan como ayuda inicial, sin inventar días ni interpretar «gimnasio»
como disponibilidad de cada aparato. Guardar contexto no reinicia el programa
ni borra resultados: entra en la siguiente adaptación. El cuestionario de
carrera integrado reutiliza la disponibilidad común y mantiene sus datos
deportivos propios. RPC de lectura `get_training_context_settings`, migración
`20261006001000`, aplicada solo en desarrollo. Detalle:
`docs/PROGRAMA_ADAPTATIVO.md`.

## UI-007 · Consultar con barra; configurar y entrenar en pantalla dedicada · 06/10/2026

Javier confirma conservar la posición de cada sección de consulta. Volver a
pulsar su destino activo abre la raíz. Configurar el programa/contexto,
registrar una marca, crear ejercicios, editar sesiones y ejecutarlas se abren
en el navegador raíz, sin barra inferior ni rail. Los formularios avisan solo
ante cambios sin guardar; los editores guardan borradores recuperables, con
aviso si los cambios incompletos no pueden guardarse. Salir del ejecutor
conserva series confirmadas y permite retomar; no equivale a abandonar.
La salida se comprueba en `GoRoute.onExit`, también para cambios de ruta.
Detalle, alcance y límites: `docs/VISUAL_DESIGN.md`.

## DEV-002 · Guardar y subir cada bloque validado · 06/10/2026

Javier confirma que la app de su PC es el estado funcional más actualizado y
pide conservarlo al consolidar Git. Después autoriza expresamente «Sí, guardar
y subir cada bloque validado». Al cerrar un bloque se revisan cambios y archivos
nuevos, se ejecuta la verificación correspondiente y se hace commit y push.
Si algo falla, se conserva el trabajo y se explica el pendiente. No se reduce
la verificación por el plan contratado ni se importan versiones de otros chats
sin contrastarlas con el código local. Procedimiento en `AGENTS.md`.

## UI-008 · Refresh de recorridos, sin cambiar el motor · 06/10/2026

Javier acepta la revisión general y autoriza su implementación por tramos
verificados. La identidad visual se mantiene. Se priorizan navegación previsible,
conservación del trabajo y un siguiente paso claro, incluyendo el panel admin.
`go_router` gestiona todas las pantallas; los diálogos mantienen su naturaleza
modal. Clean Architecture no obliga a convertir widgets con campos, pestañas o
animaciones en StatelessWidget: el estado temporal de presentación es legítimo.
No se introducen reglas de entrenamiento ni consultas directas a Supabase en los
nuevos widgets. El algoritmo se gestiona en otro chat y queda fuera de este
refresh, al igual que cambios o despliegues en producción.

Alcance implementado, verificaciones y pendientes en `docs/VISUAL_DESIGN.md`.

### Ratificación de UI-008 · 07/10/2026

Javier aprueba continuar el refresh de recorridos propuesto a partir del mapa
actual: fiabilidad/retorno/refresco primero, luego Inicio/Mi plan, lenguaje,
Evolución, Biblioteca, admin y cuenta. Los motores se pulirán en sus tareas
propias. El informe pegado se reconcilia con lo ya implementado, sin rehacerlo
ni sustituir el código actual por versiones anteriores. Estado y cierres en
`docs/REFRESH_STATUS_2026_10_07.md` y `docs/VISUAL_DESIGN.md`.

Quedan comprobados el refresco al regresar y el guardado editorial retenido.
Javier reafirma `go_router` para pantallas y `Navigator` para modales; se unifican
los retornos restantes del editor/carrera. Javier pide continuar y se cierra
Inicio/Mi plan con programa en curso, semana y pendientes, manteniendo calendario,
preparaciones y Biblioteca. El resumen distingue guardar una preparación de
iniciar su programa y no traslada reglas deportivas a Flutter. Alcance, pruebas
e imágenes actuales en `docs/REFRESH_PLAN_2026_10_07.md`. El siguiente tramo UX
es Evolución/Marcas, filtros e historial antiguo.

UI-011 cierra después resultados e historial consultable, conservando el límite
UI-010 y las comparativas nuevas como pendiente. El siguiente bloque UX es
Biblioteca: vídeo y gestión de ejercicios propios. Detalle e imágenes del código
actual en `docs/REFRESH_EVOLUTION_2026_10_07.md`.

## Regla para nuevas decisiones

Una entrada debe ser concreta y comprobable. Si todavía faltan datos, se
registra la pregunta como pendiente en lugar de completar huecos con una
suposición. Los detalles, fórmulas, fuentes y límites pertenecen al documento de
dominio enlazado; este índice debe seguir siendo breve.
