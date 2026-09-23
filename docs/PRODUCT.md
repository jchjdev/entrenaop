# Producto EntrenaOP

## Visión

EntrenaOP es una aplicación multiplataforma para preparar pruebas físicas de
oposiciones militares y de fuerzas y cuerpos de seguridad. Combina fuerza,
calistenia, carrera y planificación específica. Debe funcionar en Android,
iPhone, web y Windows con interfaces adaptadas a cada formato.

No pretende ser una biblioteca genérica de ejercicios. Su promesa inicial es:

> Dime dónde estás y cuándo te examinas; EntrenaOP te ayuda a llegar preparado
> y te muestra si vas por buen camino.

El ciclo principal del producto es:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

## Estado validado del producto

Instantánea comprobada en código, migraciones y pruebas el 22 de septiembre de
2026, tras cerrar Carrera V1 mínima:

- El acceso, la restauración de sesión y la navegación responsive están
  operativos.
- El usuario puede mantener varias preparaciones activas, registrar y consultar
  evaluaciones físicas versionadas de ingreso a Tropa y Marinería, y guardar su
  disponibilidad y contexto de entrenamiento.
- La biblioteca pública y las sesiones personales comparten vista previa,
  agenda semanal, sesión guiada e historial, pero conservan origen, privacidad
  y versión distintos.
- El creador personal admite varios bloques, series con objetivos diferentes,
  superseries, circuitos con transiciones, intervalos de trabajo, Tabata, EMOM y
  AMRAP. También permite crear ejercicios privados con descripción y una URL de
  vídeo HTTPS opcional.
- El creador especializado de carrera admite carrera continua por distancia o
  duración y tramos ordenados con ritmo exacto o rango. Cada tramo conserva su
  recuperación pasiva, andando o trotando por duración o distancia. Repetir un
  tramo y crear una pirámide son ayudas de edición: la prescripción se guarda
  expandida y versionada.
- Los borradores se guardan localmente por sesión. Duplicar, revisar o archivar
  una sesión no reescribe ejecuciones pasadas: las revisiones forman una familia
  versionada y el historial conserva una instantánea de la prescripción.
- La agenda semanal permite añadir sesiones públicas o personales, moverlas,
  retirarlas, iniciarlas y continuar las que están en curso.
- Inicio muestra un resumen compacto de lunes a domingo; cada día indica si hay
  sesiones y abre la agenda completa en la fecha elegida.
- Cada preparación activa dispone de una vista propia con su fecha objetivo,
  la última evaluación compatible y las sesiones de la semana vinculadas a
  ella. Es una vista de solo lectura: el usuario no puede crear, vincular,
  mover ni retirar contenido de un plan oficial.
- La sesión guiada conserva objetivos y resultados por serie, descripciones y
  vídeos, pausas y temporizadores recuperables. Registra omisiones, abandono con
  motivo, esfuerzo final, notas y el resultado agregado propio de AMRAP.
- Una cola local permite continuar las mutaciones de una ejecución ya cargada
  durante cortes de red; Supabase las aplica de forma idempotente. Las
  correcciones del historial permanecen en línea y se auditan durante 24 horas,
  con motivo obligatorio y un máximo de tres cambios por serie.

Esto cierra los recorridos manuales de fuerza V1 y Carrera V1 mínima, no el
ciclo principal completo. El contexto de preparación, marcas, agenda y carrera
ya está conectado, pero todavía no existen la generación del plan semanal, la
adaptación posterior al resultado, los simulacros ni la revisión por un
entrenador. Carrera V1 no incluye GPS, mapas, seguimiento en vivo, zonas
cardíacas ni integraciones. El vídeo propio se referencia por URL; no
hay subida ni gestión de archivos. Los borradores y temporizadores son locales
al dispositivo y el soporte offline no permite descubrir, cargar o iniciar una
sesión que nunca se hubiera obtenido del servidor.

