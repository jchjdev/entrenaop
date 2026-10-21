# Acceso a proveedores de dispositivos · INT-001 · 21/10/2026

## Alcance de la comprobación

Revisión de documentación y entradas públicas oficiales el 21/10/2026, junto
con configuración y código relacionados del repositorio. No es una prueba
autenticada de APIs, de consolas de desarrollador ni de un reloj real. No se han
creado cuentas, aceptado contratos, solicitado altas, enviado mensajes ni
introducido credenciales. La disponibilidad pública se debe volver a comprobar
al tramitar cada acceso; no garantiza aprobación para EntrenaOP.

Javier confirma que no disponemos de API Garmin. En el código/configuración
inspeccionados tampoco hay conectores de salud o de estas marcas. No se acredita
acceso operativo a ningún otro proveedor: no se ha consultado un inventario
externo de cuentas o secretos. Una cuenta de usuario de reloj no equivale a
credenciales de desarrollador.

## Matriz de acceso y cobertura de carrera

| Canal | Entrada posible | Salida al reloj | Acceso acreditado para EntrenaOP | Próxima comprobación concreta |
| --- | --- | --- | --- | --- |
| Salud de Apple / HealthKit | Lectura nativa en iPhone de actividades y métricas que realmente estén en Salud, con permiso. | Es otro contrato: WorkoutKit para sesiones planificadas compatibles. Escribir una actividad completada en Salud no programa una sesión en el reloj. | Documentación pública; capacidad, firma y lectura real pendientes. | Habilitar capability y propósitos en un ensayo móvil aislado; verificar cuenta/firma y permiso con una carrera real. |
| Health Connect | Lectura nativa Android de registros que otras apps hayan compartido, con permiso y disponibilidad. | Health Connect no acredita envío universal a los relojes de fabricantes. No se habilita esa capacidad en V1. | Documentación pública; SDK, permisos, declaración Play y ensayo pendientes. | Contrastar SDK/Gradle y teléfono compatibles antes de elegir adaptador; ensayar lectura de una carrera. |
| Garmin Connect | Activity API directa tras acceso aprobado; posible vía indirecta Salud/Health Connect para los datos que Garmin comparta. | Training API para sesiones/planes y dispositivos compatibles, tras aprobación. | Sin API, confirmado por Javier. | Confirmar un canal de solicitud operativo y elegibilidad empresarial; preparar petición de Activity + Training. |
| COROS | Partner API para actividades; la cobertura indirecta se comprobará por plataforma y campos. | Partner API documenta sesiones estructuradas y planes. | Documentación pública, sin credenciales verificadas. | Contrastar elegibilidad de plataforma/empresa y preparar solicitud con aplicación y callbacks. |
| Suunto | Cloud API y FIT mediante programa de partners. | Evaluar SuuntoPlus Guides; la API de subida de actividad completada no demuestra envío de prescripción. | Documentación/portal públicos; aceptación y claves pendientes. | Obtener acceso de partner y confirmar el producto de prescripción, modelos y cuotas admitidos. |
| Huawei Health | Health Kit documenta lectura/escritura consentida de datos expuestos. | Envío de sesiones estructuradas a reloj no acreditado en esta revisión. | Documentación pública; permisos de producto/región y credenciales no verificados. | Confirmar vía aplicable en España/UE, permisos de entrenamientos y detalle de segmentos/pulso para una integración de servidor/móvil. |

No se anuncian «todos los relojes compatibles». La matriz de aceptación futura
registrará marca/modelo, firmware, teléfono/SO, canal, versión del adaptador,
lectura de resumen/segmentos/pulso, envío y fecha/evidencia real. Cada capacidad
se habilitará con su alcance conocido. Las filas anteriores no son esa matriz
de dispositivos probados.

## Apple: acceso nativo y envío separados

