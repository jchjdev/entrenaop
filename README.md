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
