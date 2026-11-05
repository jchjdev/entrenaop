# Preparación del lanzamiento en tiendas

## Alcance confirmado · 05/11/2026

Javier quiere preparar el terreno y posponer la subida hasta cerrar sesiones,
programas y preparaciones. Esta tarea no autoriza altas de pago, envío de
binarios, activación de compras ni despliegues de producción. Google Play es
la primera opción preferida; App Store se prepara después sobre el mismo cierre
del producto. Se mantiene el circuito privado de APK y las pruebas iOS con Xcode.

Este documento organiza la preparación; no acredita una auditoría completa,
el cierre del núcleo deportivo ni la disponibilidad de cuentas de tienda.
La recomendación es fijar una primera versión publicable con criterios finitos,
en lugar de condicionar la salida a todas las ampliaciones futuras.

## Estado localizado contrastado el 05/11/2026

- Existe un producto integrado: biblioteca y sesiones personales, programas,
  preparación adaptativa, agenda, ejecución e historial. Los contratos responsables
  son [Programas](PROGRAMAS_GUIADOS.md), [Preparaciones](PROGRAMA_ADAPTATIVO.md)
  y los recorridos de [la app](ATHLETE_TRAINER_NAVIGATION_2026_10_22.md).
- El roadmap registra análisis, pruebas automáticas y correcciones recientes.
  También conserva aceptaciones físicas pendientes. Esta revisión documental no
  vuelve a ejecutar esas pruebas ni transforma simulaciones en eficacia deportiva.
- Android tiene un circuito de APK release con firma beta estable y Dev.
  No se ha acreditado en esta tarea un AAB apto para Play ni una identidad de
  firma definitiva de tienda. [Circuito](ANDROID_BETA.md).
- `AppConfig` distingue desarrollo y producción y rechaza el proyecto Dev al
  declarar producción. Esto no acredita infraestructura productiva operativa;
  no se consulta ni modifica producción en esta preparación.
- Pro tiene compras y restauración con RevenueCat Test Store; el cliente actual
  las habilita exclusivamente en móvil debug de desarrollo con clave `test_`.
  Las compras Apple/Google y su configuración release siguen pendientes.
  [Estado comercial y trabajo real](PRO_LAUNCH.md).
- Ajustes ofrece información de pruebas y soporte. El roadmap conserva como
  pendiente el contrato y la implementación de eliminación de cuenta; no se
  sustituye por cerrar sesión, borrar preferencias o enviar un correo.

## Secuencia recomendada

### 1. Cerrar el recorrido deportivo de la primera versión

Mantener como trabajo principal sesiones → programas → preparaciones. Para cada
modalidad incluida, aceptar en dispositivo la creación/configuración, consulta,
inicio, interrupción y recuperación, registro/cierre e historial. Comprobar los
cambios de semana o fase y la continuación adaptativa cuando correspondan.
Añadir pérdida de red, reintentos y acceso Free/Pro a los recorridos afectados.

Antes de declarar cerrado el bloque, contrastar recetas, resultados, permisos y
versiones entre app, servidor y herramientas de autoría con la matriz de AGENTS.
En preparaciones, comprobar decisiones explicables y regresiones del motor;
las simulaciones no acreditan por sí solas eficacia deportiva en personas.
Los dispositivos se anuncian solo para capacidades realmente aceptadas. Una
ampliación de relojes, formatos o estrategias puede quedar para después sin
impedir publicar las capacidades ya verificadas.

### 2. Preparar los requisitos de salida

- Concretar titular/editor, cuenta personal u organización e identidad de app
  antes de registrar la ficha. Conservar y respaldar el material de firma;
  revisar la actualización de las APK existentes antes de elegir firma Play.
- Definir y después implementar eliminación de cuenta con sus datos compartidos,
  conexiones y conservación/anonimización justificada. Requiere propuesta propia
  antes de cambiar modelo de datos o seguridad.
- Inventariar datos, permisos y proveedores utilizados para completar privacidad,
  condiciones, declaraciones de datos/salud y textos de permisos coherentes.
- Completar las compras nativas, restauración, gestión de suscripción y
  recuperación de conciliación antes de vender Pro. No presentar Test Store
  como aceptación del sandbox de Apple o Google. Cualquier alternativa de salida
  sin ventas requiere acuerdo explícito; no se cambia ahora el modelo comercial.
- Preparar la lista de configuración productiva, recuperación de cuenta, enlaces,
  notificaciones, conexiones, soporte y copias/restauración. Su implantación y
  comprobación en producción quedan para un bloque expresamente autorizado.
- Redactar ficha, descripción y notas para revisión; capturas finales y cuenta de
  revisión se preparan sobre el alcance estabilizado, sin anunciar trabajo futuro.

Esta fase puede avanzar documentalmente mientras se cierra el núcleo. No supone
abrir a la vez todas las implementaciones anteriores.

### 3. Validar una candidata y entonces distribuir

Cuando Javier decida iniciar la distribución: verificar cuentas y requisitos
vigentes, generar el artefacto firmado, ejecutar la matriz de comprobación y
aceptar los recorridos en Android/iPhone. Empezar por prueba interna de Play;
si corresponde a la cuenta, completar después la prueba cerrada requerida antes
de solicitar acceso público. Preparar TestFlight/App Store en el bloque posterior.
Separar en todo momento prueba privada, publicación pública y ventas.

## Referencias de tienda consultadas el 05/11/2026

- [Pruebas de Google Play](https://support.google.com/googleplay/android-developer/answer/9845334).
- [Prueba cerrada para cuentas personales nuevas](https://support.google.com/googleplay/android-developer/answer/14151465).
- [Eliminación de cuenta en Google Play](https://support.google.com/googleplay/android-developer/answer/13327111).
- [Declaración de salud en Google Play](https://support.google.com/googleplay/android-developer/answer/14738291).
- [Eliminación de cuenta en Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
- [Revisión de Apple](https://developer.apple.com/app-store/review/guidelines/).

Revalidar estos requisitos al preparar la candidata. No equivalen a una revisión
jurídica ni garantizan la aprobación por las tiendas.
