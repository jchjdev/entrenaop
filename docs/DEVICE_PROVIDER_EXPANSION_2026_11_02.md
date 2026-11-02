# Dispositivos: presentación y ampliación · 02/11/2026

## Alcance confirmado

Javier aporta un vídeo de Kotcha y pide una presentación visual de las conexiones,
con relojes y tarjetas de marca. Reabre la ampliación a Huawei, Suunto, Amazfit,
Polar y COROS, pospuesta al priorizar Garmin. Se conserva el editor y la
prescripción propia de EntrenaOP, así como los recorridos existentes de Garmin,
Apple Watch y Salud. La aceptación física pendiente de Apple no se da por hecha.

La pantalla usa ilustraciones propias de familias de relojes; no identifica el
modelo que tiene el usuario. Las tarjetas disponibles abren la gestión existente.
Salud mantiene su acceso independiente. Solo Dev muestra un desplegable con las
cinco conexiones en estudio y una explicación de su indisponibilidad: no inicia
OAuth, solicita permisos ni anuncia soporte operativo. La vista general sigue
sin leer actividades, autorizar o desconectar al abrirse.

## Revisión de vías oficiales

Comprobación pública del 02/11/2026. Ninguna fila acredita alta, credenciales,
contrato aceptado, cuotas aplicables ni prueba de reloj para EntrenaOP. Algunas
páginas dinámicas de Huawei y Zepp solo permiten contrastar el índice público;
sus esquemas completos y condiciones deben revisarse al obtener acceso.

| Marca | Resultados terminados | Prescripción al reloj | Acceso y siguiente comprobación |
| --- | --- | --- | --- |
| Huawei | Health Kit / Health Service Kit documenta datos de ejercicio y escenarios de carrera con segmentos. | Existe un escenario oficial de importar cursos de carrera desde la nube y abrir Huawei Health. No equivale a acreditar programación, cambios y cancelaciones automáticos para EntrenaOP. | Confirmar entidad/cuenta verificada, modalidad cloud, región España/UE y scopes de lectura y cursos. Primera prioridad de ampliación. |
| Suunto | Cloud API con OAuth2 y descarga FIT documentada. | La guía oficial SuuntoPlus Guides documenta creación, actualización y borrado de guías. Subir una actividad FIT por Upload API es otro recorrido. | Programa de partners, acceso Development API y clave de suscripción; contrastar relojes y limitaciones. |
| Amazfit / Zepp | Plataforma oficial para terceros con OAuth2, APIs y eventos. | Zepp anuncia envío de planes de TrainingPeaks e Intervals.icu a determinados modelos. Esto demuestra una capacidad de esas integraciones, no una concesión a EntrenaOP ni cobertura universal. | Revisar onboarding de partner y contrato concreto de planes, cambios, retirada y resultados. No confundir Zepp OS, una app de reloj y una API cloud. |
| Polar | AccessLink permite crear un cliente; la documentación Dynamic API v4 contiene lectura de sesiones, objetivos y dispositivos. | No se acredita un endpoint público para escribir objetivos. Leer objetivos del calendario no demuestra poder enviarlos. | Preparar lectura autorizada; confirmar con Polar una vía de escritura antes de anunciar envío al reloj. |
| COROS | Partner API para plataformas establecidas, con requisitos de entidad, seguridad y usuarios demostrables. | La oferta de partners contempla sincronización de entrenamientos/planes; falta verificar el contrato concedido a EntrenaOP. | Solicitud oficial y validación de elegibilidad. El MCP orientado a herramientas de IA no acredita por sí solo una integración multiusuario de producto. |

Fuentes primarias:

