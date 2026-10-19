# Revisión del creador de programas · UI-060 · 19/10/2026

Javier pide revisar el creador completo para evitar comunicar cada solapamiento
por separado. El alcance es ADMIN: datos del programa, clasificación, fases,
sesiones, calentamientos, descansos, acciones finales y recuperación del guardado.

## Hallazgos y correcciones

- Las etiquetas flotantes no reservaban espacio después de botones, cabeceras e
  interruptores; las largas se truncaban con texto ampliado. El creador utiliza
  etiquetas en el flujo vertical, con varias líneas y nombre accesible en el
  control. Conserva campos, validaciones, teclado, contenido y estados.
- Los títulos largos competían con tres acciones de orden. Las cabeceras pasan
  a dos filas cuando el ancho o el texto lo necesitan.
- Los interruptores estrechaban en exceso sus títulos y ayudas. Con poco espacio
  se colocan debajo, manteniendo el mismo valor, callback y bloqueo de guardado.
- Los chips imponían una sola línea; ahora se mide el espacio disponible antes
  de distribuir el texto. Los selectores de categoría principal y calentamiento
  admiten varias líneas también en el valor seleccionado.
- El panel de guardado incierto usaba una columna sin desplazamiento. Puede
  desplazarse para mantener accesible el reintento en móvil y texto grande.

## Verificación

Matriz del widget real: Rutina y Por fases a 320, 390 y 1100 px, con texto 1× y
2×. Son doce configuraciones que comprueban ausencia de excepciones de layout,
separación entre etiquetas y controles anteriores, y visibilidad de la última
letra de la categoría. Incluye calentamiento adjunto, calentamiento propio y
descansos habilitados o incompatibles. Se generan 66 capturas en
`admin_app/build/performance_v2_review/program-creator-*`, con revisión visual
representativa y tres muestras conservadas en
`docs/visual-audit/admin-program-creator-2026-10-19/`.

Análisis ADMIN limpio y batería completa: 242 pruebas correctas, con las dos
omisiones preexistentes. Se conserva el recorrido de autoría/publicación y se
amplía el reintento idempotente a 320 px con texto doble. Las pruebas existentes
localizan los controles por claves estables al quedar la etiqueta fuera de ellos;
conservan sus aserciones de guardado, categorías y publicación.

No cambia el tema global ni la aplicación del deportista; no hay cambios de
esquema, RPC, permisos, dependencias, ejecutores ni despliegues manuales. Los
diálogos y el selector mantienen sus implementaciones y pruebas existentes.
No se acredita teclado nativo ni dispositivos físicos; las capturas son widgets
reales con datos sintéticos y no una sesión remota de Javier.
