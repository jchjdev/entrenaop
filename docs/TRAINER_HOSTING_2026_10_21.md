# Publicación del panel profesional Dev · TRN-011 · 21/10/2026

## Autorización y alcance

Javier solicita publicar `trainer.entrenaop.es` y habilitar su cuenta
administrativa existente como preparador para probar el mismo TOTP antes de
continuar las asignaciones. Solo EntrenaOP Dev (`sxbxfjqgoddzhtcyhalw`).
Cupo operativo concedido: cinco alumnos de prueba, sin cobros y sin conceder
otros permisos ni Pro personal. No se modifica producción.

El subdominio tendrá la carpeta propia `public_html/trainer` del alojamiento
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

## Estado pendiente de acreditar

Javier confirma de nuevo la creación y publicación. Hostinger acredita el alta de
`trainer.entrenaop.es` en `public_html/trainer` el 21/10/2026. La confirmación
inmediata exigida por el navegador se ha recibido antes de pulsar Crear.

Aún no se acredita carga, acceso HTTPS ni entrada TOTP humana. Las pruebas y
la publicación real se registrarán al completarse. El contrato de pagos al
entrenador queda separado en [TRN-012](TRAINER_PAYMENTS.md).

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

La carga está pendiente del permiso «Permitir acceso a URL de archivo» de la
extensión de Chrome. El gestor de Hostinger ya tiene `trainer-releases` fuera
de `public_html`; todavía no contiene el ZIP. La validación GitHub del flujo
ADMIN 39573481003 pasa, pero su transferencia termina en `OSError`; el dominio
ADMIN conserva `4b2759d`. La corrección del análisis no acredita despliegue.
