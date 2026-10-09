# Roadmap de EntrenaOP

**UI-024, 09/10/2026 · gesto de volver verificado:** páginas explícitas de Flutter
y gesto desde el borde en Android/iOS/web, manteniendo flecha, scroll y pestañas. Sesiones
y formularios consultan sus protecciones antes de salir; cancelar permite repetir
el gesto y mantiene los datos. Javier precisa que Android debe ofrecerlo también
con navegación de tres botones, además de atrás del sistema: implementado.
Análisis limpio, 706 pruebas completas correctas con la omisión web existente;
51 regresiones relacionadas incluyen ambos móviles. La primera verificación
acreditó además nueve regresiones en Chrome. El banco web necesitó normalizar en memoria
dos rutas generadas por Flutter en Windows; no se modificó el SDK. Requiere hot
restart. [Implementación y límites](VISUAL_DESIGN.md). Nuevo gesto Android físico,
iPhone físico y un nuevo
recorrido autenticado siguen pendientes. El único siguiente bloque recomendado
continúa siendo la revisión de Javier de preparación → Mi plan → Hoy.

**UI-022, 09/10/2026 · ajustes cotidianos cerrados:** descarte confirmado de
ejecución en curso y series, con cita restaurada e historial cerrado protegido;
Perfil sin acceso duplicado; Añadir entrenamiento en agenda; días/minutos
separados; FAS con carga acotada y reintento. Análisis limpio, 685 pruebas
completas correctas con una omisión web existente, captura de Disponibilidad
y tres pruebas SQL con `ROLLBACK`. 134 migraciones coincidentes en desarrollo.
[Recorridos, contrato y límites](UX_REVIEW_2026_10_09.md).

El único siguiente bloque recomendado continúa siendo la revisión pausada de
Javier del recorrido preparación → Mi plan → Hoy, por estados reales. Este
cierre no acredita gimnasio, iPhone físico ni recorrido Flutter autenticado
nuevo. Los pendientes de negocio, motores, vídeo y comparativas siguen aparte.

**UI-021, 08/10/2026 · coherencia localizada cerrada:** referencias y meta de
carrera mantienen campos separados, selección completa y ayudas legibles.
Mi plan sin programa ofrece Elige una preparación antes de la semana, diferencia
borrador/pausa/finalización y resume el contexto común de disponibilidad/material.
Inicio usa Preparaciones y no elige la primera entre varias sin programa activo.
El bloqueo por sesión abre la ejecución concreta y vuelve a la misma propuesta,
conservando la semana; retomar después mantiene el bloqueo y resolverla permite
revisar la activación. Tarjetas y portadas conservadas. Análisis limpio y 671
pruebas completas correctas con la omisión web existente; capturas de fixtures
revisadas y 133 migraciones coincidentes en desarrollo, sin cambios SQL.
[Recorrido, evidencia y límites](PLAN_COHERENCE_2026_10_08.md).

El único siguiente bloque recomendado es la revisión pausada de incoherencias
que Javier quiere hacer, por recorrido y estado real. Este cierre no acredita
una prueba autenticada nueva ni el uso entrenando. Gimnasio, iPhone físico y
primera entrada Android sin permiso quedan como validaciones posteriores.
Negocio Free/Pro, motores, vídeos y comparación configurable siguen aparte.

**UI-020, 08/10/2026 · tiempo y salidas verificados:** corregido el valor de
segundos que el temporizador escribía sin formato en Tiempo realizado. 20 se
muestra como 0:20 y se confirma como 20 segundos; también comprobados 90 y 3601.
La flecha ofrece seguir, retomar o abandonar conservando resultados con motivo.
Cancelación, error/reintento y sincronización pendiente mantienen su contrato.
Diálogos desplazables a 320 px con texto doble. Análisis limpio en app/admin/
entrena_ui y baterías completas de 630/91/6 pruebas correctas, con las dos
omisiones existentes; 30 regresiones específicas correctas.
[Detalle](SESSION_CONTROLS_2026_10_08.md).

**IOS-002, 08/10/2026 · audio del simulador comprobado:** la copia del Mac y la
app instalada seguían en 98e037e, antes de incorporar plugin y WAV. Actualizada
sin cambios de código a 774361b y reconstruida: banco iOS compila, arranca y
confirma reproducción de todos los avisos. Javier confirma «Sí, ahora suena».
Análisis limpio, 621 pruebas correctas con la omisión web; app principal
relanzada con Supabase de desarrollo. La vibración estaba activada y sus llamadas
no dieron errores. [Evidencia y límites](IOS_DEVELOPMENT.md).

**HAPT-001, 08/10/2026 · vibración física confirmada en Samsung:** Javier confirma
que funciona en SM-A326B/Android 13 al conceder el permiso de notificaciones.
El log anterior acreditó que Samsung cancelaba los avisos por tenerlas
desactivadas para EntrenaOP. La prueba manual pide el permiso y respeta su
denegación; análisis limpio, 653 pruebas correctas con la omisión web existente
y compilaciones Android/iOS correctas. Percibe un pequeño adelanto respecto al
sonido, aceptable y sin medir. La primera sesión activa ofrece ahora el permiso
si falta en Android 13+, con explicación, Permitir avisos o Ahora no y recuerdo
local para no repetirlo. La prueba manual sigue disponible. Este nuevo recorrido
de entrada requiere comprobación en un Android físico sin permiso.
[Evidencia y límites](WORKOUT_AUDIO_2026_10_08.md).

Javier aclara que ya ha comprobado parcialmente en Android el recorrido de
avisos, guardado, salida/reanudación y resultado. El uso entrenando en el gimnasio
queda como validación posterior, junto con volumen/silencio, música y auriculares.
iPhone físico y primer uso Android sin permiso conservan sus pruebas pendientes;
no se exige realizarlas ahora para continuar con la revisión de incoherencias
que Javier quiere mostrar. El simulador no acredita sensación física y segundo
plano mantiene su alcance pendiente. Descartar resultados registrados, negocio
y motores continúan aparte.

**UI-019, 08/10/2026 · correcciones localizadas verificadas:** los vídeos de
Javier permiten reproducir la ausencia de abandono en el cierre final y el
ancho fijo de los días en Mi semana. Ambos corregidos conservando diseño y
contratos. Cuenta de trabajo añade los pitidos 3, 2, 1 confirmados por Javier.
Análisis limpio, 621 pruebas completas correctas con la omisión web existente,
regresiones de fallo/reintento/sincronización, anchos y restauración, además de
tres capturas de semana actual y banco web compilado. Cuenta real de cinco
segundos en Chromium con tres pitidos finales y final aceptados, sin errores.
[Cambios, evidencia y límites](SESSION_CONTROLS_2026_10_08.md).
UI-020 amplía la salida con opciones; el posible descarte total sigue pendiente
de contrato. La recomendación original de escucha en el Mac queda comprobada
en IOS-002; este arreglo por sí solo no acredita un cierre global.

**UI-018, 08/10/2026 · sonido implementado, revisión nativa abierta:** corregido
el adaptador que usaba SystemSound.alert, ignorado en Android/iOS/web. Cinco
WAV locales y audioplayers 6.8.1; preparación/inicio/mitad/diez segundos/final
en trabajo y descanso, sin duplicar ni reproducir hitos pasados. Preferencias
independientes, prueba explícita y fallos aislados. Análisis limpio app/admin,
606 y 91 pruebas completas correctas con las omisiones existentes, 27 específicas,
reproducción real aceptada en Chromium y APK debug compilada. Se mantiene el
aspecto de la app y la configuración iOS del Mac. No modifica motores, negocio,
SQL ni producción. [Recorrido, evidencia y límites](WORKOUT_AUDIO_2026_10_08.md).

