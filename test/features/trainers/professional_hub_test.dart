import 'dart:async';

import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_hub_page.dart';
import 'package:entrenaop/features/trainers/presentation/widgets/home_professional_hub.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const allResources = StudentNoticeResources(
  hasForms: true,
  hasAssessments: true,
  hasConversations: true,
  hasTechnique: true,
  hasAssignedWorkouts: true,
  conversationRelationId: 'relation',
);

StudentNotice notice(String id, {DateTime? readAt}) => StudentNotice(
  id: id,
  kind: StudentNoticeKind.form,
  title: 'Formulario recibido $id',
  createdAt: DateTime(2026, 10, 21),
  readAt: readAt,
);

StudentNoticeSnapshot snapshot({
  StudentNoticeResources resources = allResources,
  List<StudentNotice> items = const [],
  int unread = 120,
  bool more = false,
}) => StudentNoticeSnapshot(
  items: items,
  hasMore: more,
  unreadCount: unread,
  resources: resources,
);

class NoticeFixture extends StudentNoticeRepository {
  StudentNoticeSnapshot data = const StudentNoticeSnapshot(
    items: [],
    hasMore: false,
    unreadCount: 120,
    resources: allResources,
  );
  bool fail = false;
  int loads = 0;
  final acknowledgements = <String>[];
  final cursors = <StudentNotice?>[];
  final kinds = <StudentNoticeKind?>[];
  Future<StudentNoticeSnapshot> Function()? pending;
  StudentNoticeTarget? target = const StudentNoticeTarget(
    kind: StudentNoticeTargetKind.form,
    targetId: 'form',
  );

  @override
  Future<StudentNoticeSnapshot> snapshot({
    StudentNotice? before,
    StudentNoticeKind? kind,
  }) async {
    loads++;
    cursors.add(before);
    kinds.add(kind);
    if (fail) throw StateError('Sin conexión');
    return pending?.call() ?? data;
  }

  @override
  Future<void> ack(String noticeId, {int? generation}) async {
    acknowledgements.add(noticeId);
  }

  @override
  Future<StudentNoticeTarget?> resolve(
    String noticeId, {
    int? generation,
  }) async => target;
  @override
  Future<TechniqueTargetPage> listTechnique({TechniqueTarget? before}) async =>
      const TechniqueTargetPage(items: [], hasMore: false);
}

Future<void> press(WidgetTester tester, String label) async {
  await reveal(tester, find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250, maxScrolls: 40);
  }
  await tester.ensureVisible(finder.last);
}

