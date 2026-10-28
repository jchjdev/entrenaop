import 'package:trainer_access/trainer_calendar.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_security_gate.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_pages.dart';

import 'dart:async';

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/core/router/coach_workspace_routes.dart';
import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_controller.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:trainer_access/trainer_security.dart';
import 'package:workout_core/professional_opposition_goal.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

class FakeSecurity implements TrainerSecurity {
  bool verified = true;
  int checks = 0;
  @override
  Future<bool> assured() async {
    checks++;
    return verified;
  }

  @override
  Future<List<String>> factors() async => ['factor'];
  @override
  Future<void> verify(String factor, String code) async {
    verified = code == '123456';
  }

  @override
  Future<TrainerTotpSetup> enroll() async =>
      const TrainerTotpSetup('factor', '', 'clave');
}

class FakeCoach extends CoachWorkspaceRepository {
  bool enabled = true, failed = false, shareEnabled = true;
  int assignmentCalls = 0, failedReviews = 0;
  Map<String, dynamic>? resultData;
  final reviewCalls = <(String, String, int, String)>[];

  int clientCalls = 0, inboxCalls = 0;
  Future<List<TrainerClient>> Function()? readClients;
  Future<CoachAccount> Function()? readAccount;
  final clientRow = TrainerClient.fromJson({
    'person_id': 'isabel',
    'person_name': 'Isabel',
    'created_at': '2026-10-20T00:00:00Z',
    'updated_at': '2026-10-20T00:00:00Z',
    'accepted_at': '2026-10-20T00:00:00Z',
    'active_relation_id': 'relation',
    'episode_count': 1,
  });
  @override
  Future<CoachAccount> account() async {
    if (failed) throw StateError('Sin red');
    return readAccount == null
        ? CoachAccount(enabled: enabled)
        : readAccount!();
  }

  @override
  Future<TrainerMessageInbox> inbox() async {
    inboxCalls++;
    return const TrainerMessageInbox(
      totalUnread: 2,
      conversations: [],
      clients: {
        'isabel': TrainerClientMessageSummary(
          unreadCount: 2,
          relationId: 'relation',
        ),
      },
    );
  }

  @override
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  }) async {
    clientCalls++;
    return readClients == null ? [clientRow] : readClients!();
  }

  @override
  Future<CoachClientDetail> client(String id) async => CoachClientDetail(
    clientRow,
    ProfessionalOppositionGoal(
      revision: 0,
      title: 'Policía',
      targets: const [],
      canEdit: true,
      historyComplete: true,
    ),
  );
  @override
  Future<List<CoachTechniquePending>> pendingTechnique({
    CoachTechniquePending? before,
  }) async => [];
  @override
  Future<List<CoachAssignment>> agenda(
    DateTime from,
    DateTime to, {
    CoachAssignment? after,
  }) async => [];
  @override
  Future<List<CoachAssignment>> reviews({CoachAssignment? before}) async => [];
  @override
  Future<List<CoachAssignment>> assignments(
    String id, {
    CoachAssignment? before,
  }) async => [];
  @override
  Future<SharedCalendarPage> sharedCalendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) async => SharedCalendarPage.fromJson({
    'shared': shareEnabled,
    'has_more': false,
    'coaches': [],
    'items': !shareEnabled
        ? []
        : [
            {
              'id': 'foreign',
              'scheduled_date': '2026-10-28',
              'template_name': 'Series de Ervi',
              'source': 'coach',
              'status': 'planned',
              'is_own': false,
              'trainer_name': 'Ervi',
            },
            {
              'id': 'session',
              'scheduled_date': '2026-10-28',
              'template_name': 'Fuerza con Javier',
              'source': 'coach',
              'status': 'planned',
              'is_own': true,
              'trainer_name': 'Javier',
            },
          ],
  });
  @override
  Future<CoachAssignment> assignment(String id) async {
    assignmentCalls++;
    return CoachAssignment(
      id: id,
      name: 'Fuerza con Javier',
      date: DateTime(2026, 10, 28),
      createdAt: DateTime(2026, 10, 28),
      clientId: 'isabel',
      clientName: 'Isabel',
      status: 'completed',
    );
  }

  @override
  Future<Map<String, dynamic>?> result(String id) async => resultData;
  @override
  Future<void> review(
    String operation,
    String assignmentId,
    int revision,
    String note,
  ) async {
    reviewCalls.add((operation, assignmentId, revision, note));
    if (failedReviews-- > 0) throw StateError('Sin confirmar');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessages implements TrainerInboxMessageRepository {
  int loads = 0, reads = 0;
  @override
  Future<TrainerConversationContext> context(String id) async =>
      TrainerConversationContext.fromJson({'name': 'Isabel', 'can_send': true});
  @override
  Future<List<TrainerMessage>> list(
    String id, {
    DateTime? beforeAt,
    String? beforeId,
  }) async {
    loads++;
    return [
      TrainerMessage.fromJson({
        'id': 'm1',
        'body': 'Hola, entrenador',
        'sender_id': 'isabel',
        'created_at': '2026-10-28T09:00:00Z',
      }, 'javier'),
    ];
  }

  @override
  Future<void> markRead(List<String> ids) async {
    reads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeVideo implements ExerciseVideoSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouter createRouter(
  FakeCoach repo,
  FakeSecurity security, {
  FakeMessages? messages,
  String initial = '/home',
}) {
  final exits = WorkflowExitRegistry();
  return GoRouter(
    initialLocation: initial,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CoachWorkspaceEntry(
          key: const ValueKey('javier'),
          repository: repo,
          security: security,
          messages: messages ?? FakeMessages(),
          video: FakeVideo(),
          child: AppShell(navigationShell: shell),
        ),
        branches: [
          for (final path in [
            '/home',
            '/plan',
            '/library',
            '/evolution',
            '/my-trainer',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(
                    appBar: AppBar(title: Text('Página $path')),
                    body: Text(
                      path == '/my-trainer'
                          ? 'Mi preparador es Ervi'
                          : 'Contenido $path',
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (_, _) =>
                          const Scaffold(body: Text('Mi detalle personal')),
                    ),
                  ],
                ),
              ],
            ),
          coachWorkspaceBranch(exits),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Perfil personal')),
      ),
    ],
  );
}

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
}