El recorrido recomendado originalmente fue actualizar y reiniciar completamente
la app de desarrollo en el Mac, compilar el plugin nuevo y escuchar Probar sonido
y un intervalo/descanso. SPM revisado por configuración, sin acreditar aún ese
arranque o escucha en esa comprobación; IOS-002 añade después esa evidencia.
HAPT-001 añade después la confirmación física en Samsung; música/auriculares,
sesión real y segundo plano no se dan por comprobados. Javier comunica una
revisión superficial positiva en
simulador de guardado, Evolución y fotografías; no cierra la auditoría
autenticada global. Recuperación de correo nativa puede esperar. Comparativas
configurables, seguridad de publicación, vídeos, negocio y motores mantienen
su alcance aparte. Esta entrada sustituye las recomendaciones previas ya
realizadas, sin actualizar sus fechas históricas de comprobación.

**UI-017, 08/10/2026 · tramo de formularios cerrado:** nuevo programa admin y
selectores del formulario compartido de ejercicios muestran sus selecciones
completas con texto grande. Nombre/tipo se conservan tras fallo y reintento;
crear programa continúa creando un borrador. Los controles de foto se sitúan
bajo la vista previa cuando necesitan espacio, conservando imagen y encuadre.
No cambia Inicio/Mi plan, datos, permisos, rutas, motores, negocio o producción.
Análisis limpio de app/admin/paquete; 591, 91 y 8 pruebas completas correctas,
con sus omisiones existentes. Seis recorridos visuales y 12 imágenes revisadas.
[Alcance, imágenes y límites](REFRESH_FORMS_2026_10_08.md).

El único siguiente bloque recomendado es la comprobación autenticada de los
recorridos actuales de app/admin. El navegador disponible está sin sesión;
esa prueba queda pendiente. Este cierre es localizado, no cierra todo el pulido
transversal. Comparación configurable, revisión física y pendientes de
publicación de UI-013 permanecen abiertos. iPhone/iOS espera al entorno Mac de
Javier; vídeos, negocio y motores mantienen sus tareas aparte.

**UI-016, 08/10/2026 · tipo histórico y filtro cerrados en desarrollo:**
Evolución filtra Carrera, Fuerza y acondicionamiento, Mixta y Sin clasificar,
combinados con preparación, fechas, estado y paginación. Servidor conserva tipo
y política al iniciar; editar la plantilla no altera el dato. Las sesiones
anteriores mantienen su clasificación ausente y siguen consultables. Selectores
completos con texto ampliado. Análisis limpio, 591 pruebas completas y 25
regresiones específicas correctas (una exclusiva web omitida); tres recorridos
de captura y 15 imágenes revisadas. Solo desarrollo: 133 migraciones coincidentes
y cuatro pruebas SQL con `ROLLBACK` correctas. No cambia Inicio/Mi plan, fotos,
código admin, paquetes, motores, negocio ni producción.
[Recorrido, criterio y evidencia](HISTORY_SESSION_TYPE_2026_10_08.md).

El único siguiente bloque UX recomendado es el pulido localizado de textos,
estados y accesos de app/admin, conservando aspecto y trabajo ya terminado.
Comparación configurable y recorrido autenticado global siguen pendientes.
MAIL-001 ya acredita recepción y recuperación web confirmadas por Javier;
iPhone/iOS espera a su entorno Mac. Keychain, eliminación de cuenta y acceso a
privacidad quedan registrados para preparar publicación. Vídeos, negocio y
motores siguen aparte. Los cierres anteriores conservan sus fechas y pruebas;
esta entrada sustituye sus recomendaciones de siguiente bloque ya realizadas.

**UI-015, 08/10/2026 · comparativas guardadas cerradas en desarrollo:**
«Marcas y resultados» permite elegir prueba y dos fechas, consultar cambio en
repeticiones/tiempo y conservar selección durante refresco, fallo o entrada de
otra evaluación. Tropa exige versión, columna, hito, unidad y dirección iguales;
FAS compara marcas de su catálogo versionado compatible, mostrando edades;
los controles de 2 km conservan RPE y se mantienen separados de evaluaciones.
Los resultados configurables siguen mostrando snapshot/puntos/intentos; faltan
unidad y protocolo históricos completos para compararlos. Tarjetas con estado
de expansión propio y selectores sin recortes con texto grande. Análisis limpio,
579 pruebas de raíz correctas (una exclusiva web omitida) y seis recorridos
de captura, con 19 imágenes revisadas. No modifica Inicio/Mi plan, fotografías,
admin, motores, negocio, paquetes compartidos, SQL ni producción. No cierra toda
Evolución ni la revisión autenticada. Detalle en
[MEASUREMENT_COMPARISON_2026_10_08.md](MEASUREMENT_COMPARISON_2026_10_08.md).
El único siguiente bloque UX recomendado es definir el dato histórico de tipo
deportivo antes de implementar su filtro: la ejecución actual no lo conserva;
no se infiere de una plantilla mutable ni se reclasifican sesiones antiguas sin
evidencia. Se explicará el cambio de contrato antes de aplicarlo. Comparativas
configurables pendientes. Correo/dispositivo real se comprobarán cuando Javier
pueda; vídeos, negocio y motores siguen aparte.

**UI-014, 08/10/2026 · detalle de programa admin cerrado en desarrollo:**
índice fijo de Contenido, Evaluación y Entrenamiento; los saltos conservan las
secciones y sus estados. Sesiones se sitúa junto a la preparación deportiva.
Baremo publicado se presenta como consulta; módulos y cobertura de fuerza
ofrecen reintento. Formularios y acciones admiten texto grande y pantalla estrecha;
las pruebas conservan estado propio al recargar y no comparten el almacenamiento
del scroll. No se presenta una prueba ya vinculada como una prueba inexistente.
Análisis admin limpio, 89 pruebas y seis recorridos de captura correctos
(95 en la ejecución final conjunta), con una captura optativa existente omitida.
24 imágenes de widgets actuales con datos ficticios y tema compartido.
Sin cambios en deportista, paquetes, SQL, permisos, motores, negocio o producción.
Se adelanta este tramo puntual del pulido mientras Javier no puede completar
la prueba del correo desde el móvil; Cuenta permanece abierta para su recorrido
real. No cierra el resto de formularios del pulido transversal ni acredita
revisión autenticada. Detalle en [REFRESH_ADMIN_2026_10_08.md](REFRESH_ADMIN_2026_10_08.md).
El único siguiente bloque UX recomendado sigue siendo Evolución: definir y
mostrar comparativas de mediciones compatibles y el filtro deportivo, sin
inferir protocolos ni tipo histórico de una plantilla actual. Antes de ampliar
sus contratos se explicará el criterio y el impacto; el correo real se comprobará
cuando Javier disponga del dispositivo. Vídeos, negocio y motores siguen aparte.

**UI-013, 08/10/2026 · Cuenta comprobada en desarrollo, recorrido real abierto:**
recuperación con sesión diferenciada por el SDK, pantallas persistentes de correo,
confirmación y contraseña actualizada, errores con campos conservados y reenvío
limitado. Auth autoriza el cambio; URL y marcador local no conceden derechos.
Respuestas tardías no restauran otra cuenta. Retornos web/móvil configurados
solo en desarrollo, conservando confirmación de correo, límites y MFA remotos.
Análisis limpio en ambas apps; 563 pruebas de raíz y 85 de admin correctas, con
una exclusiva web y una optativa de admin omitidas. Tres recorridos de captura,
21 imágenes de widgets actuales; web debug y APK debug compilados. Sin cambios
SQL, RLS, motores, negocio, Inicio/Mi plan o producción. No acredita auditoría
integral de seguridad del login. Pendientes: correo real, enlaces caducados o
reutilizados en servidor y recorrido de nuevo acceso en dispositivo físico;
iOS no compilado desde Windows. Detalle en
[REFRESH_ACCOUNT_2026_10_08.md](REFRESH_ACCOUNT_2026_10_08.md).
El único siguiente bloque UX recomendado es Evolución: filtro por tipo deportivo
y comparativas de mediciones compatibles. Antes de dar por cerrado el recorrido
de Cuenta hay que completar su comprobación real; no se presenta como validado.
Pulido transversal/admin y retirada de ejercicios personales permanecen después;
vídeos, negocio y motores mantienen sus trabajos aparte.

