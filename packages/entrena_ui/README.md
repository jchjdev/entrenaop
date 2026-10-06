# Entrena UI

Identidad visual compartida por la aplicación del deportista y el admin.
Solo depende de Flutter: no incluye rutas, repositorios, permisos ni reglas
de entrenamiento.

- `EntrenaTheme.dark`: tema Material 3 con la identidad EntrenaOP.
- `context.visuals`: tokens semánticos para superficies, bordes y estados.
- `EntrenaCard`: superficies de marca; reservar el tono acentuado para la
  acción principal y usar `Card` para contenido convencional.
- `EntrenaWordmark`: letras oficiales con variantes para fondo claro y oscuro,
  cargadas desde los assets del paquete.

Las dos aplicaciones consumen el mismo tema. La composición y la densidad de
cada pantalla se deciden en su propia capa de presentación.

Criterios vigentes: `../../docs/VISUAL_DESIGN.md`.
