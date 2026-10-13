# Compras de prueba · COM-013/014

COM-016 agrega **Cuentas y Pro** en el admin (`/accounts`) para regalos gratuitos,
separados de las compras del proveedor. Busca correo, elige plazo, fecha o sin
fecha de fin, indica motivo y confirma. Dev tiene `gift_management_enabled=true`;
no se modifica producción. El deportista debe actualizar la beta para regalos
indefinidos y puede reconsultar Perfil → Mi suscripción → Actualizar acceso.
Retirar el regalo conserva la compra vigente. La prueba SQL
`supabase/tests/administrative_pro_gifts.sql` cubre permisos, caducidad,
auditoría y fuentes simultáneas con ROLLBACK. La ampliación no utiliza promociones
de RevenueCat ni hace falta un pago de prueba para regalar Pro.

El código está preparado para RevenueCat Test Store y Supabase Dev. El proyecto
externo **EntrenaOP**, `bb91cf72`, está creado y conectado a Supabase Dev. La
migración y las dos funciones están desplegadas; SANDBOX está habilitado solo
en Dev. No hay cobros reales activos.
La beta profile conserva los accesos manuales y contratación deshabilitada.

## Estado externo comprobado el 13/10/2026

- Test Store: `app78a6582249`.
- Entitlement `pro`, nombre visible EntrenaOP Pro: `entl1e019d80cb`.
- Offering `default`: `ofrng09c459baeb`, actual, con `$rc_monthly` y `$rc_annual`.
- `entrenaop_pro_monthly`, `prod8c8016bec6`: **3,99 EUR/mes**.
- `entrenaop_pro_annual`, `prodb40fc8e7e5`: **29,99 EUR/año**.
- Ambos productos están asociados a `pro`; la previsualización oficial del SDK
  confirma los paquetes y sus identificadores. No hay producto Lifetime.
- La petición pública de productos que utiliza el SDK, con configuración
  española `es_ES`, devuelve esos importes en EUR. No acredita aún una compra
  ni el recorrido nativo completo. La moneda no se sustituye con un símbolo.
- Los precios USD de ejemplo del asistente siguen como alternativa en el
  catálogo de pruebas (9,99/79,99); no son tarifas comerciales aprobadas. Antes
  de validar otra región debe comprobarse qué moneda devuelve el proveedor.
- El auxiliar `entrenaop_pro_monthly_v1`, `prode7f0958689`, sin compras ni
  asociaciones, queda archivado de forma reversible. No se borran productos.
- Javier autoriza OAuth del CLI oficial 0.1.4 y guardar su sesión local,
  limitado al proyecto EntrenaOP. La sesión está conectada y los precios EUR
  actualizados. El identificador API es `projbb91cf72`, distinto del ID del panel.
  No hay conexión ni lectura de Gmail.
- Javier autoriza crear la clave privada y conectar exclusivamente Supabase Dev.
  La clave y el secreto independiente del webhook se transfieren directamente
  al formulario seguro de Supabase, sin copia local ni contenido en Git.
- Webhook `whintgrf014797801`: Test Store, Sandbox only, todos los eventos.
  Evento TEST autenticado: HTTP 200; ambas funciones sin autorización: HTTP 401.
- Una compra mensual simulada con el CLI oficial para la cuenta principal de
  pruebas genera `INITIAL_PURCHASE` y el servidor guarda `active=true`,
  `environment=SANDBOX`, `store=test_store` y la vigencia canónica del proveedor.
  La concesión manual principal se conserva; en ese primer ensayo la segunda
  cuenta sigue Free.
  No acredita compra/restauración desde la interfaz nativa ni ventas reales.
- Al vencer los cinco minutos de la compra mensual simulada, el reloj SQL deja
  de contar esa compra como fuente válida; la cuenta conserva su Pro manual.
  Esto comprueba vencimiento por fecha, no entrega de un evento EXPIRATION.
- En la comprobación posterior llegan RENEWAL y EXPIRATION de la compra inicial:
  la fuente RevenueCat queda inactiva y se conserva el Pro manual.
- Javier ejecuta después la app en Android físico (Samsung SM-A326B, Android 13)
  y utiliza las tres opciones del simulador. INITIAL_PURCHASE de la cuenta
  secundaria llega el 13/10 a las 21:08 (Madrid); el servidor confirma Pro por
  RevenueCat, SANDBOX, producto mensual. No hay cobro real. El texto pegado solo
  contiene logs de ventanas Android: respuesta visible de error/cancelación,
  pantalla final de Pro y restauración aún no quedan verificadas.
