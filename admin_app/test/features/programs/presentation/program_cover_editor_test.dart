import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';
import 'package:entrenaop_admin/features/programs/presentation/program_cover_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/program_cover_image_draft.dart';

// PNG mínimo válido; el editor recibe bytes ya optimizados por el selector real.
final imageBytes = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  96,
  0,
  2,
  0,
  0,
  5,
  0,
  1,
  165,
  246,
  69,
  64,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

class FakeCoverRepository implements ProgramCoverRepository {
  ProgramCover value = const ProgramCover(programId: 'fas');
  int saves = 0, loads = 0;
  Object? failure;
  ProgramCoverUpload? lastUpload;
  bool removed = false;
  @override
  Future<ProgramCover> load(String programId) async {
    loads++;
    return value;
  }

  @override
  Future<ProgramCover> save(
    ProgramCover current, {
    required double focalX,
    required double focalY,
    required double headerFocalX,
    required double headerFocalY,
    ProgramCoverUpload? upload,
    bool removeImage = false,
  }) async {
    saves++;
    lastUpload = upload;
    removed = removeImage;
    if (failure != null) throw failure!;
    value = ProgramCover(
      programId: current.programId,
      focalX: focalX,
      focalY: focalY,
      headerFocalX: headerFocalX,
      headerFocalY: headerFocalY,
      revision: current.revision + 1,
    );
    return value;
  }
}