**UI-012, 08/10/2026 · Biblioteca y fotografías cerrado en desarrollo:**
corregida la pérdida de portadas web al regresar, conservando aspecto y
encuadres. Biblioteca ofrece vídeo bajo demanda/enlace externo y edición de
ejercicios personales privados con foto, borrador protegido, error persistente
y retorno conservando búsqueda. RPC de edición con autoría/validación en
servidor; instantáneas históricas preservadas. Análisis limpio en ambas apps,
544 pruebas de raíz y 85 de admin correctas (una exclusiva web y una optativa
de admin omitidas respectivamente), cinco recorridos de captura, doce imágenes
de widgets y dos del navegador. Prueba comparada de cinco retornos en Chromium:
proveedor anterior pierde la imagen, proveedor corregido la conserva.
Compilación web debug correcta; 132 migraciones coincidentes y tres baterías
SQL correctas con `ROLLBACK`, solo en desarrollo. No modifica producción,
motores, diseño de Inicio/Mi plan ni negocio Free/Pro.
Límites: recorrido autenticado/dispositivo pendiente; runner web automatizado
no arrancó, sustituido para las fotos por reproducción compilada y navegador
real. Sin borrado/archivado de ejercicios ni resolución de edición concurrente.
Detalle en [REFRESH_LIBRARY_2026_10_08.md](REFRESH_LIBRARY_2026_10_08.md).
Ese cierre dio paso a Cuenta, implementada después en UI-013 con los límites
indicados arriba. Comparativas de Evolución y pulido transversal/admin siguen
después; negocio y motores mantienen sus trabajos aparte.

**UI-011, 07/10/2026 · resultados e historial cerrado:** Marcas abre una consulta
por preparación; registrar vuelve a los formularios existentes y actualiza al
retornar. Historial con preparación, fechas y estado, páginas de 30 y reintento
sin perder datos. El refresco mantiene la profundidad consultada, también con
más de mil sesiones; cambiar cuenta renueva raíz y vistas de resultados.
`flutter analyze` limpio, 537 pruebas completas y nueve recorridos de captura
correctos, con 22 imágenes de widgets reales y datos ficticios. No acredita
consulta autenticada a Supabase ni dispositivo real. No cambia SQL, motores,
admin, paquetes compartidos, Inicio/Mi plan, portadas ni catálogo.
Alcance, imágenes y límites en [REFRESH_EVOLUTION_2026_10_07.md](REFRESH_EVOLUTION_2026_10_07.md).
Las comparativas nuevas y el filtro por tipo deportivo siguen pendientes: no
se deducen de plantillas actuales ni se mezclan protocolos/baremos.
Este cierre dio paso a Biblioteca, implementada después en UI-012 para consulta
de vídeo y edición de ejercicios propios, respetando autoría e historial.
Cuenta y pulido transversal/admin permanecen después; negocio Free/Pro y
motores se trabajan aparte, manteniendo UI-010.

**UI-010, 07/10/2026 · refresh separado del negocio:** la base sigue siendo la
restaurada en COM-003. Inicio/Mi plan ya están cerrados; no se reabre su diseño
ni el de las tarjetas, catálogo o preparaciones para introducir Free/Pro.
En esa delimitación se recomendó Evolución/Marcas: destino de
resultados, filtros e historial antiguo. Descubrimiento comercial y derechos
de cuenta se abordarán aparte. La delimitación inicial fue documental;
UI-011 implementa el siguiente tramo acotado, sin nueva prueba autenticada.

**COM-003, 07/10/2026 · reversión del último bloque:** se retira `308ae18` y se
recuperan código y pruebas de `82d74df`, conservando el historial de Git. No hay
selector Free/Pro, guardas de simulación ni ficha básica añadida por ese bloque;
la reorganización UI-009 permanece pendiente. No cambia admin, paquetes
compartidos, SQL, datos remotos o producción. El trabajo comercial se deja para
un chat aparte: cerrar capacidades, derechos de servidor y ciclo de pago antes
de adaptar las vistas de la app. No retomar la simulación descartada COM-002.
Validación de la restauración: `flutter analyze` limpio y las 505 pruebas
completas del estado anterior correctas; código y pruebas sin diferencias
respecto a `82d74df`. Compilación web debug correcta, sin despliegue.

**UI-008, 07/10/2026 · Inicio/Mi plan cerrado:** Mi plan presenta programa en
curso, semana y sesiones pendientes, con estados separados para preparaciones
por configurar, pausadas y finalizadas. Abre el programa directamente, conserva
el vínculo de la sesión al consultar/retomar y retira accesos duplicados a
Biblioteca. Inicio comparte estados/siguiente paso y conserva su calendario.
El resumen de Mi plan se carga al visitar la raíz, se actualiza al regresar y
se renueva al cambiar de cuenta, conservándolo al renovar la misma sesión.
Análisis limpio, 505 pruebas completas de raíz y ocho capturas verificadas;
20 imágenes de widgets actuales con datos simulados. Sin cambios en admin,
SQL, motores o producción; pendiente la revisión autenticada en dispositivo.
Detalle en [REFRESH_PLAN_2026_10_07.md](REFRESH_PLAN_2026_10_07.md).
Ese cierre dio paso a Evolución/Marcas, completado después en UI-011 con
resultados e historial consultable.

**UI-008, 07/10/2026 · guardado editorial cerrado:** pruebas, reglas, tramos,
mínimos, importación, clonación y vinculación de estrategia conservan los
formularios hasta persistir y permiten reintentar sin perder campos. Se mantienen
las confirmaciones y reglas actuales; cancelar una revisión devuelve al
formulario. Un fallo de recarga posterior no habilita un nuevo envío del mismo
guardado. Incluye mínimos a 320 × 480 con texto 2×. Análisis limpio en ambas
apps, 482 pruebas de raíz, 85 de admin (una optativa omitida) y seis de
`entrena_ui`. Sin SQL, motores o producción; falta revisión autenticada real.
Detalle en `REFRESH_STATUS_2026_10_07.md` y `VISUAL_DESIGN.md`. El único siguiente
tramo UX recomendado es Inicio/Mi plan orientado a programa, semana y pendientes;
el bloque deportivo conserva su prioridad y se gestiona fuera de este refresh.

**UI-008, 07/10/2026 · refresco cerrado:** Inicio, Perfil, Mi semana y Evolución
actualizan al regresar sin desmontar ramas ni perder selección/posición. Se
conserva la última consulta y se descartan respuestas antiguas en los Cubits
afectados. Análisis limpio y 482 pruebas completas de raíz; sin cambios en SQL,
motores o producción. No acredita el recorrido autenticado en dispositivo.
Comparación del informe anterior en `REFRESH_STATUS_2026_10_07.md`. El único
siguiente tramo UX es completar el guardado retenido editorial de admin, antes
de reorganizar Mi plan y Evolución. El bloque deportivo conserva su prioridad.

**Inventario visual, 07/10/2026:** [mapa de app/admin](SCREEN_MAP_2026_10_07.md)
con imágenes de widgets actuales, estados, recorridos y mejoras diferenciadas.
Análisis de ambas apps limpio; 474 pruebas de raíz y 74 del admin correctas
(una optativa omitida). No modifica SQL, motor ni producción; no cierra la
revisión autenticada. El siguiente tramo UX sigue siendo guardado retenido y
refresco entre secciones; el deportivo, controles de protocolo y prioridades
por déficit.

