import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrena_ui/media_cleanup_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> report({
  int pending = 0,
  int deleted = 0,
  int protected = 0,
  String? state,
}) => {
  'items': [
    if (state != null)
      {
        'kind': 'video',
        'state': state,
        'blocked_reason': state == 'blocked' ? 'exercise_reference' : null,
      },
  ],
  'summary': {
    'pending': pending,
    'deleted': deleted,
    'protected': protected,
    'freed_images': deleted,
    'freed_bytes': 0,
  },
};

class Fixture {
  final operations = <String>[];
  final videos = <String>[];
  bool fail = false;
  int serial = 0;
  Completer<Map<String, dynamic>>? gate;
  Map<String, dynamic> current = report();
  Future<Map<String, dynamic>> inspect() async => current;
  Future<Map<String, dynamic>> sweep(String operation) async {
    operations.add(operation);
    if (gate != null) return gate!.future;
    if (fail) throw StateError('Respuesta perdida');
    return current;
  }

  Future<Map<String, dynamic>> delete(String operation, String id) async {
    videos.add(id);
    return sweep(operation);
  }
}

Widget app(
  Fixture fixture, {
  Object owner = 'owner',
  MediaCleanupVideoTarget? video,
  double textScale = 1,
}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: MediaCleanupView(
    ownerKey: owner,
    inspect: fixture.inspect,
    sweep: fixture.sweep,
    run: fixture.inspect,
    deleteVideo: fixture.delete,
    initialVideo: video,
    newOperationId: () => 'operation-${++fixture.serial}',
  ),
);

Future<void> confirmSweep(WidgetTester tester) async {
  await tester.tap(find.text('Limpiar archivos sin uso'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Limpiar archivos sin uso').last);
  await tester.pump();
}

void main() {
  testWidgets(
    'barrido confirma alcance y nunca da por liberada una reserva pendiente',
    (tester) async {
      final fixture = Fixture()..current = report(pending: 1, state: 'retry');
      await tester.pumpWidget(app(fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar archivos sin uso'));
      await tester.pumpAndSettle();
      expect(fixture.operations, isEmpty);
      expect(find.textContaining('24 horas'), findsOneWidget);
      expect(find.textContaining('vídeos listos'), findsOneWidget);
      await tester.tap(find.text('Limpiar archivos sin uso').last);
      await tester.pumpAndSettle();
      expect(fixture.operations, hasLength(1));
      expect(fixture.videos, isEmpty);
      expect(find.text('1 pendientes'), findsOneWidget);
      expect(find.text('0 limpiados'), findsOneWidget);
      expect(find.textContaining('reserva todavía cuenta'), findsOneWidget);
    },
  );

  testWidgets(
    'respuesta incierta conserva UUID incluso después de actualizar',
    (tester) async {
      final fixture = Fixture()..fail = true;
      await tester.pumpWidget(app(fixture));
      await tester.pumpAndSettle();
      await confirmSweep(tester);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar la misma operación'), findsOneWidget);
      await tester.tap(find.text('Actualizar estado'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar la misma operación'), findsOneWidget);
      fixture.fail = false;
      await tester.tap(find.text('Reintentar la misma operación'));
      await tester.pumpAndSettle();
      expect(fixture.operations, ['operation-1', 'operation-1']);
      expect(find.text('¿Limpiar archivos sin uso?'), findsNothing);
    },
  );

  testWidgets('cambiar de cuenta descarta informe y respuesta antiguos', (
    tester,
  ) async {
    final original = Fixture()..gate = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(app(original));
    await tester.pumpAndSettle();
    await confirmSweep(tester);
    final replacement = Fixture();
    await tester.pumpWidget(app(replacement, owner: 'other'));
    await tester.pumpAndSettle();
    original.gate!.complete(report(deleted: 99));
    await tester.pumpAndSettle();
    expect(find.text('99 limpiados'), findsNothing);
    expect(find.text('0 limpiados'), findsOneWidget);
    expect(find.text('Reintentar la misma operación'), findsNothing);
  });

  testWidgets(
    'demostración requiere confirmación y distingue protección de borrado real',
    (tester) async {
      final fixture = Fixture()
        ..current = report(protected: 1, state: 'blocked');
      await tester.pumpWidget(
        app(
          fixture,
          video: const MediaCleanupVideoTarget(
            ownerKey: 'owner',
            id: 'own-video',
            name: 'Dominada',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.videos, isEmpty);
      expect(find.text('¿Eliminar esta demostración?'), findsOneWidget);
      await tester.tap(find.text('Eliminar demostración').last);
      await tester.pumpAndSettle();
      expect(fixture.videos, ['own-video']);
      expect(find.text('1 protegidos'), findsOneWidget);
      expect(find.text('Vídeo · Protegido'), findsOneWidget);
      expect(
        find.text('Lo utiliza un ejercicio o una versión conservada.'),
        findsOneWidget,
      );
      expect(find.text('exercise_reference'), findsNothing);
      expect(find.text('0 limpiados'), findsOneWidget);
    },
  );

  testWidgets('contexto de otra cuenta jamás solicita eliminar el vídeo', (
    tester,
  ) async {
    final fixture = Fixture();
    await tester.pumpWidget(
      app(
        fixture,
        video: const MediaCleanupVideoTarget(
          ownerKey: 'other',
          id: 'foreign',
          name: 'Ajeno',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.videos, isEmpty);
    expect(find.text('¿Eliminar esta demostración?'), findsNothing);
    expect(find.textContaining('pertenece a otra cuenta'), findsOneWidget);
  });

  testWidgets('pantalla y confirmación son utilizables a 320px y texto doble', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = Fixture();
    await tester.pumpWidget(app(fixture, textScale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Limpiar archivos sin uso'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar archivos sin uso'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(fixture.operations, isEmpty);
  });
}
