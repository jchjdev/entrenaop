import 'dart:async';

import 'package:entrenaop/features/trainers/presentation/my_trainer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

import '../../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_forms_page_test.dart' show StudentFormsFixture, fixture;
import 'trainer_assessments_page_test.dart' show AssessmentFixture, delivery;

import 'package:workout_core/professional_assessment.dart';

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'otro preparador se invita sin sustituir al actual; compartir es explícito',
    (tester) async {
      final repository = FakeTrainerRepository()
        ..active = [trainerRelation('Javier')];
      final sharing = _SharingFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: MyTrainerPage(repository: repository, calendarSharing: sharing),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Javier'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(sharing.enabled, isTrue);
      expect(sharing.revision, 1);
      expect(repository.ends, 0);
    },
  );
  testWidgets(
    'dos preparadores tienen conversaciones individuales y se respeta el máximo',
    (tester) async {
      final repository = FakeTrainerRepository()
        ..active = [
          trainerRelation('Javier', id: 'fuerza', personId: 'javier'),
          trainerRelation('Ervi', id: 'carrera', personId: 'ervi'),
        ];
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MyTrainerPage(
            repository: repository,
            calendarSharing: _SharingFixture()..count = 2,
            onOpenConversation: opened.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mis preparadores'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final chats = find.text('Conversación con mi preparador');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(chats.at(i));
        await tester.tap(chats.at(i));
        await tester.pump();
      }
      expect(opened, ['fuerza', 'carrera']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pruebas visibles solo con entregas, incluido histórico sin vínculo',
    (tester) async {
      final assessments = _AssessmentPresence();
      await tester.pumpWidget(
        MaterialApp(
          home: MyTrainerPage(
            repository: FakeTrainerRepository(),
            assessments: assessments,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pruebas de mi preparador'), findsNothing);
      assessments.rows = [delivery(status: 'completed', active: false)];
      await press(tester, 'Actualizar');
      expect(find.text('Pruebas de mi preparador'), findsOneWidget);
      expect(
        find.textContaining('Todavía no tienes preparador'),
        findsOneWidget,
      );
      assessments.rows = [];
      await press(tester, 'Actualizar');
      expect(find.text('Pruebas de mi preparador'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sin entregas no aparece sección profesional vacía', (
    tester,
  ) async {
    final forms = _EmptyForms();
    await tester.pumpWidget(
      MaterialApp(
        home: MyTrainerPage(repository: FakeTrainerRepository(), forms: forms),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Formularios de mi preparador'), findsNothing);
    expect(find.textContaining('Todavía no tienes preparador'), findsOneWidget);
  });
  testWidgets(
    'entregas históricas conservan acceso aunque no haya vínculo activo',
    (tester) async {
      final forms = StudentFormsFixture()
        ..row = fixture(submitted: true, active: false);
      await tester.pumpWidget(
        MaterialApp(
          home: MyTrainerPage(
            repository: FakeTrainerRepository(),
            forms: forms,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Formularios de mi preparador'), findsOneWidget);
      expect(
        find.textContaining('Todavía no tienes preparador'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'vista previa no vincula y editar el código invalida el consentimiento',
    (tester) async {
      final repo = FakeTrainerRepository();
      await tester.pumpWidget(
        MaterialApp(home: MyTrainerPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a' * 64);
      await press(tester, 'Ver invitación');
      expect(find.text('Preparador A'), findsOneWidget);
      expect(repo.accepts, 0);
      await tester.enterText(find.byType(TextField), 'b' * 64);
      await tester.pump();
      expect(find.text('Aceptar y vincularme'), findsNothing);
      await press(tester, 'Ver invitación');
      await press(tester, 'Aceptar y vincularme');
      expect(repo.accepts, 1);
      expect(find.text('PREPARADOR ACTIVO'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('rechaza código incompleto sin consultar el servidor', (
    tester,
  ) async {
    final repo = FakeTrainerRepository();
    await tester.pumpWidget(MaterialApp(home: MyTrainerPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await press(tester, 'Ver invitación');
    expect(repo.previews, 0);
    expect(
      find.text('Pega el código completo de 64 caracteres.'),
      findsOneWidget,
    );
  });
  testWidgets('terminar necesita confirmación y conserva el vínculo anterior', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..active = [trainerRelation('Preparador A')];
    await tester.pumpWidget(MaterialApp(home: MyTrainerPage(repository: repo)));
    await tester.pumpAndSettle();
    await press(tester, 'Finalizar vínculo');
    await press(tester, 'Volver');
    expect(repo.ends, 0);
    await press(tester, 'Finalizar vínculo');
    await press(tester, 'Finalizar vínculo');
    expect(repo.ends, 1);
    expect(find.text('Vínculos anteriores'), findsOneWidget);
  });
  testWidgets('respuesta de una identidad anterior no aparece en la nueva', (
    tester,
  ) async {
    final pending = Completer<List<TrainerRelation>>();
    final previous = FakeTrainerRepository()
      ..relationsOverride = () => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: MyTrainerPage(key: const ValueKey('a'), repository: previous),
      ),
    );
    final next = FakeTrainerRepository()
      ..active = [trainerRelation('Preparador B')];
    await tester.pumpWidget(
      MaterialApp(
        home: MyTrainerPage(key: const ValueKey('b'), repository: next),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete([trainerRelation('Privado A')]);
    await tester.pumpAndSettle();
    expect(find.text('Preparador B'), findsOneWidget);
    expect(find.text('Privado A'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _SharingFixture implements TrainerCalendarSharingRepository {
  bool enabled = false;
  int revision = 0, count = 1;
  @override
  Future<TrainerCalendarSharing> get() async => TrainerCalendarSharing(
    enabled: enabled,
    revision: revision,
    activeTrainers: count,
    maxActiveTrainers: 2,
  );
  @override
  Future<TrainerCalendarSharing> set(bool value, int expectedRevision) async {
    expect(expectedRevision, revision);
    enabled = value;
    revision++;
    return get();
  }
}

class _EmptyForms extends StudentFormsFixture {
  @override
  Future<List<TrainerFormAssignment>> mine({
    TrainerFormAssignment? before,
  }) async => [];
}

class _AssessmentPresence extends AssessmentFixture {
  List<ProfessionalAssessmentDelivery> rows = [];
  @override
  Future<List<ProfessionalAssessmentDelivery>> mine({
    ProfessionalAssessmentDelivery? before,
  }) async => rows;
}