El primer recorrido **implementado** es el ingreso a Tropa y Marinería; no
equivale a la evaluación periódica del personal ya incorporado. Para validar
el primer plan adaptativo se prioriza ahora un piloto de evaluación periódica
militar, familiar para Javier, pendiente de concretar normativa y vigencia.
Se modelará como programa distinto, no renombrando Tropa ni tratándolo como
otra oposición. Los accesos a Suboficiales y Oficiales tendrán sus propios
catálogos oficiales. CNP existe solo como borrador sin pruebas definidas y no
se publicará por ahora; Guardia Civil y otros cuerpos quedan fuera del MVP
inicial.

Lema previsto: **Entrena. Supera. Aprueba.**

## Usuarios y evolución del producto

EntrenaOP comienza como una aplicación para el opositor, pero también debe
convertirse en una herramienta profesional para entrenadores. Una misma persona
podrá ser deportista, entrenador de otros usuarios o ambas cosas; estos
contextos no se representarán mediante un único rol excluyente.

La evolución comercial prevista tiene dos vías complementarias:

- **B2C:** el opositor descubre la aplicación, utiliza el nivel gratuito y
  puede contratar adaptación automática o seguimiento humano.
- **Profesional:** el entrenador incorpora y gestiona clientes desde un espacio
  de trabajo propio.

Una variante para academias podría incorporar organizaciones, grupos, alumnos y
varios entrenadores. Es una dirección futura, no alcance del MVP. El modelo
actual debe evitar bloquearla, pero no implementarla anticipadamente.

## Niveles comerciales

### Free

- Biblioteca y sesiones públicas no adaptativas.
- Creación de rutinas propias.
- Creación de sesiones personales de carrera continua, series y pirámides.
- Las rutinas propias son privadas y se distinguen visualmente de la biblioteca
  pública de EntrenaOP.
- El creador mantiene una entrada rápida para series iguales, pero permite
  ajustar objetivo, carga, RIR y descanso de cada serie cuando se necesita.
- El selector permite buscar por nombre, músculo o material y distingue el
  catálogo verificado de EntrenaOP de los ejercicios privados del usuario.
- El usuario puede crear un ejercicio propio con descripción y vídeo HTTPS
  opcional. Nunca puede publicarlo como contenido oficial desde el cliente.
- El creador guarda automáticamente un borrador local. Una sesión nueva y cada
  revisión mantienen espacios separados; al regresar, el usuario decide si
  recupera o descarta los cambios sin finalizar.
- Editar una rutina no cambia entrenamientos pasados: la interfaz guarda una
  nueva versión y conserva la anterior para el historial.
- Historial conservado aunque el usuario deje de pagar.
- Sin progresión adaptativa personalizada.

### Pro (nombre provisional)

- Planes específicos de oposiciones.
- Progresión adaptativa automática.
- Prescripciones privadas generadas para las marcas, objetivos y contexto del
  usuario; no son simples copias de las sesiones públicas.
- Seguimiento de marcas y comparación con baremos.
- Sin intervención diaria de un entrenador.

### Coaching (nombre provisional)

- Javier asigna y modifica entrenamientos.
- Acceso detallado al progreso del cliente.
- Comunicación directa y feedback.
- Chat interno cuando se desarrolle esa fase.

El nivel comercial, los permisos administrativos y la relación entre entrenador
y cliente son conceptos diferentes.

Los nombres comerciales se validarán antes del lanzamiento. `Pro` y `Coaching`
describen mejor el beneficio que etiquetas genéricas como `Premium` o `VIP`,
pero todavía no son nombres definitivos.

## Alcance de la primera versión validable

