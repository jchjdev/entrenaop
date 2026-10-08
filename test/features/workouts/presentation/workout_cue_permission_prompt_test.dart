import 'dart:async';

import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_permission_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget page(_Cues cues, {double textScale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: WorkoutCuePermissionPrompt(
        cueService: cues,
        child: const Text('Sesión disponible'),
      ),
    ),
  );

  testWidgets('Ahora no permite continuar y no insiste al volver', (
    tester,
  ) async {
    final cues = _Cues();
    await tester.pumpWidget(page(cues));
    await tester.pumpAndSettle();
    expect(find.text('Avisos de la sesión'), findsOneWidget);
    expect(cues.requests, 0);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.text('Sesión disponible'), findsOneWidget);
    expect(cues.requests, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page(cues));
    await tester.pumpAndSettle();
    expect(find.text('Avisos de la sesión'), findsNothing);
    expect(cues.offers, 1);
  });

  testWidgets('Permitir solicita sin emitir sonido ni vibración', (
    tester,
  ) async {
    final cues = _Cues();
    await tester.pumpWidget(page(cues));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir avisos'));
    await tester.pumpAndSettle();
    expect(cues.requests, 1);
    expect(cues.signals, 0);
    expect(cues.previews, 0);
    expect(cues.saves, 0);
    expect(find.text('Avisos de la sesión'), findsNothing);
    expect(find.text('Sesión disponible'), findsOneWidget);
  });

  testWidgets('denegar en el sistema conserva la sesión y ofrece ayuda', (
    tester,
  ) async {
    final cues = _Cues()..allowed = false;
    await tester.pumpWidget(page(cues));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir avisos'));
    await tester.pumpAndSettle();
    expect(cues.requests, 1);
    expect(find.text('Sesión disponible'), findsOneWidget);
    expect(find.textContaining('Puedes seguir sin vibración.'), findsOneWidget);
    expect(cues.signals, 0);
  });

  testWidgets('no ofrece ni solicita si el servicio no necesita permiso', (
    tester,
  ) async {
    final cues = _Cues()..eligible = false;
    await tester.pumpWidget(page(cues));
    await tester.pumpAndSettle();
    expect(find.text('Avisos de la sesión'), findsNothing);
    expect(cues.offers, 0);
    expect(cues.requests, 0);
  });

  testWidgets(
    'salir durante la consulta no abre un diálogo fuera de la sesión',
    (tester) async {
      final query = Completer<bool>();
      final cues = _Cues()..query = query.future;
      await tester.pumpWidget(page(cues));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('Otra pantalla')));
      query.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(find.text('Avisos de la sesión'), findsNothing);
      expect(cues.offers, 0);
      expect(cues.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la explicación admite pantalla estrecha y texto doble', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cues = _Cues();
    await tester.pumpWidget(page(cues, textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ahora no'));
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.text('Avisos de la sesión'), findsNothing);
    expect(cues.requests, 0);
  });
}

class _Cues implements WorkoutCueService {
  bool eligible = true;
  bool offered = false;
  bool allowed = true;
  Future<bool>? query;
  int offers = 0;
  int requests = 0;
  int signals = 0;
  int previews = 0;
  int saves = 0;

  @override
  Future<bool> shouldOfferHapticsPermission() async =>
      query == null ? eligible && !offered : await query!;
  @override
  Future<void> markHapticsPermissionOffered() async {
    offered = true;
    offers++;
  }

  @override
  Future<bool> requestHapticsPermission() async {
    requests++;
    return allowed;
  }

  @override
  WorkoutCuePreferences get preferences => const WorkoutCuePreferences();
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> previewSound() async {
    previews++;
    return true;
  }

  @override
  Future<bool> previewHaptics() async {
    previews++;
    return true;
  }

  @override
  Future<void> savePreferences(WorkoutCuePreferences preferences) async =>
      saves++;
  @override
  Future<void> signal(WorkoutCue cue) async => signals++;
}
