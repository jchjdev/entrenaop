import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

void main() {
  Future<void> press(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty &&
        {
          'Desactivar servicio',
          'Archivar cliente',
          'Recuperar cliente',
          'Historial del vínculo',
        }.contains(label)) {
      final menus = find.byIcon(Icons.more_vert);
      await tester.scrollUntilVisible(menus, 250);
      await tester.pumpAndSettle();
      await tester.tap(menus.last);
      await tester.pumpAndSettle();
    }
    final target = find.text(label).last;
    if (target.evaluate().isEmpty) await tester.scrollUntilVisible(target, 250);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'acceso desde contacto abre la invitación existente sin crear ni vincular al entrar',
    (tester) async {
      final repo = FakeTrainerRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerClientsPage(repository: repo, inviteOnOpen: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Correo del alumno'), findsOneWidget);
      expect(repo.drafts, isEmpty);
      expect(repo.accepts, 0);
      await tester.enterText(find.byType(TextFormField), 'alumna@example.test');
      await tester.tap(find.text('Crear enlace'));
      await tester.pumpAndSettle();
      expect(repo.drafts.single.recipientEmail, 'alumna@example.test');
      expect(repo.accepts, 0);
    },
  );

  testWidgets('el acceso desde contacto respeta el cupo completo', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..current = TrainerAccess.fromJson({
        'trainer_id': 'trainer-a',
        'effective': true,
        'enabled': true,
        'client_limit': 1,
        'active_clients': 1,
        'revision': 1,
      });
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerClientsPage(repository: repo, inviteOnOpen: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Correo del alumno'), findsNothing);
    expect(find.textContaining('Tu cupo está completo.'), findsOneWidget);
    expect(repo.drafts, isEmpty);
    expect(repo.accepts, 0);
  });

  testWidgets('la baja conserva la ficha inactiva y sus etapas', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..active = [trainerRelation('Alumno conservado')];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'Desactivar servicio');
    await press(tester, 'Desactivar servicio');
    expect(repo.ends, 1);
    expect(repo.active, isEmpty);
    expect(repo.history, hasLength(1));
    await press(tester, 'Inactivos');
    expect(find.text('Alumno conservado'), findsOneWidget);
    expect(find.text('1 etapa de seguimiento'), findsOneWidget);
    await press(tester, 'Historial del vínculo');
    expect(
      find.text('Historial del vínculo · Alumno conservado'),
      findsOneWidget,
    );
    expect(find.text('1/10/2026 → 2/10/2026'), findsOneWidget);
  });

  testWidgets('archivar y recuperar no borra ni reactiva al alumno', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..history = [trainerRelation('Alumno inactivo', ended: true)];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'Inactivos');
    await press(tester, 'Archivar cliente');
    await press(tester, 'Archivar cliente');
    expect(repo.archivedClients, contains('person-a'));
    expect(repo.history, hasLength(1));
    expect(find.text('Alumno inactivo'), findsNothing);
    await press(tester, 'Archivados');
    expect(find.text('Alumno inactivo'), findsOneWidget);
    await press(tester, 'Recuperar cliente');
    await press(tester, 'Recuperar cliente');
    expect(repo.archivedClients, isEmpty);
    expect(repo.active, isEmpty);
    expect(repo.ends, 0);
    await press(tester, 'Inactivos');
    expect(find.text('Alumno inactivo'), findsOneWidget);
  });

  testWidgets('reintentar una creación incierta conserva identidad y secreto', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()..createError = StateError('network');
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Invitar alumno'));
    await tester.tap(find.text('Invitar alumno'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'alumno@example.invalid',
    );
    await tester.tap(find.text('Crear enlace'));
    await tester.pumpAndSettle();
    expect(repo.drafts, hasLength(1));
    expect(repo.drafts.single.recipientEmail, 'alumno@example.invalid');
    repo.createError = null;
    await tester.ensureVisible(find.text('Reintentar invitación'));
    await tester.tap(find.text('Reintentar invitación'));
    await tester.pumpAndSettle();
    expect(repo.drafts, hasLength(2));
    expect(identical(repo.drafts[0], repo.drafts[1]), isTrue);
    await tester.ensureVisible(find.text('Código de respaldo'));
    await tester.tap(find.text('Código de respaldo'));
    await tester.pumpAndSettle();
    expect(find.text(repo.drafts[0].secret), findsOneWidget);
  });
  testWidgets('cuota completa no permite crear pero conserva consulta', (
    tester,
  ) async {
    final repo = FakeTrainerRepository();
    repo.active = [trainerRelation('Alumno A')];
    // Snapshot autorizado del servidor, independiente del listado paginado.
    repo.current = accessFixture(full: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cupo completo'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Invitar alumno'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Alumno A'), findsOneWidget);
  });
  for (final size in [320.0, 1100.0]) {
    testWidgets('clientes y acciones se adaptan a $size con texto grande', (
      tester,
    ) async {
      tester.view.physicalSize = Size(size, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeTrainerRepository()
        ..active = [
          trainerRelation(
            'Alumno con nombre y apellidos especialmente largos para comprobar la lectura',
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TrainerClientsPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await press(tester, 'Desactivar servicio');
      await press(tester, 'Volver');
      expect(repo.ends, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pulsar la tarjeta abre la ficha y gestionar no dispara la navegación',
    (tester) async {
      final repo = FakeTrainerRepository()
        ..active = [trainerRelation('Alumno de prueba')];
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerClientsPage(repository: repo, onOpenClient: opened.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Alumno de prueba'));
      await tester.tap(find.text('Alumno de prueba'));
      await tester.pumpAndSettle();
      expect(opened, ['person-a']);
      await press(tester, 'Desactivar servicio');
      expect(opened, ['person-a']);
      expect(repo.ends, 0);
      await press(tester, 'Volver');
      expect(repo.ends, 0);
    },
  );

  testWidgets(
    'separación de pendientes e historial conserva las fechas de aceptación',
    (tester) async {
      final repo = FakeTrainerRepository()
        ..invites = [
          TrainerInvitation.fromJson({
            'id': 'pending-invitation',
            'created_at': '2026-10-21T10:00:00Z',
            'expires_at': DateTime.now()
                .add(const Duration(days: 7))
                .toIso8601String(),
          }),
          TrainerInvitation.fromJson({
            'id': 'accepted-invitation',
            'created_at': '2026-10-21T10:00:00Z',
            'expires_at': '2026-10-29T10:00:00Z',
            'accepted_at': '2026-10-22T10:00:00Z',
          }),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerClientsPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Invitación pendiente'), 300);
      expect(find.text('Referencia pending-'), findsOneWidget);
      expect(find.text('Referencia accepted'), findsNothing);
      await press(tester, 'Historial de invitaciones');
      expect(find.text('Aceptada el 22/10/2026'), findsOneWidget);
      final acceptedCard = find
          .ancestor(
            of: find.text('Referencia accepted'),
            matching: find.byType(Card),
          )
          .first;
      expect(
        find.descendant(
          of: acceptedCard,
          matching: find.textContaining('Caduca'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'elegir alumno para técnica no consulta invitaciones ni permite gestionar el servicio',
    (tester) async {
      final repo = TechniqueClientsFixture()
        ..active = [trainerRelation('Alumno con técnica')];
      final chosen = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerClientsPage(
            repository: repo,
            techniqueMode: true,
            onOpenTechnique: chosen.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.invitationReads, 0);
      expect(find.text('Invitar alumno'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      await tester.ensureVisible(find.text('Alumno con técnica'));
      await tester.tap(find.text('Alumno con técnica'));
      expect(chosen, ['person-a']);
      expect(repo.ends, 0);
    },
  );
}

class TechniqueClientsFixture extends FakeTrainerRepository {
  int invitationReads = 0;
  @override
  Future<List<TrainerInvitation>> invitations({
    TrainerInvitation? before,
  }) async {
    invitationReads++;
    return super.invitations(before: before);
  }
}

TrainerAccess accessFixture({bool full = false}) => TrainerAccess.fromJson({
  'trainer_id': 'trainer-a',
  'enabled': true,
  'effective': true,
  'client_limit': 3,
  'active_clients': full ? 3 : 0,
  'revision': 1,
});
