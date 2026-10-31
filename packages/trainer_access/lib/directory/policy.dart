import 'domain.dart';

// Cambiar el contenido de esta versión exige una nueva aceptación en servidor.
const directoryConsentVersion = 2;

String directoryPublicationConsent(DirectoryVisibility visibility) =>
    'Autorizo que mi ficha profesional, incluida mi foto, presentación, '
    'especialidades y los contactos que he indicado, sea visible '
    '${visibility == DirectoryVisibility.web ? 'en la app y en la web pública, accesible sin cuenta' : 'para usuarios identificados con correo confirmado dentro de la app de EntrenaOP'}, '
    'para que puedan encontrarme y contactar conmigo. '
    'Puedo retirar la publicación desde mi ficha en cualquier momento.';

const directoryPublicationConditions =
    'Publica información propia y veraz. No se permiten suplantaciones, '
    'contenido sexual explícito o violencia gráfica, acoso, odio, spam, '
    'enlaces engañosos ni datos de otras personas sin autorización. '
    'La publicación es directa y admite denuncias. Una denuncia no oculta '
    'automáticamente la ficha; el responsable puede suspenderla tras revisar '
    'la incidencia y registrar el motivo. La información la aporta cada '
    'profesional: aparecer aquí no acredita titulaciones verificadas.';

const directoryPrivacyInformation = '''Información del directorio · versión 2

Responsable y contacto
Javier Charlez, responsable del proyecto EntrenaOP.
javier.charlez@entrenaop.es

Datos y finalidad
Tratamos el nombre profesional, foto, presentación, especialidades, servicios, modalidad, zona, contactos, precio opcional y disponibilidad que incluyes en tu ficha para prepararla y permitir que te encuentren y contacten. Los favoritos son privados. Las denuncias incluyen su motivo, explicación y resolución.

Base del tratamiento
Preparar y gestionar tu ficha responde al servicio que solicitas. La publicación se basa en tu consentimiento y puedes retirarla desde «Publicar ficha». La gestión de incidencias y la seguridad responde al interés legítimo de mantener un directorio seguro.

Quién puede verla
«Solo dentro de la app» permite consultar tu ficha a usuarios identificados con correo confirmado. «App y web pública» también permite consultas sin cuenta. El piloto de pruebas admite únicamente la primera opción. No publicamos datos de tus alumnos ni tu historial de entrenamiento.

Contacto externo
Correo, web y WhatsApp abren servicios externos con sus propias condiciones. Contactar o guardar un favorito no crea un vínculo con el preparador ni contrata un entrenamiento. La app admite hasta dos preparadores activos por alumno.

Conservación y retirada
Al retirar la publicación o perder la habilitación, tu ficha deja de estar disponible en nuevas consultas y queda como borrador. La ficha y sus aceptaciones se conservan mientras mantengas la ficha o hasta que proceda su supresión. Conservamos las incidencias y resoluciones durante el tiempo necesario para gestionarlas y atender las responsabilidades que puedan derivarse. Retirar la ficha no elimina capturas ni información que otras personas ya hayan recibido.

Proveedores
La cuenta, la ficha y sus imágenes se alojan en Supabase, en el proyecto de la Unión Europea. Hostinger aloja el portal profesional. Estos proveedores intervienen en el alojamiento y seguridad del servicio. Sus condiciones de protección de datos y las garantías de transferencias internacionales, cuando correspondan, pueden consultarse en supabase.com/legal/dpa y hostinger.com/legal/privacy-policy. El contacto externo utiliza el proveedor que elijas.

Tus derechos
Puedes solicitar acceso, rectificación, supresión, oposición, limitación o portabilidad cuando proceda escribiendo a javier.charlez@entrenaop.es. Puedes retirar el consentimiento de publicación en cualquier momento y reclamar ante la Agencia Española de Protección de Datos (aepd.es).
''';