**UI-008, 06/10/2026 · primer tramo de fiabilidad y navegación:** admin pasa a
`go_router` con URLs por identificador, verificación de acceso y recursos,
reintentos y renovación de la pila al cambiar de cuenta. Las evaluaciones
oficiales y el editor admin protegen cambios pendientes. Referencias, creación
de programa y edición de ejercicios conservan el formulario hasta confirmar
guardado. El cierre del entrenamiento respeta el origen, permite abrir el
resultado concreto y admite notas largas/texto grande. Búsquedas del admin
conservadas al recargar; laboratorio separado de la edición habitual.

Comprobación: análisis de ambas apps sin incidencias, 474 pruebas de raíz,
74 del admin (una omitida por su condición existente), cinco de `entrena_ui`
y compilaciones web correctas. Pruebas con repositorios simulados; no acredita
el recorrido autenticado en dispositivo ni protege el cierre del navegador o
proceso. No cambia SQL, algoritmos, permisos ni producción. Este tramo queda
validado, no todo el refresh. Alcance y pendientes en `VISUAL_DESIGN.md`.

El único siguiente tramo **UX** recomendado es completar el guardado retenido
de los restantes formularios editoriales y el refresco entre secciones sin
perder estado, antes de reorganizar Mi plan y Evolución. El siguiente bloque
**deportivo** permanece sin cambios: controles de protocolo y prioridades por
déficit, gestionados fuera de este refresh.

**Consolidación, 06/10/2026:** se conserva el estado local confirmado por Javier
en el punto de recuperación `236f8b7`, sin importar versiones antiguas. Se
separan pendientes y borradores por usuario, con 17 regresiones nuevas y 470
pruebas completas de la app correctas. v1 permanece intacto: los pendientes se
recuperan mediante comprobación remota del propietario; los borradores sin
propietario requieren recuperación explícita, aún sin pantalla de importación.
`website/` conserva su repositorio independiente y una copia completa en un
bundle versionado. DEV-002 autoriza commit y subida de cada bloque validado;
procedimiento permanente en `AGENTS.md` y detalle en la auditoría. Análisis
final limpio y compilación web del deportista correcta.

**Chequeo general inicial, 06/10/2026:** app, admin, paquetes compartidos y Supabase de
desarrollo contrastados; informe e inventario en
[AUDIT_2026_10_06.md](AUDIT_2026_10_06.md). La auditoría comienza con 123 archivos
modificados y 346 sin seguimiento, entre ellos 81 migraciones aplicadas en
desarrollo. No se crea ningún commit ni se modifica producción.

Análisis limpio, 453 pruebas de raíz, 68 del admin y una omitida por condición
de capturas, seis de `workout_editor_ui` y dos de `entrena_ui`. Compilan las dos
webs y las APK Android debug/release de desarrollo; se corrigió el permiso de
red de release, que aún usa firma de depuración. Pasan las 55 baterías SQL tras corregir una
expectativa antigua del tamaño del catálogo. Windows carece de componentes
del toolchain e iOS no se compila desde este equipo.

El aislamiento y la consolidación recomendados por el chequeo inicial se
abordan en el cierre descrito arriba. Este chequeo no cierra el bloque
deportivo; continúa el único siguiente bloque deportivo de controles de
protocolo y prioridades por déficit. La recuperación explícita de borradores
v1 queda registrada como límite técnico, sin ampliar ahora el motor deportivo.

**STR-033/UI-007, 06/10/2026 · contexto y navegación de tareas:** Perfil y
«Mi programa» usan el contexto real por usuario del coordinador, con días y
minutos concretos y material seleccionable/retirable. Carrera integrada
reutiliza disponibilidad y ofrece una continuación visible. Configuración,
registro de marcas, creación de ejercicios, editores y ejecutor se abren sin
barra; las secciones de consulta conservan su estado. Salidas distinguen
descarte, borrador y sesión retomable. Migración `20261006001000` aplicada
solo en desarrollo; no se redefinen carrera v5 ni su adaptador.

Verificación del recorrido: pruebas de navegación y conservación de campos,
guardado/recuperación de borradores, salida sin abandonar ni perder series,
persistencia del mismo contexto Perfil/programa e aislamiento de cuentas en SQL.
Revisión de capturas de Flutter a 360 px y adaptación a 320 px con texto 2×,
y escritorio de 1000 px. Los formularios de evaluación oficial existentes y
el cierre del navegador/proceso no se reorganizan en este tramo. El siguiente
bloque deportivo recomendado sigue siendo controles de protocolo y prioridades
por déficit; esta corrección no amplía el alcance deportivo de STR-032.

Comprobación el 06/10/2026: 451 pruebas de raíz, 67 del admin (una omitida por
su condición existente) y seis del paquete `workout_editor_ui`; análisis de
ambas apps, compilación web y trece baterías SQL transaccionales sobre desarrollo
instalado. Historial de migraciones enlazado sin diferencias. No acredita el
recorrido autenticado en el dispositivo de Javier ni modifica producción.

**STR-029/031/032, 06/10/2026 · tramo v3 aplicado en desarrollo:**
flexiones, plancha y COD incorporan fase real por respuesta, previsión visible,
principal/apoyo calibrado y alternativas con/sin accesorios. Referencias libres
y temporales independientes; comprobación submáxima que sustituye trabajo;
calentamiento guiado omisible con neutralidad comprobada. La continuidad,
selección, pausa y recuperación conservan sus contratos. Carrera v5 y su
adaptador no se redefinen. Migración `20261006000000` aplicada solo en desarrollo.
Reglas, evidencia y límites: `docs/ESTRATEGIAS_RENDIMIENTO_V3.md`.

Verificación del tramo el 06/10/2026: análisis Flutter limpio, 437 pruebas de la
aplicación del deportista, compilación web y doce baterías SQL transaccionales
contra desarrollo instalado. Se comprueba la identidad de las funciones de
carrera v5 y su adaptador, además de sus regresiones y horizontes. Las capturas
de widgets contrastan las fases a 360 px; no acreditan una revisión autenticada
en el dispositivo de Javier. Las semanas guardadas mantienen su versión; la
selección nueva entra en las siguientes adaptaciones.

El único siguiente bloque recomendado es definir controles de protocolo que
actualicen marcas y prioridades por déficit con datos comparables, antes de
ampliar cuerda/reactividad. No se presenta el banco entero como activado ni una
simulación como eficacia en deportistas reales. Los horizontes no fijan la
duración de mesociclos obligatorios.

**STR-027, 04/10/2026 · selección, pausa y reanudación verificadas:** preparación
completa, solo carrera o solo rendimiento con preguntas y cobertura condicionales.
Un único generador por usuario, cambio aceptado y atómico, conservación del
historial y nueva pauta al retomar con calendario/contexto actuales. Inicio y
agenda distinguen preparación pausada de programa entrenando. Migración
`20261004012000` aplicada solo en desarrollo; análisis limpio, 375 pruebas Flutter,
compilación web y nueve baterías SQL sobre el esquema instalado con `ROLLBACK`.
Los tres modos ejecutan sesiones reales y continúan automáticamente desde sus
resultados; carrera conserva v5. Capturas de widgets a 390 px, sin acreditar
recorrido autenticado en el dispositivo del usuario. Detalle y límites:
`docs/PROGRAMA_ADAPTATIVO.md`. Este recorrido queda comprobado; el bloque
deportivo completo sigue abierto por controles específicos y metas de fuerza.
El único siguiente bloque recomendado continúa siendo el descrito más abajo.

**STR-024, 04/10/2026:** aplicación explícita de datos nuevos a semanas no
empezadas, conservación de semanas realizadas y reinicio administrativo de
ensayos desde desarrollo. Migración `20261004011000` aplicada; análisis limpio,
357 pruebas Flutter, compilación web y cuatro fixtures SQL con `ROLLBACK`.
Detalle y validación: `docs/PROGRAMA_ADAPTATIVO.md`.
No cierra los controles deportivos y metas de fuerza pendientes del bloque.

