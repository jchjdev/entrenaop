import 'dart:async';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  tearDown(sl.reset);

  testWidgets(
    'una ruta hija directa no consulta Mi plan y visitarlo conserva su Cubit',
    (tester) async {
      final source = _Overview('user');
      DashboardCubit? cubit;
      final router = GoRouter(
        initialLocation: '/plan/detail',
        routes: [
          GoRoute(
            path: '/plan',
            builder: (_, _) => TrainingHubEntry(
              createCubit: () =>
                  cubit = DashboardCubit(getOverview: source)..load(),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, _) => const Scaffold(body: Text('Detalle')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);
      expect(cubit, isNull);
      expect(source.calls, 0);
      router.go('/plan');
      await tester.pumpAndSettle();
      final original = cubit;
      expect(find.text('Programa user'), findsOneWidget);
      expect(source.calls, 1);
      router.push('/plan/detail');
      await tester.pumpAndSettle();
      expect(cubit, original);
      expect(source.calls, 1);
      router.pop();
      await tester.pumpAndSettle();
      expect(cubit, original);
      expect(source.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'router real conserva resumen al renovar sesión y lo sustituye al cambiar cuenta',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.close);
      final sources = <_Overview>[];
      final cubits = <DashboardCubit>[];
      sl.registerFactory<DashboardCubit>(() {
        final source = _Overview((auth.state as AuthAuthenticated).user.id);
        sources.add(source);
        final cubit = DashboardCubit(getOverview: source)..load();
        cubits.add(cubit);
        return cubit;
      });
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/plan');
      await tester.pumpWidget(
        MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router.config,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Programa A'), findsOneWidget);
      expect(sources, hasLength(1));
      auth.setUser('A', email: 'renewed@example.test');
      await tester.pumpAndSettle();
      expect(sources, hasLength(1));
      expect(cubits.first.isClosed, isFalse);
      final pending = Completer<PreparationOverview>();
      sources.first.pending = pending.future;
      final oldLoad = cubits.first.load();
      await tester.pump();
      auth.setUser('B');
      await tester.pumpAndSettle();
      expect(sources, hasLength(2));
      expect(cubits.first.isClosed, isTrue);
      expect(find.text('Programa A'), findsNothing);
      expect(find.text('Programa B'), findsOneWidget);
      pending.complete(sources.first.data);
      await oldLoad;
      await tester.pumpAndSettle();
      expect(find.text('Programa B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(_state('A'));
  void setUser(String id, {String? email}) => emit(_state(id, email: email));
  static AuthAuthenticated _state(String id, {String? email}) =>
      AuthAuthenticated(
        user: UserEntity(
          id: id,
          email: email ?? '$id@example.test',
          role: 'free',
          createdAt: DateTime(2026),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(String user)
    : data = PreparationOverview(
        assessments: const [],
        preferences: null,
        goals: const [],
        weekStart: DateTime(2026, 10, 5),
        weeklyWorkouts: const [],
        programs: [
          AdaptiveProgramProgress(
            goalId: user,
            name: 'Programa $user',
            status: 'training',
            message: 'En curso',
          ),
        ],
      );
  final PreparationOverview data;
  int calls = 0;
  Future<PreparationOverview>? pending;
  @override
  Future<PreparationOverview> call() async {
    calls++;
    return pending ?? data;
  }
}
