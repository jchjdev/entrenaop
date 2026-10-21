# Publicación del panel profesional Dev · TRN-011 · 21/10/2026

## Autorización y alcance

Javier solicita publicar `trainer.entrenaop.es` y habilitar su cuenta
administrativa existente como preparador para probar el mismo TOTP antes de
continuar las asignaciones. Solo EntrenaOP Dev (`sxbxfjqgoddzhtcyhalw`).
Cupo operativo propuesto: cinco alumnos de prueba, sin cobros y sin conceder
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