Un usuario puede seguir varias preparaciones verificadas de forma simultánea.
Inicio enseña solo las que ha añadido; el catálogo completo se consulta aparte.
Las sesiones personales no dependen de una oposición concreta. La agenda
semanal ya reúne sesiones personales y de biblioteca; más adelante integrará
las prescripciones de varias preparaciones con una carga global coherente.
Una sesión libre puede convivir el mismo día con una prescripción oficial, pero
no pasa a formar parte de Tropa, CNP ni de otro plan interno porque el usuario
la añada. El vínculo con una preparación queda reservado al algoritmo y a los
servicios de confianza de EntrenaOP. En el futuro, el usuario podrá agrupar sus
sesiones en una planificación personal claramente separada y sin adaptación ni
supervisión de EntrenaOP.
El creador permite dividir una sesión en bloques convencionales con nombre y
orden propios, manteniendo una entrada sencilla con un bloque principal creado
por defecto.
Una superserie enlaza exactamente dos posiciones A1/A2; un circuito recorre dos
o más estaciones. Ambos permiten elegir rondas y descanso entre vueltas y se
presentan en ese orden durante la sesión guiada. En un circuito, cada estación
puede definir además su transición hasta la siguiente. Las posiciones son
independientes y pueden reutilizar un ejercicio del catálogo cuando la
secuencia lo requiera.
Los intervalos de trabajo repiten un único ejercicio y permiten ajustar el
objetivo de cada esfuerzo y una recuperación común. Sirven para trabajo
temporizado de fuerza-resistencia o acondicionamiento; no representan series
de carrera. Tabata se ofrece como protocolo cerrado de ocho rondas de 20
segundos de trabajo y 10 de recuperación. El usuario elige uno o varios
movimientos y la secuencia se repite hasta completar los ocho intervalos. EMOM
alterna uno o varios ejercicios, asigna un minuto a cada uno y
repite la secuencia por vueltas; completar u omitir una estación conserva el
tiempo restante hasta el siguiente minuto. AMRAP usa un único reloj global y
registra vueltas completas, último ejercicio parcial y repeticiones parciales.

La carrera dispone de un creador específico dentro de la sesión unificada.
Expresa tramos ordenados con distancia o duración, ritmo objetivo propio y
recuperación individual, incluida su modalidad. Una pirámide puede así combinar
200/400/600/800/1000 metros y regresar sin fingir que todos los tramos comparten
ritmo o descanso. Las series iguales se editan como un bloque compacto `× N` y
solo se expanden al guardar la prescripción; las pirámides mantienen visibles
sus tramos distintos. Biblioteca, agenda, ejecución e historial leen esa misma
lista final. La duración se estima automáticamente con distancia, ritmo y
recuperaciones temporizadas, sin inventar tiempos para distancias sin ritmo.
El resultado de una carrera continua se registra de forma global. En series,
intervalos o fartlek se registra obligatoriamente cada tramo y su recuperación;
el ritmo se deriva de distancia y tiempo para no ocultar la regularidad detrás
de un promedio. El RPE final es obligatorio y la frecuencia cardíaca media y
máxima son opcionales. Los resultados distinguen entrada manual y dispositivo
para permitir una futura sincronización sin reinterpretar el historial.
El futuro algoritmo generará el mismo contrato versionado, no reglas ocultas en
la interfaz.
Los motores de fuerza y carrera no competirán por separado: una capa de
planificación global coordinará la carga semanal del alumno y podrá producir
sesiones específicas o combinadas. La forma comercial de presentar esos
programas se decidirá después; el modelo no debe obligarnos prematuramente a
una única estructura visible.

La primera versión validable debe demostrar el ciclo completo con **un programa
oficial delimitado**. Tropa y Marinería aporta la vertical de evaluación ya
implementada; el piloto de planificación se orientará a la evaluación
periódica tras verificar su fuente y baremo:

1. Alta, acceso y perfil físico.
2. Selección de convocatoria, categoría y fecha objetivo.
3. Registro de marcas iniciales.
4. Generación o asignación de una semana de entrenamiento.
5. Pantalla Hoy con acceso claro a la sesión.
6. Sesión activa con temporizadores, indicaciones, vídeo y registro rápido.
7. Resultado realizado con RPE/RIR, molestias y notas.
8. Evolución de marcas y comparación con el baremo aplicable.
9. Simulacro de las pruebas físicas del programa.
10. Revisión y modificación del plan por el entrenador.

