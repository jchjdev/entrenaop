import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_cubits.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../../helpers/performance_visual_review.dart';
import '../../support/guided_program_fixture.dart';

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final view in [
    (390.0, 844.0, 1.0),
    (320.0, 780.0, 2.0),
    (844.0, 390.0, 1.3),
    (1100.0, 850.0, 1.0),
  ]) {
    for (final kind in ['dejar', 'pausar', 'elegir', 'avanzar', 'completar']) {
      testWidgets('$kind: acciones separadas y completas en $view', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(view.$1, view.$2));
        tester.platformDispatcher.textScaleFactorTestValue = view.$3;
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final repo = _Repository(kind);
        final cubit = GuidedDetailCubit(repo, 'program')..load();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: const GuidedProgramPage(),
              ),
            ),
          ],
        );
        addTearDown(cubit.close);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: EntrenaTheme.dark.copyWith(platform: TargetPlatform.iOS),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(
                  top: view.$2 > view.$1 ? 44 : 0,
                  bottom: 20,
                ),
              ),
              child: RepaintBoundary(
                key: const ValueKey('review-boundary'),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final entryLabel = switch (kind) {
          'dejar' => 'Dejar programa',
          'pausar' => 'Pausar programa',
          'elegir' => 'Continuar solo con este programa',
          'avanzar' => 'Revisar paso de fase',
          _ => 'Completar programa',
        };
        await tester.scrollUntilVisible(find.text(entryLabel), 180);
        await tester.ensureVisible(find.text(entryLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entryLabel));
        await tester.pumpAndSettle();
        final dialog = find.byType(EntrenaDialog);
        expect(dialog, findsOneWidget);
        final primary = find.descendant(
          of: dialog,
          matching: find.byType(FilledButton),
        );
        final secondary = find.descendant(
          of: dialog,
          matching: find.byType(OutlinedButton),
        );
        expect(primary, findsOneWidget);
        expect(secondary, findsOneWidget);
        final primaryRect = tester.getRect(primary),
            secondaryRect = tester.getRect(secondary);
        expect(
          secondaryRect.top - primaryRect.bottom,
          greaterThanOrEqualTo(10),
        );
        expect(secondaryRect.left, closeTo(primaryRect.left, 0.01));
        expect(secondaryRect.width, closeTo(primaryRect.width, 0.01));
        expect(primaryRect.overlaps(secondaryRect), isFalse);
        if (kind == 'dejar') {
          expect(
            find.descendant(of: primary, matching: find.text('Cancelar')),
            findsOneWidget,
          );
          final style = tester.widget<OutlinedButton>(secondary).style!;
          final context = tester.element(secondary);
          expect(
            style.foregroundColor!.resolve({}),
            Theme.of(context).colorScheme.error,
          );
        }
        await tester.ensureVisible(secondary);
        await tester.pumpAndSettle();
        final screen = Offset.zero & Size(view.$1, view.$2);
        expect(screen.contains(tester.getCenter(secondary)), isTrue);
        await capturePerformanceWidget(
          tester,
          'programa-dialogo-$kind-${view.$1}-${view.$3}',
        );
        final cancel = kind == 'dejar' ? primary : secondary;
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(repo.mutations, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Repository extends GuidedTestRepository {
  _Repository(this.kind);
  final String kind;
  int mutations = 0;
  @override
  Future<GuidedProgramDetail> detail(String id) async => GuidedProgramDetail(
    const GuidedProgram(
      id: 'program',
      name: 'Dominadas',
      status: 'published',
      mode: GuidedProgramMode.phased,
      phases: [
        GuidedPhase(
          name: 'Base',
          durationWeeks: 2,
          instructions: 'Revisa tus resultados y confirma que has trabajado la técnica antes de avanzar.',
          sessions: [GuidedSession(templateId: 'session', name: 'Sesión A')],
        ),
        GuidedPhase(
          name: 'Progreso',
          durationWeeks: 2,
          instructions:
              'Comprueba tus resultados antes de completar el programa.',
          sessions: [GuidedSession(templateId: 'session', name: 'Sesión B')],
        ),
      ],
    ),
    follow: GuidedFollow(
      id: 'follow',
      phaseIndex: kind == 'completar' ? 1 : 0,
      completed: false,
    ),
    access: GuidedProgramAccess(isPro: kind != 'elegir', activePrograms: 3),
  );
  @override
  Future<void> abandon(String followId) async {
    mutations++;
  }

  @override
  Future<void> setPaused(String followId, {required bool paused}) async {
    mutations++;
  }

  @override
  Future<void> keepFreeProgram(String followId) async {
    mutations++;
  }

  @override
  Future<void> advance(String followId, int expectedPhase) async {
    mutations++;
  }
}
