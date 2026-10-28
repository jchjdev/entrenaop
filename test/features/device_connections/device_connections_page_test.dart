import 'dart:async';

import 'package:device_health/device_health.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/device_connections/domain/garmin_connection.dart';
import 'package:entrenaop/features/device_connections/presentation/device_connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GarminConnectionSnapshot _snapshot({
  bool connected = false,
  bool allowed = true,
}) => GarminConnectionSnapshot(
  status: connected
      ? GarminConnectionStatus.connected
      : GarminConnectionStatus.disconnected,
  allowed: allowed,
  generation: 1,
  canRead: connected,
  canSend: connected,
);

class _Garmin extends Fake implements GarminConnectionRepository {
  GarminConnectionSnapshot current = _snapshot();
  Future<GarminConnectionSnapshot> Function()? loader;
  int loads = 0, writes = 0;
  @override
  Future<GarminConnectionSnapshot> load() {
    loads++;
    return loader?.call() ?? Future.value(current);
  }

  @override
  Future<GarminAuthorization> begin() async {
    writes++;
    throw StateError('No autorizar desde el resumen');
  }

  @override
  Future<GarminConnectionSnapshot> disconnect(int generation) async {
    writes++;
    throw StateError('No retirar permisos desde el resumen');
  }
}

class _Health extends Fake implements LocalRunningHealth {
  _Health({this.value = HealthStoreAvailability.available});
  final HealthStoreAvailability value;
  int reads = 0, permissions = 0;
  @override
  LocalHealthPlatform get platform => LocalHealthPlatform.appleHealth;
  @override
  Future<HealthStoreAvailability> availability() async => value;
  @override
  Future<HealthReadConsent> requestReadAccess() async {
    permissions++;
    return HealthReadConsent.queryAllowedUnknown;
  }

  @override
  Future<LocalHealthRead> read({
    required HealthReadWindow window,
    required String localSessionScope,
  }) async {
    reads++;
    return LocalHealthRead(
      activities: const [],
      rejectedRecords: 0,
      truncated: false,
    );
  }
}

Widget _page(
  _Health health,
  _Garmin garmin, {
  String owner = 'owner-a',
  double scale = 1,
  Future<void> Function()? onHealth,
  Future<void> Function()? onGarmin,
}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: DeviceConnectionsPage(
    ownerId: owner,
    health: health,
    garmin: garmin,
    onOpenHealth: onHealth ?? () async {},
    onOpenGarmin: onGarmin ?? () async {},
  ),
);

void main() {
  testWidgets('el resumen no pide permisos ni autoriza Garmin al abrirse', (
    tester,
  ) async {
    final health = _Health();
    final garmin = _Garmin();
    await tester.pumpWidget(_page(health, garmin));
    await tester.pumpAndSettle();
    expect(find.text('Lectura disponible'), findsOneWidget);
    expect(find.text('Sin conectar'), findsOneWidget);
    expect(health.permissions, 0);
    expect(health.reads, 0);
    expect(garmin.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volver de gestionar Garmin vuelve a consultar el estado', (
    tester,
  ) async {
    final health = _Health();
    final garmin = _Garmin();
    await tester.pumpWidget(
      _page(
        health,
        garmin,
        onGarmin: () async {
          garmin.current = _snapshot(connected: true);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gestionar Garmin'));
    await tester.tap(find.text('Gestionar Garmin'));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta conectada'), findsOneWidget);
    expect(garmin.loads, 2);
    expect(garmin.writes, 0);
  });

  testWidgets('un error no presenta Garmin como desconectado ni oculta Salud', (
    tester,
  ) async {
    final health = _Health();
    final garmin = _Garmin()
      ..loader = () async => throw StateError('Sin respuesta');
    await tester.pumpWidget(_page(health, garmin));
    await tester.pumpAndSettle();
    expect(find.text('Estado sin confirmar'), findsOneWidget);
    expect(find.text('Sin conectar'), findsNothing);
    expect(find.text('Lectura disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'una cuenta sin derecho conserva acceso a gestionar y desconectar',
    (tester) async {
      final health = _Health();
      final garmin = _Garmin()
        ..current = _snapshot(connected: true, allowed: false);
      var opened = 0;
      await tester.pumpWidget(
        _page(
          health,
          garmin,
          onGarmin: () async {
            opened++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sincronización no disponible'), findsOneWidget);
      await tester.ensureVisible(find.text('Gestionar Garmin'));
      await tester.tap(find.text('Gestionar Garmin'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(garmin.writes, 0);
    },
  );

  testWidgets('una respuesta tardía no muestra el estado de otra cuenta', (
    tester,
  ) async {
    final pending = Completer<GarminConnectionSnapshot>();
    final health = _Health();
    final first = _Garmin()..loader = () => pending.future;
    await tester.pumpWidget(_page(health, first));
    await tester.pump();
    final second = _Garmin();
    await tester.pumpWidget(_page(health, second, owner: 'owner-b'));
    await tester.pumpAndSettle();
    pending.complete(_snapshot(connected: true));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta conectada'), findsNothing);
    expect(find.text('Sin conectar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'texto grande y pantalla estrecha mantienen los accesos utilizables',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final health = _Health(value: HealthStoreAvailability.unsupported);
      final garmin = _Garmin();
      await tester.pumpWidget(_page(health, garmin, scale: 1.5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Gestionar Garmin'), 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Lectura desde el móvil'), findsOneWidget);
    },
  );
}
