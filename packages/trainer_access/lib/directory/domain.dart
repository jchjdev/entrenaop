/// Reglas del directorio, independientes de Flutter y del proveedor de datos.
enum DirectoryVisibility { app, web }

enum DirectoryMode { online, presencial, ambas }

class DirectoryProfile {
  const DirectoryProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.specialties,
    required this.services,
    required this.mode,
    required this.city,
    required this.visibility,
    this.photoPath,
    this.email = '',
    this.website = '',
    this.whatsapp = '',
    this.price = '',
    this.accepting = true,
    this.favorite = false,
  });
  final String id, name, description, city, email, website, whatsapp, price;
  final List<String> specialties, services;
  final String? photoPath;
  final DirectoryMode mode;
  final DirectoryVisibility visibility;
  final bool accepting, favorite;

  List<({String label, Uri uri})> get contacts => [
    if (email.isNotEmpty)
      (label: 'Correo', uri: Uri(scheme: 'mailto', path: email)),
    if (website.isNotEmpty) (label: 'Web', uri: Uri.parse(website)),
    if (whatsapp.isNotEmpty)
      (label: 'WhatsApp', uri: Uri.https('wa.me', '/$whatsapp')),
  ];

  String? validate({required bool publishing, required bool consent}) {
    if (name.trim().isEmpty || name.trim().length > 80) {
      return 'Indica un nombre de hasta 80 caracteres.';
    }
    if (description.trim().isEmpty || description.trim().length > 1200) {
      return 'Escribe una descripción de hasta 1.200 caracteres.';
    }
    for (final tags in [specialties, services]) {
      if (tags.isEmpty ||
          tags.length > 8 ||
          tags.any((v) => v.trim().isEmpty || v.length > 60)) {
        return 'Indica entre una y ocho especialidades y servicios, de hasta 60 caracteres cada uno.';
      }
    }
    if (city.length > 80 ||
        (mode != DirectoryMode.online && city.trim().isEmpty)) {
      return 'Indica la zona del servicio presencial (hasta 80 caracteres).';
    }
    if (price.length > 120) {
      return 'El precio orientativo admite hasta 120 caracteres.';
    }
    if (email.isNotEmpty &&
        (email.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      return 'Revisa el correo profesional.';
    }
    final uri = Uri.tryParse(website);
    if (website.isNotEmpty &&
        (website.length > 500 ||
            uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty)) {
      return 'Utiliza una web HTTPS sin credenciales.';
    }
    if (whatsapp.isNotEmpty && !RegExp(r'^[0-9]{8,15}$').hasMatch(whatsapp)) {
      return 'Indica WhatsApp con prefijo de país, solo números.';
    }
    if (email.isEmpty && website.isEmpty && whatsapp.isEmpty) {
      return 'Elige al menos un contacto profesional.';
    }
    if (publishing && photoPath == null) {
      return 'Añade una foto antes de publicar.';
    }
    if (publishing && !consent) {
      return 'Acepta expresamente la publicación de estos datos.';
    }
    return null;
  }
}

class DirectoryOwnerProfile {
  const DirectoryOwnerProfile({
    required this.profile,
    required this.revision,
    required this.eligible,
    required this.published,
    required this.blocked,
    required this.consent,
    required this.enabled,
    this.pilotUntil,
    this.webAllowed = true,
  });
  final DirectoryProfile? profile;
  final int revision;
  final bool eligible, published, blocked, consent, enabled;
  final DateTime? pilotUntil;
  final bool webAllowed;
}

class DirectoryPage {
  const DirectoryPage(this.items, this.next);
  final List<DirectoryProfile> items;
  final String? next;
}

enum DirectoryReportReason {
  explicit,
  harassment,
  impersonation,
  spam,
  misleading,
  other,
}

class DirectoryReport {
  const DirectoryReport({
    required this.id,
    required this.profile,
    required this.reason,
    required this.details,
    required this.status,
    required this.suspended,
  });
  final String id, reason, details, status;
  final DirectoryProfile profile;
  final bool suspended;
}

abstract class DirectoryRepository {
  bool get signedIn;
  Future<DirectoryPage> search({
    String query = '',
    DirectoryMode? mode,
    String city = '',
    bool favorites = false,
    String? after,
  });
  Future<DirectoryProfile> profile(String id);
  Future<void> favorite(String id, bool value);
  Future<void> report(String id, DirectoryReportReason reason, String details);
  Future<DirectoryOwnerProfile> own();
  Future<DirectoryOwnerProfile> save(
    DirectoryProfile profile, {
    required int revision,
    required bool published,
    required bool consent,
  });
  Future<List<DirectoryReport>> reports({String? after});
  Future<void> moderate(
    String reportId, {
    required bool suspend,
    required String reason,
  });
}

class DirectoryFailure implements Exception {
  const DirectoryFailure(this.message);
  final String message;
}

String directoryError(Object error) => error is FormatException
    ? error.message
    : error is DirectoryFailure
    ? error.message
    : 'No se pudo confirmar la operación. Comprueba la conexión y reintenta.';
