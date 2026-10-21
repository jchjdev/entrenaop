import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

class _Repository extends Fake implements GuidedWorkRepository {
  int saves = 0;
  Map<String, dynamic>? stored;
  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    saves++;
    stored = state;
    return GuidedWork(id: work.id, revision: work.revision + 1, state: state);
  }
}

void main() {
  test(
    'JSONB con otro orden de claves no ensucia ni escribe un trabajo igual',
    () async {
      final repository = _Repository();
      final original = <String, dynamic>{
        'schema': 1,
        'phases': [
          {
            'z': ' 60 ',
            'a': [
              {'positionId': 'p', 'id': 'S'},
            ],
          },
        ],
        'name': 'Programa',
      };
      final controller = GuidedWorkController(
        repository,
        GuidedWork(id: 'work', revision: 3, state: original),
        original,
      );
      addTearDown(controller.dispose);
      controller.update({
        'name': 'Programa',
        'phases': [
          {
            'a': [
              {'id': 'S', 'positionId': 'p'},
            ],
            'z': ' 60 ',
          },
        ],
        'schema': 1,
      });
      expect(controller.dirty, isFalse);
      await controller.flush();
      expect(repository.saves, 0);
      expect(controller.work.revision, 3);
      expect(original.keys, ['schema', 'phases', 'name']);
    },
  );

  test(
    'incorporar posición ausente sigue siendo cambio real y la persiste',
    () async {
      final repository = _Repository();
      final old = <String, dynamic>{
        'sessions': [
          {'id': 'S'},
        ],
      };
      final controller = GuidedWorkController(
        repository,
        GuidedWork(id: 'work', revision: 3, state: old),
        old,
      );
      addTearDown(controller.dispose);
      controller.update({
        'sessions': [
          {'id': 'S', 'positionId': 'p'},
        ],
      });
      expect(controller.dirty, isTrue);
      await controller.flush();
      expect(repository.saves, 1);
      expect(
        (repository.stored!['sessions'] as List).single['positionId'],
        'p',
      );
      expect(controller.dirty, isFalse);
    },
  );

  test(
    'orden de posiciones y espacios del texto crudo no se normalizan',
    () async {
      final repository = _Repository();
      final state = <String, dynamic>{
        'sessions': ['S', 'T'],
        'minimum': ' 60 ',
      };
      final controller = GuidedWorkController(
        repository,
        GuidedWork(id: 'work', revision: 3, state: state),
        state,
      );
      addTearDown(controller.dispose);
      controller.update({
        'minimum': ' 60 ',
        'sessions': ['T', 'S'],
      });
      expect(controller.dirty, isTrue);
      await controller.flush();
      expect(repository.stored!['sessions'], ['T', 'S']);
      expect(repository.stored!['minimum'], ' 60 ');
      controller.update({
        'sessions': ['T', 'S'],
        'minimum': '60',
      });
      expect(controller.dirty, isTrue);
    },
  );
}
