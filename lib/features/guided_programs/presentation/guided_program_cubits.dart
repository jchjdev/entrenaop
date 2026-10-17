import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:workout_core/guided_program.dart';

import '../domain/guided_program_repository.dart';

class GuidedCatalogState {
  const GuidedCatalogState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.page = 0,
    this.hasMore = false,
  });
  final List<GuidedProgram> items;
  final bool loading, hasMore;
  final String? error;
  final int page;
}

class GuidedCatalogCubit extends Cubit<GuidedCatalogState> {
  GuidedCatalogCubit(this.repository) : super(const GuidedCatalogState());
  final GuidedProgramRepository repository;
  String query = '';
  GuidedProgramMode? mode;
  bool followed = false;
  int _request = 0;
  Timer? _debounce;
  Future<void> load({int page = 0}) async {
    final request = ++_request;
    emit(GuidedCatalogState(loading: true, page: page, items: state.items));
    try {
      final result = await repository.catalog(
        query: query,
        mode: mode,
        followed: followed,
        page: page,
      );
      if (isClosed || request != _request) return;
      emit(
        GuidedCatalogState(
          items: result.items,
          page: page,
          hasMore: result.hasMore,
        ),
      );
    } catch (_) {
      if (!isClosed && request == _request) {
        emit(
          GuidedCatalogState(
            error: 'No se pudieron cargar los programas. Revisa la conexión.',
            page: page,
          ),
        );
      }
    }
  }

  void search(String value) {
    query = value;
    _debounce?.cancel();
    ++_request;
    _debounce = Timer(const Duration(milliseconds: 300), () => load());
  }

  void filter(String value) {
    _debounce?.cancel();
    followed = value == 'following';
    mode = switch (value) {
      'guide' => GuidedProgramMode.guide,
      'phased' => GuidedProgramMode.phased,
      _ => null,
    };
    load();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

class GuidedDetailState {
  const GuidedDetailState({
    this.detail,
    this.loading = false,
    this.busy = false,
    this.error,
  });
  final GuidedProgramDetail? detail;
  final bool loading, busy;
  final String? error;
}

class GuidedDetailCubit extends Cubit<GuidedDetailState> {
  GuidedDetailCubit(this.repository, this.programId)
    : super(const GuidedDetailState());
  final GuidedProgramRepository repository;
  final String programId;
  Future<void> load() async {
    if (isClosed) return;
    emit(
      GuidedDetailState(detail: state.detail, loading: true, busy: state.busy),
    );
    try {
      final detail = await repository.detail(programId);
      if (!isClosed) emit(GuidedDetailState(detail: detail));
    } catch (_) {
      if (!isClosed) {
        emit(
          GuidedDetailState(
            detail: state.detail,
            error: 'No se pudo cargar el programa. Revisa la conexión.',
          ),
        );
      }
    }
  }

  Future<void> follow() async => _mutate(() => repository.follow(programId));
  Future<void> advance() async {
    final f = state.detail?.follow;
    if (f == null) return;
    await _mutate(() => repository.advance(f.id, f.phaseIndex));
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (state.busy) return;
    emit(GuidedDetailState(detail: state.detail, busy: true));
    try {
      await action();
      if (!isClosed) await load();
    } catch (_) {
      if (!isClosed) {
        emit(
          GuidedDetailState(
            detail: state.detail,
            error: 'No se pudo guardar el cambio. Si tienes una sesión en curso, resuélvela antes de avanzar.',
          ),
        );
      }
    }
  }
}
