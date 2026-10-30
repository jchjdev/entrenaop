import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/directory/domain.dart';
import 'package:entrenaop_trainer/trainer_directory_editor.dart';

class DraftRepository implements DirectoryRepository {
  int writes = 0;
  bool? published;
  bool failSave = false;
  DirectoryProfile? submitted;
  final value = const DirectoryOwnerProfile(
    profile: DirectoryProfile(
      id: 'draft',
      name: 'Preparador de prueba',
      description: 'Carrera para oposiciones',
      specialties: ['Carrera'],
      services: ['Seguimiento'],
      mode: DirectoryMode.online,
      city: '',
      visibility: DirectoryVisibility.app,
      email: 'coach@example.test',
    ),
    revision: 1,
    eligible: false,
    published: false,
    blocked: false,
    consent: false,
    enabled: false,
  );
  @override
  Future<DirectoryOwnerProfile> own() async => value;
  @override
  Future<DirectoryOwnerProfile> save(
    DirectoryProfile profile, {
    required int revision,
    required bool published,
    required bool consent,
  }) async {
    writes++;
    this.published = published;
    submitted = profile;
    if (failSave) throw const DirectoryFailure('Fallo de guardado de prueba.');
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget editor(DraftRepository repository) => MaterialApp(
    home: TrainerDirectoryEditor(
      repository: repository,
      photo: (_) async => Uint8List(0),
      uploadPhoto: (_, _) async => 'unused',
      discardPhoto: (_) async {},
      cleanupPhotoDrafts: () async {},
    ),
  );

  Future<void> pressSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Guardar ficha'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar ficha'));
    await tester.pumpAndSettle();
  }

  testWidgets('validación visible al guardar desde el final del formulario', (
    tester,
  ) async {
    final repository = DraftRepository();
    await tester.pumpWidget(editor(repository));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, 'Nombre profesional');
    await tester.scrollUntilVisible(
      name,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(name, '');
    await pressSave(tester);
    expect(repository.writes, 0);
    expect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.text('Indica un nombre de hasta 80 caracteres.'),
          )
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('fallo de guardado visible y reintento conserva la edición', (
    tester,
  ) async {
    final repository = DraftRepository()..failSave = true;
    await tester.pumpWidget(editor(repository));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, 'Nombre profesional');
    await tester.scrollUntilVisible(
      name,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(name, 'Nombre editado');
    await pressSave(tester);
    expect(repository.writes, 1);
    expect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.text('Fallo de guardado de prueba.'),
          )
          .hitTestable(),
      findsOneWidget,
    );
    repository.failSave = false;
    await pressSave(tester);
    expect(repository.writes, 2);
    expect(repository.submitted!.name, 'Nombre editado');
    expect(repository.published, isFalse);
    expect(find.text('Ficha guardada.').hitTestable(), findsOneWidget);
    expect(find.text('Fallo de guardado de prueba.'), findsNothing);
  });

  testWidgets(
    'cuenta sin prestación puede preparar borrador sin activar publicación',
    (tester) async {
      final repository = DraftRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerDirectoryEditor(
            repository: repository,
            photo: (_) async => Uint8List(0),
            uploadPhoto: (_, _) async => 'unused',
            discardPhoto: (_) async {},
            cleanupPhotoDrafts: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'La publicación del directorio está en preparación',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Publicar ficha'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final publish = find.widgetWithText(SwitchListTile, 'Publicar ficha');
      expect(tester.widget<SwitchListTile>(publish).onChanged, isNull);
      await tester.scrollUntilVisible(
        find.text('Guardar ficha'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar ficha'));
      await tester.pumpAndSettle();
      expect(repository.writes, 1);
      expect(repository.published, isFalse);
    },
  );
}