HealthKit exige configuración de acceso y textos de propósito, además de la
autorización del titular para los tipos leídos/escritos. La denegación de lectura
no siempre puede distinguirse de la ausencia de datos. La lectura local no
acredita por sí misma autorización para subir/compartir todo el almacén.
[Configuración oficial](https://developer.apple.com/documentation/xcode/configuring-healthkit-access)
y [autorización](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

WorkoutKit permite crear y programar entrenamientos para Entreno en Apple Watch
y requiere autorización propia. Su presentación oficial establece iOS 17 y
watchOS 10 como base inicial; cada API utilizada debe comprobar su disponibilidad.
El proyecto actual conserva mínimo iOS 15: integrar envío exige detección de
disponibilidad y no subir ese mínimo sin una decisión explícita. Firma y ensayo
físico necesitarán Mac/iPhone y, para envío, reloj compatible.
[WorkoutKit, presentación y transcripción](https://developer.apple.com/videos/play/wwdc2023/10016/).

## Android: Health Connect como entrada, sin presumir equivalencia de marcas

Health Connect permite leer sesiones y métricas de otras apps. La información
disponible depende de lo que escriban y de los permisos; el registro puede
contener segmentos o vueltas sin garantizar correspondencia con nuestra receta.
[Sesiones y métricas](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts).

La guía actual distingue soporte SDK y disponibilidad real en el teléfono.
Indica Android 9+ para usar Health Connect, comprobación de funciones y requisitos
de compilación concretos según SDK. El proyecto delega compile/min/target SDK
en Flutter, por lo que no se declara todavía compatibilidad resoluble.
[Inicio y disponibilidad](https://developer.android.com/health-and-fitness/health-connect/get-started).

Para distribuir, Google exige declarar los tipos de salud y el uso en Play
Console. No se ha comprobado la declaración de EntrenaOP. La primera lectura
será con permisos mínimos; segundo plano e historial ampliado se evaluarán
separadamente. No se diseña sobre Google Fit.
[Publicación](https://developer.android.com/health-and-fitness/health-connect/publish).

## Garmin: qué podemos hacer sin API y qué queda condicionado

La documentación diferencia Activity API para recibir actividad de Training API
para publicar recetas/planes. El programa exige aprobación y uso empresarial.
La FAQ describe OAuth 2.0; no acredita que EntrenaOP tenga alta ni que una
solicitud se tramite ahora. Las páginas actuales muestran un aviso de próximas
actualizaciones y no se ha acreditado formulario operativo ni plazo efectivo.
No se interpreta el plazo orientativo de la FAQ como fecha de entrega.
[Programa](https://developer.garmin.com/gc-developer-program/overview/),
[Training API](https://developer.garmin.com/gc-developer-program/training-api/)
y [FAQ](https://developer.garmin.com/gc-developer-program/program-faq/).

Garmin documenta compartir datos con Salud de Apple y Health Connect. Eso permite
plantear una primera lectura indirecta, limitada a los datos exportados y con
prueba real pendiente. La ayuda de Apple Health advierte limitaciones del detalle
cardíaco de actividades; no se promete fidelidad de la API directa.
[Garmin → Apple Health](https://support.garmin.com/en-US/?faq=lK5FPB9iPF5PXFkIpFlFPA)
y [Garmin → Health Connect](https://support.garmin.com/en-US/?faq=JToBEy0jfe6pIygark2Ui5).

**Recomendación operativa:** avanzar con la entrada de salud y el dominio común;
preparar Activity + Training sin bloquearlos. No usar contraseñas de Garmin,
scraping, endpoints privados o bibliotecas que simulen iniciar sesión. Connect
IQ es otro programa y una app para reloj tendría un alcance propio.
Si la admisión directa sigue sin resolverse, se puede evaluar importación manual
FIT/TCX como entrega adicional; no se da por aprobada ni implementada aquí, ni
resuelve automáticamente el envío de planes.

## COROS: requisitos explícitos de partner

La página oficial revisada en septiembre de 2026 exige una plataforma con base
de usuarios demostrable, empresa registrada, representante autorizado y acuerdo
de condiciones. Describe OAuth multiusuario, notificaciones, descarga FIT y
sincronización de sesiones/planes. No se inventan cifras de usuarios para cumplir
la solicitud. La alternativa MCP que ofrece COROS para proyectos pequeños no se
considera por sí sola un conector de producto autorizado para todos los alumnos.
[Partner API Access](https://support.coros.com/hc/en-us/articles/53181766856724-Partner-API-Access).

Existe una entrada pública de solicitud. Se debe comprobar elegibilidad y
aportar los datos reales antes de tramitarla. El acceso a la página no constituye
solicitud enviada, aprobación ni credencial emitida.
[Solicitud oficial](https://support.coros.com/hc/en-us/articles/17085887816340-Submit-an-API-Application).

## Suunto: lectura y prescripción son productos distintos

El portal exige admisión al programa de partners para probar las APIs. Su guía
documenta configuración OAuth, usuario de prueba y clave de suscripción además
del token. El acceso público a la documentación no emite esas claves.
[APIs y admisión](https://apizone.suunto.com/apis),
[FAQ](https://apizone.suunto.com/faq) y
[configuración inicial](https://apizone.suunto.com/how-to-start).

La Cloud API ofrece FIT con información de actividades; subir un FIT de una
actividad realizada no equivale a prescribir intervalos futuros. Para salida se
evaluará la API de SuuntoPlus Guides y su compatibilidad con nuestra carrera,
sin afirmar cobertura de todos los modelos.
[Cloud API](https://apizone.suunto.com/),
[subida de actividad](https://apizone.suunto.com/how-to-workout-upload) y
[Guía oficial de SuuntoPlus Guides](https://aspartnercontent.blob.core.windows.net/apizone/docs/SuuntoplusGuideCloudAPI.pdf).

## Huawei: acceso por confirmar para este producto y región

Health Kit documenta lectura/escritura autorizada y varias plataformas. Esa
descripción no prueba que todos los datos, regiones, SDK o funciones estén
habilitados para EntrenaOP, ni que escribir datos programe intervalos en un
reloj. La documentación de permisos distingue autorización de la aplicación y
permisos del usuario. Algunas páginas de detalle no devuelven contenido legible
sin la aplicación web; esta revisión no sustituye la comprobación de consola.
[Health Kit](https://developer.huawei.com/consumer/en/hms/huaweihealth/)
y [autorización y permisos](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides-V1/signing-in-and-pplying-for-permissions-0000001074001642-V1).

Se necesita confirmar con la documentación/consola de la modalidad elegida:
elegibilidad de la entidad, región España/UE, acceso de servidor, tipos exactos
de carrera, segmentos y frecuencia cardíaca, historial y condiciones. No se
presupone que Huawei Health escriba toda la carrera en Health Connect/Salud.
La importación indirecta solo se ofrecerá después de observarla realmente.

## Expediente preparado para las altas, sin enviar

Descripción común utilizable: «EntrenaOP es una aplicación de entrenamiento y
preparación física con app del deportista y espacios web separados de
administración y preparadores. Solicitamos importar carreras consentidas y,
cuando el producto lo permita, enviar sesiones estructuradas de carrera. El
alumno autoriza su conexión; el preparador solo consulta resultados de sus
asignaciones. No solicitamos inicialmente salud diaria ni GPS en directo».

| Dato para tramitar | Estado / criterio |
| --- | --- |
| Titular jurídico, registro y representante autorizado | Pendiente de datos reales del titular; no inferirlos del usuario de GitHub. |
| Contacto empresarial/técnico | Pendiente de confirmar; no publicar correos personales por defecto. |
| Producto, web y plataformas | Descripción anterior y entrenaop.es; distinguir desarrollo de servicio publicado al público. |
| Usuarios activos, demanda y dispositivos de prueba | Pendiente de cifras/recursos reales; no estimaciones presentadas como hechos. |
| Lectura solicitada | Carrera terminada: tiempos, distancia, segmentos y pulso cuando estén disponibles y autorizados. |
| Escritura solicitada | Prescripción de carrera versionada, agenda y pasos compatibles; no subir actividad en nombre del alumno como sustituto del envío. |
| Política de privacidad y explicación de datos | Revisar que cubran integración, subida, destinatarios y revocación antes de adjuntarlas o activar datos reales. |
| Callback OAuth/webhooks | URLs exactas pendientes de diseñar y registrar en infraestructura propia de desarrollo. No reservar rutas en Trainer ni inventar subdominios desplegados. |
| Credenciales y entornos | Una configuración identificada por entorno y proveedor; secretos únicamente en servidor/gestor seguro, sin valores en Git ni logs. |
| Condiciones, tarifas y límites | Revisión por proveedor antes de aceptación. El acceso público a docs no acredita acceso gratuito ni contrato aceptado. |

No hay un trámite enviado pendiente de respuesta. Las altas no realizadas son
dependencias externas de los conectores directos, no fallos de la base de
importación local. No hacen falta contraseñas de alumnos para preparar el
contrato ni para solicitar acceso de desarrollador.

## Puertas de habilitación y resultado de esta revisión

Se distinguen cinco evidencias: documentación pública → elegibilidad/alta →
credenciales/capability configurada → prueba consentida real → capacidad
habilitada en producto. En esta entrega solo se acredita la primera. Apple y
Android requieren configuración nativa propia en lugar de claves cloud de
partner; Garmin, COROS y Suunto tienen vías de acceso sujetas a aprobación;
Huawei requiere confirmar la modalidad y los permisos aplicables.

Antes de habilitar cualquier fila se adjuntarán al registro de desarrollo la
configuración sin secretos, scopes reales, prueba de autorización/revocación,
actividad de prueba con campos comprobados, comportamiento de cambios/borrados,
límites y modelos ensayados. No se usan datos del titular para fabricar pruebas.

**Siguiente acción técnica:** implementar el dominio puro del
[contrato V1](DEVICE_RUNNING_CONTRACT_V1.md), sin tocar Trainer. Antes de su
primer adaptador se verificará compatibilidad real del SDK y se preparará un
ensayo móvil aislado; las solicitudes de partner requieren completar los datos
reales del expediente y una acción expresa para su envío/aceptación de términos.