- Huawei: [Health Kit](https://developer.huawei.com/consumer/en/hms/huaweihealth/),
  [cursos de carrera](https://developer.huawei.com/consumer/fr/doc/HMSCore-Guides/running-course-import-0000001416016218)
  y [carrera con segmentos](https://developer.huawei.com/consumer/ru/doc/HMSCore-Guides/running-section-scene-0000001360502541).
- Suunto: [programa y Cloud API](https://apizone.suunto.com/) y
  [SuuntoPlus Guide Cloud API](https://aspartnercontent.blob.core.windows.net/apizone/docs/SuuntoplusGuideCloudAPI.pdf).
- Zepp: [plataforma](https://devopen.zepp.com/docs/getting-started/introduction),
  [onboarding](https://devopen.zepp.com/docs/getting-started/partner-onboarding) y
  [planes en modelos compatibles](https://os.zepp.com/news/train-smarter-with-trainingpeaks-and-intervalsicu).
- Polar: [AccessLink](https://www.polar.com/accesslink-api/) y
  [Dynamic API v4](https://www.polar.com/polar-api-v4/).
- COROS: [Partner API Access](https://support.coros.com/hc/en-us/articles/53181766856724-Partner-API-Access)
  y [solicitud](https://support.coros.com/hc/en-us/articles/17085887816340-Submit-an-API-Application).

## Contrato común y límites

El proveedor traduce la misma prescripción versionada y devuelve mediciones con
su procedencia. No se añade un editor por marca ni se amplían los objetos Garmin
para fingir que representan a todos los fabricantes. Las futuras capacidades se
contrastan por operación, deporte, tipo de paso, finalización y objetivo. Una
marca visible o conectada no acredita por sí sola fuerza, Lap, cambios o retorno.

Cada adaptador reutilizará los puertos de prescripción/resultados y las reglas
vigentes de propiedad, permisos, idempotencia y cierre. El transporte, OAuth y
formatos externos permanecen fuera del dominio deportivo y de las pantallas de
entrenadores. Un paso no representable se declara incompatible; no se elimina
una recuperación ni se inventa una duración para exportarlo.

Se conserva INT-006: lectura local de Salud para Free; conexiones directas y
envío sujetos a los derechos efectivos de Pro o seguimiento. La autorización del
alumno, la relación profesional y el consentimiento para compartir resultados
siguen separados. No se solicita salud diaria como requisito del primer conector.

## Siguiente bloque único: acceso Huawei

Javier confirma el 02/11 que no tiene una cuenta HUAWEI Developer verificada.
El titular debe completar el alta y la verificación de identidad desde el
[portal oficial](https://developer.huawei.com/consumer/en/). No se solicitan
documentos de identidad, contraseñas o secretos en el chat ni en el repositorio.
El expediente técnico queda preparado, pero esa verificación y la concesión
de Health Kit son dependencias externas del conector.
El tipo de alta y los servicios disponibles dependen de la entidad real y del
país; no se presupone que una cuenta individual habilite todas las capacidades.
La documentación distingue [derechos por tipo de desarrollador](https://developer.huawei.com/consumer/en/doc/help/developerrights-0000001053174003).

Descripción técnica preparada para el registro, sujeta a los campos reales del
portal: «EntrenaOP is a training platform for athletes and coaches. With each
user's authorization, we request completed running workouts and their available
intervals and heart-rate data, and compatible structured running courses. Users
can revoke the connection. We do not request unrelated daily health data.»
No se copia un callback Garmin ni se inventa un endpoint Huawei desplegado: el
retorno Dev se fijará y verificará con su modalidad OAuth real.

1. Contrastar la consola y documentación completa desde una cuenta verificada
   del titular: entidad real, España/UE, servicio cloud y scopes concedidos.
2. Preparar el registro Dev de EntrenaOP y su justificación mínima: carreras
   pautadas por algoritmo/preparador, resultados autorizados y revocación. No
   enviar datos societarios inventados ni usar credenciales de deportistas.
3. Fijar el contrato concreto de lectura y cursos antes del primer adaptador;
   probar contrato y errores con fixtures, manteniendo Garmin/Apple operativos.
4. Acreditar en un Huawei real autorización, entrega de fases y resultados.
   Cambios/cancelaciones y eventual intervención en Huawei Health se explicitan
   según el contrato real; no se promete paridad con Garmin antes de probarla.

Las solicitudes de otros partners pueden prepararse con este mismo expediente;
no se han enviado correos, formularios ni aceptado términos en esta revisión.
Tampoco se ha implementado ni habilitado ninguno de esos cinco conectores.

## Verificación de esta entrega

`flutter analyze --no-pub` global sin incidencias y batería raíz completa:
1.625 pruebas correctas y una omisión previa. Ocho pruebas focalizadas conservan
permisos, navegación, errores, cambios de cuenta y gestión sin derecho comercial;
añaden el carácter informativo de las futuras marcas, texto al 200 % y acción
accesible de la tarjeta. Cuatro capturas del widget real, con fixtures sin red ni
cuentas reales, están en
[`visual-audit/device-connections-2026-11-02/`](visual-audit/device-connections-2026-11-02/).
No cambian esquema, Edge Functions, suscripciones ni editores. Para ver el cambio
en el iPhone se necesita compilar de nuevo la app; los portales web profesionales
no consumen esta pantalla nativa.
