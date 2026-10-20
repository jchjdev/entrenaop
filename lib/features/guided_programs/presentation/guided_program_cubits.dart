import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:workout_core/guided_program.dart';

import '../domain/guided_program_repository.dart';
import '../../pro/domain/pro_access.dart';

class GuidedCatalogState {
  const GuidedCatalogState({
    this.items = const [],
    this.loading = false,
    this.error,
  });
  final List<GuidedProgram> items;
  final bool loading;
  final String? error;
}

class GuidedCatalogCubit extends Cubit<GuidedCatalogState> {
  GuidedCatalogCubit(this.repository) : super(const GuidedCatalogState());
  final GuidedProgramRepository repository;
  String query = '';
  GuidedProgramMode? mode;
  String? categoryId;
  bool followed = false;
  int _request = 0;
  Timer? _debounce;
  Future<void> load({bool keepItems = false}) async {
    if (isClosed) return;
    final request = ++_request;
    final previousItems = keepItems ? state.items : const <GuidedProgram>[];
    emit(GuidedCatalogState(loading: true, items: previousItems));
    final currentQuery = query;
    final currentMode = mode;
    final currentFollowed = followed;
    final currentCategory = categoryId;
    try {
      final programs = <Object, GuidedProgram>{};
      var page = 0;
      // Las tandas son un detalle de consulta: el catálogo tiene un único final,
      // sin páginas visibles ni un botón para continuar explorando.
      while (true) {
        final result = await repository.catalog(
          query: currentQuery,
          mode: currentMode,
          followed: currentFollowed,
          categoryId: currentCategory,
          page: page,
          pageSize: 24,
        );
        if (isClosed || request != _request) return;
        for (final program in result.items) {
          programs[program.id ?? program] = program;
        }
        if (!result.hasMore || result.items.isEmpty) break;
        page++;
      }
      emit(GuidedCatalogState(items: List.unmodifiable(programs.values)));
    } catch (_) {
      if (!isClosed && request == _request) {
        emit(
          GuidedCatalogState(
            items: previousItems,
            error: 'No se pudieron cargar los programas. Revisa la conexión.',
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

  void filterCategory(String? value) {
    categoryId = value;
    _debounce?.cancel();
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
    this.restriction,
  });
  final GuidedProgramDetail? detail;
  final bool loading, busy;
  final String? error;
  final ProAccessDenied? restriction;
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
  Future<void> abandon() async {
    final follow = state.detail?.follow;
    if (follow == null || follow.completed || follow.abandoned) return;
    await _mutate(
      () => repository.abandon(follow.id),
      errorMessage: 'No se pudo dejar el programa. Revisa la conexión y termina o abandona cualquier sesión en curso antes de reintentar.',
    );
  }

  Future<void> setPaused(bool paused) async {
    final follow = state.detail?.follow;
    if (follow == null || follow.completed || follow.abandoned) return;
    await _mutate(
      () => repository.setPaused(follow.id, paused: paused),
      errorMessage: 'No se pudo cambiar el programa. Revisa la conexión y termina o abandona la sesión en curso antes de pausar.',
    );
  }

  Future<void> advance() async {
    final f = state.detail?.follow;
    if (f == null) return;
    await _mutate(() => repository.advance(f.id, f.phaseIndex));
  }

  Future<void> keepFreeProgram() async {
    final follow = state.detail?.follow;
    if (follow == null || !follow.active || !state.detail!.requiresSelection) {
      return;
    }
    await _mutate(
      () => repository.keepFreeProgram(follow.id),
      errorMessage: 'No se pudo elegir el programa. Termina o abandona las sesiones abiertas de los otros programas y vuelve a intentarlo.',
    );
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    String errorMessage = 'No se pudo guardar el cambio. Si tienes una sesión en curso, resuélvela antes de avanzar.',
  }) async {
    if (state.busy) return;
    emit(GuidedDetailState(detail: state.detail, busy: true));
    try {
      await action();
      if (!isClosed) await load();
    } on ProAccessDenied catch (denied) {
      if (!isClosed) {
        emit(GuidedDetailState(detail: state.detail, restriction: denied));
      }
    } catch (_) {
      if (!isClosed) {
        emit(GuidedDetailState(detail: state.detail, error: errorMessage));
      }
    }
  }
}