**STR-023, 04/10/2026:** reabierto el cierre de recorrido tras el vídeo del usuario.
Se corrigen el retorno al cuestionario desde una semana vacía, el cálculo expuesto
como tarea cotidiana y la ausencia de recuperación desde Inicio/agenda. El
programa activo tiene panel propio y continuidad única; las estrategias y el
coordinador existentes conservan sus reglas. La simulación usa un reloj aislado
y el recorrido real de publicación/ejecución, incluyendo adelantos y recuperación.
El detalle de verificación y los límites están en `PROGRAMA_ADAPTATIVO.md`.
Migración `20261004010000` aplicada solo en desarrollo; análisis limpio,
354 pruebas de app, compilación web y 21 baterías SQL distintas con `ROLLBACK`.
Revisión visual de widgets a 390 px. El bloque deportivo completo permanece
abierto por los controles y la aplicación de metas numéricas descritos debajo.

**Instantánea anterior, 04/10/2026 (STR-022):** se declaró cerrado el recorrido de programa y
continuidad automática en desarrollo: fecha/metas, disponibilidad común, paso de
carrera, referencias agrupadas, propuesta y activación; cierre de sesiones →
siguiente semana desde resultados, con revisión ante omisiones completas o
molestias. Control común de 2 km sin desvío a baremos. Revisión informativa de
fuerza por señales/fase, no por contador. Migraciones hasta `20261004009000`.
Análisis limpio, 352 pruebas Flutter, compilación web y 21 baterías SQL distintas
correctos. Revisión visual de widgets; falta recorrido autenticado en dispositivo.

**Tramo recomendado antes de STR-029, integrado en esa ampliación:** cerrar la política deportiva de controles
específicos y de priorización por meta, incluyendo protocolo, motivo, sustitución
de carga, recuperación, registro y efecto sobre decisiones posteriores. No está
implementado por el mero hecho de guardar metas o mostrar revisiones. No ampliar
cuerda/reactividad antes de cerrar ese contrato. Detalle:
`docs/PROGRAMA_ADAPTATIVO.md`. El motor completo de rendimiento sigue abierto.

**Instantánea anterior, 04/10/2026 (STR-021):** aplicado en desarrollo el selector v2
y coordinador v2.1. Referencias explícitas, dosis submáximas, feedback pertinente,
componentes COD, formatos cortos y cobertura. Sesiones mixtas con preparación
compartida y resultados de carrera separados; revisión y continuidad semanal.
Dieciocho baterías SQL verifican recorrido y fronteras con `ROLLBACK`.
Análisis limpio en ambas apps; 348 pruebas de la app y 58 de ADMIN correctas,
compilación web completada y migraciones de desarrollo hasta `20261004006000`.
Detalle vigente: `docs/MOTOR_FUERZA_RENDIMIENTO_V2.md`. Las instantáneas v1 que
siguen describen entregas anteriores, no el selector aplicado hoy.

**Tramo recomendado entonces, sustituido por STR-022:** revisar con Javier las salidas guardadas
y el recorrido autenticado recompilado, contrastando dosis/respuesta antes de
ampliar programación autónoma de cuerda/reactividad. No falta enlazar un selector
local: la aplicación consulta el servidor v2.1. La revisión visual actual abarca
widgets reales, no una prueba autenticada completa en su dispositivo.

**Banco V2 recibido (04/10/2026, STR-020):** revisión y correspondencias completas
con las propuestas anteriores en `docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`.
Se recomienda un banco normalizado de estímulos y recetas reutilizables, sin
duplicar versiones ni activar sus cifras como políticas aprobadas. Persisten
entradas ambiguas, reglas de progresión por concretar y familias ausentes en
los textos nuevos. La V2 no sustituye aún `performance_v1_1`. Se mantiene el
único siguiente tramo de STR-019, con carrera v5 conservando sus reglas.

**Revisión de sesión y programación deportiva (04/10/2026, STR-019):** el vídeo
de Javier confirma que la integración técnica no cierra la dosificación ni
la selección de estímulos previstas. El servidor v1 sigue copiando la dosis
declarada; circuito por componentes y evolución del banco siguen pendientes.
Corregidos campos impropios del circuito fijo, lenguaje e instrucciones de
trabajo, acceso a preparar la semana elegida y continuidad explícita semanal.
El calentamiento nuevo tiene una guía derivada de los patrones del trabajo,
con instantánea histórica inmutable; siete minutos siguen siendo una reserva
aproximada. Migración `20261004002000` aplicada solo en desarrollo.

Conservados los dos textos aportados y revisadas sus 40 fichas, composición,
entradas, porcentajes, compatibilidad y límites de evidencia en
`docs/MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`. No se han activado sus dosis
ni cambiado carrera v5. Verificación técnica: análisis de ambas apps, 344 pruebas
de raíz, 58 de ADMIN y doce baterías SQL transaccionales correctas. La revisión
del vídeo y esas pruebas no acreditan eficacia deportiva ni recorrido manual
de la versión corregida en el dispositivo de Javier.
**Único siguiente tramo:** cerrar el banco parametrizable y las entradas de
capacidad/dosis, y sustituir el selector deportivo de servidor con las regresiones
de fuerza/carrera pertinentes. Este bloque permanece abierto.

**Corrección de usabilidad e integración (04/10/2026, STR-018):** el vídeo de
Javier detectó que una propuesta con sesiones rompía la pantalla al formatear
el día en español. Corregido junto al descanso obligatorio con un solo intento,
las instrucciones de plancha, los detalles de preparación y el acceso duplicado
a carrera. El flujo común admite solo carrera y revisión explícita de la última
semana publicada aún sin empezar, conservando decisiones y cancelando solo sus
pendientes al sustituirla. Migraciones `20261004000000`/`20261004001000` en
desarrollo; análisis y pruebas completas de raíz, regresiones móviles y diez
baterías SQL con `ROLLBACK` correctos. Carrera v5 conserva sus reglas.
Siguiente paso del mismo piloto: comprobar estos recorridos con la sesión real
de Javier. No se acredita todavía esa comprobación desde su dispositivo.

## Fuerza y rendimiento: contrato, catálogo y persistencia (03/10/2026)

Javier confirma empezar por el contrato deportivo y el catálogo antes de
implementar progresión y fatiga. Sus pautas completas siguen siendo el alcance
del bloque: flexiones, dominadas, fuerza con carga, isométricos, cuerda,
saltos/reactividad, COD/agilidad y circuitos. La entrega inicial contiene un
contrato documentado y 63 variantes editoriales en JSON, con dominio puro y
codec en `workout_core` y pruebas de las doce combinaciones de aceptación.

**Tramo comprobado el 03/10/2026:** persistencia aplicada en **entrenaop-dev**,
con 63 perfiles versionados y las 63 variantes como ejercicios públicos de
EntrenaOP. La corrección de Javier ha llevado a materializar las 60 entradas
que quedaron pendientes; la biblioteca debe estar disponible en la app y ser
independiente de cualquier prueba oficial. Los dos enlaces revisados del
borrador CNP son adaptadores opcionales de evaluación. Ambas apps leen los
perfiles desde datos sin dependencias de Supabase en dominio. La plancha de
ensayo queda definida sobre antebrazos. Análisis limpio de ambas apps,
255 pruebas en raíz y 36 en ADMIN junto al contrato compartido; historial de
migraciones contrastado. Pruebas SQL de perfiles, biblioteca, seguridad de
ejercicios, módulos y publicación correctas con `ROLLBACK`. La regresión del
selector carga las 63 variantes y permite buscar/añadir una dominada desde
EntrenaOP. El ejecutor conserva su capacidad actual: falta
ampliar prescripción/resultados, no hay reglas adaptativas de fuerza ni cierre
del bloque funcional. El catálogo mantiene clasificación editorial provisional.

