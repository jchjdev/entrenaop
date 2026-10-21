# Publicación del panel profesional Dev · TRN-011 · 21/10/2026

## Autorización y alcance

Javier solicita publicar `trainer.entrenaop.es` y habilitar su cuenta
administrativa existente como preparador para probar el mismo TOTP antes de
continuar las asignaciones. Solo EntrenaOP Dev (`sxbxfjqgoddzhtcyhalw`).
Cupo operativo concedido: cinco alumnos de prueba, sin cobros y sin conceder
otros permisos ni Pro personal. No se modifica producción.

El subdominio tiene la carpeta propia `public_html/trainer` del alojamiento
existente. La publicación no usa la cuenta FTPS confinada de ADMIN ni cambia
la web principal. La identidad es la de EntrenaOP; cada origen web tiene su
sesión y el acceso profesional exige AAL2 y un TOTP verificado en servidor.

## Preparación técnica

- Se conserva el contrato del publicador ADMIN: solo su empaquetado estático
  pasa a `tools/static_web_release.py`. Sus guardas de identidad, transporte
  FTPS, conservación de archivos y restauración permanecen en el adaptador.
- `trainer_app/tool/trainer_release.py` prepara un paquete versionado y ZIP
  para la carga inicial en Hostinger y permite verificar después manifiesto,
  revisión, SHA-256 del JavaScript, cabeceras y MIME WebAssembly por HTTPS.
- La configuración específica solo admite trainer.entrenaop.es y Dev, fuerza
  HTTPS, evita listado/indexación, limita el origen de arranque y conserva
  rutas estables mientras los recursos viven en `releases/<id>/`.
- Las fuentes deben estar guardadas y coincidir con HEAD al empaquetar.
  Se conserva `default.php` y no se borra la publicación de ADMIN.
- El paso de dependencias de `admin-dev.yml` resuelve también trainer_app antes
  del análisis raíz. Corrige el fallo de la ejecución 39569428173, que ocurrió
  antes del despliegue: en un ejecutor nuevo faltaba su contexto de paquetes.
- La nueva aplicación no reutiliza credenciales de publicación administrativas.
  Este primer despliegue no configura acceso persistente nuevo para CI.

## Procedimiento preparado

Desde una revisión validada de main y con el árbol de fuentes correspondiente
guardado:

```powershell
cd trainer_app
flutter build web --release --csp --no-web-resources-cdn --no-source-maps --no-wasm-dry-run --dart-define=APP_ENV=development
cd ..
python trainer_app/tool/trainer_release.py package --output build/trainer-release-IDENTIDAD --revision SHA_COMPLETO --release-id SHA_COMPLETO-IDENTIDAD-1
```

IDENTIDAD debe ser numérica. El paquete ya contiene las cabeceras, el manifiesto
y la estructura de recursos. El ZIP se carga en una carpeta privada del
administrador de archivos y se extrae en `public_html/trainer`, conservando
archivos ajenos. Después:

```powershell
python trainer_app/tool/trainer_release.py verify --output build/trainer-release-IDENTIDAD
```

Las contraseñas y el OTP los introduce Javier directamente en los formularios;
no se solicitan por el chat ni se guardan en el repositorio. La comprobación
humana debe ver el reto MFA y después el panel con el cupo concedido.

## Publicación y entrada humana comprobadas

Javier confirma de nuevo la creación y publicación. Hostinger acredita el alta de
`trainer.entrenaop.es` en `public_html/trainer` el 21/10/2026. La confirmación
inmediata exigida por el navegador se ha recibido antes de pulsar Crear.

El paquete se ha cargado y extraído en `public_html/trainer`, sin sobrescribir
archivos ajenos. El verificador HTTPS acredita host, proyecto Dev, revisión,
SHA-256 de JavaScript, arranque versionado, no-store, X-Frame-Options DENY y MIME
WebAssembly. Chrome muestra el formulario real de acceso con logo, estilos y
recursos locales. Javier completa después la entrada con contraseña y TOTP,
y se comprueba el panel protegido.
El contrato de pagos queda separado en [TRN-012](TRAINER_PAYMENTS.md).

## Habilitación inicial comprobada

Se activa `manual_access_enabled` exclusivamente en Dev y se concede acceso
profesional a la cuenta existente del responsable de cuentas, previamente
contrastada con `admin_permissions` y un factor TOTP verificado. Cinco plazas,
revisión 1, sin fecha automática de caducidad y sin cambios de Pro o permisos
administrativos. No se fija una política comercial de caducidad.

Alta operativa mediante conexión administrativa de confianza, en una transacción
con bloqueo asesor y comprobación de ausencia de concesiones previas. Incluye
un registro `trainer_access_audit`; `actor_id` y `updated_by` nulos identifican
la operación de infraestructura, no una sesión humana AAL2. El motivo conserva
la autorización, fecha y alcance. No se suplantan claims ni se altera MFA/RLS.

Validación del paquete: 30 pruebas del publicador ADMIN y cinco profesionales;
análisis raíz y profesional limpios; 1133 pruebas raíz aprobadas (una omitida
preexistente) y siete profesionales aprobadas. Se incorpora el arranque web
propio sin registro de service worker, con el mismo contrato del publicador.
ZIP preparado de `6b7f0d5`, SHA-256
`a9c836e1492280bce02e7674265621ecbfc2d1f3bb4e3c578f78f457959258ff`.

Javier confirma que ha activado el permiso de archivos de la extensión. Se sube
el ZIP a `trainer-releases` fuera de `public_html` y se extrae en la carpeta
independiente de Trainer, sin crear credenciales persistentes de publicación.
La entrada pública está verificada el 21/10/2026:

