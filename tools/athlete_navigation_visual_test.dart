// Capturas de las pantallas reales con datos ficticios y sin acceso a red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_hub_page.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/features/trainers/professional_hub_test.dart'
    show NoticeFixture, snapshot;

import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';

void main() {
  var fontsLoaded = false;
  for (final (screen, width, scale, unread) in [
    ('inicio', 390.0, 1.0, 2),
    ('sin-avisos', 390.0, 1.0, 0),
    ('inicio-accesible', 320.0, 2.0, 2),
    ('preparador', 390.0, 1.0, 2),
    ('historial', 390.0, 1.0, 0),
  ]) {
    testWidgets('captura $screen', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (!fontsLoaded) {
        await tester.runAsync(() async {
          final fonts =
              Platform.environment['FLUTTER_FONT_DIR'] ??
              'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
          for (final (family, name) in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final bytes = await File('$fonts/$name').readAsBytes();
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
          fontsLoaded = true;
        });
      }
      final repository = NoticeFixture()
        ..data = snapshot(
          unread: unread,
          resources: screen == 'historial'
              ? const StudentNoticeResources()
              : const StudentNoticeResources(
                  hasAssignedWorkouts: true,
                  hasForms: true,
                  hasConversations: true,
                  conversationRelationId: 'fixture',
                ),
        );
      final navigation = StudentNavigationController(
        loadSnapshot: repository.snapshot,
        loadHasRelationship: () async => true,
      );
      await navigation.refresh();
      addTearDown(navigation.dispose);
      final cubit = DashboardCubit(getOverview: _Overview());
      await cubit.load();
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: ['preparador', 'historial'].contains(screen)
            ? '/my-trainer'
            : '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => StudentNavigationScope(
              controller: navigation,
              child: AppShell(navigationShell: shell),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, _) => BlocProvider.value(
                      value: cubit,
                      child: HomePage(
                        favoritesRepository: _Favorites(),
                        userId: 'fixture',
                      ),
                    ),
                  ),
                ],
              ),
              for (final path in ['/plan', '/library', '/assessment/history'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(path: path, builder: (_, _) => const Scaffold()),
                  ],
                ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/my-trainer',
                    builder: (_, _) => ProfessionalHubPage(
                      repository: repository,
                      userId: 'fixture',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (find.byType(HomePage).evaluate().isNotEmpty) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(
              'assets/branding/entrenaop_wordmark_on_dark.png',
              package: 'entrena_ui',
            ),
            tester.element(find.byType(HomePage)),
          ),
        );
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Mi perfil'), findsOneWidget);
      expect(find.byTooltip('Mi perfil').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('Mi perfil')).right,
        lessThanOrEqualTo(width),
      );
      if (unread == 0) {
        expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      }
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'docs/visual-audit/athlete-navigation-2026-10-22/$screen.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

class _Overview implements GetPreparationOverviewUseCase {
  @override
  Future<PreparationOverview> call() async {
    final today = DateUtils.dateOnly(DateTime.now());
    return PreparationOverview(
      assessments: const [],
      preferences: null,
      goals: const [],
      weekStart: today.subtract(Duration(days: today.weekday - 1)),
      weeklyWorkouts: [
        ScheduledWorkout(
          id: 'fixture',
          templateId: 'fixture',
          templateName: 'Fuerza del preparador',
          templateVersion: 1,
          scheduledDate: today,
          source: ScheduledWorkoutSource.coach,
          status: ScheduledWorkoutStatus.planned,
        ),
      ],
    );
  }
}

class _Favorites implements HomeFavoritesRepository {
  @override
  Future<List<HomeShortcut>> load(String userId) async => [];
  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async {}
}
