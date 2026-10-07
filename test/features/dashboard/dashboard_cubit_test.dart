import 'dart:async';

import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Inicio conserva el resumen y solo acepta la consulta más reciente',
    () async {
      final query = _Query();
      final cubit = DashboardCubit(getOverview: query);
      await cubit.load();
      final previous = cubit.state.overview;
      final old = Completer<PreparationOverview>();
      query.next = () => old.future;
      final oldLoad = cubit.load();
      expect(cubit.state.overview, same(previous));
      query.next = () async => _overview(12);
      await cubit.load();
      old.completeError(StateError('error de la petición anterior'));
      await oldLoad;
      expect(cubit.state.status, DashboardStatus.loaded);
      expect(cubit.state.overview!.weekStart, DateTime(2026, 10, 12));
      final pending = Completer<PreparationOverview>();
      query.next = () => pending.future;
      final closing = cubit.load();
      await cubit.close();
      pending.complete(_overview(5));
      await closing;
      await cubit.load();
    },
  );
}

PreparationOverview _overview(int day) => PreparationOverview(
  assessments: const [],
  preferences: null,
  goals: const [],
  weekStart: DateTime(2026, 10, day),
  weeklyWorkouts: const [],
);

class _Query implements GetPreparationOverviewUseCase {
  Future<PreparationOverview> Function() next = () async => _overview(5);
  @override
  Future<PreparationOverview> call() => next();
}
