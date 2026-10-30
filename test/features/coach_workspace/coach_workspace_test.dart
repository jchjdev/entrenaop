import '../../support/coach_workspace_fixture.dart';

import 'package:workout_editor_ui/exercise_video_preview.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_detail_pages.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_security_gate.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_pages.dart';

import 'dart:async';

import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_controller.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

void main() {
  test('una cuenta normal no consulta MFA ni bandeja profesional', () async {
    final repo = FakeCoach()..enabled = false;
    final security = FakeSecurity();
    final controller = CoachWorkspaceController(
      repository: repo,
      security: security,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.enabled, false);
    expect(controller.canRead, false);
    expect(security.checks, 0);
    expect(repo.inboxCalls, 0);
  });
  test('Pro o el nombre de cuenta no sustituyen MFA profesional', () async {
    final repo = FakeCoach();
    final controller = CoachWorkspaceController(
      repository: repo,
      security: FakeSecurity()..verified = false,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.enabled, true);
    expect(controller.canRead, false);
    expect(repo.inboxCalls, 0);
  });
  test('revocación y error limpian los contadores y cierran acceso', () async {
    final repo = FakeCoach();
    final controller = CoachWorkspaceController(
      repository: repo,
      security: FakeSecurity(),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.unread, 2);
    repo.enabled = false;
    await controller.refresh();
    expect(controller.canRead, false);
    expect(controller.unread, 0);
    repo.enabled = true;
    await controller.refresh();
    repo.failed = true;
    await controller.refresh();
    expect(controller.canRead, false);
    expect(controller.unread, 0);
    expect(controller.error, isNotNull);
  });
  test('una respuesta anterior no reabre un permiso revocado', () async {
    final repo = FakeCoach();
    final old = Completer<CoachAccount>();
    repo.readAccount = () => old.future;
    final controller = CoachWorkspaceController(
      repository: repo,
      security: FakeSecurity(),
    );
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    repo.readAccount = () async => const CoachAccount(enabled: false);
    await controller.refresh();
    old.complete(const CoachAccount(enabled: true));
    await pending;
    expect(controller.enabled, false);
    expect(controller.unread, 0);
    expect(repo.inboxCalls, 0);
  });
  test('descarta respuestas después de cerrar la cuenta', () async {
    final repo = FakeCoach();
    final old = Completer<CoachAccount>();
    repo.readAccount = () => old.future;
    final controller = CoachWorkspaceController(
      repository: repo,
      security: FakeSecurity(),
    );
    final pending = controller.refresh();
    controller.dispose();
    old.complete(const CoachAccount(enabled: true));
    await pending;
    expect(controller.enabled, false);
  });
  testWidgets('deportista normal conserva su navegación sin selector', (
    t,
  ) async {
    final repo = FakeCoach()..enabled = false;
    final router = createRouter(repo, FakeSecurity());
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(repo.clientCalls, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('enlace profesional directo exige MFA antes de leer alumnos', (
    t,
  ) async {
    final repo = FakeCoach();
    final router = createRouter(
      repo,
      FakeSecurity()..verified = false,
      initial: '/coach/clients',
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(find.text('Código de seis cifras'), findsOneWidget);
    expect(find.text('Isabel'), findsNothing);
    expect(repo.clientCalls, 0);
    await t.enterText(find.byType(TextField), '123456');
    await t.tap(find.text('Verificar y entrar'));
    await t.pumpAndSettle();
    expect(find.text('Isabel'), findsOneWidget);
    expect(repo.clientCalls, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'mantiene dos espacios y vuelve a la pantalla personal anterior',
    (t) async {
      final repo = FakeCoach();
      final router = createRouter(
        repo,
        FakeSecurity(),
        initial: '/library/detail',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Mi detalle personal'), findsOneWidget);
      await t.tap(find.text('Entrenador'));
      await t.pumpAndSettle();
      expect(find.text('Tu seguimiento'), findsOneWidget);
      await t.tap(find.text('Alumnos'));
      await t.pumpAndSettle();
      expect(find.text('Isabel'), findsOneWidget);
      await t.tap(find.text('Mi entrenamiento'));
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/library/detail');
      expect(find.text('Mi detalle personal'), findsOneWidget);
      router.go('/my-trainer');
      await t.pumpAndSettle();
      expect(find.text('Mi preparador es Ervi'), findsOneWidget);
      await t.tap(find.text('Entrenador'));
      await t.pumpAndSettle();
      expect(find.text('Isabel'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mensaje leído solo al abrirlo y refresco detenido en el otro espacio',
    (t) async {
      final repo = FakeCoach();
      final messages = FakeMessages();
      final router = createRouter(
        repo,
        FakeSecurity(),
        messages: messages,
        initial: '/coach/messages',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(messages.reads, 0);
      await t.tap(find.text('Isabel'));
      await t.pumpAndSettle();
      expect(find.text('Hola, entrenador'), findsOneWidget);
      expect(messages.reads, 1);
      await t.enterText(find.byType(TextField), 'Mi borrador');
      await t.tap(find.text('Mi entrenamiento'));
      await t.pumpAndSettle();
      // La protección de salida solicita confirmar un borrador.
      if (find.text('Salir').evaluate().isNotEmpty) {
        await t.tap(find.text('Salir'));
        await t.pumpAndSettle();
      }
      expect(router.state.uri.path, '/home');
      final calls = messages.loads;
      await t.pump(const Duration(seconds: 30));
      await t.pumpAndSettle();
      expect(messages.loads, calls);
      await t.tap(find.text('Entrenador'));
      await t.pumpAndSettle();
      expect(find.text('Mi borrador'), findsOneWidget);
      expect(messages.reads, 1);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('cambiar de cuenta descarta fichas privadas pendientes', (
    t,
  ) async {
    final old = FakeCoach();
    final pending = Completer<List<TrainerClient>>();
    old.readClients = () => pending.future;
    Widget frame(String owner, FakeCoach repo) => MaterialApp(
      home: CoachWorkspaceEntry(
        key: ValueKey(owner),
        repository: repo,
        security: FakeSecurity(),
        messages: FakeMessages(),
        video: FakeVideo(),
        child: const CoachSecurityGate(child: CoachClientsPage()),
      ),
    );
    await t.pumpWidget(frame('anterior', old));
    await t.pump();
    await t.pump();
    expect(old.clientCalls, 1);
    final next = FakeCoach()..readClients = () async => [];
    await t.pumpWidget(frame('nueva', next));
    await t.pumpAndSettle();
    pending.complete([old.clientRow]);
    await t.pumpAndSettle();
    expect(find.text('Isabel'), findsNothing);
    expect(find.text('No hay alumnos en este estado.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'el segundo plano detiene las consultas de conversación y bandeja',
    (t) async {
      final repo = FakeCoach();
      final messages = FakeMessages();
      final router = createRouter(
        repo,
        FakeSecurity(),
        messages: messages,
        initial: '/coach/messages/relation',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      final calls = messages.loads, inbox = repo.inboxCalls;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 2));
      expect(messages.loads, calls);
      expect(repo.inboxCalls, inbox);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(repo.inboxCalls, greaterThan(inbox));
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('espacio profesional a $width px y texto $scale', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final router = createRouter(
          FakeCoach(),
          FakeSecurity(),
          initial: '/coach',
        );
        addTearDown(router.dispose);
        const capturePath = String.fromEnvironment('COACH_CAPTURE_DIR');
        if (capturePath.isNotEmpty) {
          await t.runAsync(() async {
            final font = FontLoader('Roboto');
            font.addFont(
              File('C:/Windows/Fonts/segoeui.ttf')
                  .readAsBytes()
                  .then((b) => ByteData.sublistView(b)),
            );
            await font.load();
            final icons = FontLoader('MaterialIcons');
            icons.addFont(
              File(
                'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            );
            await icons.load();
          });
        }
        final boundaryKey = GlobalKey();
        await t.pumpWidget(
          MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundaryKey, child: child!),
            ),
          ),
        );
        await t.pumpAndSettle();
        for (final tab in ['Resumen', 'Agenda', 'Alumnos', 'Mensajes']) {
          await t.tap(find.text(tab));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          const capture = String.fromEnvironment('COACH_CAPTURE_DIR');
          if (capture.isNotEmpty && width == 390 && scale == 1) {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await t.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$capture/$tab.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'calendario compartido permite consulta, sin abrir resultados del otro preparador',
    (t) async {
      final repo = FakeCoach();
      final router = createRouter(
        repo,
        FakeSecurity(),
        initial: '/coach/calendar/isabel',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Series de Ervi'), findsOneWidget);
      await t.tap(find.text('Series de Ervi'));
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/coach/calendar/isabel');
      expect(repo.assignmentCalls, 0);
      repo.shareEnabled = false;
      await t.tap(find.byTooltip('Actualizar calendario'));
      await t.pumpAndSettle();
      expect(find.text('Series de Ervi'), findsNothing);
      expect(
        find.textContaining('no tiene activada la compartición'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'resultado reutilizado y revisión con reintento sin cambiar el envío',
    (t) async {
      final repo = FakeCoach()..failedReviews = 1;
      repo.resultData = {
        'id': 'execution',
        'template_id': 'template',
        'template_name': 'Fuerza con Javier',
        'template_version': 1,
        'started_at': '2026-10-28T10:00:00Z',
        'status': 'completed',
        'result_revision': 3,
        'workout_execution_sets': [],
      };
      final router = createRouter(
        repo,
        FakeSecurity(),
        initial: '/coach/assignment/session',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Solo diferencias con la pauta'), findsOneWidget);
      await t.tap(find.text('Marcar revisado'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Progreso correcto');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.textContaining('Conservamos el envío'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(repo.reviewCalls, hasLength(2));
      expect(repo.reviewCalls[0], repo.reviewCalls[1]);
      expect(repo.reviewCalls.first.$2, 'session');
      expect(repo.reviewCalls.first.$3, 3);
      expect(repo.reviewCalls.first.$4, 'Progreso correcto');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'un fallo de comprobación oculta el chat sin perder el borrador; revocar lo desmonta',
    (t) async {
      final repo = FakeCoach();
      final router = createRouter(
        repo,
        FakeSecurity(),
        initial: '/coach/messages/relation',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Borrador protegido');
      final controller = CoachWorkspaceScope.of(
        t.element(find.byType(CoachConversationPage)),
      ).controller;
      repo.failed = true;
      await controller.refresh();
      await t.pumpAndSettle();
      expect(find.text('Borrador protegido'), findsNothing);
      expect(find.text('Hola, entrenador'), findsNothing);
      expect(
        find.textContaining('No se pudo verificar el acceso'),
        findsOneWidget,
      );
      repo.failed = false;
      await controller.refresh();
      await t.pumpAndSettle();
      expect(find.text('Borrador protegido'), findsOneWidget);
      repo.enabled = false;
      await controller.refresh();
      await t.pumpAndSettle();
      expect(
        find.text('Borrador protegido', skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Hola, entrenador', skipOffstage: false), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'al ocultar el espacio se desmonta el reproductor para detener vídeo y audio',
    (t) async {
      final repo = FakeCoach()
        ..clips = [
          {
            'id': 'clip',
            'created_at': '2026-10-28T10:00:00Z',
            'status': 'ready',
            'playback_url': 'https://video.example.invalid/clip.mp4',
            'duration_seconds': 30,
            'can_feedback': true,
            'feedback_count': 0,
            'feedback': [],
          },
        ];
      final router = createRouter(
        repo,
        FakeSecurity(),
        initial: '/coach/technique/session',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.byType(ExerciseVideoPreview), findsOneWidget);
      await t.tap(find.text('Mi entrenamiento'));
      await t.pumpAndSettle();
      expect(
        find.byType(ExerciseVideoPreview, skipOffstage: false),
        findsNothing,
      );
      await t.tap(find.text('Entrenador'));
      await t.pumpAndSettle();
      expect(find.byType(ExerciseVideoPreview), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
}
