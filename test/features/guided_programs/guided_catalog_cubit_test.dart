import 'dart:async';

import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_cubits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';

import '../../support/guided_program_fixture.dart';

GuidedProgram program(String id) => GuidedProgram(
  id: id,
  name: id,
  mode: guidedFixture.mode,
  phases: guidedFixture.phases,
);

void main() {
  test(
    'actualizar al volver de la ficha conserva las tarjetas incluso si falla',
    () async {
      final repo = _PendingRepository();
      final cubit = GuidedCatalogCubit(repo);
      addTearDown(cubit.close);
      final first = cubit.load();
      repo.calls[0].result.complete(
        GuidedCatalogPage([program('a')], hasMore: false),
      );
      await first;
      final refresh = cubit.load(keepItems: true);
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.items.single.id, 'a');
      repo.calls[1].result.completeError(StateError('Sin conexión'));
      await refresh;
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.items.single.id, 'a');
    },
  );

  test(
    'reúne las tandas, conserva los criterios y evita tarjetas duplicadas',
    () async {
      final repo = _PendingRepository();
      final cubit = GuidedCatalogCubit(repo)
        ..query = 'gluteo'
        ..categoryId = 'strength'
        ..followed = true;
      addTearDown(cubit.close);
      final loading = cubit.load();
      repo.calls[0].result.complete(
        GuidedCatalogPage([program('a'), program('b')], hasMore: true),
      );
      await pumpEventQueue();
      expect(cubit.state.loading, isTrue);
      expect(repo.calls[1].page, 1);
      expect(repo.calls[1].query, 'gluteo');
      expect(repo.calls[1].category, 'strength');
      expect(repo.calls[1].followed, isTrue);
      repo.calls[1].result.complete(
        GuidedCatalogPage([program('b'), program('c')], hasMore: false),
      );
      await loading;
      expect(cubit.state.items.map((p) => p.id), ['a', 'b', 'c']);
      expect(cubit.state.loading, isFalse);
    },
  );

  test(
    'cambiar categoría descarta una tanda anterior que llega tarde',
    () async {
      final repo = _PendingRepository();
      final cubit = GuidedCatalogCubit(repo);
      addTearDown(cubit.close);
      final first = cubit.load();
      repo.calls[0].result.complete(
        GuidedCatalogPage([program('old')], hasMore: true),
      );
      await pumpEventQueue();
      cubit.filterCategory('new-category');
      expect(repo.calls[2].page, 0);
      repo.calls[2].result.complete(
        GuidedCatalogPage([program('new')], hasMore: false),
      );
      await pumpEventQueue();
      repo.calls[1].result.complete(
        GuidedCatalogPage([program('obsolete')], hasMore: true),
      );
      await first;
      expect(cubit.state.items.single.id, 'new');
      expect(repo.calls.length, 3);
      expect(cubit.categoryId, 'new-category');
    },
  );

  test('un fallo en otra tanda permite reintentar sin ocultar resultados faltantes', () async {
    final repo = _PendingRepository();
    final cubit = GuidedCatalogCubit(repo);
    addTearDown(cubit.close);
    final first = cubit.load();
    repo.calls[0].result.complete(
      GuidedCatalogPage([program('a')], hasMore: true),
    );
    await pumpEventQueue();
    repo.calls[1].result.completeError(StateError('Sin conexión'));
    await first;
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.items, isEmpty);
    final retry = cubit.load();
    expect(repo.calls[2].page, 0);
    repo.calls[2].result.complete(
      GuidedCatalogPage([program('a'), program('b')], hasMore: false),
    );
    await retry;
    expect(cubit.state.items.map((p) => p.id), ['a', 'b']);
    expect(cubit.state.error, isNull);
  });
}

class _PendingRepository extends GuidedTestRepository {
  final calls =
      <
        ({
          int page,
          String query,
          String? category,
          bool followed,
          Completer<GuidedCatalogPage> result,
        })
      >[];

  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  }) {
    final result = Completer<GuidedCatalogPage>();
    calls.add((
      page: page,
      query: query,
      category: categoryId,
      followed: followed,
      result: result,
    ));
    return result.future;
  }
}
