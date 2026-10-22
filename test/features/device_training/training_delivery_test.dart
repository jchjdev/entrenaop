import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/device_training/domain/training_delivery.dart';
import 'package:entrenaop/features/device_training/data/supabase_training_delivery_repository.dart';
import 'package:entrenaop/features/device_training/presentation/training_delivery_cubit.dart';
import 'package:entrenaop/features/device_training/presentation/training_delivery_page.dart';

const candidate = TrainingCandidate(
  'scheduled',
  'Carrera del entrenador',
  '2026-10-27',
  'coach',
);
final examplePreview = TrainingPreview(
  'a' * 64,
  candidate.name,
  candidate.date,
  const [
    TrainingStep('run', 'meters', 1000, 'Trabajo', 300, 360),
    TrainingStep('walk', 'seconds', 30, 'Recuperación andando', null, null),
  ],
);
TrainingReceipt receipt(String status) => TrainingReceipt(
  'delivery',
  candidate.id,
  status,
  candidate.name,
  candidate.date,
  null,
);

class FakeTraining implements TrainingDeliveryRepository {
  int sends = 0;
  String? revision;
  Future<TrainingPreview> Function()? onPreview;
  Future<TrainingReceipt> Function()? onSend;
  @override
  Future<TrainingCatalog> load() async =>
      const TrainingCatalog([candidate], []);
  @override
  Future<TrainingPreview> preview(String id) async =>
      onPreview == null ? previewValue : await onPreview!();
  TrainingPreview get previewValue => examplePreview;
  @override
  Future<TrainingReceipt> send(String id, String value) async {
    sends++;
    revision = value;
    return onSend == null ? receipt('sent') : await onSend!();
  }
}

class FakeSyncTraining extends FakeTraining implements TrainingSyncRepository {
  bool enabled = false;
  bool reject = false;
  @override
  Future<TrainingSyncSettings> syncSettings({bool? enabled}) async {
    if (reject) throw const TrainingDeliveryException('access_required');
    this.enabled = enabled ?? this.enabled;
    return TrainingSyncSettings(this.enabled, 2, 1);
  }
}

