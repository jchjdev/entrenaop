# Web comercial en privado · propuesta del 31/10/2026

Javier plantea trabajar la web comercial con el chat de webs y mantenerla privada
mientras se construye. Este documento prepara el alcance; no crea un subdominio,
no publica otra web y no modifica `entrenaop.es` ni su repositorio independiente.

## Recorrido principal recomendado

Crear una copia de pruebas en un subdominio separado, por ejemplo
`pre.entrenaop.es` (nombre propuesto, sin configurar). Proteger todo el sitio y
sus recursos mediante contraseña en el servidor y HTTPS. Añadir `noindex` y
excluirlo de los sitemaps como medidas complementarias. Ocultar una URL o pedir
que no se indexe no sustituye el control de acceso.

El criterio de comprobación antes de compartirlo es: sin credenciales no se
obtiene el contenido; con credenciales se ve la web completa, incluidos recursos
y navegación directa. Revisar HTML, imágenes y otras rutas, además de la portada.
Las credenciales de la vista previa se gestionan fuera del código y de GitHub.

Google distingue expresamente protección mediante contraseña de las opciones
para controlar la indexación: [controlar el contenido que se comparte](https://developers.google.com/search/docs/crawling-indexing/control-what-you-share).

## División de trabajo

El chat de webs puede encargarse del diseño, textos, capturas y navegación de
esta copia privada. El trabajo de Trainer conserva los contratos de identidad,
acceso, cupos y contratación del servidor. La web comercial consume/enlaza esos
recorridos; no crea un segundo registro ni otro sistema de derechos.

### Encaje con «Valorar portal de entrenadores»

El 31/10 Javier pide tener en cuenta ese chat. Su trabajo vigente es el directorio
de descubrimiento de preparadores: fichas, presentación, especialidades,
ubicación y contacto voluntario. Está preparando un piloto de Javier y Ervi con
aceptación individual y visibilidad solo dentro de la app; la habilitación y la
migración de ese piloto siguen siendo responsabilidad de ese bloque.

La web comercial debe integrar el directorio existente cuando corresponda, con
sus repositorios/API, filtros y autorización de servidor. No debe crear otra
tabla de profesionales ni copiar una selección de perfiles a HTML estático.
Las búsquedas por localidad y especialidad comparten el contrato del directorio.

Cada ficha conserva su consentimiento por canal: una autorización para la app
no habilita publicación web, tampoco por estar en la copia de pruebas. La web
solo podrá mostrar fichas cuya elegibilidad y autorización web confirme el
servidor. Mientras no haya perfiles autorizados para ese canal, el diseño usa
un estado vacío o material de diseño sin datos personales reales.

Contratar herramientas, ser elegible para publicitarse, publicar la ficha y
aceptar un vínculo con un alumno son acciones distintas. Visitar o contactar una
ficha no concede acceso a calendarios ni resultados, ni ocupa una plaza. Se
conserva el contacto externo voluntario y la aceptación explícita del vínculo.
Ninguna página comercial puede convertir el piloto temporal en un plan pagado
general ni decidir por su cuenta qué planes incluyen el directorio.

Referencias: [directorio y criterios](TRAINER_PLATFORM.md)
y el bloque TRN-040 de [decisiones](DECISIONS.md). Contrastar código y estado de
ese bloque antes de implementar o publicar la integración web.

Antes de editar `website/`, revisar su estado y sus instrucciones: es un
repositorio independiente y su copia recuperable se renueva conforme a
`AGENTS.md`. Este documento no autoriza sustituir la web pública con el borrador.

## Páginas y llamadas a la acción

1. Portada con dos entradas claras: entrenar por cuenta propia y trabajar como
   preparador de oposiciones.
2. Deportista: explicar planificación adaptativa, entrenamiento e historial;
   conservar contratación Pro en las tiendas. Mostrar únicamente los destinos
   de instalación realmente disponibles y distinguir beta de publicación.
3. Preparador: explicar cartera, creadores, planificación compartida, revisión y
   comunicación; enlaces a registro/acceso de Trainer ya existentes.
4. Oferta profesional: presentar cupos y prestaciones cuando se acuerden. Los
   niveles, tarifas y políticas finales siguen pendientes; el ensayo de 1 EUR
   simulado no es una oferta comercial.
5. Registro → confirmación de correo → acceso profesional con su doble factor
   → contratación de pruebas o acceso manual de ADMIN. La cuenta por sí sola no
   concede herramientas profesionales ni permisos administrativos.

La copia privada utiliza Dev y el circuito de contratación de pruebas existente.
Los enlaces de autenticación pueden seguir abriendo Trainer, que ya tiene el
registro y la recuperación, hasta que exista una razón concreta para integrarlos
en otra presentación. La vuelta de Checkout conserva el control del servidor:
volver de la pasarela no acredita por sí mismo un pago.

## Límites y siguiente decisión

La suscripción del preparador a EntrenaOP y el cobro del preparador a sus alumnos
son circuitos diferentes. Esta web no implementa el segundo ni activa cobros
reales. La política Pro incluida con planes profesionales sigue como propuesta.
No se reutilizan secretos activos en la vista previa.

Una vez aceptado el recorrido de grupos, el siguiente paso comercial es acordar
tarifas, cupos y políticas sobre la contratación sandbox existente. El diseño
privado puede avanzar en paralelo a esa decisión, sin publicar ofertas finales.

Referencias: [contratación profesional](TRAINER_COMMERCIAL_CONTRACT.md),
[cobro del servicio](TRAINER_PAYMENTS.md), [plataforma](TRAINER_PLATFORM.md).
