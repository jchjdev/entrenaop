import 'package:entrenaop_admin/features/operations/data/admin_error_reporter.dart';
import 'package:entrenaop_admin/features/operations/data/admin_operations_repository.dart';
import 'package:entrenaop_admin/features/operations/presentation/admin_recovery_panel.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../test/helpers/performance_visual_review.dart';

class _Recovery extends Fake implements AdminOperationsRepository {
  bool expired = false;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> diagnostics() async {
    if (fail) throw StateError('fixture');
    return {
      'checked_at': '2026-10-20T17:00:00Z',
      'backups': [
        {
          'run_id': '12345-1',
          'started_at': '2026-10-20T03:00:00Z',
          'finished_at': '2026-10-20T03:10:00Z',
          'status': 'verified',
          'restore_verified_at': '2026-10-20T03:09:00Z',
          'expires_at': expired
              ? '2026-10-19T03:10:00Z'
              : '2026-10-27T03:10:00Z',
        },
      ],
      'collection': {
        'status': 'success',
        'checked_at': '2026-10-20T16:30:00Z',
        'truncated': true,
      },
      'errors': [
        {
          'source': 'admin',
          'component': 'sessions',
          'code': 'framework_error',
          'occurred_at': '2026-10-20T16:00:00Z',
        },
        {
          'source': 'postgres_logs',
          'component': 'database',
          'code': '23514',
          'occurred_at': '2026-10-20T16:00:00Z',
        },
      ],
    };
  }
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  test('el informador limita reintentos, normaliza contexto y nunca propaga su fallo', () async {
    var clock = DateTime(2026, 10, 20);
    final sent = <(String, String)>[];
    final reporter = AdminErrorReporter(
      send: (code, component) async {
        sent.add((code, component));
        throw StateError('server secret');
      },
      clock: () => clock,
    );
    await reporter.report('framework_error', 'private@example.com');
    await reporter.report('framework_error', 'admin');
    await reporter.report('password=secret', 'admin');
    expect(sent, [('framework_error', 'admin')]);
    clock = clock.add(const Duration(minutes: 2));
    await reporter.report('framework_error', 'sessions');
    reporter.dispose();
    await reporter.report('framework_error', 'operations');
    expect(sent, [
      ('framework_error', 'admin'),
      ('framework_error', 'sessions'),
    ]);
  });
  test('conserva el manejador de Flutter y registra solo el código', () async {
    final original = FlutterError.onError;
    final previous = <FlutterErrorDetails>[];
    final sent = <(String, String)>[];
    FlutterError.onError = previous.add;
    final reporter = AdminErrorReporter(
      send: (a, b) async {
        sent.add((a, b));
      },
    );
    addTearDown(() {
      reporter.dispose();
      FlutterError.onError = original;
    });
    reporter.attach(() => 'sessions');
    final details = FlutterErrorDetails(
      exception: StateError('password=private'),
    );
    FlutterError.onError!(details);
    await Future<void>.delayed(Duration.zero);
    expect(previous, [details]);
    expect(sent, [('framework_error', 'sessions')]);
    reporter.dispose();
    FlutterError.onError!(details);
    expect(previous, hasLength(2));
    expect(sent, hasLength(1));
  });
  for (final (width, scale) in [(1100.0, 1.0), (320.0, 2.0)]) {
    testWidgets('evidencias de copia y errores a $width/$scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Recovery();
      final opened = <String>[];
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  AdminRecoveryPanel(repository: repo, openUrl: opened.add),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Copia cifrada disponible · datos restaurados en ensayo aislado',
        ),
        findsOneWidget,
      );
      final link = find.text('Ver ejecución y paquete cifrado');
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(opened, [
        'https://github.com/jchjdev/entrenaop/actions/runs/12345',
      ]);
      final admin = find.widgetWithText(ChoiceChip, 'Admin');
      await tester.scrollUntilVisible(
        admin,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      await tester.ensureVisible(admin);
      await tester.pumpAndSettle();
      await tester.tap(admin);
      await tester.pumpAndSettle();
      expect(find.textContaining('framework_error'), findsOneWidget);
      expect(find.textContaining('23514'), findsNothing);
      await capturePerformanceWidget(
        tester,
        'admin-recovery-${width.toInt()}-${scale.toInt()}',
      );
      expect(tester.takeException(), isNull);
      repo.expired = true;
      final refresh = find.text('Actualizar copias y errores');
      await tester.ensureVisible(refresh);
      await tester.pumpAndSettle();
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      final expired = find.text('La copia registrada ha caducado');
      await tester.scrollUntilVisible(
        expired,
        -250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      expect(expired, findsOneWidget);
      expect(
        find.text(
          'Copia cifrada disponible · datos restaurados en ensayo aislado',
        ),
        findsNothing,
      );
    });
  }
}
