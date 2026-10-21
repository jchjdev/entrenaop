// Capturas de widgets reales con datos ficticios, sin cuentas ni red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrena_ui/conversation_view.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_client_workspace.dart';
import 'package:entrenaop_trainer/trainer_home_page.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../test/trainer_client_workspace_test.dart' show WorkspaceFixture;
import '../test/trainer_operations_flow_test.dart' show OperationsFixture;
import '../test/trainer_program_flow_test.dart' show AgendaFixture;

void main() {
  for (final width in [390.0, 1200.0]) {
    for (final screen in ['inicio', 'agenda', 'ficha', 'conversacion']) {
      testWidgets('captura $screen $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(() async {
          for (final (family, filename) in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final fontDirectory =
                Platform.environment['FLUTTER_FONT_DIR'] ??
                'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
            final bytes = await File('$fontDirectory/$filename').readAsBytes();
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
        });
        final boundary = GlobalKey();
        final agenda = AgendaFixture();
        final operations = OperationsFixture()..fail = false;
        final child = switch (screen) {
          'inicio' => TrainerHomePage(
            access: FakeTrainerRepository(),
            agenda: agenda,
            operations: operations,
            now: DateTime(2026, 10, 21),
          ),
          'agenda' => TrainerAgendaPage(
            repository: agenda,
            now: DateTime(2026, 10, 21),
            onMove: (_, _) async {},
            onCopyWeek: (_, _) async {},
            onAdapt: (_) async {},
          ),
          'ficha' => TrainerClientWorkspacePage(
            repository: WorkspaceFixture(),
            clientId: 'client',
          ),
          _ => ConversationView(
            header: () async => const ConversationHeader(
              title: 'Alumno de ensayo',
              canSend: true,
            ),
            load: (_) async => [
              ConversationEntry(
                id: 'demo',
                body: 'He terminado la sesión. En la última serie he mantenido la técnica.',
                createdAt: DateTime.utc(2026, 10, 21, 10),
                mine: false,
              ),
            ],
            send: (_, _) async {},
            newOperationId: () => 'demo',
            errorLabel: (_) => 'Ensayo',
          ),
        };
        final location = switch (screen) {
          'inicio' => '/home',
          'agenda' => '/agenda',
          _ => '/clients/client',
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: EntrenaTheme.dark,
              home: TrainerShell(location: location, child: child),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            '../docs/visual-audit/trainer-professional-2026-10-21/$screen-${width.toInt()}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
