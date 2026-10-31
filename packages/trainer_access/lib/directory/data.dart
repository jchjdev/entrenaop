import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain.dart';
import 'policy.dart';

typedef _Json = Map<String, dynamic>;

DirectoryProfile _directoryProfileFromJson(_Json j) => DirectoryProfile(
  id: j['id'] as String,
  name: j['name'] as String,
  description: j['description'] as String,
  specialties: List<String>.from(j['specialties'] as List),
  services: List<String>.from(j['services'] as List),
  mode: DirectoryMode.values.byName(j['mode'] as String),
  city: j['city'] as String,
  visibility: DirectoryVisibility.values.byName(j['visibility'] as String),
  photoPath: j['photo_path'] as String?,
  email: j['email'] as String,
  website: j['website'] as String,
  whatsapp: j['whatsapp'] as String,
  price: j['price'] as String,
  accepting: j['accepting'] as bool,
  favorite: j['favorite'] == true,
  appContactEnabled: j['app_contact_enabled'] == true,
  isOwner: j['is_owner'] == true,
);

_Json _directoryProfileToJson(DirectoryProfile p) => {
  'name': p.name.trim(),
  'description': p.description.trim(),
  'specialties': p.specialties.map((s) => s.trim()).toSet().toList(),
  'services': p.services.map((s) => s.trim()).toSet().toList(),
  'mode': p.mode.name,
  'city': p.city.trim(),
  'visibility': p.visibility.name,
  'photo_path': p.photoPath,
  'email': p.email.trim(),
  'website': p.website.trim(),
  'whatsapp': p.whatsapp.trim(),
  'price': p.price.trim(),
  'accepting': p.accepting,
  'app_contact_enabled': p.appContactEnabled,
};

class SupabaseDirectoryRepository implements DirectoryRepository {
  SupabaseDirectoryRepository(
    this.client, {
    required this.owner,
    this.webOnly = false,
  });
  final SupabaseClient client;
  final String? owner;
  final bool webOnly;
  @override
  bool get signedIn => owner != null;
  void _identity() {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('La cuenta ha cambiado. Vuelve a abrir el directorio.');
    }
  }

  Future<dynamic> _rpc(String name, _Json params) async {
    _identity();
    dynamic result;
    try {
      result = await client.rpc(name, params: params);
    } on PostgrestException catch (e) {
      throw DirectoryFailure(
        e.code == '40001'
            ? 'La ficha ha cambiado. Recarga antes de guardar.'
            : e.code == '42501'
            ? 'Esta cuenta no tiene acceso o el perfil ya no está disponible.'
            : 'No se pudo confirmar la operación. Revisa los datos y reintenta.',
      );
    }
    _identity();
    return result;
  }

  @override
  Future<DirectoryPage> search({
    String query = '',
    DirectoryMode? mode,
    String city = '',
    bool favorites = false,
    String? after,
  }) async {
    final j = _Json.from(
      await _rpc('directory_search', {
        'p_query': query.trim(),
        'p_mode': mode?.name,
        'p_city': city.trim(),
        'p_favorites': favorites,
        'p_after': after,
        'p_web_only': webOnly,
      }) as Map,
    );
    return DirectoryPage(
      (j['items'] as List)
          .map((v) => _directoryProfileFromJson(_Json.from(v as Map)))
          .toList(),
      j['next'] as String?,
    );
  }

  @override
  Future<DirectoryProfile> profile(String id) async =>
      _directoryProfileFromJson(
        _Json.from(
          await _rpc('directory_profile', {'p_id': id, 'p_web_only': webOnly})
              as Map,
        ),
      );
  @override
  Future<void> favorite(String id, bool value) async {
    await _rpc('directory_favorite', {
      'p_expected_owner': owner,
      'p_id': id,
      'p_value': value,
    });
  }

  @override
  Future<void> report(
    String id,
    DirectoryReportReason reason,
    String details,
  ) async {
    await _rpc('directory_report', {
      'p_expected_owner': owner,
      'p_id': id,
      'p_reason': reason.name,
      'p_details': details.trim(),
    });
  }

  DirectoryOwnerProfile _own(dynamic value) {
    final j = _Json.from(value as Map);
    return DirectoryOwnerProfile(
      profile: j['profile'] == null
          ? null
          : _directoryProfileFromJson(_Json.from(j['profile'] as Map)),
      revision: (j['revision'] as num).toInt(),
      eligible: j['eligible'] == true,
      published: j['published'] == true,
      blocked: j['blocked'] == true,
      consent: j['consent'] == true,
      enabled: j['enabled'] == true,
      pilotUntil: DateTime.tryParse(j['pilot_until'] as String? ?? ''),
      webAllowed: j['web_allowed'] != false,
    );
  }

  @override
  Future<DirectoryOwnerProfile> own() async =>
      _own(await _rpc('directory_own', {'p_expected_owner': owner}));
  @override
  Future<DirectoryOwnerProfile> save(
    DirectoryProfile profile, {
    required int revision,
    required bool published,
    required bool consent,
  }) async {
    final error = profile.validate(publishing: published, consent: consent);
    if (error != null) throw FormatException(error);
    return _own(
      await _rpc('directory_save', {
        'p_expected_owner': owner,
        'p_revision': revision,
        'p_data': {
          ..._directoryProfileToJson(profile),
          if (consent) 'consent_version': directoryConsentVersion,
        },
        'p_published': published,
        'p_consent': consent,
      }),
    );
  }

  Future<Uint8List> photo(String path) async {
    _identity();
    final bytes = await client.storage.from('trainer-directory').download(path);
    _identity();
    return bytes;
  }

  Future<String> uploadPhoto(Uint8List bytes, String id) async {
    _identity();
    if (bytes.length > 500 * 1024) {
      throw const FormatException('La foto supera 500 KB.');
    }
    final path = '$owner/$id.jpg';
    await client.storage
        .from('trainer-directory')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '0',
          ),
        );
    _identity();
    return path;
  }

  Future<void> discardPhoto(String path) async {
    _identity();
    await client.storage.from('trainer-directory').remove([path]);
    _identity();
  }

  Future<void> cleanupPhotoDrafts() async {
    _identity();
    if (owner == null) {
      throw const DirectoryFailure('Inicia sesión para gestionar tus fotos.');
    }
    final files = await client.storage
        .from('trainer-directory')
        .list(path: owner!);
    _identity();
    // La política de DELETE protege siempre la foto de la ficha guardada.
    final paths = files
        .where((f) => f.name.endsWith('.jpg'))
        .map((f) => '$owner/${f.name}')
        .toList();
    if (paths.isNotEmpty) {
      await client.storage.from('trainer-directory').remove(paths);
    }
    _identity();
  }

  @override
  Future<List<DirectoryReport>> reports({String? after}) async =>
      (await _rpc('directory_reports', {
        'p_expected_owner': owner,
        'p_after': after,
      }) as List).map((v) {
        final j = _Json.from(v as Map);
        return DirectoryReport(
          id: j['id'] as String,
          profile: _directoryProfileFromJson(_Json.from(j['profile'] as Map)),
          reason: j['reason'] as String,
          details: j['details'] as String,
          status: j['status'] as String,
          suspended: j['suspended'] == true,
        );
      }).toList();
  @override
  Future<void> moderate(
    String reportId, {
    required bool suspend,
    required String reason,
  }) async {
    await _rpc('directory_moderate', {
      'p_expected_owner': owner,
      'p_report_id': reportId,
      'p_suspend': suspend,
      'p_reason': reason.trim(),
    });
  }
}
