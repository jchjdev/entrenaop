import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/garmin_connection.dart';

class GarminConnectionState {
  const GarminConnectionState({
    this.snapshot,
    this.busy = false,
    this.problem,
    this.authorizationUrl,
  });
  final GarminConnectionSnapshot? snapshot;
  final bool busy;
  final GarminConnectionProblem? problem;
  final Uri? authorizationUrl;
}

class GarminConnectionCubit extends Cubit<GarminConnectionState> {
  GarminConnectionCubit(this.repository) : super(const GarminConnectionState());
  final GarminConnectionRepository repository;
  Future<void> load() => _run(repository.load);
  Future<void> begin() async {
    if (state.busy || state.snapshot?.allowed != true) return;
    emit(GarminConnectionState(snapshot: state.snapshot, busy: true));
    try {
      final result = await repository.begin();
      if (!isClosed) {
        emit(
          GarminConnectionState(
            snapshot: result.snapshot,
            authorizationUrl: result.url,
          ),
        );
      }
    } catch (error) {
      _failed(error);
    }
  }

  Future<void> disconnect() async {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    await _run(() => repository.disconnect(snapshot.generation));
  }

  Future<void> _run(Future<GarminConnectionSnapshot> Function() action) async {
    if (state.busy) return;
    emit(GarminConnectionState(snapshot: state.snapshot, busy: true));
    try {
      final snapshot = await action();
      if (!isClosed) emit(GarminConnectionState(snapshot: snapshot));
    } catch (error) {
      _failed(error);
    }
  }

  void _failed(Object error) {
    if (isClosed) return;
    final problem = error is GarminConnectionException
        ? error.problem
        : GarminConnectionProblem.unavailable;
    emit(
      GarminConnectionState(
        snapshot: problem == GarminConnectionProblem.accountChanged
            ? null
            : state.snapshot,
        problem: problem,
      ),
    );
  }
}
