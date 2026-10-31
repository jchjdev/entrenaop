import 'dart:typed_data';

class ProfilePhotoState {
  const ProfilePhotoState({required this.path, required this.revision});
  final String? path;
  final int revision;
}

abstract interface class ProfilePhotoRepository {
  String get ownerId;
  Future<ProfilePhotoState> own();
  Future<ProfilePhotoState> save(String? path, {required int revision});
  Future<String> upload(Uint8List bytes, String id);
  Future<Uint8List> download(String path);
  Future<void> discard(String path);
  Future<void> cleanup();
}

class ProfilePhotoFailure implements Exception {
  const ProfilePhotoFailure(this.message);
  final String message;
}

String profilePhotoError(Object error) => error is ProfilePhotoFailure
    ? error.message
    : error is FormatException
    ? error.message
    : 'No se pudo confirmar el cambio de foto. Conservamos la selección para reintentar.';
