import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_settings_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('avisos con botones separados y accesibles a $width / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Cues();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: WorkoutCueSettingsButton(cueService: service)),
        ),
      );
      await tester.tap(find.byTooltip('Avisos del temporizador'));
      await tester.pumpAndSettle();
      final sound = find.widgetWithText(OutlinedButton, 'Probar sonido');
      final haptics = find.widgetWithText(OutlinedButton, 'Probar vibración');
      await tester.ensureVisible(haptics);
      await tester.pumpAndSettle();
      expect(tester.getSize(sound).width, tester.getSize(haptics).width);
      expect(tester.getSize(sound).height, tester.getSize(haptics).height);
      expect(
        tester.getTopLeft(haptics).dy - tester.getBottomLeft(sound).dy,
        greaterThanOrEqualTo(10),
      );
      await tester.tap(haptics);
      await tester.pump();
      expect(service.hapticPreviews, 1);
      expect(service.saves, 0);
      await tester.ensureVisible(find.text('Cómo funcionan los avisos'));
      await tester.tap(find.text('Cómo funcionan los avisos'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Los intervalos cortos tienen menos avisos'),
        findsOneWidget,
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(service.saves, 1);
      expect(tester.takeException(), isNull);
    });
  }

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
  Future<bool> shouldOfferHapticsPermission() async => false;
  @override
  Future<void> markHapticsPermissionOffered() async {}
  @override
  Future<bool> requestHapticsPermission() async => true;
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