void main() {
  testWidgets(
    'activar y desactivar el envío guarda la preferencia por cuenta',
    (tester) async {
      final repository = FakeSyncTraining();
      await tester.pumpWidget(
        MaterialApp(home: TrainingDeliveryPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(repository.enabled, true);
      expect(find.text('2 pendientes · 1 requieren revisión'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(repository.enabled, false);
      expect(repository.sends, 0);
    },
  );

  testWidgets('un rechazo del servidor no simula la activación automática', (
    tester,
  ) async {
    final repository = FakeSyncTraining();
    await tester.pumpWidget(
      MaterialApp(home: TrainingDeliveryPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    repository.reject = true;
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    expect(
      find.text('Necesitas Pro vigente o tu servicio de entrenador activo.'),
      findsOneWidget,
    );
  });
  test(
    'respuesta HTTP antigua se descarta si cambia la cuenta en vuelo',
    () async {
      const first = '10000000-0000-4000-8000-000000000001';
      const second = '10000000-0000-4000-8000-000000000002';
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          if (request.url.path.contains('/functions/')) {
            started.complete();
            return pending.future;
          }
          return Future.value(http.Response('{}', 200));
        }),
      );
      String savedSession(String owner) {
        final expires =
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = base64Url.encode(
          utf8.encode(
            jsonEncode({
              'sub': owner,
              'exp': expires,
              'session_id': '20000000-0000-4000-8000-000000000001',
            }),
          ),
        );
        return jsonEncode({
          'access_token': 'e30.$payload.fixture',
          'refresh_token': 'fixture',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-10-22T00:00:00Z',
          },
        });
      }

      await client.auth.recoverSession(savedSession(first));
      final repository = SupabaseTrainingDeliveryRepository(client, first);
      final request = repository.load();
      final assertion = expectLater(
        request,
        throwsA(
          isA<TrainingDeliveryException>().having(
            (e) => e.code,
            'code',
            'account_changed',
          ),
        ),
      );
      await started.future;
      await client.auth.recoverSession(savedSession(second));
      pending.complete(
        http.Response(
          '{"candidates":[],"deliveries":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await assertion;
      await client.dispose();
    },
  );
  test(
    'doble envío en curso usa una sola petición y la revisión mostrada',
    () async {
      final repository = FakeTraining(), pending = Completer<TrainingReceipt>();
      repository.onSend = () => pending.future;
      final cubit = TrainingDeliveryCubit(repository);
      await cubit.load();
      await cubit.select(candidate);
      final first = cubit.send();
      await cubit.send();
      expect(repository.sends, 1);
      expect(repository.revision, examplePreview.revision);
      pending.complete(receipt('sent'));
      await first;
      expect(cubit.state.receipt?.status, 'sent');
      await cubit.close();
    },
  );
  test(
    'respuesta tardía de otra pantalla no publica una vista previa',
    () async {
      final repository = FakeTraining(), pending = Completer<TrainingPreview>();
      repository.onPreview = () => pending.future;
      final cubit = TrainingDeliveryCubit(repository);
      await cubit.load();
      final request = cubit.select(candidate);
      await cubit.close();
      pending.complete(examplePreview);
      await request;
      expect(cubit.state.preview, isNull);
    },
  );
  test('cambio de cuenta no se convierte en recibo de éxito', () async {
    final repository = FakeTraining()
      ..onSend = () async =>
          throw const TrainingDeliveryException('account_changed');
    final cubit = TrainingDeliveryCubit(repository);
    await cubit.load();
    await cubit.select(candidate);
    await cubit.send();
    expect(cubit.state.error, 'account_changed');
    expect(cubit.state.receipt, isNull);
    await cubit.close();
  });
  test(
    'versión obsoleta requiere otra vista previa y no inventa resultado',
    () async {
      final repository = FakeTraining()
        ..onSend = () async =>
            throw const TrainingDeliveryException('stale_prescription');
      final cubit = TrainingDeliveryCubit(repository);
      await cubit.load();
      await cubit.select(candidate);
      await cubit.send();
      expect(cubit.state.error, 'stale_prescription');
      expect(cubit.state.receipt, isNull);
      await cubit.load();
      expect(cubit.state.preview, isNull);
      await cubit.close();
    },
  );
  test(
    'codec rechaza pasos imposibles, ritmo invertido y estados desconocidos',
    () {
      Map<String, dynamic> data() => {
        'revision': 'a' * 64,
        'prescription': {
          'name': 'Carrera',
          'date': candidate.date,
          'steps': [
            {
              'kind': 'run',
              'measure': 'meters',
              'value': 1000,
              'description': 'Trabajo',
              'pace': {'fast': 300, 'slow': 360},
            },
          ],
        },
      };
      expect(decodeTrainingPreview(data()).steps.single.slow, 360);
      final invalid = data();
      (invalid['prescription']['steps'] as List).first['value'] = double.nan;
      expect(() => decodeTrainingPreview(invalid), throwsFormatException);
      final inverted = data();
      inverted['prescription']['steps'][0]['pace']['slow'] = 200;
      expect(() => decodeTrainingPreview(inverted), throwsFormatException);
      expect(
        () => decodeTrainingReceipt({'status': 'on_watch'}),
        throwsFormatException,
      );
    },
  );
  testWidgets('exige revisar fecha y pasos y no confunde Garmin con el reloj', (
    tester,
  ) async {
    final repository = FakeTraining();
    await tester.pumpWidget(
      MaterialApp(home: TrainingDeliveryPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(candidate.name));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar a Garmin'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enviar a Garmin'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Enviar a Garmin'));
    await tester.pumpAndSettle();
    expect(repository.sends, 1);
    expect(
      find.textContaining('Enviada y confirmada en el calendario de Garmin'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enviar a Garmin'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('un envío incierto se muestra sin éxito y bloquea repetirlo', (
    tester,
  ) async {
    final repository = FakeTraining()
      ..onSend = () async => receipt('uncertain');
    await tester.pumpWidget(
      MaterialApp(home: TrainingDeliveryPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(candidate.name));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar a Garmin'));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Enviar a Garmin'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Envío sin confirmar'), findsOneWidget);
    expect(find.textContaining('Enviada y confirmada'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enviar a Garmin'),
          )
          .onPressed,
      isNull,
    );
  });
}
