import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/coach_mobile_fixture.dart';
import '../../support/coach_planning_fixture.dart';
import '../../support/coach_workspace_fixture.dart';

Future<GoRouter> mount(
  WidgetTester t,
  FakeCoachPlanning planning,
  String path, {
  FakeCoach? coach,
}) async {
  final router = createRouter(
    coach ?? CoachMobileFixture(),
    FakeSecurity(),
    planning: planning,
    initial: path,
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await t.pumpAndSettle();
  return router;
}

Future<void> tapText(WidgetTester t, String text) async {
  final candidates = find.text(text);
  final target = candidates.last;
  if (candidates.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'asignación preseleccionada conserva identidad y datos tras respuesta incierta',
    (t) async {
      final p = FakeCoachPlanning()..failAssignment = true;
      final router = await mount(
        t,
        p,
        '/coach/assign?client=isabel&session=template&day=2026-11-03',
      );
      await t.enterText(find.byType(TextField), 'Nota móvil');
      await tapText(t, 'Confirmar asignación');
      expect(p.assigned.length, 1);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
      await tapText(t, 'Reintentar');
      expect(p.assigned.length, 2);
      expect(p.assigned.first, p.assigned.last);
      expect(p.assigned.last['date'], '2026-11-03');
      expect(p.assigned.last['relation'], 'relation');
      expect(router.state.uri.path, '/coach');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'la ficha precarga alumno y la biblioteca vuelve con una única selección',
    (t) async {
      final p = FakeCoachPlanning();
      final router = await mount(t, p, '/coach/clients/isabel');
      await tapText(t, 'Asignar sesión');
      expect(router.state.uri.queryParameters['client'], 'isabel');
      await tapText(t, 'Elegir sesión');
      await tapText(t, 'Fuerza de piernas');
      await tapText(t, 'Usar esta sesión');
      expect(router.state.uri.path, '/coach/assign');
      expect(find.text('Elegir sesión'), findsNothing);
      await tapText(t, 'Confirmar asignación');
      expect(p.assigned.single['template'], 'template');
      expect(router.state.uri.path, '/coach/clients/isabel');
    },
  );
  testWidgets('Para mí usa su relación propia, no la de otro alumno', (
    t,
  ) async {
    final p = FakeCoachPlanning();
    await mount(t, p, '/coach/assign?session=template');
    await tapText(t, 'Elegir alumno');
    await tapText(t, 'Para mí · no ocupa plaza');
    await tapText(t, 'Confirmar asignación');
    expect(p.assigned.single['relation'], 'self-relation');
  });
  testWidgets('las notas conservan revisión y no se envían a conversación', (
    t,
  ) async {
    final p = FakeCoachPlanning();
    await mount(t, p, '/coach/notes/isabel');
    await t.enterText(find.byType(TextField).last, 'Nota privada nueva');
    await tapText(t, 'Guardar');
    expect(p.noteWrites.single['revision'], 7);
    expect(p.noteWrites.single['notes'], 'Nota privada nueva');
    expect(p.noteWrites.single['goal'], 'Coordinar fuerza y carrera');
  });
  testWidgets('crear cita usa la hora civil, zona y alumno elegidos', (
    t,
  ) async {
    final p = FakeCoachPlanning();
    await mount(t, p, '/coach/new-appointment?client=isabel&day=2026-11-03');
    await t.enterText(find.byType(TextField).first, 'Revisión presencial');
    await t.pumpAndSettle();
    await tapText(t, 'Guardar cita');
    expect(p.appointments.saved.length, 1);
    final a = p.appointments.saved.single;
    expect(a.relationId, 'relation');
    expect(a.minute, 540);
    expect(a.timezone, 'Europe/Madrid');
    expect(a.day, DateTime(2026, 11, 3));
  });
  testWidgets(
    'una cancelación incierta reintenta cancelar y nunca guarda la cita',
    (t) async {
      final p = FakeCoachPlanning();
      p.appointments.failCancel = true;
      await mount(t, p, '/coach/appointment/appointment');
      await tapText(t, 'Cancelar cita');
      await tapText(t, 'Cancelar cita');
      expect(p.appointments.cancelled, 1);
      await tapText(t, 'Reintentar');
      expect(p.appointments.cancelled, 2);
      expect(p.appointments.saved, isEmpty);
    },
  );
  testWidgets(
    'formulario se envía a la versión elegida y conserva las respuestas falsas',
    (t) async {
      final p = FakeCoachPlanning();
      final router = await mount(t, p, '/coach/send-form?client=isabel');
      await tapText(t, 'Seguimiento semanal');
      await tapText(t, 'Enviar al alumno');
      expect(p.sentForms.single['form'], 'form');
      expect(p.sentForms.single['relation'], 'relation');
      router.go('/coach/form/form-assignment');
      await t.pumpAndSettle();
      expect(find.text('No'), findsOneWidget);
    },
  );
  testWidgets(
    'biblioteca distingue origen y muestra los detalles del ejercicio',
    (t) async {
      final p = FakeCoachPlanning();
      await mount(t, p, '/coach/exercises');
      await tapText(t, 'Mi dominada');
      expect(find.text('Extiende los brazos.'), findsOneWidget);
      await t.tap(find.byType(BackButton).last);
      await t.pumpAndSettle();
      await tapText(t, 'EntrenaOP');
      expect(find.text('Dominada oficial'), findsOneWidget);
    },
  );
  testWidgets(
    'la agenda reúne citas y sesiones con alumno y permite añadir en la fecha seleccionada',
    (t) async {
      final p = FakeCoachPlanning();
      p.appointments.items = [p.appointments.row()];
      final router = await mount(t, p, '/coach/agenda');
      expect(find.text('Revisión presencial'), findsOneWidget);
      expect(find.text('Series de 400 m y técnica de carrera'), findsOneWidget);
      await t.tap(find.byTooltip('Añadir a la agenda'));
      await t.pumpAndSettle();
      await tapText(t, 'Asignar sesión guardada');
      expect(router.state.uri.path, '/coach/assign');
      expect(router.state.uri.queryParameters['day'], isNotNull);
    },
  );
  testWidgets(
    'sin acceso profesional no se monta la biblioteca ni se consulta',
    (t) async {
      final p = FakeCoachPlanning(), coach = FakeCoach()..enabled = false;
      await mount(t, p, '/coach/library', coach: coach);
      expect(p.reads, 0);
      expect(find.text('Fuerza de piernas'), findsNothing);
    },
  );
  testWidgets(
    'el borrador de asignación sobrevive al cambio de espacio sin enviar nada',
    (t) async {
      final p = FakeCoachPlanning();
      await mount(t, p, '/coach/assign?client=isabel&session=template');
      await t.enterText(find.byType(TextField), 'Indicaciones conservadas');
      await t.tap(find.text('Mi entrenamiento'));
      await t.pumpAndSettle();
      expect(p.assigned, isEmpty);
      await t.tap(find.text('Entrenador'));
      await t.pumpAndSettle();
      expect(find.text('Indicaciones conservadas'), findsOneWidget);
      expect(p.assigned, isEmpty);
    },
  );
  testWidgets(
    'mes, día y filtro de alumno conservan la selección y las tarjetas',
    (t) async {
      final p = FakeCoachPlanning();
      await mount(t, p, '/coach/agenda');
      await tapText(t, 'Mes');
      await t.scrollUntilVisible(
        find.text('Series de 400 m y técnica de carrera'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.pumpAndSettle();
      expect(find.text('Series de 400 m y técnica de carrera'), findsOneWidget);
      await t.tap(find.byTooltip('Filtros'));
      await t.pumpAndSettle();
      await tapText(t, 'Todos los alumnos');
      await tapText(t, 'Isabel Rodríguez Fernández');
      expect(find.text('Ver todos'), findsOneWidget);
      await tapText(t, 'Día');
      expect(find.text('Series de 400 m y técnica de carrera'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'el buscador de ejercicios admite teclado en un móvil de poca altura',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await mount(t, FakeCoachPlanning(), '/coach/exercises');
      await t.enterText(find.byType(TextField), 'dominada');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('planificación táctil a $width y texto $scale', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final p = FakeCoachPlanning();
        p.appointments.items = [p.appointments.row()];
        final router = createRouter(
          CoachMobileFixture(),
          FakeSecurity(),
          planning: p,
          initial: '/coach/agenda',
        );
        addTearDown(router.dispose);
        await t.pumpWidget(
          MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 47, bottom: 34),
              ),
              child: child!,
            ),
          ),
        );
        await t.pumpAndSettle();
        for (final route in [
          '/coach/agenda',
          '/coach/library',
          '/coach/exercises',
          '/coach/assign?client=isabel&session=template',
          '/coach/notes/isabel',
          '/coach/new-appointment?client=isabel',
          '/coach/send-form?client=isabel',
          '/coach/forms/isabel',
          '/coach/form/form-assignment',
        ]) {
          router.go(route);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: route);
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
