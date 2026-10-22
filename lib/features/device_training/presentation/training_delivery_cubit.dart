import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/training_delivery.dart';

class TrainingDeliveryState {
  const TrainingDeliveryState({
    this.busy = false,
    this.catalog,
    this.selected,
    this.preview,
    this.receipt,
    this.error,
  });
  final bool busy;
  final TrainingCatalog? catalog;
  final TrainingCandidate? selected;
  final TrainingPreview? preview;
  final TrainingReceipt? receipt;
  final String? error;
}

class TrainingDeliveryCubit extends Cubit<TrainingDeliveryState> {
  TrainingDeliveryCubit(this.repository) : super(const TrainingDeliveryState());
  final TrainingDeliveryRepository repository;
  int _request = 0;
  bool _current(int value) => !isClosed && value == _request;
  String _error(Object error) =>
      error is TrainingDeliveryException ? error.code : 'garmin_unavailable';
  Future<void> load() async {
    if (state.busy) return;
    final request = ++_request;
    emit(TrainingDeliveryState(busy: true, catalog: state.catalog));
    try {
      final catalog = await repository.load();
      if (_current(request)) emit(TrainingDeliveryState(catalog: catalog));
    } catch (error) {
      if (_current(request)) {
        emit(
          TrainingDeliveryState(catalog: state.catalog, error: _error(error)),
        );
      }
    }
  }

  Future<void> select(TrainingCandidate selected) async {
    if (state.busy) return;
    final request = ++_request;
    emit(
      TrainingDeliveryState(
        busy: true,
        catalog: state.catalog,
        selected: selected,
      ),
    );
    try {
      final preview = await repository.preview(selected.id);
      if (_current(request)) {
        emit(
          TrainingDeliveryState(
            catalog: state.catalog,
            selected: selected,
            preview: preview,
          ),
        );
      }
    } catch (error) {
      if (_current(request)) {
        emit(
          TrainingDeliveryState(
            catalog: state.catalog,
            selected: selected,
            error: _error(error),
          ),
        );
      }
    }
  }

  Future<void> send() async {
    if (state.busy || state.selected == null || state.preview == null) return;
    final selected = state.selected!,
        preview = state.preview!,
        catalog = state.catalog;
    final request = ++_request;
    emit(
      TrainingDeliveryState(
        busy: true,
        catalog: catalog,
        selected: selected,
        preview: preview,
      ),
    );
    try {
      final receipt = await repository.send(selected.id, preview.revision);
      if (_current(request)) {
        emit(
          TrainingDeliveryState(
            catalog: catalog,
            selected: selected,
            preview: preview,
            receipt: receipt,
          ),
        );
      }
    } catch (error) {
      if (_current(request)) {
        emit(
          TrainingDeliveryState(
            catalog: catalog,
            selected: selected,
            preview: preview,
            error: _error(error),
          ),
        );
      }
    }
  }
}
