import 'dart:async';

import 'package:entrenaop/core/navigation/app_account_actions.dart';
import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentNoticeSnapshot data(int unread) => StudentNoticeSnapshot(
  items: const [],
  hasMore: false,
  unreadCount: unread,
  resources: const StudentNoticeResources(),
);

void main() {
  test(
    'push durante una lectura fuerza un snapshot posterior sin perder el aviso',
    () async {
      final pending = Completer<StudentNoticeSnapshot>();
      var calls = 0;
      final controller = StudentNavigationController(
        loadSnapshot: () {
          calls++;
          return calls == 1 ? pending.future : Future.value(data(1));
        },
        loadHasRelationship: () async => true,
      );
      addTearDown(controller.dispose);
      final first = controller.refresh();
      final notification = controller.refreshAfterNotice();
      pending.complete(data(0));
      await Future.wait([first, notification]);
      expect(calls, 2);
      expect(controller.unreadCount, 1);
    },
  );

  test(
    'un vínculo anterior mantiene Preparador sin contenido ni avisos',
    () async {
      final controller = StudentNavigationController(
        loadSnapshot: () async => data(0),
        loadHasRelationship: () async => true,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.hasTrainer, isTrue);
      expect(controller.unreadCount, 0);
    },
  );

  test(
    'refrescos simultáneos comparten consulta y un fallo conserva lo conocido',
    () async {
      final pending = Completer<StudentNoticeSnapshot>();
      var reads = 0;
      var fail = false;
      final controller = StudentNavigationController(
        loadSnapshot: () {
          reads++;
          if (fail) throw StateError('offline');
          return pending.future;
        },
        loadHasRelationship: () async {
          if (fail) throw StateError('offline');
          return true;
        },
      );
      addTearDown(controller.dispose);
      final a = controller.refresh();
      final b = controller.refresh();
      pending.complete(data(3));
      await Future.wait([a, b]);
      expect(reads, 1);
      fail = true;
      await controller.refresh();
      expect(controller.unreadCount, 3);
      expect(controller.hasTrainer, isTrue);
    },
  );

  test(
    'marcar avisos prevalece sobre lectura antigua sin perder el vínculo',
    () async {
      final pending = Completer<StudentNoticeSnapshot>();
      final controller = StudentNavigationController(
        loadSnapshot: () => pending.future,
        loadHasRelationship: () async => true,
      );
      addTearDown(controller.dispose);
      final load = controller.refresh();
      controller.acceptSnapshot(data(0));
      pending.complete(data(8));
      await load;
      expect(controller.unreadCount, 0);
      expect(controller.hasTrainer, isTrue);
    },
  );

  testWidgets('cambio de cuenta descarta vínculo y respuesta tardíos', (
    tester,
  ) async {
    final oldNotices = Completer<StudentNoticeSnapshot>();
    final oldRelation = Completer<bool>();
    Widget app(String owner) => MaterialApp(
      home: StudentNavigationEntry(
        key: ValueKey(owner),
        loadSnapshot: () =>
            owner == 'old' ? oldNotices.future : Future.value(data(0)),
        loadHasRelationship: () =>
            owner == 'old' ? oldRelation.future : Future.value(false),
        child: Builder(
          builder: (context) => Text(
            StudentNavigationScope.maybeOf(context)!.hasTrainer
                ? 'Preparador presente'
                : 'Sin preparador',
          ),
        ),
      ),
    );
    await tester.pumpWidget(app('old'));
    await tester.pumpWidget(app('new'));
    oldNotices.complete(data(6));
    oldRelation.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Sin preparador'), findsOneWidget);
    expect(find.text('Preparador presente'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('campana solo con avisos sin leer y Perfil siempre arriba', (
    tester,
  ) async {
    final controller = StudentNavigationController(
      loadSnapshot: () async => data(0),
      loadHasRelationship: () async => true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentNavigationScope(
          controller: controller,
          child: Scaffold(appBar: AppBar(actions: const [AppAccountActions()])),
        ),
      ),
    );
    expect(find.byTooltip('Mi perfil'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    controller.acceptSnapshot(data(2));
    await tester.pumpAndSettle();
    expect(find.byTooltip('2 avisos sin leer'), findsOneWidget);
    controller.acceptSnapshot(data(0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.byTooltip('Mi perfil'), findsOneWidget);
  });
}