**Avance experimental posterior (STR-007, 03/10/2026):** primera estrategia de
flexiones en dominio puro y laboratorio ADMIN, con lectura del catálogo real,
selección específica/apoyo calibrado, agenda reservada y respuesta simulada.
Las constantes de dosis quedan pendientes de revisión deportiva. El ejecutor
ya distingue esfuerzo prescrito y declarado: RIR/RPE reales permanecen nulos
si no se informan. Análisis limpio en ambas apps; raíz completa, 278 pruebas;
ADMIN y contratos compartidos, 56 pruebas, correctas; compilación web de ADMIN
correcta. Sin cambios SQL ni
publicación automática. Detalle y límites en
[`ESTRATEGIA_FLEXIONES_V1.md`](ESTRATEGIA_FLEXIONES_V1.md).

**Base ejecutable posterior (STR-010, 03/10/2026):** contrato común de objetivos,
pendientes y propuestas en dominio puro, con bloques pertinentes y cobertura
incompleta visible. Comprueba representación de las 63 variantes sin declarar
políticas adaptativas disponibles. El adaptador de flexiones conserva dosis,
versión y estado experimental; ADMIN lo consume. Raíz completa, 292 pruebas,
y ADMIN con contratos compartidos, 73 pruebas, correctas. No hay cambios del
motor/recorrido de carrera ni SQL. No se ha cerrado el bloque de coordinación.

**Criterio deportivo previo (STR-011, 03/10/2026):** Javier solicita explicar y
consensuar progresión y evolución temporal por modelo antes de ampliar dosis.
La [propuesta deportiva](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md) conserva
el alcance completo y los seis horizontes, separando evidencia de parámetros
por revisar. Esta entrega es documental; no modifica carrera ni el laboratorio.

**Avance ejecutable (STR-012, 03/10/2026):** Javier respalda el planteamiento
general. Dominio compartido para repeticiones, carga/repeticiones y segundos
isométricos, con dosis calibradas y respuesta comparable; laboratorio ADMIN
por bloques con ejemplos de flexiones, dominadas, plancha, suspensión y banca.
Los objetivos sin dosificación conservan su estado pendiente. Las constantes
siguen siendo experimentales; no publica sesiones, coordina carrera ni
implementa aún los seis horizontes en fuerza. La investigación incorpora
fuentes militares y CrossFit, sin extrapolar sus protocolos automáticamente.

Verificación de STR-012: análisis limpio en raíz y ADMIN; 312 pruebas completas
en raíz y 98 en ADMIN junto con contratos compartidos, correctas. Incluye
regresiones de progresión, protocolo/montaje, ausencia de datos, retorno entre
bloques y pantalla de 360 px. Se comprueba la compilación web de ADMIN; no se
han modificado SQL, entorno o sesiones del deportista. El bloque global de
planificación conjunta permanece abierto.

**Revisión aplicada (STR-013, 03/10/2026):** Javier revisa el laboratorio y
descarta el campo de series separadas por espacios. ADMIN ahora permite
editar cada serie con su unidad, añadir y quitar filas, conservando valores
al volver. Análisis limpio, compilación web y 41 pruebas completas de ADMIN correctas, con
regresiones de edición/eliminación y pantalla estrecha; renderizado revisado.
Las reglas de progresión y carrera conservan su comportamiento.

**Captura ejecutable (STR-016, 03/10/2026):** el laboratorio permite registrar
resultados ficticios de cada serie, editar/cancelar y conservar la dosis
original. Retira el selector de respuestas prefabricadas y mantiene los
ejemplos explícitos. Dominio experimental v2: condiciones declaradas y carga
real compatible antes de atribuir mejora/dificultad a la dosis pautada. No
hay cambios SQL, publicación o evolución temporal nueva; carrera conserva
su comportamiento.

Comprobación de STR-016: análisis limpio en ambas apps, 315 pruebas completas
de raíz y 52 de ADMIN correctas, compilación web y renderizado del registro revisado. Los
resultados del ensayo siguen siendo ficticios y locales.

**Actualización STR-017 · cierre técnico del recorrido integrado (03/10/2026):**
los tramos experimentales anteriores quedan superados para publicación por
`performance_v1_1` en servidor. Contexto real → referencias por prueba → semana
coordinada → agenda → ejecución → historial → adaptación están implementados
en desarrollo. ADMIN configura estrategias; FAS/Tropa identifican sus pruebas;
64 variantes tienen perfil público (63 v1 y el circuito específico v2).

Verificación: migraciones hasta `20261003016000`, 328 pruebas de raíz, 54 de
ADMIN, análisis de ambas apps y compilaciones web. SQL transaccional: contrato,
catálogo/modelos, seis horizontes, respuesta de calidad, seguridad bajo rol real,
deduplicación e integración, junto a regresiones de carrera. El cuestionario y
la política v5 de carrera permanecen; su adaptador admite tiempo/carga conjuntos.
No se ha realizado una revisión manual autenticada en navegador ni en dispositivo.

**Límites:** dosis operativas pendientes de validación con deportistas; práctica
completa de protocolos no sustituible por apoyos; cámara aparte. Se publica una
preparación respetando agenda global; aún no hay optimización conjunta de todos
los programas activos ni prioridad basada en déficit de baremos.

**Único siguiente bloque recomendado:** piloto deportivo y de usabilidad del
recorrido ya integrado, sin abrir otro laboratorio de dosis desconectado.
Contrato y reglas exactas en
[`MOTOR_FUERZA_RENDIMIENTO_V1.md`](MOTOR_FUERZA_RENDIMIENTO_V1.md).

## Carrera 2 km: cierre técnico del bloque el 01/10/2026

Motor `running_2k_v5` aplicado en **entrenaop-dev**. FAS, Tropa y programas
con prueba vinculada al módulo 2 km usan un único planificador de servidor,
con sus propias marcas y baremos. Reutiliza agenda y ejecutor; no hay IA de
pago ni selector deportivo en Flutter. Incluye objetivos libre/tiempo/margen,
lectura de registros incompletos, contraste del RPE y vuelta gradual tras fatiga.
V3 corrigió encaje de calidad y repetición del foco; v4 añade dosis repartida
al pasar a dos calidades; v5 permite progresar minutos fáciles al mantenerlas.
Recomendaciones de disponibilidad sin modificar la elección.

Verificados 1.573 semanas sintéticas, publicación → ejecutor → adaptación y
reinicio → nueva publicación en SQL transaccional, además de análisis Flutter,
batería completa de la app y compilación web. La experiencia de series anterior
puede declararse sin hacerse pasar por ejecución verificada; el RPE persistente
se aclara sin reducir minutos automáticamente. Existe reinicio voluntario por
preparación, con doble confirmación, y las sesiones completadas abren su
resultado. Límites y evidencia en [`MOTOR_CARRERA_2K_V5.md`](MOTOR_CARRERA_2K_V5.md).

**Alcance cerrado:** recorrido técnico de carrera 2 km en desarrollo. No se ha
probado la eficacia fisiológica ni se ha realizado aún el recorrido visual con
la cuenta autenticada tras la última compilación. Javier supervisará marca,
contexto, propuesta, publicación, sesión completada y reinicio en la app. El
visor histórico compara 13 perfiles; el comparador controlado de 2/3/4/5 días
queda fuera del bloque. Producción no modificada.

**Único siguiente bloque recomendado:** coordinación de carrera con fuerza y
otras pruebas dentro de la misma semana. Abrirlo después de la supervisión
visual. Esta revisión del 01/10/2026 cubre el código del motor 2 km, las
migraciones de desarrollo, sus tests transaccionales, widgets y compilación; no
certifica los bloques ajenos ni sustituye la instantánea general anterior.

