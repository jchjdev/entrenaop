import 'package:entrena_ui/media_cleanup_controls.dart';
import 'package:entrenaop_trainer/main.dart';
import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_exercise_repository.dart';
import 'package:entrenaop_trainer/trainer_security_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_account_pages_test.dart' show AccountFixture;
import 'trainer_exercise_flow_test.dart' show ExerciseFixture;
import 'trainer_media_cleanup_repository_test.dart' show CleanupServer;

import 'package:entrenaop_trainer/trainer_media_page.dart';

import 'trainer_media_pages_test.dart' show MediaFixture;

class _RouterServer extends CleanupServer {
  bool assured = false;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path.endsWith('get_trainer_security_status')) {
      return super.json(request, assured);
    }
    return super.handle(request);
  }
}

class _Images extends ExerciseFixture {
  int images = 2;
  @override
  Future<TrainerExerciseUsage> usage() async => TrainerExerciseUsage.fromJson({
    'exercise_used': 500,
    'exercise_limit': 500,
    'image_used': images,
    'image_limit': 1000,
  });
}

void main() {
  testWidgets(
    'biblioteca permite borrar solo demostraciones y pasa asset ID sin URL',
    (tester) async {
      final media = MediaFixture();
      media.media.add({
        ...media.media.single,
        'id': 'technique',
        'scope': 'client_technique',
      });
      MediaCleanupVideoTarget? target;
      final router = GoRouter(
        initialLocation: '/media',
        routes: [
          GoRoute(
            path: '/media',
            builder: (_, _) =>
                TrainerMediaPage(repository: media, cleanupOwnerKey: 'owner'),
          ),
          GoRoute(
            path: '/media/cleanup',
            builder: (_, state) {
              target = state.extra as MediaCleanupVideoTarget?;
              return const Scaffold(body: Text('Confirmar demostración'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar demostración'), findsOneWidget);
      await tester.ensureVisible(find.text('Eliminar demostración'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar demostración'));
      await tester.pumpAndSettle();
      expect(target!.id, 'demo');
      expect(target!.ownerKey, 'owner');
      expect(router.state.uri.queryParameters, isEmpty);
    },
  );

  testWidgets('cupo completo permite limpiar y actualiza imágenes al volver', (
    tester,
  ) async {
    final repository = _Images();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerExercisePage(
          repository: repository,
          access: FakeTrainerRepository(),
          onCleanup: () async {
            repository.images = 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2/1000 imágenes'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Crear ejercicio privado'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Limpiar archivos sin uso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/1000 imágenes'), findsOneWidget);
  });

  for (final assured in [false, true]) {
    testWidgets(
      'mantenimiento en router real requiere MFA $assured y no otra compra',
      (tester) async {
        final server = _RouterServer()..assured = assured;
        await tester.runAsync(server.login);
        addTearDown(() => tester.runAsync(server.client.dispose));
        await tester.pumpWidget(
          TrainerApp(
            client: server.client,
            accounts: AccountFixture()
              ..professional = true
              ..enabled = false,
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.go('/media/cleanup');
        // La codificación de Functions usa un isolate real; se deja resolver
        // entre el redirect del router y el montaje de la nueva pantalla.
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
        }
        await tester.pumpAndSettle();
        if (assured) {
          expect(find.byType(MediaCleanupView), findsOneWidget);
          expect(server.cleanupCalls, hasLength(1));
        } else {
          expect(find.byType(TrainerSecurityPage), findsOneWidget);
          expect(server.cleanupCalls, isEmpty);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
