import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/directory/domain.dart';
import 'package:trainer_access/directory/presentation.dart';

DirectoryProfile sampleDirectoryProfile({
  String id = 'one',
  String email = 'coach@example.test',
  String website = '',
  String? photo = 'coach/photo.jpg',
  DirectoryVisibility visibility = DirectoryVisibility.app,
  bool favorite = false,
}) => DirectoryProfile(
  id: id,
  name: 'Ervi · Carrera',
  description: 'Preparación de carrera para oposiciones',
  specialties: const ['Carrera'],
  services: const ['Seguimiento'],
  mode: DirectoryMode.online,
  city: '',
  visibility: visibility,
  email: email,
  website: website,
  photoPath: photo,
  favorite: favorite,
);

class FakeDirectory implements DirectoryRepository {
  @override
  bool signedIn = true;
  bool saved = false, fail = false;
  int calls = 0, reportsSent = 0;
  @override
  Future<DirectoryPage> search({
    String query = '',
    DirectoryMode? mode,
    String city = '',
    bool favorites = false,
    String? after,
  }) async {
    calls++;
    if (fail) throw const DirectoryFailure('Sin conexión de prueba');
    return DirectoryPage(
      favorites && !saved ? [] : [sampleDirectoryProfile(favorite: saved)],
      null,
    );
  }

  @override
  Future<DirectoryProfile> profile(String id) async =>
      FakeDirectoryProfile.make(saved);
  @override
  Future<void> favorite(String id, bool value) async {
    saved = value;
  }

  @override
  Future<void> report(
    String id,
    DirectoryReportReason reason,
    String details,
  ) async {
    reportsSent++;
  }

  @override
  Future<DirectoryOwnerProfile> own() async => throw UnimplementedError();
  @override
  Future<DirectoryOwnerProfile> save(
    DirectoryProfile profile, {
    required int revision,
    required bool published,
    required bool consent,
  }) async => throw UnimplementedError();
  @override
  Future<List<DirectoryReport>> reports({String? after}) async => [];
  @override
  Future<void> moderate(
    String reportId, {
    required bool suspend,
    required String reason,
  }) async {}
}

class FakeDirectoryProfile {
  static DirectoryProfile make(bool saved) =>
      sampleDirectoryProfile(favorite: saved);
}

Widget directory(FakeDirectory repository, {String? id}) => MaterialApp(
  home: TrainerDirectoryPage(
    repository: repository,
    profileId: id,
    loadPhoto: (_) async => Uint8List(0),
    onOpen: (_) {},
    onContact: (_) async => true,
    publicBase: Uri.parse('https://trainer.example.test/directory'),
  ),
);

void main() {
  test('publicar exige foto y aceptación; guardar borrador no publica', () {
    expect(
      sampleDirectoryProfile().validate(publishing: true, consent: false),
      contains('Acepta'),
    );
    expect(
      sampleDirectoryProfile(photo: null)
          .validate(publishing: true, consent: true),
      contains('foto'),
    );
    expect(
      sampleDirectoryProfile(photo: null)
          .validate(publishing: false, consent: false),
      isNull,
    );
  });
  test('contactos rechazan credenciales y esquemas ejecutables', () {
    expect(
      sampleDirectoryProfile(website: 'https://user:secret@example.test')
          .validate(publishing: false, consent: false),
      contains('HTTPS'),
    );
    expect(
      sampleDirectoryProfile(website: 'javascript:alert(1)')
          .validate(publishing: false, consent: false),
      contains('HTTPS'),
    );
    expect(
      sampleDirectoryProfile(email: 'correo\ninyectado@example.test')
          .validate(publishing: false, consent: false),
      contains('correo'),
    );
    expect(
      sampleDirectoryProfile(email: '')
          .validate(publishing: false, consent: false),
      contains('contacto'),
    );
    expect(sampleDirectoryProfile().contacts.single.uri.scheme, 'mailto');
  });
  testWidgets('buscar y guardar favorito no crean vínculos', (tester) async {
    final repository = FakeDirectory();
    await tester.pumpWidget(directory(repository));
    await tester.pumpAndSettle();
    expect(find.text('Ervi · Carrera'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar en favoritos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar en favoritos'));
    await tester.pumpAndSettle();
    expect(repository.saved, isTrue);
    expect(find.text('Quitar de favoritos'), findsOneWidget);
    expect(find.text('Aceptar invitación'), findsNothing);
  });
  testWidgets('fallo de búsqueda ofrece recuperación', (tester) async {
    final repository = FakeDirectory()..fail = true;
    await tester.pumpWidget(directory(repository));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión de prueba'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ervi · Carrera'), findsOneWidget);
  });
  testWidgets(
    'solo app no ofrece enlace público y denuncia informa de la revisión',
    (tester) async {
      final repository = FakeDirectory();
      await tester.pumpWidget(directory(repository, id: 'one'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar enlace de la ficha'), findsNothing);
      await tester.ensureVisible(find.text('Denunciar perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Denunciar perfil'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La denuncia se revisará. No oculta automáticamente el perfil.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar denuncia'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<DirectoryReportReason>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam o enlaces engañosos').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar denuncia'));
      await tester.pumpAndSettle();
      expect(repository.reportsSent, 1);
      expect(find.text('Ervi · Carrera'), findsOneWidget);
    },
  );
  testWidgets('visitante puede consultar pero no tiene acciones personales', (
    tester,
  ) async {
    final repository = FakeDirectory()..signedIn = false;
    await tester.pumpWidget(directory(repository, id: 'one'));
    await tester.pumpAndSettle();
    expect(find.text('Ervi · Carrera'), findsOneWidget);
    expect(find.text('Guardar en favoritos'), findsNothing);
    expect(find.text('Denunciar perfil'), findsNothing);
  });
}
