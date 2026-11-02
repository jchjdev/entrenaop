# Entrenar · revisión visual del 02/11/2026

Capturas de widgets Flutter reales con datos ficticios, sin cuentas ni red.
Cubren Preparación, Programas, gestión de preparaciones y Disponibilidad, a
390 px; Disponibilidad incluye 320 px con texto 2× y sus acciones desplazadas.
Se conservan las capturas históricas del 01/11 en su directorio original.

Reproducción desde la raíz:

```powershell
flutter test tools/athlete_navigation_visual_test.dart --plain-name 'captura entrenar-'
```

Las pruebas comprueban también las cinco etiquetas inferiores, la geometría de
la barra dentro de la pantalla y la interacción de Perfil. En este entorno el
rasterizador de tests puede omitir parte de la pintura inferior y el glifo de
flecha textual, aun conservando geometría e interacción correctas. No se ha
cambiado la aplicación para compensar esa limitación de las capturas.

Estas imágenes no acreditan compilación ni aceptación en un iPhone. El siguiente
recorrido físico es instalar desde Mac y probar consulta, semanas, retorno,
activación/revisión/pausa, Biblioteca y guardado de disponibilidad.