void main() {
  test('un grupo de planificación abre la agenda y conserva la fecha sin seleccionar una receta', () {
    expect(
      studentNoticeTargetRoute(
        StudentNoticeTarget(
          kind: StudentNoticeTargetKind.planning,
          targetId: 'group',
          scheduledDate: DateTime(2026, 11, 1),
        ),
      ),
      '/plan/week?date=2026-11-01',
    );
    expect(
      studentNoticeTargetRoute(
        const StudentNoticeTarget(
          kind: StudentNoticeTargetKind.planning,
          targetId: 'group',
        ),
      ),
      isNull,
    );
  });

  testWidgets('volver de Resumen permite abrir Avisos otra vez por su URL', (
    tester,
  ) async {
    final repository = NoticeFixture()..data = snapshot(items: [notice('a')]);
    final router = GoRouter(
      initialLocation: '/my-trainer?view=notices',
      routes: [
        GoRoute(
          path: '/my-trainer',
          builder: (_, state) => ProfessionalHubPage(
            repository: repository,
            userId: 'owner',
            focusNotices: state.uri.queryParameters['view'] == 'notices',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await press(tester, 'Resumen');
    expect(router.state.uri.queryParameters['view'], isNull);
    expect(find.text('Formulario recibido a'), findsNothing);
    router.go('/my-trainer?view=notices');
    await tester.pumpAndSettle();
    expect(find.text('Formulario recibido a'), findsOneWidget);
  });
  testWidgets(
    'Resumen conserva entrada al vínculo e historial aunque no queden recursos',
    (tester) async {
      final repository = NoticeFixture()
        ..data = snapshot(resources: const StudentNoticeResources(), unread: 0);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalHubPage(
            repository: repository,
            userId: 'owner',
            onOpen: (route) async {
              opened.add(route);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Vínculo e historial con mi preparador'),
        findsOneWidget,
      );
      expect(find.text('No hay avisos en esta categoría.'), findsNothing);
      await press(tester, 'Vínculo e historial con mi preparador');
      expect(opened, ['/profile/trainer']);
      await press(tester, 'Avisos');
      expect(find.text('No hay avisos en esta categoría.'), findsOneWidget);
    },
  );

  Future<void> home(
    WidgetTester tester,
    NoticeFixture repository, {
    String owner = 'owner',
    int refresh = 0,
    List<String>? opened,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: StudentNavigationEntry(
          key: ValueKey(owner),
          loadSnapshot: repository.snapshot,
          loadHasRelationship: () async => false,
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeProfessionalHub(
                onOpen: (route) async {
                  opened?.add(route);
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (refresh > 0) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  }

  testWidgets(
    'Inicio oculta todo profesional sin recursos, incluido contador vacío',
    (tester) async {
      final repository = NoticeFixture()
        ..data = snapshot(resources: const StudentNoticeResources(), unread: 0);
      await home(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text('Con mi preparador'), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.textContaining('sin leer'), findsNothing);
    },
  );

  testWidgets('Inicio usa total servidor sin duplicar módulos profesionales', (
    tester,
  ) async {
    final repository = NoticeFixture()
      ..data = snapshot(
        resources: const StudentNoticeResources(hasForms: true),
        items: [notice('one')],
      );
    final opened = <String>[];
    await home(tester, repository, opened: opened);
    await tester.pumpAndSettle();
    expect(find.text('120 novedades de tu preparador'), findsOneWidget);
    expect(find.text('Formularios'), findsNothing);
    expect(find.text('Técnica de mis sesiones'), findsNothing);
    expect(find.text('Conversación'), findsNothing);
    await press(tester, 'Consultar avisos');
    expect(opened, ['/my-trainer?view=notices']);
  });

  for (final confirmedEmpty in [false, true]) {
    testWidgets(
      'fallo sin recursos profesionales confirmados no muestra panel: vacío conocido=$confirmedEmpty',
      (tester) async {
        final repository = NoticeFixture()
          ..data = snapshot(
            resources: const StudentNoticeResources(),
            unread: 0,
          )
          ..fail = !confirmedEmpty;
        await home(tester, repository);
        await tester.pumpAndSettle();
        if (confirmedEmpty) {
          repository.fail = true;
          await home(tester, repository, refresh: 1);
          await tester.pumpAndSettle();
        }
        expect(find.text('Con mi preparador'), findsNothing);
        expect(
          find.text('No se pudieron actualizar tus novedades.'),
          findsNothing,
        );
        expect(find.text('Reintentar novedades'), findsNothing);
        expect(find.byType(Card), findsNothing);
      },
    );
  }

  testWidgets('fallo del resumen conserva el contador conocido y se recupera', (
    tester,
  ) async {
    final repository = NoticeFixture();
    await home(tester, repository);
    await tester.pumpAndSettle();
    repository.fail = true;
    await home(tester, repository, refresh: 1);
    await tester.pumpAndSettle();
    expect(find.text('120 novedades de tu preparador'), findsOneWidget);
    repository.fail = false;
    repository.data = snapshot(unread: 0);
    await home(tester, repository, refresh: 2);
    await tester.pumpAndSettle();
    expect(find.textContaining('novedades de tu preparador'), findsNothing);
  });

  testWidgets('cambiar identidad descarta respuesta tardía de Inicio', (
    tester,
  ) async {
    final delayed = Completer<StudentNoticeSnapshot>();
    final old = NoticeFixture()..pending = () => delayed.future;
    await home(tester, old);
    final next = NoticeFixture()
      ..data = snapshot(resources: const StudentNoticeResources(), unread: 0);
    await home(tester, next, owner: 'new-owner');
    await tester.pumpAndSettle();
    delayed.complete(snapshot());
    await tester.pumpAndSettle();
    expect(find.text('Con mi preparador'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inicio refresca al reanudar y cabe a 320px con texto doble', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = NoticeFixture();
    await home(tester, repository, scale: 2);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('120 novedades de tu preparador'));
    expect(tester.takeException(), isNull);
    final before = repository.loads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.loads, greaterThan(before));
  });

  Future<void> hub(
    WidgetTester tester,
    NoticeFixture repository, {
    List<String>? opened,
    String owner = 'owner',
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ProfessionalHubPage(
        repository: repository,
        userId: owner,
        focusNotices: true,
        onOpen: (route) async {
          opened?.add(route);
        },
      ),
    ),
  );

  testWidgets('abrir un aviso resuelve el destino sin confirmarlo como leído', (
    tester,
  ) async {
    final repository = NoticeFixture()..data = snapshot(items: [notice('a')]);
    final opened = <String>[];
    await hub(tester, repository, opened: opened);
    await tester.pumpAndSettle();
    await press(tester, 'Abrir contenido');
    expect(opened, ['/my-trainer/forms/form']);
    expect(repository.acknowledgements, isEmpty);
    await press(tester, 'Marcar como leído');
    expect(repository.acknowledgements, ['a']);
  });

  testWidgets('destino retirado conserva aviso y no marca leído', (
    tester,
  ) async {
    final repository = NoticeFixture()
      ..data = snapshot(items: [notice('a')])
      ..target = null;
    final opened = <String>[];
    await hub(tester, repository, opened: opened);
    await tester.pumpAndSettle();
    await press(tester, 'Abrir contenido');
    expect(opened, isEmpty);
    expect(repository.acknowledgements, isEmpty);
    await tester.scrollUntilVisible(
      find.textContaining('ya no está disponible'),
      -200,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ya no está disponible'), findsOneWidget);
    await reveal(tester, find.text('Formulario recibido a'));
    expect(find.text('Formulario recibido a'), findsOneWidget);
  });

  testWidgets('paginación y filtro conservan contrato sin inferir totales', (
    tester,
  ) async {
    final repository = NoticeFixture()
      ..data = snapshot(items: [notice('a')], more: true);
    await hub(tester, repository);
    await tester.pumpAndSettle();
    repository.data = snapshot(items: [notice('b')]);
    await press(tester, 'Cargar avisos anteriores');
    expect(repository.cursors.last?.id, 'a');
    expect(find.text('Formulario recibido a'), findsOneWidget);
    expect(find.text('Formulario recibido b'), findsOneWidget);
    expect(find.text('120 sin leer'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await press(tester, 'Técnica');
    expect(repository.kinds.last, StudentNoticeKind.techniqueFeedback);
    expect(repository.cursors.last, isNull);
  });

  testWidgets('hub cabe en 320px con texto doble y recursos existentes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await hub(
      tester,
      NoticeFixture()..data = snapshot(items: [notice('a')]),
      scale: 2,
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Marcar como leído'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'destinos de pautas conservan fecha y cita sin arrancar otra plantilla',
    () {
      expect(
        studentNoticeTargetRoute(
          StudentNoticeTarget(
            kind: StudentNoticeTargetKind.workout,
            targetId: 'schedule',
            scheduledDate: DateTime(2026, 10, 21),
          ),
        ),
        '/plan/week?date=2026-10-21&session=schedule',
      );
      expect(
        studentNoticeTargetRoute(
          const StudentNoticeTarget(
            kind: StudentNoticeTargetKind.workout,
            targetId: 'schedule',
          ),
        ),
        isNull,
      );
    },
  );
}
