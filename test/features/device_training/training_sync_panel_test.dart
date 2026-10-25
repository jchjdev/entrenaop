import 'dart:async';

import 'package:entrenaop/features/device_connections/domain/garmin_connection.dart';
import 'package:entrenaop/features/device_connections/presentation/garmin_connection_page.dart';
import 'package:entrenaop/features/device_training/domain/training_delivery.dart';
import 'package:entrenaop/features/device_training/presentation/training_sync_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SyncFixture implements TrainingSyncRepository {
  final calls = <bool?>[];
  TrainingSyncSettings settings = const TrainingSyncSettings(false, 0, 0);
  Future<TrainingSyncSettings> Function(bool?)? respond;

  @override
  Future<TrainingSyncSettings> syncSettings({bool? enabled}) async {
    calls.add(enabled);
    if (respond != null) return respond!(enabled);
    if (enabled != null) settings = TrainingSyncSettings(enabled, 0, 0);
    return settings;
  }
}

class ConnectionFixture implements GarminConnectionRepository {
  bool allowed = true;
  bool canSend = true;
  int generation = 7;

  @override
  Future<GarminConnectionSnapshot> load() async => GarminConnectionSnapshot(
    status: GarminConnectionStatus.connected,
    allowed: allowed,
    generation: generation,
    canRead: true,
    canSend: canSend,
  );

  @override
  Future<GarminAuthorization> begin() => throw UnimplementedError();
  @override
  Future<GarminConnectionSnapshot> disconnect(int generation) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
    'el automático aparece al conectar sin entrar en envío manual y no se activa solo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sync = SyncFixture();
      var manualOpens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GarminConnectionPage(
            repository: ConnectionFixture(),
            syncRepository: sync,
            openAuthorization: (_) async => true,
            onOpenPro: () {},
            onOpenTraining: () => manualOpens++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byType(SwitchListTile);
      expect(tester.getRect(toggle).bottom, lessThan(844));
      expect(
        find.text('Desactivada · tus nuevas sesiones no se envían solas.'),
        findsOneWidget,
      );
      expect(sync.calls, [null]);
      expect(manualOpens, 0);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(sync.calls, [null, true]);
      expect(
        find.text('Activada · tus sesiones compatibles se envían a Garmin.'),
        findsOneWidget,
      );
      expect(manualOpens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin permiso o acceso vigente no se consulta ni ofrece activar el automático',
    (tester) async {
      final connection = ConnectionFixture()..canSend = false;
      final sync = SyncFixture();
      Widget page() => MaterialApp(
        home: GarminConnectionPage(
          repository: connection,
          syncRepository: sync,
          openAuthorization: (_) async => true,
          onOpenPro: () {},
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.byType(TrainingSyncPanel), findsNothing);
      expect(sync.calls, isEmpty);
      connection
        ..canSend = true
        ..allowed = false;
      await tester.tap(find.text('Actualizar estado'));
      await tester.pumpAndSettle();
      expect(find.byType(TrainingSyncPanel), findsNothing);
      expect(sync.calls, isEmpty);
    },
  );

  testWidgets(
    'una respuesta perdida no anuncia activación y reconsulta antes de escribir otra vez',
    (tester) async {
      final sync = SyncFixture();
      sync.respond = (enabled) async {
        if (enabled != null) {
          throw const TrainingDeliveryException('garmin_unavailable');
        }
        return sync.calls.length == 1
            ? const TrainingSyncSettings(false, 0, 0)
            : const TrainingSyncSettings(true, 2, 1);
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrainingSyncPanel(repository: sync),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        find.text('Estado del envío automático sin confirmar.'),
        findsOneWidget,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      await tester.tap(find.text('Consultar de nuevo'));
      await tester.pumpAndSettle();
      expect(sync.calls, [null, true, null]);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(find.text('2 pendientes · 1 requieren revisión'), findsOneWidget);
    },
  );

  testWidgets(
    'cambiar generación descarta la respuesta anterior y cabe con texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<TrainingSyncSettings>();
      final old = SyncFixture()..respond = (_) => pending.future;
      final current = SyncFixture();
      Widget page(int generation, SyncFixture repository) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TrainingSyncPanel(
                key: ValueKey(generation),
                repository: repository,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(1, old));
      await tester.pump();
      await tester.pumpWidget(page(2, current));
      await tester.pumpAndSettle();
      pending.complete(const TrainingSyncSettings(true, 0, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(current.calls, [null]);
      expect(tester.takeException(), isNull);
    },
  );
}