Este roadmap expresa prioridades, no fechas cerradas. La instantánea histórica
anterior se había contrastado con código, las 48 migraciones locales y remotas de desarrollo, las
pruebas Flutter y las pruebas SQL transaccionales el 24 de septiembre de 2026,
tras el cierre de Carrera V1 mínima, la autoría oficial inicial y la calculadora
FAS 2027. Esa instantánea precede al piloto de carrera FAS de 30 de
septiembre: ya publica semanas de carrera en desarrollo y lee ejecuciones para
la siguiente decisión. El bloque funcional completo sigue abierto: faltan
fuerza, coordinación entre módulos y comprobación visual de extremo a extremo.

## Estado del ciclo principal (actualizado el 06/10/2026)

El ciclo objetivo continúa siendo:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

| Tramo | Estado | Evidencia y límite actual |
| --- | --- | --- |
| Acceso y contexto inicial | Terminado | Autenticación restaurable, varias preparaciones, evaluación inicial e historial de Tropa y Marinería, y preferencias de disponibilidad, experiencia y material. |
| Biblioteca y sesiones personales | Terminado para fuerza V1 | Biblioteca pública, sesiones privadas, ejercicios propios, descripción y vídeo HTTPS, duplicado, archivado, borradores locales y revisiones versionadas. |
| Agenda semanal manual | Terminada | Reúne biblioteca y sesiones personales; permite programar, reprogramar, retirar, iniciar y continuar. Inicio resume los siete días y abre la fecha seleccionada. Conserva nombre, versión y duración como instantánea. |
| Contexto por preparación | Terminado | Permite entrar en una preparación activa, ver objetivo, marcas vinculadas expresamente a ella y sesiones oficiales vinculadas. El deportista solo consulta y ejecuta: no puede crear, vincular, mover ni retirar sesiones del plan oficial. |
| Creador de fuerza por bloques | Terminado en V1 | Series variables, superseries A1/A2, circuitos con transiciones, intervalos de trabajo, Tabata 8 × 20/10, EMOM y AMRAP, con vista previa coherente. |
| Sesión guiada e historial | Terminado para los formatos V1 | Objetivo y resultado real, omisión, abandono, RPE final, notas, vídeos, temporizadores restaurables, avisos configurables, cola idempotente e historial con correcciones auditadas. |
| Funcionamiento sin conexión | Parcial; defecto de cambio de cuenta | Encola completar/omitir serie, AMRAP, finalizar y abandonar una ejecución cargada. Cola y borradores nuevos aún carecen de aislamiento por cuenta. No replica catálogo o agenda y las correcciones exigen conexión. |
| Evaluación y progreso | Parcial | Registra, evalúa y compara marcas con el catálogo versionado de ingreso a Tropa y Marinería, calcula evolución y recomienda focos. La evaluación periódica FAS 2027 tiene registro e historial propios y calculadora gratuita separada. No hay panel longitudinal completo ni simulacro. |
| Plan semanal adaptativo | Carrera v5 y rendimiento v3 en desarrollo | Coordinador común, referencias, contexto, alcance y un generador activo por usuario. Persisten los límites deportivos de STR-032. |
| Adaptación posterior | Continuidad automática en desarrollo | Resultados versionados, publicación al resolver las sesiones, recuperación, pausa/reanudación y revisión cuando corresponde; no exige publicar manualmente cada semana. |
| Carrera especializada | Terminada en V1 manual | Creador de carrera continua, series y pirámides; repeticiones agrupadas al prescribir, registro individual obligatorio de parciales y recuperaciones, ritmo calculado, RPE, FC opcional, clasificación de cumplimiento e historial. No incluye GPS, mapas, zonas ni integraciones. |
| Seguimiento profesional | No existe | No hay relación entrenador-cliente, asignación, anulación manual, panel profesional ni chat. |
| Derechos y monetización | No existe | La separación conceptual está decidida, pero no hay suscripciones ni concesión fiable de derechos comerciales. |

## Base completada

### Estabilización y seguridad

- Entornos de Supabase separados por configuración.
- Línea base SQL reproducible, saneamiento de acceso, RLS, constraints e
  índices.
- Restauración y observación de autenticación, navegación centralizada y
  pruebas base.
- Arquitectura modular aplicada sin imponer capas que no aporten valor.

### Dominio de evaluación y contexto

- Catálogo versionado de ingreso a Tropa y Marinería 2026 y evaluación de sus
  cuatro pruebas.
- Historial de evaluaciones, progreso y recomendación explicable del foco.
- Preferencias de entrenamiento y bloqueo cuando se solicita revisión
  profesional.
- Múltiples preparaciones activas, sin duplicar un mismo programa activo.
- Detalle de preparación que compone fecha objetivo, última evaluación
  compatible y agenda semanal relacionada, sin generar aún decisiones
  deportivas. El vínculo queda reservado al futuro algoritmo o a un servicio
  administrativo de confianza.

### Vertical manual de entrenamiento

- Plantillas jerárquicas y ejecuciones con instantáneas inmutables de la
  prescripción, el formato y el contenido explicativo usado.
- Biblioteca pública, sesiones personales y agenda semanal común.
- Creador privado y transaccional con múltiples bloques y objetivos por serie.
- Series convencionales, superseries, circuitos, intervalos, Tabata, EMOM y
  AMRAP; posiciones repetibles y transiciones de circuito.
- Ejercicios privados, búsqueda por catálogo, descripción y vídeo HTTPS.
- Borradores locales por sesión, duplicado, archivado y familias de revisiones.
- Vista previa, sesión guiada, temporizadores persistentes, avisos sonoros y
  hápticos, resultados, omisiones, abandono, notas y esfuerzo final.
- Cola local de mutaciones con recibos idempotentes, historial y correcciones
  auditadas limitadas por tiempo y número.
- Carrera personal mediante un formato distinto de los intervalos de fuerza,
  con borrador local, revisión versionada, tramos ordenados, ritmo y
  recuperación propia; usa la biblioteca, agenda, ejecución e historial
  comunes.

## Prioridades históricas del piloto inicial

Esta sección conserva el contexto anterior al programa integrado. El estado
y el único siguiente bloque vigentes son los indicados al comienzo del documento.

El control independiente de carrera de 2 km ya dispone de registro repetible,
fechado y vinculado a una preparación, con RPE obligatorio, FC y parciales de
400 m opcionales. Su protocolo de calentamiento y su cadencia de repetición
siguen pendientes de validación deportiva; ninguna semana se recalcula aún
automáticamente a partir de estas marcas.

La batería de evaluación acordada para Carrera incluye VAM, 2.000 m y Cooper.
Solo el control de 2.000 m está implementado. Antes de incorporar las otras dos
pruebas deben cerrarse el protocolo de VAM y las reglas que deciden cuándo usar
VAM o Cooper; no se crearán equivalencias implícitas entre sus resultados.

El contrato y la primera decisión determinista de carrera se documentan en
`docs/ALGORITMO_CARRERA_V1.md` y `docs/RECORRIDO_CARRERA_2K.md`. El piloto FAS
ya recoge días concretos y carga reciente, publica sesiones de carrera en
agenda y usa sus ejecuciones al calcular la semana siguiente. La coordinación
con fuerza y otras preparaciones sigue pendiente.

