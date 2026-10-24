import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:entrenaop_trainer/trainer_shared_calendar_page.dart';

class CalendarFixture implements TrainerSharedCalendarRepository {
  bool shared = true, denied = false;
  int reads = 0;
  Completer<SharedCalendarPage>? pending;
  @override
  Future<SharedCalendarPage> calendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) async {
    reads++;
    if (pending != null) return pending!.future;
    if (denied) throw StateError('Acceso retirado');
    return SharedCalendarPage.fromJson({
      'shared': shared,
      'has_more': false,
      'coaches': [
        {'name': 'Javier', 'is_you': true},
        {'name': 'Ervi', 'is_you': false},
      ],
      'items': !shared
          ? []
          : [
              for (var i = 0; i < 2; i++)
                {
                  'id': '$i',
                  'scheduled_date': from.toIso8601String(),
                  'template_name': i == 0 ? 'Fuerza' : 'Series fuertes',
                  'source': 'coach',
                  'status': 'planned',
                  'trainer_name': i == 0 ? 'Javier' : 'Ervi',
                  'is_own': i == 0,
                  'relation_active': true,
                  'is_running': i == 1,
                },
            ],
    });
  }

  @override
  Future<Map<String, dynamic>> workout(
    String clientId,
    String scheduledId,
  ) async => {
    'id': 'template',
    'name': 'Series fuertes',
    'version': 1,
    'workout_blocks': [],
  };
}

void main() {
  testWidgets('calendario legible a 320 con texto doble', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TrainerSharedCalendarPage(
          repository: CalendarFixture(),
          clientId: 'isabel',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Series fuertes'), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'muestra ambos preparadores y abre pauta sin edición; revocar limpia datos',
    (tester) async {
      final repository = CalendarFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSharedCalendarPage(
            repository: repository,
            clientId: 'isabel',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Series fuertes'), findsOneWidget);
      expect(find.textContaining('Ervi'), findsNWidgets(2));
      await tester.tap(find.text('Series fuertes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Solo lectura'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar pauta'));
      await tester.pumpAndSettle();
      repository.denied = true;
      await tester.tap(find.byTooltip('Actualizar calendario'));
      await tester.pumpAndSettle();
      expect(find.text('Series fuertes'), findsNothing);
      expect(find.textContaining('Ervi'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sin consentimiento no enseña sesiones ni preparadores', (
    tester,
  ) async {
    final repository = CalendarFixture()..shared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerSharedCalendarPage(
          repository: repository,
          clientId: 'isabel',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('todavía no comparte'), findsOneWidget);
    expect(find.textContaining('Ervi'), findsNothing);
  });
  testWidgets('cambiar alumno descarta respuestas anteriores', (tester) async {
    final previous = CalendarFixture()
      ..pending = Completer<SharedCalendarPage>();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerSharedCalendarPage(
          key: const ValueKey('a'),
          repository: previous,
          clientId: 'a',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerSharedCalendarPage(
          key: const ValueKey('b'),
          repository: CalendarFixture()..shared = false,
          clientId: 'b',
        ),
      ),
    );
    previous.pending!.complete(
      SharedCalendarPage.fromJson({
        'shared': true,
        'has_more': false,
        'items': [],
        'coaches': [
          {'name': 'Privado A', 'is_you': true},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Privado A'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
