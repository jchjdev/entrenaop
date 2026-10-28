import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_invitation_link.dart';
import 'package:entrenaop/features/trainers/presentation/trainer_invitation_entry.dart';
import 'package:entrenaop/features/trainers/presentation/trainer_invitation_page.dart';

import '../../../packages/trainer_access/test_support/fake_trainer_repository.dart';

class WaitingRepository extends FakeTrainerRepository {
  Completer<void>? acceptPending;
  @override
  Future<void> accept(String secret) async {
    accepts++;
    await acceptPending?.future;
  }
}

void main() {
  final a = List.filled(64, 'a').join(), b = List.filled(64, 'b').join();
  testWidgets(
    'abrir y previsualizar nunca acepta; requiere acción explícita y limpia solo esa intención',
    (tester) async {
      final entry = TrainerInvitationEntry()
        ..receive(TrainerInvitationLink.openApp(a));
      addTearDown(entry.dispose);
      final repo = WaitingRepository();
      final router = GoRouter(
        initialLocation: '/invite',
        routes: [
          GoRoute(
            path: '/invite',
            builder: (_, _) => TrainerInvitationPage(
              entry: entry,
              repository: repo,
              email: 'alumno@example.invalid',
              signOut: () async {},
            ),
          ),
          GoRoute(
            path: '/my-trainer',
            builder: (_, _) => const Scaffold(body: Text('Mi preparador')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(repo.previews, 1);
      expect(repo.accepts, 0);
      expect(find.textContaining('alumno@example.invalid'), findsOneWidget);
      await tester.tap(find.text('Aceptar preparador'));
      await tester.pumpAndSettle();
      expect(repo.accepts, 1);
      expect(entry.pending, false);
      expect(entry.secret, isNull);
      expect(find.text('Mi preparador'), findsOneWidget);
    },
  );
  testWidgets(
    'un error o cambiar de cuenta conserva el enlace y no permite aceptar a ciegas',
    (tester) async {
      final entry = TrainerInvitationEntry()
        ..receive(TrainerInvitationLink.openApp(a));
      addTearDown(entry.dispose);
      final repo = WaitingRepository()
        ..previewError = StateError('No autorizada');
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerInvitationPage(
            entry: entry,
            repository: repo,
            email: 'otra@example.invalid',
            signOut: () async {
              exits++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aceptar preparador'), findsNothing);
      expect(repo.accepts, 0);
      await tester.ensureVisible(find.text('Entrar con otra cuenta'));
      await tester.tap(find.text('Entrar con otra cuenta'));
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(entry.secret, a);
      expect(entry.pending, true);
    },
  );
  testWidgets(
    'otra invitación recibida durante la aceptación no queda borrada por una respuesta tardía',
    (tester) async {
      final entry = TrainerInvitationEntry()
        ..receive(TrainerInvitationLink.openApp(a));
      addTearDown(entry.dispose);
      final repo = WaitingRepository()..acceptPending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerInvitationPage(
            entry: entry,
            repository: repo,
            email: 'alumno@example.invalid',
            signOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar preparador'));
      await tester.pump();
      entry.receive(TrainerInvitationLink.openApp(b));
      await tester.pumpAndSettle();
      repo.acceptPending!.complete();
      await tester.pumpAndSettle();
      expect(entry.pending, true);
      expect(entry.secret, b);
      expect(repo.accepts, 1);
    },
  );
}