- Dominio: https://trainer.entrenaop.es
- Revisión: `6b7f0d5c2bebba0c742f2fa3b1a7c1b44789b91d`.
- Publicación: `6b7f0d5c2bebba0c742f2fa3b1a7c1b44789b91d-20261021-1`.
- Verificador: `python trainer_app/tool/trainer_release.py verify --output build/trainer-release-20261021`, correcto.
- [Captura del acceso publicado](visual-audit/trainer-access-2026-10-21/published-login.png).

La validación GitHub ADMIN 39573481003 pasó, pero su transferencia terminó en
`OSError`. La siguiente ejecución 39574069062 completa validación, publicación
HTTPS y conservación de paquetes correctamente. No se alteró el transporte FTPS
para resolver esa incidencia.

Javier completa contraseña → reto del autenticador → panel profesional en
Chrome. Se acredita acceso activo con 0/5 plazas ocupadas y carga de alumnos e
invitaciones sin error. Actualizar vuelve a consultar correctamente; Finalizados
muestra su estado vacío; una recarga completa conserva la sesión verificada y
regresa al panel de alumnos activos. Los RPC que alimentan acceso y vínculos
exigen AAL2/TOTP en servidor; esta comprobación no lee ni exporta tokens.

Los tres errores de consola observados proceden de una extensión de Chrome
(`Receiving end does not exist`), no del origen del panel. No se crean invitaciones,
vínculos ni datos de alumnos durante esta comprobación.
[Captura del panel autenticado](visual-audit/trainer-access-2026-10-21/published-clients.png).

El autenticador pertenece a cada identidad EntrenaOP: cada preparador usa el
suyo y lo configura con QR si aún no lo tiene. La cuenta de Javier reutiliza su
factor existente de ADMIN porque es la misma identidad; esto no comparte códigos
entre personas ni concede permisos administrativos a otros preparadores.

Se cierra publicación y primera entrada humana del piloto Dev. Siguen sin
ensayo humano remoto la caducidad de sesión y la recuperación de un autenticador
perdido. Las pruebas anteriores cubren invitaciones, cupo e aislamiento; esta
entrada manual no acredita el recorrido con un alumno real ni asignaciones.
El único siguiente bloque recomendado es concretar derechos tras fin de vínculo
y convivencia con el plan, y completar sesión privada → asignación versionada →
ejecución existente → resultados autorizados. No se activan cobros aquí.

## Actualización de cartera · TRN-015 · 21/10/2026

Publicación `029a46ce7a638ac5954c9e85cd4ea7034636e144-20261021-2`, con fuentes
guardadas en `029a46ce7a638ac5954c9e85cd4ea7034636e144`. ZIP cargado en
`trainer-releases`, fuera de `public_html`, SHA-256
`1551e7c22bdf1d190476dead43e9931a64638327b05cc5674c912f56bfd81f89`.
Se extrae en `public_html/trainer`, actualizando la entrada y conservando la
publicación anterior en su carpeta versionada.

`trainer_release.py verify --output build/trainer-portfolio-release-20261021`
acredita por HTTPS la revisión, el JavaScript y las cabeceras esperadas. Chrome
carga las tres listas Activos/Inactivos/Archivados con la sesión existente y
0/5 plazas, sin errores de consola ni crear alumnos o invitaciones de ensayo.
[Captura publicada](visual-audit/trainer-portfolio-2026-10-21/published-clients.png).
La cartera y sus pruebas se describen en [TRN-015](TRAINER_CLIENT_LIFECYCLE.md).

## Sesiones privadas y resultados · TRN-016 · 21/10/2026

Publicación final `efff7227653cea6b37e26f6c362a6b7c0e4e03e8-20261021-4` desde
fuentes guardadas, ZIP SHA-256
`a3be588ea2d7fe916021090160ee54505fc27490b82860176791c831546ef867`.
Se carga en `trainer-releases` y se extrae en `public_html/trainer`, conservando
las versiones anteriores. No se modifican ADMIN, credenciales ni producción.

`trainer_release.py verify --output build/trainer-workouts-catalog-release-20261021`
correcto por HTTPS. Chrome conserva la sesión MFA y acredita biblioteca vacía,
creador compartido y catálogo autorizado sin guardar datos de prueba. Consola
del portal sin errores en la comprobación. Los resultados no se atribuyen a una
prueba humana con alumnos: [contrato y límites](TRAINER_PRIVATE_WORKOUTS.md).

## Programas privados y agenda · TRN-017 · 21/10/2026

Publicación final `834e3b649f8f797df7e1dcd77f620b07a7f9126c-20261021-6`, ZIP
SHA-256 `e8140b94dbccc13ff34895129c85f1ba407a24b0b6d9d70aee3ff17b3bc66ebe`.
Se carga en `trainer-releases` y se extrae solo en `public_html/trainer`,
conservando publicaciones anteriores. El verificador HTTPS acredita revisión,
hash de JavaScript, entrada, cabeceras y WebAssembly. El empaquetado comprueba
los paquetes locales resueltos de Trainer, sin incluir trabajo paralelo de
paquetes que aún no consume.

Chrome acredita agenda mensual, biblioteca de programas y creador con la sesión
MFA existente, cero errores de consola y los cuatro destinos en el árbol
accesible. Se corrige el bloqueo semántico de la barra lateral antes del cierre.
No se guarda contenido de prueba ni se toca ADMIN o producción durante la
publicación. La actualización móvil y el recorrido humano con alumno siguen
pendientes. [Contrato, pruebas y capturas](TRAINER_PRIVATE_PROGRAMS.md).
