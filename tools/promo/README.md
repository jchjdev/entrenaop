# Demo y grabación local de EntrenaOP

Alumnos ficticios: Lucía Vega, Dani Torres, Nora Martín y Marcos Vidal.
Preparador: Entrenador demo. La semana se fija en el 31/10/2026 para la filmación.
No hay correos, fotos, credenciales ni datos de personas reales.

## Qué se ejecuta

Dos entradas alternativas, fuera de los `main.dart` de producto, reutilizan sus
pantallas, Cubits y navegación. Se inyectan repositorios locales en memoria.
No se inicializan Supabase, compras, push ni proveedores de servicios.
No se dan de alta usuarios ni se escriben datos en Dev o producción.

- `athlete_demo.dart`: inicio, plan, semana, biblioteca, ejercicios, marcas,
  espacio con el preparador y conversación de ejemplo.
- `trainer_app/tool/promo/trainer_demo.dart`: alumnos, ficha con objetivos y
  seguimiento, agenda y conversación de ejemplo.
- Las rutas ajenas al recorrido muestran un aviso de demo. No son dos nuevas
  aplicaciones de producto. No se ofrecen pagos, conexión entre procesos,
  vídeos técnicos externos ni ejecución completa de entrenamientos.

## Regrabar

Desde la raíz, con Flutter y FFmpeg existentes en PATH:

```powershell
./tools/promo/record.ps1
```

El script ejecuta dos recorridos de widgets reales. Captura los fotogramas del
motor Flutter a 20 fps durante las transiciones y gestos; conserva la duración
de las pausas con un manifiesto FFconcat. No utiliza las capturas históricas de
la web ni dibuja una interfaz parecida. FFmpeg codifica H.264/yuv420p sin sonido
y con `faststart`; también extrae los pósteres WebP.

Los PNG y manifiestos quedan en `build/promo/take-*/`, fuera de Git. Los vídeos
y pósteres se escriben en `website/next/assets/`. Regrabar es una acción local:
no publica nada ni modifica los precios o el panel Trainer existentes.

## Abrir las demos navegables

Cada comando se ejecuta desde el proyecto correspondiente. Usan puertos
distintos del Live Server de la web (5500):

```powershell
# Raíz del repositorio, en una terminal:
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8780 --target tools/promo/athlete_demo.dart

# Desde trainer_app/, en otra terminal:
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8781 --target tool/promo/trainer_demo.dart
```

Para una compilación estática, usar `flutter build web --release --no-pub
--no-web-resources-cdn --target ... --output RUTA_ABSOLUTA`. En Windows el
compilador de shaders puede fallar con una salida relativa fuera del proyecto.
Los builds se conservan en `build/promo/athlete-web/` y
`build/promo/trainer-web/`; se sirven solo en loopback durante esta revisión.
Para abrir ambos builds ya generados: `node tools/promo/serve.mjs` desde la raíz.
La demo del deportista se ha comprobado también en build web `--debug`, con
los recursos e iconos cargados; Trainer utiliza el build de release. Antes de
servir un build debe existir su `assets/FontManifest.json`: una compilación
interrumpida puede dejar el directorio de recursos vacío.

La demo usa datos fijados para el rodaje. El Inicio real consulta la fecha del
dispositivo; fuera de la semana de ejemplo puede mostrar un día sin sesión.
