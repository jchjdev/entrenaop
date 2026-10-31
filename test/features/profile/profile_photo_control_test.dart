import 'dart:convert';
import 'dart:typed_data';

import 'package:entrenaop/features/profile/presentation/profile_photo_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/profile_photo/domain.dart';
import 'package:trainer_access/profile_photo/presentation.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a22kAAAAASUVORK5CYII=',
);

class _Photos implements ProfilePhotoRepository {
  @override
  String get ownerId => 'owner';
  ProfilePhotoState state = const ProfilePhotoState(path: null, revision: 0);
  int writes = 0;
  bool failBefore = false, failAfter = false;
  final uploads = <String>[], discarded = <String>[];
  @override
  Future<ProfilePhotoState> own() async => state;
  @override
  Future<ProfilePhotoState> save(String? path, {required int revision}) async {
    writes++;
    if (failBefore) throw const ProfilePhotoFailure('Prueba sin conexión');
    if (revision != state.revision) throw StateError('Revisión incorrecta');
    state = ProfilePhotoState(path: path, revision: revision + 1);
    if (failAfter) throw const ProfilePhotoFailure('Respuesta perdida');
    return state;
  }

  @override
  Future<String> upload(Uint8List bytes, String id) async {
    uploads.add(id);
    return '$ownerId/$id.jpg';
  }

  @override
  Future<Uint8List> download(String path) async => _pixel;
  @override
  Future<void> discard(String path) async {
    discarded.add(path);
  }

  @override
  Future<void> cleanup() async {}
}

void main() {
  testWidgets('un cambio de otra sesión se conserva al descartar el intento', (
    tester,
  ) async {
    final photos = _Photos();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePhotoControl(
            repository: photos,
            name: 'Ana Alumna',
            pick: (_) async {
              photos.state = const ProfilePhotoState(
                path: 'owner/other-session.jpg',
                revision: 1,
              );
              return _pixel;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cambiar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(photos.state.path, 'owner/other-session.jpg');
    await tester.tap(find.byTooltip('Cambio de foto pendiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar cambio pendiente'));
    await tester.pumpAndSettle();
    expect(photos.state.path, 'owner/other-session.jpg');
    expect(photos.discarded.length, 1);
    expect(photos.discarded, isNot(contains('owner/other-session.jpg')));
  });
  Future<void> mount(
    WidgetTester tester,
    _Photos photos, {
    bool cancel = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePhotoControl(
            repository: photos,
            name: 'Ana Alumna',
            pick: (_) async => cancel ? null : _pixel,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Cambiar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancelar la selección no sube ni escribe', (tester) async {
    final photos = _Photos();
    await mount(tester, photos, cancel: true);
    await choose(tester);
    expect(photos.uploads, isEmpty);
    expect(photos.writes, 0);
    expect(find.text('AA'), findsOneWidget);
  });
  testWidgets('respuesta perdida confirma la foto sin duplicar la escritura', (
    tester,
  ) async {
    final photos = _Photos()..failAfter = true;
    await mount(tester, photos);
    await choose(tester);
    expect(photos.writes, 1);
    expect(photos.uploads.length, 1);
    expect(find.text('Foto de perfil guardada.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
  testWidgets('reintento conserva el identificador de la subida', (
    tester,
  ) async {
    final photos = _Photos()..failBefore = true;
    await mount(tester, photos);
    await choose(tester);
    expect(find.text('Prueba sin conexión'), findsOneWidget);
    photos.failBefore = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(photos.uploads.length, 2);
    expect(photos.uploads.toSet().length, 1);
    expect(photos.writes, 2);
    expect(find.text('Foto de perfil guardada.'), findsOneWidget);
  });
  testWidgets('quitar foto confirma el cambio y limpia la anterior', (
    tester,
  ) async {
    final photos = _Photos()
      ..state = const ProfilePhotoState(path: 'owner/old.jpg', revision: 1);
    await mount(tester, photos);
    await tester.tap(find.byTooltip('Cambiar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar foto'));
    await tester.pumpAndSettle();
    expect(photos.writes, 0);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(photos.state.path, isNull);
    expect(photos.discarded, ['owner/old.jpg']);
    expect(find.text('AA'), findsOneWidget);
  });
  testWidgets('al reanudar se comprueba acceso y se recuperan las iniciales', (
    tester,
  ) async {
    var permitted = true, calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePhotoAvatar(
          name: 'Ana Alumna',
          path: 'owner/photo.jpg',
          load: (_) async {
            calls++;
            if (!permitted) throw StateError('Sin vínculo');
            return _pixel;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    permitted = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('AA'), findsOneWidget);
  });
}
