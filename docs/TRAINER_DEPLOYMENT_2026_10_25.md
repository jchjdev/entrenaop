# Publicación automática de Trainer Dev · 25/10/2026

## Alcance y estado

Javier pide automatizar la publicación de `trainer.entrenaop.es` como ADMIN,
sin depender del gestor de archivos de Hostinger. El destino sigue siendo solo
EntrenaOP Dev, proyecto `sxbxfjqgoddzhtcyhalw`, carpeta `public_html/trainer`.
No se configura ni se modifica producción, autenticación de usuarios o MFA.

El código incorpora el circuito de validación, compilación, artefacto y despliegue
separado en `.github/workflows/trainer-dev.yml`. El despliegue queda omitido
mientras la variable de repositorio `TRAINER_DEV_DEPLOY_ENABLED` no sea `true`.
La validación y el artefacto funcionan independientemente de disponer de cuenta
FTPS. Este estado no acredita todavía una publicación automática de Trainer.

Comprobación de Hostinger del 25/10: existe la cuenta administrativa confinada,
pero todavía no una cuenta Trainer. La creación de `trainerci` se prepara para
que Javier introduzca su contraseña; no se inventa ni se copia una contraseña
de ADMIN. El entorno GitHub `trainer-dev` ya está creado, limitado a una rama
`main` y cero tags, sin bypass administrativo, con los secretos aún vacíos.
Quedan pendientes la cuenta confinada, los secretos propios, la activación y una ejecución
real que termine con la verificación pública correcta.

## Motor común y adaptadores separados

`tools/static_web_release.py` conserva el empaquetado público común. Se extraen
sin duplicarlos a `tools/static_web_deploy.py` el transporte IPv4/TLS, lectura del
`main` remoto, subida versionada, activación, reintentos y restauración existentes
en ADMIN. Los dos adaptadores mantienen sus CLI y verificadores particulares:

| Portal | Adaptador | Destino FTPS confinado | Secretos exclusivos |
| --- | --- | --- | --- |
| ADMIN Dev | `admin_app/tool/admin_release.py` | `public_html/admin` | `HOSTINGER_ADMIN_FTPS_USER`, `HOSTINGER_ADMIN_FTPS_PASSWORD` |
| Trainer Dev | `trainer_app/tool/trainer_release.py` | `public_html/trainer` | `HOSTINGER_TRAINER_FTPS_USER`, `HOSTINGER_TRAINER_FTPS_PASSWORD` |

Trainer no importa `admin_app` ni utiliza su cuenta. Un paquete o raíz remota de
ADMIN se rechaza desde Trainer antes de escribir y viceversa. Se mantiene la
identidad de host, entorno `development` y proyecto Dev. Trainer conserva además
sus requisitos de fuentes limpias y ruta versionada. Su comprobación de fuentes
incluye las dependencias locales realmente consumidas, ambos módulos Python
compartidos y su workflow.

El cambio en ADMIN conserva los nombres públicos y puntos de sustitución de
sus pruebas. No modifica su cuenta, secretos, variable ni retención. Su workflow
incluye ahora también el módulo de despliegue compartido como ruta de activación.
Su empaquetado rechaza cambios pendientes en ambos módulos comunes y el workflow,
además de su alcance previo.

## Recorrido automático

1. Solo `main`: cambios en Trainer, sus cuatro paquetes locales, dependencias,
   herramientas de publicación o workflow; también ejecución manual sobre main.
2. Si el despliegue está habilitado, prueba temprana de conexión IPv4 y certificado
   TLS sin secretos, login ni escrituras. No existe alternativa con FTP sin cifrar.
3. Flutter oficial 3.47.5 con SHA-256 fijado; dependencias con `--enforce-lockfile`.
4. Análisis y pruebas Trainer. Si cambia código compartido o se ejecuta manualmente,
   también análisis y pruebas del deportista y ADMIN. Ambos publicadores Python
   se comprueban en cada ejecución para evitar regresiones de aislamiento.
5. Compilación web solo Dev, sin mapas ni recursos externos del motor. Paquete de
   fuentes guardadas y artefacto `trainer-dev-<SHA>` conservado durante 14 días.
6. El job `deploy` requiere validación correcta, `main`, variable habilitada y el
   entorno GitHub `trainer-dev`. Solo este job recibe los dos secretos Trainer.
7. Antes de cada conexión, se contrasta el SHA contra el `main` actual de GitHub.
   Si ha avanzado, no se activa un paquete obsoleto. Concurrencia propia de Trainer,
   sin cancelar una publicación mientras esté activando archivos.
8. Cuenta confinada, TLS 1.2 mínimo con certificado/SNI válidos y canal de datos
   cifrado. Recursos de la release primero, entrada al final por renombrado.
9. Verificación HTTPS de identidad, revisión, release, ruta, SHA-256 del JavaScript,
   entrada, cabeceras y MIME de WebAssembly. Si falla, se restaura la configuración
   y entrada anteriores. No se borran releases ni historial.

Los fallos transitorios previos a la activación admiten hasta tres conexiones;
no se reintenta una activación/restauración fallida ni un certificado inválido.
Los mensajes contienen fases y categorías cerradas, no respuestas remotas ni
credenciales. Una avería de red o de Hostinger puede seguir haciendo fallar una
publicación: el circuito no promete disponibilidad del proveedor.

## Activación pendiente

La implementación y sus pruebas se completan antes de habilitar la cuenta:

1. En Hostinger, crear `trainerci` restringida exclusivamente a
   `public_html/trainer`, con contraseña introducida por Javier. No usar el
   usuario principal del hosting ni ampliar la cuenta de ADMIN.
2. En el entorno `trainer-dev` ya preparado en GitHub, guardar los secretos
   `HOSTINGER_TRAINER_FTPS_USER` y `HOSTINGER_TRAINER_FTPS_PASSWORD` con los datos
   de esa cuenta. No guardar secretos en Git, archivos, mensajes o defines Flutter.
3. Configurar la variable **de repositorio** `TRAINER_DEV_DEPLOY_ENABLED=true`.
   Se usa a nivel repositorio porque decide el job antes de entrar en el entorno.
4. Ejecutar `Publicar Trainer Dev` desde `main` y comprobar el resultado `deploy`,
   el manifiesto HTTPS y su hash. Solo entonces registrar la automatización como
   operativa. Hasta ese momento, un artefacto correcto no equivale a publicación.

Para detener nuevas publicaciones basta dejar la variable fuera de `true`; la
versión pública permanece y la validación sigue conservando artefactos. No se
configura limpieza automática destructiva del servidor. La retención inicial de
14 días afecta solo a los artefactos de GitHub de este workflow.

## Comprobación local

- 42 pruebas Python ADMIN existentes correctas tras la extracción, sin rebajarlas.
- 17 pruebas Python Trainer correctas: las siete de paquete existentes y diez
  nuevas de aislamiento, identidad, main, credenciales, restauración y logs.
- Ambos workflows pasan `actionlint` 1.7.12 y sus siete bloques Bash cada uno
  pasan `bash -n`; no se añade una dependencia al proyecto.
- `connection-check` prueba solo conectividad/certificado públicos; no acredita
  la cuenta confinada ni la publicación desde GitHub.
- Sin cambios Flutter: no se repiten sus baterías por modificar solo Python,
  workflows y documentación. El primer workflow ejecutará su validación completa.

La comprobación real de Trainer queda pendiente de la activación anterior. ADMIN
ya tenía su publicación IPv4/TLS acreditada antes de esta extracción; conservar
sus pruebas no sustituye la comprobación del siguiente despliegue automático.
