# EntrenaOP

EntrenaOP es una plataforma multiplataforma de preparación física para
oposiciones. Su primer foco es PAEF/PAFA y su núcleo de producto es el ciclo:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

La aplicación se desarrolla con Flutter y Supabase. Android e iPhone son los
clientes prioritarios para entrenar. El panel de gestión web vive en el proyecto
separado `admin_app/`; ambos comparten Supabase, no código de interfaz. Windows
se mantiene como destino compatible sin condicionar el MVP.

## Documentación vigente

- [Decisiones](docs/DECISIONS.md): índice breve de criterios confirmados,
  pendientes, implementados o sustituidos y su documento responsable.
- [Producto](docs/PRODUCT.md): visión, promesa, niveles y alcance.
- [Arquitectura](docs/ARCHITECTURE.md): estado observado y criterios técnicos.
- [Roadmap](docs/ROADMAP.md): orden de trabajo y fases.
- [Dominio de evaluación](docs/PHYSICAL_ASSESSMENT_DOMAIN.md): separación de
  programas, catálogos, baremos e historial.
- [Algoritmo de carrera V1](docs/ALGORITMO_CARRERA_V1.md): contrato probado y
  límites del prototipo de primera semana de Tropa.
- [Auditoría inicial](docs/AUDIT.md): hallazgos comprobados y prioridades de
  saneamiento; es una instantánea histórica, no el estado actual.
- [Historia](docs/HISTORY.md): contexto antiguo que no constituye una lista de
  instrucciones.

Las reglas de colaboración y las decisiones vigentes del repositorio se
encuentran en [AGENTS.md](AGENTS.md).

El panel tiene sus instrucciones de ejecución en
[admin_app/README.md](admin_app/README.md), y la evolución del esquema y sus
pruebas transaccionales se documentan en
[supabase/README.md](supabase/README.md).

## Entornos

Las ejecuciones sin parámetros usan `entrenaop-dev`. Producción nunca se elige
por defecto y requiere compilar indicando explícitamente `APP_ENV=production`,
`SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante `--dart-define` o
`--dart-define-from-file`.

Las claves publicables de Supabase identifican al cliente y pueden distribuirse
con la aplicación. Las contraseñas de base de datos, claves secretas y tokens de
administración no se guardan en el repositorio.

## Ejecutar en VS Code

En **Ejecutar y depurar** desde la raíz se puede elegir
`EntrenaOP Chrome · puerto fijo` para la versión web de la app del alumno
(`http://localhost:55554`). Para el panel, abrir `admin_app/` como **otra carpeta
de VS Code**, elegir allí `EntrenaOP Admin · Chrome 55555` y pulsar F5. Se abre
`http://localhost:55555` (sin `/#/admin`). Esa dirección solo responde mientras
está ejecutándose el panel. Cada uno es un proyecto Flutter distinto dentro del
mismo repositorio. El panel requiere una cuenta con permiso administrativo en
Supabase; sus operaciones vuelven a comprobarlo en el servidor.

Para la app, seleccionar primero un emulador o dispositivo Android en VS Code y
ejecutar `EntrenaOP App · dispositivo seleccionado`. Ambas opciones usan el mismo
proyecto del alumno y el mismo backend de desarrollo; el código de `admin_app/`
no forma parte de la APK/IPA. El panel tiene su propio inicio de sesión y guarda
la sesión por separado al funcionar en otro puerto.
Publicar una web en Internet requiere configurar un alojamiento y el entorno
de producción por separado; ejecutar en VS Code solo la sirve localmente.
