import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_client_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> mount(
  WidgetTester t, {
  bool direct = false,
  Future<bool> Function()? canLeave,
}) async {
  final reflect = GoRouter.optionURLReflectsImperativeAPIs;
  GoRouter.optionURLReflectsImperativeAPIs = true;
  addTearDown(() => GoRouter.optionURLReflectsImperativeAPIs = reflect);
  final router = GoRouter(
    initialLocation: direct ? '/clients/ana/workouts' : '/agenda',
    routes: [
      GoRoute(
        path: '/agenda',
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Semana original de Agenda')),
          body: TextButton(
            onPressed: () => context.push('/clients/ana/workouts'),
            child: const Text('Abrir Ana'),
          ),
        ),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            TrainerClientNavigation.wrap(state.uri, child),
        routes: [
          GoRoute(
            path: '/clients/:id/workouts',
            onExit: (_, _) => canLeave?.call() ?? Future.value(true),
            builder: (_, _) => const Scaffold(body: Text('Calendario de Ana')),
          ),
          GoRoute(
            path: '/clients/:id/goals',
            builder: (_, _) => const Scaffold(body: Text('Objetivos de Ana')),
          ),
          GoRoute(
            path: '/clients/:id',
            builder: (_, _) => const Scaffold(body: Text('Notas de Ana')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await t.pumpAndSettle();
  if (!direct) {
    await t.tap(find.text('Abrir Ana'));
    await t.pumpAndSettle();
  }
  return router;
}

void main() {
  testWidgets(
    'cambiar áreas sustituye la ficha sin perder la agenda de origen',
    (t) async {
      final router = await mount(t);
      await t.tap(find.text('Objetivos'));
      await t.pumpAndSettle();
      expect(find.text('Objetivos de Ana'), findsOneWidget);
      await t.ensureVisible(find.text('Notas'));
      await t.tap(find.text('Notas'));
      await t.pumpAndSettle();
      expect(find.text('Notas de Ana'), findsOneWidget);
      router.pop();
      await t.pumpAndSettle();
      expect(find.text('Semana original de Agenda'), findsOneWidget);
    },
  );
  testWidgets('la sustitución respeta la guarda de salida de la ficha', (
    t,
  ) async {
    var leave = false;
    await mount(t, canLeave: () async => leave);
    await t.tap(find.text('Objetivos'));
    await t.pumpAndSettle();
    expect(find.text('Calendario de Ana'), findsOneWidget);
    expect(find.text('Objetivos de Ana'), findsNothing);
    leave = true;
    await t.tap(find.text('Objetivos'));
    await t.pumpAndSettle();
    expect(find.text('Objetivos de Ana'), findsOneWidget);
  });
  testWidgets(
    'una entrada directa cambia de área sin fabricar una agenda anterior',
    (t) async {
      final router = await mount(t, direct: true);
      await t.tap(find.text('Objetivos'));
      await t.pumpAndSettle();
      expect(find.text('Objetivos de Ana'), findsOneWidget);
      expect(router.canPop(), isFalse);
    },
  );
}