- Javier confirma Pro tras reiniciar y concreta el error rojo en Perfil →
  Mi suscripción → Ir a Mi plan. COM-015 reproduce la clave de Navigator
  duplicada y corrige el acceso para usar `go` sin apilar otro shell. Análisis
  limpio, 37 pruebas Pro y 768 de raíz correctas, con la omisión web existente.
  La regresión incluye compra confirmada y actualización de oferta a Pro.
  Repetir ese retorno en el móvil tras reiniciar con el código actualizado;
  cancelación/error visibles y restauración continúan pendientes.
- Javier solicita devolver la cuenta secundaria a Free. La vigencia de su
  compra mensual termina el 13/10 a las 21:33 (Madrid), sin más renovaciones;
  el servidor confirma `tier=free` y fuente nula después del vencimiento.
  Se conserva el historial y no se modifica a mano una compra aún vigente.
- Historial Dev: 139 migraciones coincidentes. Las pruebas SQL de conciliación
  y cuotas se repiten tras desplegar, con ROLLBACK.

Se conservan los identificadores canónicos del contrato del código.
[Gestión oficial de precios por moneda](https://www.revenuecat.com/docs/tools/cli/commands).

## 1. Proyecto y catálogo de RevenueCat

Entrar en [el panel](https://app.revenuecat.com/), no en la documentación.
En el registro, **Add it later** permite omitir la tarjeta. Esa tarjeta pagaría
el servicio de RevenueCat; los ingresos de las tiendas se configuran en sus
portales. El servicio estándar cobra el 1 % al alcanzar 2.500 USD de ingresos
mensuales registrados; por debajo, incluido cero ingresos, no cobra.
[Tarifas](https://www.revenuecat.com/pricing).

El proyecto existente **EntrenaOP** incluye Test Store. No crear otro proyecto
para repetir esta configuración ni conectar aún tiendas reales o Stripe.
[Creación de proyectos](https://www.revenuecat.com/docs/projects/overview).

Product catalog ya contiene el entitlement `pro`, asociado a estos dos productos:

| Identificador | Duración | Paquete en offering `default` | Precio de referencia |
| --- | --- | --- | --- |
| `entrenaop_pro_monthly` | Un mes | Monthly | 3,99 €/mes |
| `entrenaop_pro_annual` | Un año | Annual | 29,99 €/año |

La moneda disponible en Test Store puede diferir. La app toma precio, moneda y
texto localizado del catálogo; calcula el ahorro anual solo si ambas monedas
coinciden. Un precio USD no se etiqueta como EUR. Los precios reales en España
se configurarán y comprobarán posteriormente en Apple/Google.

## 2. Configuración de servidor en Dev

Antes de desplegar, verificar el proyecto enlazado:
`sxbxfjqgoddzhtcyhalw`, nunca producción. La migración
`20261013000000_revenuecat_pro_reconciliation.sql` empieza en `DISABLED`.
Despliegue y activación requieren autorización propia; el acuerdo de guardar
Git no los autoriza. Javier concede esa autorización para Dev el 13/10/2026;
la migración ya está aplicada y el entorno de servidor es SANDBOX.

Las funciones necesitan estas variables privadas en la configuración segura
de Supabase Edge Functions:

| Variable | Valor esperado |
| --- | --- |
| `REVENUECAT_SECRET_KEY` | Clave privada del proyecto compatible con la API v1 de suscriptores |
| `REVENUECAT_ENVIRONMENT` | `SANDBOX` |
| `REVENUECAT_APP_ID` | Identificador de la app Test Store del proyecto |
| `REVENUECAT_WEBHOOK_TOKEN` | Secreto aleatorio independiente para autenticar el webhook |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` los proporciona
el entorno de las funciones. La función rechaza SANDBOX si la URL no corresponde
exactamente al proyecto Dev indicado. No guardar claves privadas en Flutter,
Git, capturas ni mensajes. En esta configuración se transfieren directamente
al formulario de Supabase; no se prepara un archivo local de secretos.

Se aplica solo la migración revisada y se despliegan `revenuecat-sync` y
`revenuecat-webhook`, sin podar otras funciones. El `config.toml` declara
`verify_jwt=false`: la primera verifica el JWT en Auth; la segunda verifica
`Authorization: Bearer <REVENUECAT_WEBHOOK_TOKEN>`. No son rutas anónimas.

En RevenueCat, configurar la integración webhook para la app de prueba:

`https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/revenuecat-webhook`

Utilizar ese Bearer como cabecera de autorización y los eventos sandbox de la
app correcta, incluidos compra, renovación, cancelación, caducidad, cambio de
producto, incidencia de facturación y transferencia. El aviso TEST autenticado
se reconoce sin conceder Pro. Antes de activar SANDBOX, comprobar respuesta
TEST y rechazo sin Bearer. El operador, mediante SQL de confianza en Dev, puede
entonces cambiar `revenuecat_access_settings.environment` a `SANDBOX`.

Cada evento provoca una consulta canónica al proveedor; sus fechas o importes
no conceden derechos directamente. Se deduplica por evento/cuenta y se rechaza
una instantánea anterior. Transferencias concilian origen y destino. Retirar un
Pro manual conserva una compra vigente; caducar conserva recursos e historial.

## 3. Compilación de prueba

Usar exclusivamente la clave **pública de SDK Test Store**, que comienza por
`test_`, mediante `REVENUECAT_TEST_API_KEY`. Se configura como el resto de
`dart-define` de desarrollo y se ejecuta **debug** en Android/iOS.

La configuración local Windows está preparada en `.env.revenuecat-dev.json`,
ignorada por Git, con `APP_ENV=development` y la clave pública Test Store.
No incluye claves privadas. En otro ordenador debe configurarse allí también.
La APK debug con esta configuración compila correctamente y queda en
`build/app/outputs/flutter-apk/app-debug.apk`. Javier realiza posteriormente
la prueba en Android físico. La compilación iOS requiere el Mac.

Ejemplo, conservando además la configuración Supabase Dev del proyecto:

```powershell
flutter run --debug --dart-define-from-file=.env.revenuecat-dev.json
```

En VS Code, seleccionar un Android/iPhone en el selector de dispositivos y la
configuración **EntrenaOP Compras · móvil debug Dev** en Ejecutar y depurar;
F5 arranca en debug con ese archivo de configuración. Elegir Chrome o el
perfil de rendimiento mantiene las compras deshabilitadas. En la comprobación
Windows del 13/10, Flutter no detecta móviles conectados ni emuladores Android
creados; posteriormente se conecta el Samsung para la compra. Chrome no
representa un emulador Android.

El SDK no se configura en web, profile, release o producción aunque exista la
clave. Test Store no sirve para la beta profile, TestFlight ni pistas Play.
La compra utiliza el UUID de Supabase como App User ID, nunca el correo.
[Restricciones de Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store).

## 4. Aceptación nativa completa pendiente

Usar una cuenta Free sin concesión manual para observar el cambio; el Pro manual
vigente de la cuenta principal puede ocultarlo. Comprobar en móvil debug:

1. Catálogo mensual/anual, moneda y precio; compra cancelada sin cambio de acceso.
2. Compra de prueba y confirmación en servidor antes de mostrar Pro. Volver a la
   preparación de origen sin crear ni sustituir automáticamente un programa.
3. Comprar con confirmación fallida: mostrar pendiente y comprobar acceso sin
   volver a comprar. Reabrir con recibo activo también debe conciliarlo.
4. Restaurar una compra existente; restaurar sin compras permite suscribirse.
5. Cambiar de cuenta antes/durante una operación: no trasladar el estado anterior.
6. Eventos repetidos, renovación, cancelación hasta vencimiento, caducidad,
   incidencia/gracia explícita, devolución y transferencia, contrastando servidor.
7. Probar cuotas Free y continuidad al caducar, conservando historial y uso previo.

El recorrido de receipt Test Store → webhook → consulta canónica → SQL está
comprobado con una compra simulada, pero no reemplaza este recorrido nativo.
La prueba móvil posterior acredita compra mensual y estado del servidor, pero
todavía no restaura ni documenta las respuestas visibles de todas las opciones.
El diálogo inglés de tres botones pertenece al SDK Test Store; los mensajes
posteriores de la app son españoles. Antes de las tiendas reales, acordar la política de
restauración/transferencia y validar sus sandboxes con SDK/configuración nativos.
No hay reconciliación periódica implementada: este tramo concilia por
compra/restauración, comprobación explícita y eventos autenticados. La estrategia
operativa de recuperación ante eventos perdidos debe validarse antes de vender.

## Comprobaciones reproducibles

```powershell
flutter analyze --no-pub
flutter test
node --test supabase/functions/tests/revenuecat_test.ts
deno check --no-config supabase/functions/revenuecat-sync/index.ts supabase/functions/revenuecat-webhook/index.ts
```

La prueba `supabase/tests/revenuecat_pro_reconciliation.sql` termina en ROLLBACK.
Antes del despliegue, se combina la migración y la prueba en una única
transacción, sustituyendo el COMMIT de la migración por el ROLLBACK final. Así
se verifica el esquema sin dejar tablas ni usuarios de ensayo en Dev. Se repite
también `pro_access_and_free_quotas.sql` bajo el esquema nuevo y se consulta el
historial de migraciones. En producción no se ejecuta ninguna comprobación.
