import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_settings_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('probar y cancelar no modifica las preferencias guardadas', (
    tester,
  ) async {
    final service = _Cues();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [WorkoutCueSettingsButton(cueService: service)],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Avisos del temporizador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonido'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Probar sonido'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Sonido'));
    await tester.pump();
    await tester.tap(find.text('Probar sonido'));
    await tester.pump();
    expect(service.previews, 1);
    expect(service.saves, 0);
    await tester.tap(find.text('Probar vibración'));
    await tester.pump();
    expect(service.hapticPreviews, 1);
    expect(service.previews, 1);
    expect(service.saves, 0);
    await tester.tap(find.text('Vibración'));
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(service.preferences, const WorkoutCuePreferences());
    expect(service.saves, 0);
  });

  testWidgets('la prueba de vibración indica errores sin sonido ni guardado', (
    tester,
  ) async {
    final service = _Cues()..hapticSuccess = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutCueSettingsButton(cueService: service)),
      ),
    );
    await tester.tap(find.byTooltip('Avisos del temporizador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Probar vibración'));
    await tester.pump();
    expect(
      find.text(
        'No se ha podido activar la vibración. Revisa los permisos y ajustes del dispositivo.',
      ),
      findsOneWidget,
    );
    expect(service.previews, 0);
    expect(service.saves, 0);
    service.hapticSuccess = true;
    await tester.tap(find.text('Probar vibración'));
    await tester.pump();
    expect(
      find.text(
        'No se ha podido activar la vibración. Revisa los permisos y ajustes del dispositivo.',
      ),
      findsNothing,
    );
    expect(service.hapticPreviews, 2);
    await tester.tap(find.text('Vibración'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Probar vibración'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(service.preferences.hapticsEnabled, isTrue);
    expect(service.saves, 0);
  });

  testWidgets('un error permanece visible y se puede reintentar y guardar', (
    tester,
  ) async {
    final service = _Cues()..previewSuccess = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutCueSettingsButton(cueService: service)),
      ),
    );
    await tester.tap(find.byTooltip('Avisos del temporizador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Probar sonido'));
    await tester.pump();
    expect(
      find.text('No se ha podido reproducir el sonido. Vuelve a probarlo.'),
      findsOneWidget,
    );
    service.previewSuccess = true;
    await tester.tap(find.text('Probar sonido'));
    await tester.pump();
    expect(
      find.text('No se ha podido reproducir el sonido. Vuelve a probarlo.'),
      findsNothing,
    );
    await tester.tap(find.text('Vibración'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(service.preferences.hapticsEnabled, isFalse);
    expect(service.saves, 1);
    expect(service.previews, 2);
  });
}

class _Cues implements WorkoutCueService {
  @override
  WorkoutCuePreferences preferences = const WorkoutCuePreferences();
  int previews = 0;
  int saves = 0;
  bool previewSuccess = true;
  int hapticPreviews = 0;
  bool hapticSuccess = true;

  @override
  Future<bool> previewHaptics() async {
    hapticPreviews++;
    return hapticSuccess;
  }

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> previewSound() async {
    previews++;
    return previewSuccess;
  }

  @override
  Future<void> savePreferences(WorkoutCuePreferences selected) async {
    saves++;
    preferences = selected;
  }

  @override
  Future<void> signal(WorkoutCue cue) async {}
}
