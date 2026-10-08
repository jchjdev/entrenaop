# Avisos del ejecutor · UI-018 · 08/10/2026

## Problema comprobado y criterio

Javier comunica ausencia de sonido en localhost, Android físico y el simulador
iOS. El código sí emitía eventos, pero su adaptador usaba
`SystemSound.play(SystemSoundType.alert)`: Flutter documenta que este aviso se
ignora en Android, iOS y web. No había archivos de audio incluidos.
[Contrato de Flutter](https://api.flutter.dev/flutter/services/SystemSoundType.html).

Javier confirma avisos a mitad y cuando quedan diez segundos, además de
preparación, inicio y final. Se conserva el diseño del ejecutor y las preferencias
independientes de sonido y vibración. Son avisos del reloj, sin cambiar
prescripciones, motores ni la confirmación manual de resultados.

## Implementación

- Cinco WAV originales, mono PCM de 16 bits/44,1 kHz, generados por
  `tools/generate_workout_cues.py`: preparación, inicio, mitad, diez segundos
  y final. El final del descanso usa el sonido de inicio del siguiente trabajo.
  Duraciones de 0,10 a 0,43 segundos, con fundidos y amplitud moderada.
  Están incluidos en la app; no se descargan de un servidor ni requieren red.
- `audioplayers` 6.8.1 fijado, con siete paquetes nuevos incluidos sus
  implementaciones de plataforma; no se actualizan dependencias anteriores.
  El paquete Darwin resuelto (6.5.0) incluye Swift Package Manager y mínimo
  iOS 13, compatible por configuración con el mínimo iOS 15 de IOS-001.
  Esto no sustituye una compilación y escucha nativas en el Mac.
- Adaptador de audio separado de preferencias y eventos, con un reproductor
  reutilizable y precarga. Android usa volumen multimedia sin reclamar foco
  exclusivo; iOS configura playback con mixWithOthers. No se solicitan permisos
  adicionales ni se cambia el audio global del SDK de forma indiscriminada.
  La sesión de audio de iOS es compartida por el sistema y su convivencia con
  música/vídeo debe comprobarse en dispositivo real.
- El diálogo existente añade **Probar sonido**: prueba explícita que no guarda
  ni cambia los interruptores; errores visibles con reintento. El borrador se
  aplica solo al guardar y cancelar conserva las preferencias anteriores.
- Fallos de audio o vibración no interrumpen el otro canal, el reloj ni guardados.
  Solicitudes de audio se serializan; un aviso sustituido o retrasado más de un
  segundo se descarta para evitar reproducir una fase antigua. La prueba manual
  puede esperar la carga, porque no representa un hito temporal.

La reproducción usa la interacción normal del usuario. No se desactivan las
restricciones de autoplay del navegador. En Safari/iOS web queda pendiente la
prueba específica de sus restricciones.

## Hitos y restauración

| Tiempo del intervalo | Avisos durante la cuenta |
| --- | --- |
| Hasta 10 segundos | Inicio y final, además de preparación cuando corresponda |
| De 11 a 19 segundos | Últimos 10 segundos, sin mitad |
| Desde 20 segundos | Mitad y últimos 10 segundos |

La mitad se redondea al segundo siguiente en tiempos impares. Si ambos hitos
coinciden (20 o 21 segundos), prima diez segundos. Si una actualización cruza
ambos, se emite el último; si llega directamente al final, se emite solo final.
Pausar/reanudar no repite hitos; repetir reinicia su recorrido. Restaurar no
reproduce hitos pasados. El descanso conserva duración original y tiempo
transcurrido al restaurarse, para no calcular una mitad nueva sobre el resto.

Conexiones comprobadas: reloj AMRAP, series por tiempo, ventanas de rendimiento,
EMOM y temporizador de descanso. Los cronómetros sin duración objetivo no
inventan una mitad ni un final. El ejecutor sigue requiriendo confirmar resultados.

## Validación y límites

- Análisis limpio en raíz y admin. Baterías completas: **606 pruebas correctas**
  en raíz y **91** en admin, con la omisión web y la captura optativa existentes.
- **27 pruebas específicas** correctas: WAV empaquetados con señal PCM,
  preferencias independientes/persistentes, prueba/cancelación/guardado,
  errores, reutilización del plugin, sustitución y carga lenta,
  pausa/reanudación/repetición, restauración y descansos.
- Compilación Android debug correcta, usando desarrollo. No acredita escucha
  en Android físico ni convivencia con música/auriculares.
- Banco manual `tools/workout_cue_probe.dart` compilado en web. Recorrido real
  de 40 segundos en Chromium: tres preparaciones, inicio, mitad, diez segundos
  y final con estados playing confirmados por el reproductor; final de descanso
  también reproducido. Sin errores de audio en consola. No se simula el plugin
  ni se altera autoplay en esta comprobación. Los estados acreditan aceptación
  de reproducción, no una valoración humana del volumen o de los tonos.
  Prueba explícita y recorrido final de 20 segundos también correctos: preparación,
  inicio, un solo aviso intermedio de diez segundos y final, sin errores de consola.
- iOS: compatibilidad de SPM revisada en el paquete resuelto; compilación con
  el plugin nuevo y escucha en simulador/dispositivo **pendientes**. Windows no
  permite acreditar Xcode. No se presenta UI-018 como cierre de audio nativo.
- No se implementan avisos garantizados con pantalla bloqueada o aplicación
  suspendida. El diálogo indica mantener la sesión en pantalla. El trabajo en
  segundo plano necesitaría su propio diseño y verificación.
- Sin cambios SQL, RLS, derechos Free/Pro, fotos, navegación de pantallas,
  contenido admin ni producción. El Mac IOS-001 se incorpora por avance directo
  tras revisar su diff, conservando su configuración e historial.

Javier comunica una revisión superficial en el simulador de guardado, Evolución
y fotografías con resultado correcto. Es una observación del usuario, no una
auditoría completa. La recuperación por correo en el simulador no se fuerza:
la recepción/recuperación web ya está confirmada en MAIL-001.

Capturas del banco compilado con el tema y los controles actuales, sin cuenta
ni datos personales; no representan un rediseño de la sesión:

![Diálogo actual y prueba de sonido](visual-audit/workout-audio-2026-10-08/01-avisos-probar-sonido.png)

![Intervalo de 20 segundos y estados de reproducción](visual-audit/workout-audio-2026-10-08/02-intervalo-20s.png)

## Siguiente recorrido único

Actualizar la copia del Mac con el bloque guardado, preparar dependencias con
`flutter pub get --enforce-lockfile`, detener y volver a lanzar la app en iOS
de desarrollo (el plugin nuevo requiere reinicio completo). En una sesión:
**Avisos del temporizador → Probar sonido**, seguido de un intervalo de 40
segundos, pausa/reanudación y descanso. Comprobar volumen, silencio, música y
auriculares cuando haya dispositivo físico disponible. El banco sin cuenta
puede ejecutarse también con `flutter run -d <simulador> -t
tools/workout_cue_probe.dart`.

No abrir otro bloque grande antes de resolver este recorrido o dejar su límite
explícito. Comparativas configurables, publicación segura, vídeos, negocio y
motores conservan sus pendientes propios.
