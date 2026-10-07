import 'package:bloc/bloc.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/plan_preview/data/shared_preferences_plan_preview_store.dart';
import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_cubit.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_scope.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_selector.dart';
import 'package:entrenaop/features/plan_preview/presentation/pro_preview_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<PlanPreviewCubit> preview({bool enabled = true}) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = PlanPreviewCubit(
      enabled: enabled,
      store: SharedPreferencesPlanPreviewStore(
        await SharedPreferences.getInstance(),
      ),
    )..bindAccount('user');
    addTearDown(cubit.close);
    return cubit;
  }

  testWidgets(
    'el selector cambia Free/Pro y no aparece cuando está deshabilitado',
    (tester) async {
      final cubit = await preview();
      await tester.pumpWidget(
        PlanPreviewScope(
          cubit: cubit,
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            home: const Scaffold(body: PlanPreviewSelector()),
          ),
        ),
      );
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      expect(cubit.state.isFree, isTrue);
      await tester.tap(find.text('Pro'));
      await tester.pumpAndSettle();
      expect(cubit.state.isFree, isFalse);
      final disabled = await preview(enabled: false);
      await tester.pumpWidget(
        PlanPreviewScope(
          cubit: disabled,
          child: const MaterialApp(home: Scaffold(body: PlanPreviewSelector())),
        ),
      );
      expect(find.text('Pruebas Free / Pro'), findsNothing);
    },
  );

  testWidgets('Free no monta el generador y volver a Pro recupera su acceso', (
    tester,
  ) async {
    final cubit = await preview();
    await cubit.select(PlanPreviewTier.free);
    var builds = 0;
    await tester.pumpWidget(
      PlanPreviewScope(
        cubit: cubit,
        child: MaterialApp(
          theme: EntrenaTheme.dark,
          home: ProPreviewGate(
            builder: (_) {
              builds++;
              return const Scaffold(body: Text('Generador actual'));
            },
          ),
        ),
      ),
    );
    expect(find.text('Tu programa, adaptado a ti'), findsOneWidget);
    expect(builds, 0);
    await cubit.select(PlanPreviewTier.pro);
    await tester.pumpAndSettle();
    expect(find.text('Generador actual'), findsOneWidget);
    expect(builds, 1);
    expect(tester.takeException(), isNull);
  });

  for (final path in [
    '/plan/goal/old/training',
    '/plan/goal/old/running-intake?dataOnly=true',
  ]) {
    testWidgets(
      'un enlace directo en Free no crea controladores de algoritmo: $path',
      (tester) async {
        final cubit = await preview();
        await cubit.select(PlanPreviewTier.free);
        final auth = _Auth();
        addTearDown(auth.close);
        final router = AppRouter(auth);
        addTearDown(router.dispose);
        router.config.go(path);
        await tester.pumpWidget(
          PlanPreviewScope(
            cubit: cubit,
            child: MaterialApp.router(
              theme: EntrenaTheme.dark,
              routerConfig: router.config,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tu programa, adaptado a ti'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth()
    : super(
        AuthAuthenticated(
          user: UserEntity(
            id: 'user',
            email: 'test@example.com',
            role: 'user',
            createdAt: DateTime(2026),
          ),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
