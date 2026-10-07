import 'dart:async';

import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/get_physical_assessment_history_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cerrar mientras se consulta descarta la respuesta sin emitir',
    () async {
      final pending = Completer<List<PhysicalAssessmentHistoryEntry>>();
      final repository = _HistoryRepository()..pending = pending.future;
      final cubit = PhysicalAssessmentHistoryCubit(
        getHistory: GetPhysicalAssessmentHistoryUseCase(repository),
        progressCalculator: const AssessmentProgressCalculator(),
      );
      final load = cubit.load();
      await cubit.close();
      pending.complete([]);
      await load;
      await cubit.load();
    },
  );
  test('carga el historial vacío como un resultado válido', () async {
    final cubit = PhysicalAssessmentHistoryCubit(
      getHistory: GetPhysicalAssessmentHistoryUseCase(_HistoryRepository()),
      progressCalculator: const AssessmentProgressCalculator(),
    );

    await cubit.load();

    expect(cubit.state.status, PhysicalAssessmentHistoryStatus.loaded);
    expect(cubit.state.entries, isEmpty);
    await cubit.close();
  });

  test('expone un error recuperable cuando falla la lectura', () async {
    final cubit = PhysicalAssessmentHistoryCubit(
      getHistory: GetPhysicalAssessmentHistoryUseCase(
        _HistoryRepository(shouldFail: true),
      ),
      progressCalculator: const AssessmentProgressCalculator(),
    );

    await cubit.load();

    expect(cubit.state.status, PhysicalAssessmentHistoryStatus.failure);
    expect(cubit.state.errorMessage, isNotEmpty);
    await cubit.close();
  });
}

class _HistoryRepository implements PhysicalAssessmentRepository {
  _HistoryRepository({this.shouldFail = false});

  final bool shouldFail;
  Future<List<PhysicalAssessmentHistoryEntry>>? pending;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async {
    if (pending != null) return pending!;
    if (shouldFail) throw Exception('Fallo simulado');
    return const [];
  }

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistoryForGoal(
    String goalId,
  ) async => const [];

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
    String? goalId,
  }) {
    throw UnimplementedError();
  }
}
