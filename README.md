# EntrenaOP

EntrenaOP es una plataforma multiplataforma de preparación física para
oposiciones. Su primer foco es PAEF/PAFA y su núcleo de producto es el ciclo:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

La aplicación se desarrolla con Flutter y Supabase. Android e iPhone son los
clientes prioritarios para entrenar; la web servirá inicialmente como panel de
gestión y seguimiento. Windows se mantiene como destino compatible sin
condicionar el MVP.

## Documentación vigente

- [Producto](docs/PRODUCT.md): visión, promesa, niveles y alcance.
- [Arquitectura](docs/ARCHITECTURE.md): estado observado y criterios técnicos.
- [Roadmap](docs/ROADMAP.md): orden de trabajo y fases.
- [Auditoría inicial](docs/AUDIT.md): hallazgos comprobados y prioridades de
  saneamiento.
- [Historia](docs/HISTORY.md): contexto antiguo que no constituye una lista de
  instrucciones.

Las reglas de colaboración y las decisiones vigentes del repositorio se
encuentran en [AGENTS.md](AGENTS.md).

## Entornos

Las ejecuciones sin parámetros usan `entrenaop-dev`. Producción nunca se elige
por defecto y requiere compilar indicando explícitamente `APP_ENV=production`,
`SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante `--dart-define` o
`--dart-define-from-file`.

Las claves publicables de Supabase identifican al cliente y pueden distribuirse
con la aplicación. Las contraseñas de base de datos, claves secretas y tokens de
administración no se guardan en el repositorio.

## Ejecutar en VS Code

En **Ejecutar y depurar** se puede elegir `EntrenaOP Chrome · puerto fijo` para
la web, que abre `http://localhost:55554`. Una vez autenticado, la primera zona
de administración está en `http://localhost:55554/#/admin`. Solo una cuenta con
permiso administrativo en Supabase puede listar y crear borradores. Es necesario
aplicar las migraciones pendientes del entorno antes de usarla.

Para la app, seleccionar primero un emulador o dispositivo Android en VS Code y
ejecutar `EntrenaOP App · dispositivo seleccionado`. Ambas opciones usan el mismo
código y backend de desarrollo, pero la zona `/admin` solo se presenta en web.
Publicar una web en Internet requiere configurar un alojamiento y el entorno
de producción por separado; ejecutar en VS Code solo la sirve localmente.
