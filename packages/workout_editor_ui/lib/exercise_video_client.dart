import 'dart:typed_data';

import 'exercise_video_source.dart';
import 'exercise_video_transport.dart';

/// Protocolo de medios compartido; identidad y contexto los proporciona cada app.
class ExerciseVideoClient implements ExerciseVideoSource {
  ExerciseVideoClient({
    required this.call,
    required this.checkIdentity,
    required this.operationId,
    required this.scope,
    this.context = const {},
    ExerciseVideoTransport? transport,
  }) : _transport = transport ?? const ExerciseVideoTransport();
  final Future<Map<String, dynamic>> Function(Map<String, Object?> body) call;
  final void Function() checkIdentity;
  final String Function() operationId;
  final String scope;
  final Map<String, Object?> context;
  final ExerciseVideoTransport _transport;
  String? _operation;
  int? _pendingBytes;
  final Map<String, int> _reservedLengths = {};
  static const maxSourceBytes = 100 * 1024 * 1024;
  int get _sourceCeiling =>
      scope == 'official' ? 20 * 1024 * 1024 : maxSourceBytes;

  @override
  Future<ExerciseVideoUpload> create(int bytes) async {
    checkIdentity();
    if (bytes <= 0 || bytes > _sourceCeiling) {
      throw FormatException(
        'El vídeo debe ocupar como máximo ${_sourceCeiling ~/ (1024 * 1024)} MiB.',
      );
    }
    if (_operation != null && _pendingBytes != bytes) {
      throw StateError('Reintenta la reserva pendiente con el mismo archivo.');
    }
    _operation ??= operationId();
    _pendingBytes = bytes;
    final data = await call({
      ...context,
      'action': 'create',
      'scope': scope,
      'operation_id': _operation,
      'bytes': bytes,
    });
    final result = _credentials(data, bytes);
    _operation = null;
    _pendingBytes = null;
    return result;
  }

  /// Recupera una reserva propia existente; no crea otro activo ni adivina IDs.
  Future<ExerciseVideoUpload> recover(String id, int bytes) async {
    checkIdentity();
    final data = await call({'action': 'recover', 'id': id});
    if (data['id'] != id) {
      throw const FormatException('La reserva recuperada no coincide.');
    }
    return _credentials(data, bytes);
  }

  ExerciseVideoClient resumeAsset(String id, int expectedBytes) =>
      _RecoveredVideoClient(this, id, expectedBytes);

  ExerciseVideoUpload _credentials(Map<String, dynamic> data, int bytes) {
    checkIdentity();
    final id = data['id'];
    final video = data['video_id'];
    final signature = data['signature'];
    final expiration = data['expiration'];
    final library = data['library_id'];
    if (data['scope'] != scope ||
        id is! String ||
        !_uuid.hasMatch(id) ||
        video is! String ||
        !_uuid.hasMatch(video) ||
        signature is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(signature) ||
        expiration is! int ||
        expiration <= DateTime.now().millisecondsSinceEpoch ~/ 1000 ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch('$library') ||
        data['source_limit'] is! int ||
        bytes > (data['source_limit'] as int) ||
        bytes <= 0 ||
        (data['source_limit'] as int) > _sourceCeiling) {
      throw const FormatException(
        'La autorización de vídeo profesional no es válida.',
      );
    }
    _reservedLengths[id] = bytes;
    return ExerciseVideoUpload(
      id: id,
      headers: {
        'AuthorizationSignature': signature,
        'AuthorizationExpire': '$expiration',
        'LibraryId': '$library',
        'VideoId': video,
        'Tus-Resumable': '1.0.0',
      },
    );
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<void> upload(
    ExerciseVideoUpload upload,
    Uint8List bytes,
    String contentType,
    void Function(double) onProgress,
  ) async {
    checkIdentity();
    if (_reservedLengths[upload.id] != bytes.length) {
      throw const FormatException(
        'El archivo no coincide con la reserva de vídeo.',
      );
    }
    await _transport.upload(
      upload,
      bytes,
      contentType,
      onProgress,
      maxBytes: _sourceCeiling,
      checkIdentity: checkIdentity,
    );
    checkIdentity();
  }

  @override
  Future<ExerciseVideoStatus> status(String id) async {
    final data = await call({'action': 'status', 'id': id});
    if (data['scope'] != scope) {
      throw const FormatException(
        'El vídeo no pertenece al espacio profesional.',
      );
    }
    return ExerciseVideoStatus(
      data['status'] as String,
      data['url'] as String?,
    );
  }

  @override
  Future<Uri> playback(String url) async {
    final data = await call({'action': 'playback', 'url': url});
    final target = Uri.parse(data['url'] as String);
    final reference = Uri.parse(url);
    if (target.scheme != 'https' ||
        target.port != 443 ||
        target.userInfo.isNotEmpty ||
        target.host != reference.host ||
        target.path != reference.path) {
      throw const FormatException('El destino de reproducción no es válido.');
    }
    return target;
  }

  @override
  Future<Uint8List> thumbnail(String url) async {
    final data = await call({'action': 'thumbnail', 'url': url});
    return _transport.thumbnail(
      Uri.parse(data['url'] as String),
      Uri.parse(url),
      checkIdentity: checkIdentity,
    );
  }
}

class _RecoveredVideoClient extends ExerciseVideoClient {
  _RecoveredVideoClient(
    ExerciseVideoClient original,
    this.id,
    this.expectedBytes,
  ) : super(
        call: original.call,
        checkIdentity: original.checkIdentity,
        operationId: original.operationId,
        scope: original.scope,
        context: original.context,
      );
  final String id;
  final int expectedBytes;
  @override
  Future<ExerciseVideoUpload> create(int bytes) {
    if (bytes != expectedBytes) {
      throw const FormatException(
        'Elige el archivo original de esta reserva, con el mismo tamaño.',
      );
    }
    return recover(id, bytes);
  }
}