Primero se construirá una vertical completa con un catálogo pequeño pero
revisado de ejercicios de fuerza y sesiones reales de carrera y fuerza. No se
desarrollará toda la biblioteca ni el creador administrativo completo antes de
comprobar que evaluación, entrenamiento, resultado y adaptación funcionan de
extremo a extremo. Tampoco se usará un conjunto insuficiente de movimientos
para aparentar una progresión de fuerza validada.

Quedan fuera de esta primera validación el chat, nutrición, desafíos, red
social, Garmin, Strava y la cobertura simultánea de todas las oposiciones.

## Plataformas

- Android e iPhone son prioritarios para la experiencia del opositor.
- La web responsive será inicialmente el espacio de administración y
  seguimiento del entrenador.
- Una web pública convencional podrá utilizarse para captación, contenido y
  posicionamiento sin obligar a que toda la presencia web use Flutter.
- Windows se mantendrá como destino posible, pero no condicionará el MVP.
- La sesión activa debe tolerar pérdida de conexión y poder recuperarse sin
  perder resultados.

## Áreas funcionales previstas

- **Hoy:** calendario semanal, entrenamiento asignado y acceso a la sesión
  activa.
- **Explora:** programas, sesiones públicas, rutinas propias y, más adelante,
  desafíos.
- **Programas:** ingreso a Tropa como primer catálogo implementado; evaluación
  periódica militar como piloto adaptativo tras delimitar su versión; después,
  otros accesos y evaluaciones con sus pruebas y baremos.
- **Resultados:** marcas, evolución, comparación con baremos, historial y
  métricas de carga.
- **Chat:** reservado al seguimiento personalizado en su fase correspondiente.
- **Perfil:** datos personales, métricas físicas, suscripción e integraciones.
- **Administración:** clientes, contenido público, asignaciones, ejercicios,
  progreso y comunicación.

En móvil se estudiará un número razonable de destinos principales. Web y
Windows utilizarán una composición responsive, probablemente con navegación
lateral. La antigua propuesta de seis destinos inferiores no es una obligación.

## Sesión activa

Es el flujo central del producto. Debe ofrecer:

- Temporizador claro.
- Ejercicio, indicaciones y vídeo consultable.
- Progreso de ejercicio, serie o bloque.
- Registro rápido del resultado real.
- Feedback final mediante RPE/RIR, estado y notas.

El modelo representa ya series tradicionales, circuitos, superseries, AMRAP,
EMOM, Tabata y tramos de carrera. Isométricos, calentamiento y vuelta a la calma
siguen siendo necesidades del modelo completo, no recorridos cerrados por esta
entrega.

El historial necesita datos suficientemente detallados para el algoritmo:
series, repeticiones, carga, tiempo, distancia, ritmo, descansos, cumplimiento,
RPE/RIR, modificaciones, pruebas y simulacros.

## Diseño

- Material 3.
- Apariencia oscura, seria y deportiva.
- Naranja `#E65100` como color primario de referencia.
- Fondo histórico de referencia `#0A0A0A`.
- Calisteniapp es una inspiración de experiencia, especialmente durante la
  sesión, pero no una plantilla que deba copiarse.
- Vídeos previstos: MP4/H.264, normalmente cortos y hasta 720p; esta política se
  validará con costes, accesibilidad y necesidades reales antes de cerrar la
  implementación.

## Integraciones futuras

- Suscripciones: RevenueCat o solución equivalente, después de validar iOS,
  Android, web y Windows.
- Salud móvil: Health Connect y las APIs vigentes del ecosistema Apple/Google;
  no diseñar una integración nueva alrededor del antiguo Google Fit.
- Garmin Connect y Strava se investigarán más adelante y no deben bloquear el
  MVP. La investigación de Garmin debe cubrir tanto sincronizar sesiones de
  carrera como vincularlas a planes de preparación de oposiciones.
- Nutrición, si se incorpora, comenzará con un alcance limitado.

La IA generativa no decidirá la progresión inicial. Podrá ayudar en el futuro a
explicar, resumir o redactar, pero las decisiones de entrenamiento comenzarán
con reglas deterministas, explicables, versionadas y anulables por el
entrenador.