El **piloto de evaluación periódica militar separado del ingreso a Tropa y
Marinería** ya permite la primera semana de carrera FAS en desarrollo. Javier
conoce mejor las pruebas que denomina PAFAS/PAEF y prefiere validar ahí el
contenido deportivo. No se cambiará el identificador ni el catálogo del
programa de ingreso existente: tiene marcas y preparaciones históricas. La
Orden DEF/15/2026 comparte tipos de prueba entre ingreso y evaluación
periódica, pero diferencia sus baremos; los nuevos baremos periódicos entran
en vigor el 1 de enero de 2027. Ya existe el programa estable
`fas_periodic_assessment` **habilitado en desarrollo** y un catálogo local
versionado con la tabla íntegra de 0–100 puntos por prueba, columna H/M y edad
del anexo II. La calculadora gratuita está visible en Inicio, no requiere una
preparación activa y calcula en directo al escribir o mover sus deslizadores.
Solo guarda un test cuando el usuario lo confirma. Muestra cada puntuación y el
mínimo general de 20 puntos, sin presentar la suma como resultado normativo ni
certificar aptitud oficial. Sí ofrece una suma matemática visible, rotulada como
orientativa y separada del criterio normativo. El resumen precede a una
cuadrícula compacta de pruebas para reunir total, marcas, puntos y controles en
el primer vistazo. Cada registro pertenece al
perfil del usuario y puede enlazarse opcionalmente a una preparación, sin que
esta sea su dueña. Su historial periódico sigue siendo independiente de Tropa
y valida las marcas en PostgreSQL. Antes del 1 de
enero de 2027 se muestra como referencia futura. La calculadora aislada no
prescribe; una marca elegida dentro de Mejora FAS sí puede iniciar el piloto.

Queda por completar en este bloque:

1. Completados el contrato separado de registro, los mínimos por edad/sexo,
   el historial y la validación de propiedad en PostgreSQL. Completados también
   la tabla íntegra de 0–100 puntos y su cálculo local auditable. El BOE no
   define una suma total y contiene una secuencia anómala no corregida en II.3;
   se conserva literalmente y se mantiene como limitación conocida.
   La fecha de nacimiento se recoge en el perfil; la edad se calcula para
   cada intento y el servidor comprueba que coincide. El circuito deja de
   exigirse al cumplir 45 años.
2. **Calculadora gratuita de puntos completada** para la evaluación periódica
   FAS 2027: usa la fecha de nacimiento del perfil, permite elegir explícitamente
   H/M, acepta entradas móviles de repeticiones y tiempos, muestra puntos por
   prueba, versión y fuente, permite guardar con fecha en un historial personal
   independiente y mantiene las simulaciones fuera de ese historial. Próxima
   ampliación: selección de otros programas/convocatorias cuando dispongan de
   catálogos completos igualmente verificables. La conversión a Premium no
   ocultará el cálculo gratuito ni lo confundirá con una certificación oficial.
3. Curar un catálogo **mínimo** de ejercicios oficiales de fuerza aptos para
   las primeras plantillas: técnica, objetivo, material, variantes y
   limitaciones. La carga de fotos y una biblioteca amplia no bloquean el
   piloto; tampoco se debe inventar una progresión de fuerza a partir de solo
   flexiones, sentadillas y plancha. El creador administrativo y el creador
   privado ya comparten contrato, validación y formulario.
4. Componer y revisar con Javier una semana de plantillas ejecutables de
   carrera y fuerza, registrables con los flujos existentes. Mantenerla como
   borrador hasta validar su contenido.
5. Auditar visualmente el recorrido completo de la propuesta FAS ya publicada:
   entrada, semana visible, ejecución y siguiente decisión. Revisar dosis y
   límites deportivos antes de extenderlo a otros programas.

El trabajo existente de carrera de Tropa es un prototipo específico de ese
programa: sus reglas y el borrador de `assets/programs/tropa/` no pasan
automáticamente al nuevo piloto. Se reutilizarán contratos y componentes
compatibles, no baremos ni prescripciones sin revisión.

CNP 2026 permanece como borrador administrativo hasta la revisión y publicación
explícitas. Contiene los tres ejercicios del anexo II de BOE-A-2026-15055,
variantes H/M, tablas de puntos y la repetición de agilidad solo tras nulo. El
editor ya permite crear y revisar baremos de cualquier programa, pegar tablas,
validar cobertura y publicar. ADMIN puede copiar un programa publicado a un
borrador con versión nueva. El deportista puede introducir intentos y guardar
el resultado dentro de su preparación publicada. El siguiente enlace pendiente
es utilizar esta evaluación genérica como entrada del algoritmo semanal y
decidir cómo se incorpora una edición nueva a preparaciones activas.

La **primera planificación semanal adaptativa** ya tiene un piloto de carrera
FAS. Su cierre completo debe abarcar un único tramo del ciclo:

1. Definir una prescripción mínima con entradas explícitas: preparaciones
   activas, evaluación vigente, disponibilidad, material e historial necesario;
   y separar el contenido deportivo versionado de las decisiones por usuario.
2. Versionar las reglas y guardar para cada propuesta entradas, salida y razones.
3. Generar una semana privada con origen `algorithm` y colocarla en
   `scheduled_workouts` sin modificar plantillas ni ejecuciones históricas.
4. Mostrar al usuario por qué se pauta cada sesión y permitir ejecutarla o
   registrar su resultado; cualquier sustitución futura deberá decidirla el
   algoritmo o un servicio autorizado bajo reglas versionadas.
5. Cubrir dominio, persistencia, permisos y una prueba vertical desde contexto
   válido hasta semana visible en agenda.

Se recomienda este orden porque el producto ya puede crear, programar,
ejecutar y auditar sesiones, y ya conecta cada preparación con sus marcas y su
agenda. El piloto FAS ya convierte ese contexto en sesiones de carrera;
necesita contenido de fuerza revisable para la planificación conjunta.
Una biblioteca completa o nuevos formatos no son condición previa.

La adaptación de la siguiente semana también existe en el piloto FAS; faltan
validación deportiva, revisión visual del recorrido, fuerza y extensibilidad
antes de declarar cerrado el bloque.

El panel administrativo ya tiene una aplicación web separada. Distingue
biblioteca general y plantillas de cada programa; permite crear, buscar
ejercicios, revisar, editar borradores, versionar y retirar sesiones. Solo las
sesiones generales publicadas aparecen en la biblioteca abierta; publicar una
plantilla de programa la deja disponible para las futuras reglas de esa
preparación, sin asignarla aún. Comparte modelo y validación con la app mediante
`workout_core`, pero no reutiliza sus pantallas. Todavía no define mesociclos
ni reglas deportivas. No es un requisito previo para esta primera vertical.
Las reglas y sesiones que alimente el futuro algoritmo deben seguir revisándose
como datos versionados en Git y Supabase. Publicar una sesión en la biblioteca
general no la convierte todavía en parte de un mesociclo ni la asigna a nadie.

## Después, no en paralelo

Una vez validada la primera semana adaptativa, el orden natural será:

1. Interpretar cumplimiento, RPE/RIR, molestias, omisiones y abandono para
   adaptar la semana siguiente con reglas auditables y anulación profesional.
2. Completar evolución longitudinal, simulacros y comparación con baremos.
3. Incorporar relación entrenador-cliente, panel profesional y asignaciones.
4. Consolidar derechos comerciales y monetización antes de integraciones o
   expansión a otras oposiciones.

## Fuera del camino crítico del MVP

- Resolver todas las oposiciones a la vez.
- Chat, nutrición, desafíos o red social.
- Garmin Connect, Strava y otras integraciones antes de cerrar el ciclo
  adaptativo. Después se estudiará el envío de entrenamientos de carrera y su
  vinculación con planes como Guardia Civil o Tropa y Marinería.
- Algoritmos opacos o aprendizaje automático antes de validar reglas
  deterministas.
- Academias y multi-tenancy sin un caso profesional validado.
- Arquitectura preventiva para funcionalidades todavía indefinidas.

## Regla de ejecución

Cada bloque debe entregar un recorrido utilizable y probado. No se abrirán
varias áreas grandes a la vez ni se considerará terminada una funcionalidad
porque existan sus capas si el usuario todavía no puede completar el caso de
uso.
