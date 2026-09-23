import 'package:entrenaop/features/preparation_goal/data/initial_week_draft_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el borrador versionado reserva días para carrera y fuerza', () async {
    final draft = await InitialWeekDraftCatalog.load();

    expect(draft.version, 'tropa_initial_week_draft_v1');
    expect(draft.totalDays, 3);
    expect(draft.runningDays, 2);
    expect(draft.strengthDays, 1);
    expect(draft.sessions.map((item) => item.id), [
      'controlled_quality',
      'strength',
      'easy_running',
    ]);
    expect(draft.sessions.first.details.join(' '), contains('4 × 2 min'));
  });

  test('rechaza repartir más sesiones que días declarados', () {
    expect(
      () => InitialWeekDraft.fromJson({..._validDraft, 'totalDays': 2}),
      throwsFormatException,
    );
  });

  test('rechaza publicar como si fuera un borrador', () {
    expect(
      () => InitialWeekDraft.fromJson({..._validDraft, 'status': 'published'}),
      throwsFormatException,
    );
  });
}

final _validDraft = <String, dynamic>{
  'version': 'v1',
  'programId': 'armed_forces_troop_entry',
  'status': 'draft',
  'totalDays': 1,
  'runningDays': 1,
  'strengthDays': 0,
  'intro': 'Ejemplo',
  'cycleNote': 'Pendiente',
  'sessions': [
    {
      'id': 'run',
      'dayLabel': 'Día A',
      'modality': 'running',
      'title': 'Carrera',
      'subtitle': 'Ejemplo',
      'details': ['Detalle'],
    },
  ],
};
