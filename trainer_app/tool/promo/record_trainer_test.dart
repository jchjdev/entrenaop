import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools/promo/frame_recorder.dart';
import '../../../tools/promo/portrait_data.dart';

import 'package:trainer_access/profile_photo/presentation.dart';
import 'package:entrenaop_trainer/trainer_client_workspace.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';

import 'trainer_demo.dart';

void main() {
  testWidgets(
    'graba retratos ficticios, ficha, agenda, recetas y resultados de Trainer',
    (tester) async {
      final key = GlobalKey<TrainerDemoState>();
      final recorder = DemoRecorder(
        tester,
        Platform.environment['PROMO_OUTPUT'] ?? '../build/promo/trainer',
      );
      await recorder.mount(TrainerDemo(key: key), const Size(1440, 900));
      await tester.runAsync(() async {
        for (final bytes in demoPhotos.values) {
          await precacheImage(MemoryImage(bytes), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      await recorder.hold(2);
      await recorder.scroll(
        find.byKey(const PageStorageKey('trainer-agenda-scroll')),
        300,
      );
      await recorder.hold(1);
      key.currentState!.router.go('/clients');
      await recorder.animate(0.7);
      for (final name in [
        'Lucía Vega',
        'Dani Torres',
        'Nora Martín',
        'Marcos Vidal',
      ]) {
        expect(find.text(name), findsWidgets);
      }
      expect(
        tester
            .widgetList<ProfilePhotoAvatar>(find.byType(ProfilePhotoAvatar))
            .where((a) => a.path != null)
            .length,
        4,
      );
      await recorder.hold(2.8);
      await recorder.tap(find.text('Lucía Vega').first);
      await recorder.hold(1.3);
      await recorder.scroll(
        find
            .descendant(
              of: find.byType(TrainerClientWorkspacePage),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            )
            .hitTestable()
            .first,
        440,
      );
      await recorder.hold(2.3);
      key.currentState!.router.go('/agenda');
      await recorder.animate(0.7);
      await recorder.tap(find.byKey(const ValueKey('agenda-view-week')));
      await recorder.hold(2);
      await recorder.tap(
        find.byKey(const ValueKey('agenda-board-entry-demo-2026-10-31-0')),
      );
      expect(
        find.textContaining('Circuito de fuerza · 3 rondas'),
        findsOneWidget,
      );
      await recorder.hold(2);
      await recorder.scroll(
        find.byKey(const PageStorageKey('agenda-recipe-scroll')),
        300,
      );
      await recorder.hold(2);
      await recorder.tap(find.byTooltip('Cerrar detalle'));
      await recorder.tap(
        find.byKey(const ValueKey('agenda-board-entry-demo-2026-10-28-0')),
      );
      await recorder.tap(find.widgetWithText(ChoiceChip, 'Resultados'));
      expect(find.textContaining('Buen control del ritmo'), findsOneWidget);
      await recorder.hold(2.2);
      final resultsScroll = find
          .descendant(
            of: find.byType(TrainerWorkoutResultContent),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .hitTestable()
          .first;
      await recorder.scroll(resultsScroll, 540);
      expect(
        tester.state<ScrollableState>(resultsScroll).position.pixels,
        greaterThan(300),
      );
      await recorder.hold(2.5);
      await recorder.still('results');
      await recorder.tap(find.byTooltip('Cerrar detalle'));
      await recorder.tap(find.byKey(const ValueKey('agenda-view-month')));
      await recorder.hold(1.2);
      await recorder.finish();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