Future<void> openEditor(
  WidgetTester tester,
  FakeCoverRepository repository, {
  Size size = const Size(1200, 1000),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('cover-review'),
      child: MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: ProgramCoverEditor(
                    programId: 'fas',
                    programName: 'Evaluación periódica · FAS',
                    repository: repository,
                    pickImage: () async => ProgramCoverImageDraft(
                      card: imageBytes,
                      header: imageBytes,
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> upload(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Subir imagen'));
  await tester.tap(find.text('Subir imagen'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Guardar portada'));
  await tester.tap(find.text('Guardar portada'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'tarjeta y cabecera guardan encuadres independientes y los recuperan al abrir',
    (tester) async {
      final repository = FakeCoverRepository();
      await openEditor(tester, repository);
      await upload(tester);
      tester
          .widget<Slider>(find.byKey(const ValueKey('cover-focus-x')))
          .onChanged!(0.8);
      tester
          .widget<Slider>(find.byKey(const ValueKey('cover-focus-y')))
          .onChanged!(0.2);
      await tester.pump();
      var previews = tester
          .widgetList<EntrenaCard>(find.byType(EntrenaCard))
          .toList();
      expect([previews[0].focalX, previews[0].focalY], [0.8, 0.2]);
      expect([previews[1].focalX, previews[1].focalY], [0.5, 0.5]);
      await tester.tap(find.byKey(const ValueKey('cover-frame-header')));
      await tester.pump();
      tester
          .widget<Slider>(find.byKey(const ValueKey('cover-focus-x')))
          .onChanged!(0.6);
      tester
          .widget<Slider>(find.byKey(const ValueKey('cover-focus-y')))
          .onChanged!(0.7);
      await tester.pump();
      previews = tester
          .widgetList<EntrenaCard>(find.byType(EntrenaCard))
          .toList();
      expect([previews[0].focalX, previews[0].focalY], [0.8, 0.2]);
      expect([previews[1].focalX, previews[1].focalY], [0.6, 0.7]);
      await tester.tap(find.text('Escritorio'));
      await tester.pump();
      await save(tester);
      expect([repository.value.focalX, repository.value.focalY], [0.8, 0.2]);
      expect(
        [repository.value.headerFocalX, repository.value.headerFocalY],
        [0.6, 0.7],
      );
      await tester.ensureVisible(find.byTooltip('Cerrar editor'));
      await tester.tap(find.byTooltip('Cerrar editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('cover-focus-x')))
            .value,
        0.8,
      );
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('cover-focus-y')))
            .value,
        0.2,
      );
      await tester.tap(find.byKey(const ValueKey('cover-frame-header')));
      await tester.pump();
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('cover-focus-x')))
            .value,
        0.6,
      );
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('cover-focus-y')))
            .value,
        0.7,
      );
    },
  );
  testWidgets(
    'subir y encuadrar no guarda hasta confirmar; error conserva borrador',
    (tester) async {
      final repository = FakeCoverRepository();
      await openEditor(tester, repository);
      await upload(tester);
      expect(repository.saves, 0);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('cover-focus-x')),
      );
      slider.onChanged!(0.8);
      await tester.pump();
      repository.failure = Exception('Sin conexión');
      await save(tester);
      expect(find.textContaining('Tus cambios siguen aquí'), findsOneWidget);
      expect(find.text('Cambiar imagen'), findsOneWidget);
      repository.failure = null;
      await save(tester);
      expect(repository.value.focalX, 0.8);
      expect(repository.lastUpload!.card, imageBytes);
      expect(find.textContaining('Portada guardada.'), findsOneWidget);
    },
  );
  testWidgets('cerrar solicita descarte y no persiste una imagen retirada', (
    tester,
  ) async {
    final repository = FakeCoverRepository();
    await openEditor(tester, repository);
    await upload(tester);
    await tester.ensureVisible(find.text('Quitar imagen'));
    await tester.tap(find.text('Quitar imagen'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Cerrar editor'));
    await tester.tap(find.byTooltip('Cerrar editor'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios de portada?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramCoverEditor), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramCoverEditor), findsNothing);
    expect(repository.saves, 0);
  });
  testWidgets('un conflicto bloquea guardar hasta recargar explícitamente', (
    tester,
  ) async {
    final repository = FakeCoverRepository()
      ..failure = const ProgramCoverConflict();
    await openEditor(tester, repository);
    await upload(tester);
    await save(tester);
    expect(find.textContaining('Otra edición'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar portada'),
    );
    expect(button.onPressed, isNull);
    await tester.ensureVisible(find.text('Recargar portada'));
    await tester.tap(find.text('Recargar portada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(find.text('Subir imagen'), findsOneWidget);
  });
  testWidgets('se adapta a una ventana estrecha con texto ampliado', (
    tester,
  ) async {
    await openEditor(
      tester,
      FakeCoverRepository(),
      size: const Size(400, 900),
      scale: 1.6,
    );
    await upload(tester);
    await tester.ensureVisible(find.text('Cabecera de la preparación'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('captura optativa del editor web con una fotografía real', (
    tester,
  ) async {
    final photo = await tester.runAsync(() async {
      final font = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
      final icons = await File(
        'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      final source = await File(
        '../output/preparation-covers/fas-evaluacion-periodica-v1.png',
      ).readAsBytes();
      return optimizeProgramCoverImage(source);
    });
    await openEditor(
      tester,
      FakeCoverRepository(),
      size: const Size(1440, 1080),
    );
    // Sustituye exclusivamente el selector de prueba; no sube nada a Supabase.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('cover-review'),
        child: MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(
            body: Center(
              child: ProgramCoverEditor(
                programId: 'fas',
                programName: 'Evaluación periódica FAS · 2027 (PAFAS/PAEF)',
                repository: FakeCoverRepository(),
                pickImage: () async => photo,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await upload(tester);
    await tester.runAsync(() async {
      final context = tester.element(find.byType(ProgramCoverEditor));
      await precacheImage(MemoryImage(photo!.card), context);
      await precacheImage(MemoryImage(photo.header), context);
    });
    tester
        .widget<Slider>(find.byKey(const ValueKey('cover-focus-x')))
        .onChanged!(0.8);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cover-frame-header')));
    await tester.pump();
    tester
        .widget<Slider>(find.byKey(const ValueKey('cover-focus-x')))
        .onChanged!(0.8);
    tester
        .widget<Slider>(find.byKey(const ValueKey('cover-focus-y')))
        .onChanged!(0.25);
    await tester.pump();
    await tester.tap(find.text('Escritorio'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('cover-review')),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/cover_review')
        ..createSync(recursive: true);
      await File('${directory.path}/editor-desktop.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }, skip: !const bool.fromEnvironment('CAPTURE_COVERS'));
}
