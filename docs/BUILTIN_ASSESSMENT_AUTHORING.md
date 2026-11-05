# Autoría versionada de FAS y Tropa

## Acuerdo del 05/11/2026 y alcance

Javier aprueba la propuesta de editar FAS/Tropa desde ADMIN conservando las reglas,
el historial y las herramientas existentes. Se implementa primero el recorrido
crear revisión → editar borrador → comparar/simular/revisar → publicar, limitado
a presentación, fuente, vigencia y valores de baremos. El editor de sesiones no
se modifica. Los algoritmos, dosificación y objetivos/protocolos de entrenamiento
continúan en consulta y requieren su siguiente bloque específico.

Las identidades, unidades, dirección favorable, protocolos, tramos de edad,
aplicabilidad de pruebas y marcas de las filas FAS se protegen en esta primera
entrega. Tropa permite editar mínimos por clave prueba/sexo/hito; FAS permite
editar puntos por marca/sexo/edad. Un cambio de estructura requiere nueva
capacidad de protocolo y no debe reinterpretar los resultados anteriores.

## Contrato de versiones

`builtin_assessment_revisions` conserva revisión, definición completa, base,
estado, motivo, fuentes y control de edición concurrente. Una revisión publicada
es inmutable en su definición. Retirarla afecta a nuevas selecciones; conserva
sus vínculos e historial. Recuperar una configuración anterior crea otro borrador.

Las evaluaciones Tropa conservan `catalog_version`. FAS conserva por separado
`catalog_version` de mínimos y `scoring_version` de puntuación. La semilla FAS
importa literalmente el JSON completo de la app; sus 306 filas y anomalías
anotadas no se corrigen ni interpolan automáticamente. Sus 64 mínimos se
proyectan de la tabla completa y deben coincidir con los existentes antes de
habilitar la autoría. Tropa conserva las cuatro pruebas y 24 referencias actuales.

Publicar crea nuevas referencias; nunca actualiza los mínimos de una versión
usada ni modifica `physical_test_definitions` compartida. El comparador y la
consulta histórica resuelven cada versión guardada, no la última publicación.
Los nuevos registros FAS incorporan una instantánea del cálculo en servidor;
los anteriores mantienen sus filas y semántica. No se inventa calificación
normativa agregada ni se altera el redondeo del calculador existente.

## Preparaciones y compatibilidad

Cada preparación integrada queda vinculada a una revisión. Las existentes se
fijan a la semilla; las nuevas seleccionan una publicación vigente. Si aún no
hay una vigente, se conserva la referencia futura FAS inicial ya disponible,
con su aviso de referencia previa a vigencia. Esta entrega no migra silenciosamente
preparaciones activas ni altera entrenamientos ya generados.

La app carga la revisión contextual antes de calcular y envía esa misma revisión
al registrar. Una publicación durante un formulario no cambia su definición.
La calculadora personal FAS conserva su acceso gratuito y la lectura por versión.
Los errores de carga no sustituyen silenciosamente una revisión desconocida por
el archivo antiguo. Los catálogos originales permanecen como adaptadores de las
versiones antiguas conocidas y como fixtures explícitos de pruebas.

Las API antiguas conservan su referencia original. Si la preparación está ligada
a otra revisión, deben solicitar actualizar el cliente en vez de aceptar una
marca con reglas distintas a las mostradas. La selección nueva no sustituye el
selector legado global que todavía utiliza esa API.

## Seguridad y publicación

Borradores privados al administrador; escritura únicamente mediante operaciones
validadas en servidor con permiso administrativo y segundo factor. Las operaciones
comprueban revisión de edición, identidad y estado, además de propiedad en
lecturas/escrituras contextuales del deportista. La publicación es atómica y
repite la validación. Guardar no publica. Simular no registra un intento real.

Se conservan las fronteras de preparaciones Tropa, FAS y evaluación configurable.
Los catálogos nativos no se convierten en programas guiados ni sesiones fijas.
La recuperación/copia incluye el nuevo esquema privado de autoría.

## Comprobación y cierre

Implementación completada en código y ensayada antes de aplicar: 1.872 pruebas
raíz y una omisión previa; 406 ADMIN y dos omisiones previas; análisis limpios de
ambas apps, compilaciones web Dev correctas, 48 pruebas de herramientas y tres
pruebas de semilla. La migración y el smoke completo se ejecutaron juntos en
Dev con ROLLBACK, incluyendo los negativos de permisos/contexto, sin persistir
revisiones ni intentos de ensayo. Un primer ensayo detectó una ambigüedad de
alias al publicar Tropa; corregida antes de volver a ensayar el contrato completo.

La migración se aplica solo en Dev: 309 coincidentes, contrato instalado y dos
pruebas SQL anteriores correctas con ROLLBACK; las huellas de los 15 intentos
originales permanecen iguales. Las copias previa 42085037509-3 y posterior
42092600721-1 quedan restauradas, cifradas y conservadas como verified.
ADMIN 0.7.0+12 está publicado en admin.entrenaop.es, revisión f3d8e03e, destino
Dev, índice y hash del código comprobados por HTTPS.

La calculadora personal ofrece Actualizar baremo ante la señal
builtin_reference_changed, conserva las marcas y recalcula únicamente tras
confirmar esa actualización; un fallo de recarga ofrece reintento. La verificación
de autoría no acredita revisión de una nueva norma ni instalación del cliente
1.17.0+37 en el iPhone. [Evidencia del bloque](audits/BUILTIN_ASSESSMENT_AUTHORING_2026_11_05.md).
Los cambios estructurales de protocolos y la migración explícita de preparaciones
activas a otra revisión siguen fuera de esta primera entrega.
