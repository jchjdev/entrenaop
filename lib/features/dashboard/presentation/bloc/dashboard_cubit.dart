import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required GetPreparationOverviewUseCase getOverview})
    : _getOverview = getOverview,
      super(const DashboardState());

  final GetPreparationOverviewUseCase _getOverview;
  int _loadVersion = 0;

  Future<void> load() async {
    if (isClosed) return;
    final version = ++_loadVersion;
    emit(
      DashboardState(status: DashboardStatus.loading, overview: state.overview),
    );
    try {
      final overview = await _getOverview();
      if (isClosed || version != _loadVersion) return;
      emit(DashboardState(status: DashboardStatus.loaded, overview: overview));
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        DashboardState(
          status: DashboardStatus.failure,
          overview: state.overview,
          errorMessage: 'No hemos podido actualizar el resumen.',
        ),
      );
    }
  }
}
