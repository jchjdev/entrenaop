# Herramientas profesionales · TRN-027 · 24/10/2026

Javier pide usar la calculadora de ritmos mientras trabaja en Trainer y ADMIN,
en una ventana que pueda desplazar sin abandonar el editor ni perder el borrador.
El cambio no modifica grupos, autoría de sesiones, permisos ni asignaciones.

## Implementación

- `workout_core/running_pace_calculator.dart`: misma aritmética de ritmo,
  tiempo objetivo y parciales, con las validaciones y el redondeo existentes.
  La ruta anterior del dominio del deportista reexporta esta implementación.
- `workout_editor_ui/running_pace_calculator_view.dart`: única interfaz de Series
  y Carreras; conserva distancias, unidades y cálculo inverso. El deportista
  mantiene su página y navegación. En los portales se omite el texto introductorio
  para reservar espacio a los controles y resultados.
- `entrena_ui/floating_tool_workspace.dart`: ventana no modal con movimiento
  por cabecera o flechas del teclado, tamaño ampliado, minimización y cierre.
  Se limita al área visible y se recoloca al estrechar la pantalla o abrir teclado.
- `workout_editor_ui/professional_tools_workspace.dart`: composición compartida
  y menú Herramientas → Calculadora de ritmos.

ADMIN ofrece Herramientas en su cabecera. Trainer lo ofrece en la barra lateral;
en pantallas estrechas, en Más, y dentro del creador en una franja de herramientas.
Ambos alojan la ventana junto al navegador del área autorizada, conservando sus
campos al navegar y minimizar. Abrirla de nuevo restaura la misma instancia;
cerrarla descarta su cálculo temporal. Salir del área o cambiar de cuenta desmonta
el contenedor. No se persisten datos ni se consulta el servidor para calcular.
Los diálogos del editor conservan prioridad sobre la herramienta.
ADMIN incluye además la entrada directa en su apartado lateral Herramientas.
El resultado resumido permanece visible arriba mientras se desplazan los campos
y parciales; las distancias habituales se despliegan bajo demanda. En pantallas
estrechas con texto ampliado, Series/Carreras usa un selector que evita partir
las palabras. La página del deportista conserva su presentación anterior.

## Verificación y publicación

Análisis raíz, ADMIN y Trainer limpios. La batería raíz pasa 1.330 pruebas con
una omisión preexistente. ADMIN pasa 315 pruebas con dos omisiones preexistentes;
tras añadir el acceso lateral se contrastan también sus nueve pruebas de
contenedor/herramientas y una omisión visual existente. Las regresiones finales
de ritmos, ventana y capturas suman 43 pruebas correctas, sin errores de layout
en escritorio ni a 320 px con texto 2×. El cálculo extraído se compara con el
anterior y coincide sin cambios de aritmética.

Durante la comprobación aparecen cambios ajenos en curso en el informe del
alumno y sus pruebas, con fallos en esa parte de la batería compartida. Se
conservan intactos y se contrasta esta entrega en una copia temporal del árbol
preparado: main más únicamente sus archivos, sin crear ramas ni worktrees.
Trainer pasa allí sus 184 pruebas y el análisis. No se acredita como limpia la
copia de trabajo compartida ni se incluyen las modificaciones ajenas.
Compilación web release Dev correcta desde esa copia validada, con CSP, recursos
locales y sin mapas de fuentes. El servidor profesional no se actualiza por compilar.

Capturas de widgets reales con datos ficticios y sin acceso de red:

![Trainer y creador](visual-audit/professional-tools-2026-10-24/trainer.png)
![ADMIN y creador](visual-audit/professional-tools-2026-10-24/admin.png)
![Texto ampliado](visual-audit/professional-tools-2026-10-24/trainer-accesible.png)

El primer intento de publicación queda bloqueado por el control del navegador
y el error de volumen de red del entorno (`T:`, error 64). Ese bloqueo se resuelve
después del reinicio solicitado por Javier, sin ampliar permisos.
La colaboración entre varios preparadores continúa únicamente documentada.

## Publicación Dev comprobada · 24/10/2026

Javier autoriza expresamente retomar la coordinación entre ambos chats para
publicar. El otro chat realiza la única carga en `public_html/trainer`, conservando
las releases anteriores; este chat contrasta de forma independiente el paquete,
la versión pública y la calculadora en la interfaz real. No se crean agentes ni
se cambian grupos, cuentas, permisos o datos de alumnos.

- Fuentes: `793adbf84d1ccc0fd8b62053ce293e1bc4332400`, que incluyen `07c35746`.
- Release Trainer: `793adbf84d1ccc0fd8b62053ce293e1bc4332400-20261024-1`.
- ZIP: `.dart_tool/garmin-strength/trainer-report-793adbf8-package.zip`.
- SHA-256 ZIP: `b727205435bd5a9cad0c7e0e8ba74e3996345dedfe128c0931c9f1cf11a41a7c`.
- SHA-256 JavaScript: `319c900ccb9bc7aaa910f1cdee07393fe437ae473e1024a457f4318d71a12387`.
- Destino: `trainer.entrenaop.es`, proyecto Dev `sxbxfjqgoddzhtcyhalw`.

El verificador del publicador confirma manifiesto, revisión, hash del JavaScript,
entrada versionada, cabeceras y MIME WebAssembly. El favicon servido coincide
con el PNG del paquete, SHA-256
`9963fc69a08debd3deb3d82d05ffdb25ec7ab6429583872ca3babda97e58b294`.
ADMIN también sirve `793adbf8` mediante su publicación automática Dev,
release `793adbf84d1ccc0fd8b62053ce293e1bc4332400-40071871420-1`.

Chrome acredita la entrada autenticada desde la biblioteca de sesiones a
Herramientas → Calculadora de ritmos. Se introduce 4:15/km para 400 m y se obtiene
1:42; minimizar/restaurar conserva ese valor, y arrastrar la cabecera desplaza la
ventana manteniendo la biblioteca y su URL. Solo cambia estado temporal de la
calculadora: no se guardan sesiones, resultados, notas ni asignaciones.
La captura de comprobación permanece privada y fuera de Git en
`.dart_tool/garmin-strength/trainer-tools-published-793adbf8.png`.

## Arrastre continuo · revisión del 24/10/2026

Javier detecta desplazamiento poco fluido. El cierre de build conservaba una
posición anterior: varios eventos entre repintados perdían parte del movimiento.
Se fija un origen de puntero global al iniciar el arrastre y se calcula desde él
la posición absoluta. Un ValueNotifier desplaza solo el Positioned, con el
contenido de la calculadora retenido fuera de ese repintado y RepaintBoundary.
Conserva límites de ventana, minimizado, valores y movimiento por teclado.

Las regresiones de ratón y táctil envían tres movimientos sin repintar entre
ellos y verifican todo el recorrido y que no se reconstruye el contenido.
