import 'dart:async';

import 'package:entrenaop/features/device_connections/data/supabase_garmin_connection_repository.dart';
import 'package:entrenaop/features/device_connections/domain/garmin_connection.dart';
import 'package:entrenaop/features/device_connections/presentation/garmin_connection_cubit.dart';
import 'package:entrenaop/features/device_connections/presentation/garmin_connection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GarminConnectionSnapshot snapshot({
  bool allowed = true,
  GarminConnectionStatus status = GarminConnectionStatus.disconnected,
}) => GarminConnectionSnapshot(
  status: status,
  allowed: allowed,
  generation: 7,
  canRead: true,
  canSend: false,
);

class FakeGarmin implements GarminConnectionRepository {
  GarminConnectionSnapshot current = snapshot();
  Future<GarminConnectionSnapshot> Function()? onLoad;
  Future<GarminAuthorization> Function()? onBegin;
  int begins = 0, disconnects = 0;
  int? disconnectedGeneration;
  @override
  Future<GarminConnectionSnapshot> load() async =>
      onLoad == null ? current : await onLoad!();
  @override
  Future<GarminAuthorization> begin() async {
    begins++;
    return onBegin == null
        ? GarminAuthorization(
            snapshot(status: GarminConnectionStatus.authorizing),
            Uri.parse('https://connect.garmin.com/oauth2Confirm'),
          )
        : await onBegin!();
  }

  @override
  Future<GarminConnectionSnapshot> disconnect(int generation) async {
    disconnects++;
    disconnectedGeneration = generation;
    return current = snapshot(allowed: current.allowed);
  }
}

void main() {
  test('Free puede consultar estado pero no inicia conexión directa', () async {
    final repository = FakeGarmin()..current = snapshot(allowed: false);
    final cubit = GarminConnectionCubit(repository);
    await cubit.load();
    await cubit.begin();
    expect(repository.begins, 0);
    expect(cubit.state.snapshot?.allowed, false);
    await cubit.close();
  });

  test('perder Pro no impide desconectar una cuenta ya conectada', () async {
    final repository = FakeGarmin()
      ..current = snapshot(
        allowed: false,
        status: GarminConnectionStatus.connected,
      );
    final cubit = GarminConnectionCubit(repository);
    await cubit.load();
    await cubit.disconnect();
    expect(repository.disconnects, 1);
    expect(repository.disconnectedGeneration, 7);
    expect(cubit.state.snapshot?.status, GarminConnectionStatus.disconnected);
    await cubit.close();
  });

  test('dos pulsaciones simultáneas no crean dos autorizaciones', () async {
    final pending = Completer<GarminAuthorization>();
    final repository = FakeGarmin()..onBegin = () => pending.future;
    final cubit = GarminConnectionCubit(repository);
    await cubit.load();
    final first = cubit.begin();
    await cubit.begin();
    expect(repository.begins, 1);
    pending.complete(
      GarminAuthorization(
        snapshot(status: GarminConnectionStatus.authorizing),
        Uri.parse('https://connect.garmin.com/oauth2Confirm'),
      ),
    );
    await first;
    expect(cubit.state.snapshot?.status, GarminConnectionStatus.authorizing);
    await cubit.close();
  });

  test('un cambio de cuenta descarta la instantánea anterior', () async {
    final repository = FakeGarmin();
    final cubit = GarminConnectionCubit(repository);
    await cubit.load();
    repository.onLoad = () async => throw const GarminConnectionException(
      GarminConnectionProblem.accountChanged,
    );
    await cubit.load();
    expect(cubit.state.snapshot, isNull);
    expect(cubit.state.problem, GarminConnectionProblem.accountChanged);
    await cubit.close();
  });

  test('cerrar pantalla descarta una respuesta tardía', () async {
    final pending = Completer<GarminConnectionSnapshot>();
    final repository = FakeGarmin()..onLoad = () => pending.future;
    final cubit = GarminConnectionCubit(repository);
    final load = cubit.load();
    await cubit.close();
    pending.complete(snapshot(status: GarminConnectionStatus.connected));
    await load;
    expect(cubit.state.snapshot, isNull);
  });

  test(
    'un error de red conserva el último estado para reconsultarlo',
    () async {
      final repository = FakeGarmin()
        ..current = snapshot(status: GarminConnectionStatus.connected);
      final cubit = GarminConnectionCubit(repository);
      await cubit.load();
      repository.onLoad = () async => throw Exception('fixture');
      await cubit.load();
      expect(cubit.state.snapshot?.status, GarminConnectionStatus.connected);
      expect(cubit.state.problem, GarminConnectionProblem.unavailable);
      await cubit.close();
    },
  );

  test(
    'el codec rechaza estado desconocido y datos comerciales incompletos',
    () {
      final json = <String, dynamic>{
        'status': 'connected',
        'allowed': true,
        'generation': 1,
        'can_read': true,
        'can_send': false,
      };
      expect(decodeGarminSnapshot(json).canSend, false);
      expect(
        () => decodeGarminSnapshot({...json, 'status': 'invented'}),
        throwsA(isA<GarminConnectionException>()),
      );
      expect(
        () => decodeGarminSnapshot({...json, 'generation': -1}),
        throwsA(isA<GarminConnectionException>()),
      );
      expect(
        () => decodeGarminSnapshot({...json}..remove('allowed')),
        throwsA(isA<GarminConnectionException>()),
      );
    },
  );

  testWidgets(
    'la pantalla muestra acceso incluido y no abre Garmin para Free',
    (tester) async {
      final repository = FakeGarmin()..current = snapshot(allowed: false);
      int opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GarminConnectionPage(
            repository: repository,
            openAuthorization: (_) async {
              opens++;
              return true;
            },
            onOpenPro: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conectar Garmin'), findsNothing);
      expect(find.text('Ver Pro'), findsOneWidget);
      expect(opens, 0);
    },
  );

  testWidgets(
    'conectar abre autorización; desconectar requiere acción explícita',
    (tester) async {
      final repository = FakeGarmin();
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: GarminConnectionPage(
            repository: repository,
            openAuthorization: (uri) async {
              opened = uri;
              return true;
            },
            onOpenPro: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conectar Garmin'));
      await tester.pumpAndSettle();
      expect(opened?.host, 'connect.garmin.com');
      expect(find.text('Autorización pendiente'), findsOneWidget);
      await tester.tap(find.text('Cancelar conexión'));
      await tester.pumpAndSettle();
      expect(repository.disconnects, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Desconectar'));
      await tester.pumpAndSettle();
      expect(repository.disconnects, 1);
      expect(find.text('Sin conexión'), findsOneWidget);
    },
  );

  testWidgets('revocación fallida se presenta pendiente y permite reintentar', (
    tester,
  ) async {
    final repository = FakeGarmin()
      ..current = snapshot(
        allowed: false,
        status: GarminConnectionStatus.revocationPending,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: GarminConnectionPage(
          repository: repository,
          openAuthorization: (_) async => true,
          onOpenPro: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Conexión detenida. Revocación en Garmin pendiente de confirmar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar desconexión'), findsOneWidget);
    expect(find.text('Cuenta conectada'), findsNothing);
  });
}
