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

El primer recorrido que se desarrollará en profundidad será el ingreso a Tropa
y Marinería. Los accesos a Suboficiales y Oficiales se incorporarán después con
sus propios catálogos oficiales. Las pruebas internas, ascensos, PAEF y PAFA se
modelarán como programas de evaluación distintos, no como si fueran otra
oposición. CNP, Guardia Civil y otros cuerpos quedan fuera del MVP inicial.

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

## Primera versión validable

Un usuario puede seguir varias preparaciones verificadas de forma simultánea.
Inicio enseña solo las que ha añadido; el catálogo completo se consulta aparte.
Las sesiones personales no dependen de una oposición concreta y una futura
planificación podrá atender varios objetivos con una carga global coherente.

La primera versión debe demostrar el ciclo completo con el ingreso a Tropa y
Marinería:

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

Primero se construirá una vertical completa con pocos ejercicios y una sesión
real. No se desarrollará toda la biblioteca antes de comprobar que el recorrido
de evaluación, entrenamiento, resultado y adaptación funciona de extremo a
extremo.

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
- **Programas:** ingreso a Tropa inicialmente; después, otros accesos y
  evaluaciones internas con sus pruebas, baremos y planificación adaptativa.
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

El modelo debe representar series tradicionales, circuitos, superseries, AMRAP,
EMOM, Tabata, intervalos de carrera, isométricos, calentamiento y vuelta a la
calma.

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
- Garmin y Strava se investigarán más adelante y no deben bloquear el MVP.
- Nutrición, si se incorpora, comenzará con un alcance limitado.

La IA generativa no decidirá la progresión inicial. Podrá ayudar en el futuro a
explicar, resumir o redactar, pero las decisiones de entrenamiento comenzarán
con reglas deterministas, explicables, versionadas y anulables por el
entrenador.
