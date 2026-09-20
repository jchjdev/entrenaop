import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:equatable/equatable.dart';

enum DashboardStatus { initial, loading, loaded, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.overview,
    this.errorMessage,
  });

  final DashboardStatus status;
  final PreparationOverview? overview;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, overview, errorMessage];
}
