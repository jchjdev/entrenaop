import 'dart:async';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/data/profile_name_repository.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/profile_photo/domain.dart';

void main() {
  tearDown(sl.reset);

  Future<AppRouter> mount(
    WidgetTester tester,
    _Auth auth,
    _BirthDates birthDates, {
    String path = '/profile',
  }) async {
    sl.registerSingleton<ProfileBirthDateRepository>(birthDates);
    sl.registerSingleton<ProfileNameRepository>(_Names());
    sl.registerSingleton<ProfilePhotoRepository>(_Photos(auth));
    final router = AppRouter(auth);
    addTearDown(router.dispose);
    addTearDown(auth.close);
    router.config.go(path);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router.config,
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  void registerHistory() {
    sl.registerSingleton<PreparationGoalRepository>(_Goals());
    sl.registerFactory<WorkoutHistoryCubit>(_History.new);
  }

  for (final entry in [
    ('Preguntas frecuentes', 'help'),
    ('Notificaciones', 'notifications'),
    ('Informar de un problema', 'support'),
  ]) {
    testWidgets(
      'Ajustes abre ${entry.$2} con router real y conserva el retorno',
      (tester) async {
        final auth = _Auth();
        final dates = _BirthDates(auth);
        final router = await mount(
          tester,
          auth,
          dates,
          path: '/profile/settings',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(entry.$1));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(router.config.state.uri.path, '/profile/settings/${entry.$2}');
        expect(find.byKey(ValueKey('settings-${entry.$2}-A')), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(router.config.state.uri.path, '/profile/settings');
        expect(find.text('Cuenta y Pro'), findsOneWidget);
        expect(dates.reads, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'el borrador de soporte sobrevive a renovar A y se reinicia al cambiar a B',
    (tester) async {
      final auth = _Auth();
      final dates = _BirthDates(auth);
      await mount(tester, auth, dates, path: '/profile/settings/support');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Incidencia privada de A',
      );
      await tester.ensureVisible(find.text('Incluir datos de la instalación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incluir datos de la instalación'));
      await tester.pumpAndSettle();
      final original = tester.element(
        find.byKey(const ValueKey('settings-support-A')),
      );
      auth.loading();
      await tester.pump();
      auth.setUser('A', renewed: true);
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey('settings-support-A'))),
        same(original),
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Incidencia privada de A',
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      auth.setUser('B');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-support-A')), findsNothing);
      expect(find.byKey(const ValueKey('settings-support-B')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.text('Incidencia privada de A'), findsNothing);
      expect(dates.reads, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final path in ['/privacy', '/terms']) {
    testWidgets(
      '$path es público y no consulta datos privados al entrar como invitado',
      (tester) async {
        final auth = _Auth()..guest();
        final dates = _BirthDates(auth);
        final router = await mount(tester, auth, dates, path: path);
        await tester.pumpAndSettle();
        expect(router.config.state.uri.path, path);
        expect(
          find.text(path == '/privacy' ? 'Privacidad' : 'Condiciones de uso'),
          findsWidgets,
        );
        expect(find.text('Deportista A'), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(dates.reads, isEmpty);
        expect((sl<ProfilePhotoRepository>() as _Photos).reads, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Ajustes vuelve a Perfil y los dispositivos siguen a mano', (
    tester,
  ) async {
    final auth = _Auth();
    final dates = _BirthDates(auth);
    final router = await mount(tester, auth, dates);
    await tester.pumpAndSettle();
    expect(find.text('Dispositivos y conexiones'), findsOneWidget);
    expect(find.text('Mi suscripción'), findsNothing);
    expect(dates.reads, isEmpty);

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(router.config.state.uri.path, '/profile/settings');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Mi suscripción'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Dispositivos y conexiones'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.config.state.uri.path, '/profile');
    expect(find.text('Dispositivos y conexiones'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(dates.reads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editar perfil conserva su origen y carga los datos allí', (
    tester,
  ) async {
    final auth = _Auth();
    final dates = _BirthDates(auth);
    final router = await mount(tester, auth, dates);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar perfil'));
    await tester.pump();
    await tester.pump();
    expect(router.config.state.uri.path, '/profile/edit');
    expect(dates.reads, ['A']);
    dates.pending['A']!.complete(DateTime(1992, 6, 15));
    await tester.pumpAndSettle();
    expect(find.textContaining('15-06-1992'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.config.state.uri.path, '/profile');
    expect(find.text('Mi evolución'), findsOneWidget);
    expect(find.text('Dispositivos y conexiones'), findsOneWidget);
    expect(dates.reads, ['A']);
    expect(tester.takeException(), isNull);
  });

  for (final path in ['/profile/settings', '/profile/edit']) {
    testWidgets('enlace directo $path vuelve a Perfil', (tester) async {
      final auth = _Auth();
      final dates = _BirthDates(auth);
      final router = await mount(tester, auth, dates, path: path);
      if (path.endsWith('/edit')) {
        dates.pending['A']!.complete(DateTime(1992, 6, 15));
      }
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile');
      expect(find.text('Dispositivos y conexiones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Ajustes conserva la renovación y descarta la cuenta anterior', (
    tester,
  ) async {
    final auth = _Auth();
    final dates = _BirthDates(auth);
    final router = await mount(tester, auth, dates, path: '/profile/settings');
    await tester.pumpAndSettle();
    final before = tester.element(find.byKey(const ValueKey('settings-A')));
    auth.loading();
    await tester.pump();
    auth.setUser('A', renewed: true);
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byKey(const ValueKey('settings-A'))),
      same(before),
    );
    auth.setUser('B');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-A')), findsNothing);
    expect(find.byKey(const ValueKey('settings-B')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.config.state.uri.path, '/profile');
    expect(find.text('Deportista B'), findsOneWidget);
    expect(find.text('Deportista A'), findsNothing);
    expect(dates.reads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Perfil vuelve de Evolución conservando su pantalla sin cargar datos del editor',
    (tester) async {
      registerHistory();
      final auth = _Auth();
      final dates = _BirthDates(auth);
      final router = await mount(tester, auth, dates);
      await tester.pumpAndSettle();
      final profile = find.byKey(
        const ValueKey('profile-A'),
        skipOffstage: false,
      );
      final originalElement = tester.element(profile);
      await tester.ensureVisible(find.text('Mi evolución'));
      await tester.tap(find.text('Mi evolución'));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/assessment/history');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump();
      expect(router.config.state.uri.path, '/profile');
      await tester.pumpAndSettle();
      expect(tester.element(profile), same(originalElement));
      expect(dates.reads, isEmpty);
      expect(find.text('Deportista A'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enlace directo a Evolución permite volver a Perfil', (
    tester,
  ) async {
    registerHistory();
    final auth = _Auth();
    final dates = _BirthDates(auth);
    final router = await mount(
      tester,
      auth,
      dates,
      path: '/assessment/history',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(router.config.state.uri.path, '/profile');
    expect(find.text('Deportista A'), findsOneWidget);
    expect(dates.reads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renovar la misma cuenta conserva la lectura y otra identidad descarta su respuesta tardía',
    (tester) async {
      final auth = _Auth();
      final dates = _BirthDates(auth);
      await mount(tester, auth, dates, path: '/profile/edit');
      expect(dates.reads, ['A']);

      auth.loading();
      await tester.pump();
      auth.setUser('A', renewed: true);
      await tester.pump();
      expect(dates.reads, ['A']);

      auth.setUser('B');
      await tester.pump();
      await tester.pump();
      expect(dates.reads, ['A', 'B']);
      expect(find.text('Deportista B'), findsOneWidget);
      expect(find.text('Deportista A'), findsNothing);

      dates.pending['B']!.complete(DateTime(2001, 8, 12));
      await tester.pumpAndSettle();
      expect(find.textContaining('12-08-2001'), findsOneWidget);
      dates.pending['A']!.complete(DateTime(1992, 6, 15));
      await tester.pumpAndSettle();
      expect(find.textContaining('15-06-1992'), findsNothing);
      expect(find.textContaining('12-08-2001'), findsOneWidget);
      expect(dates.reads, ['A', 'B']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cambiar de cuenta no conserva el error del perfil anterior', (
    tester,
  ) async {
    final auth = _Auth();
    final dates = _BirthDates(auth);
    await mount(tester, auth, dates, path: '/profile/edit');
    dates.pending['A']!.completeError(
      StateError('Error de la cuenta anterior'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos cargar tu fecha de nacimiento'),
      findsOneWidget,
    );

    auth.setUser('B');
    await tester.pump();
    await tester.pump();
    expect(dates.reads, ['A', 'B']);
    expect(find.text('No pudimos cargar tu fecha de nacimiento'), findsNothing);
    dates.pending['B']!.complete(DateTime(1996, 3, 7));
    await tester.pumpAndSettle();
    expect(find.textContaining('07-03-1996'), findsOneWidget);
    expect(find.text('No pudimos cargar tu fecha de nacimiento'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(_state('A'));
  String owner = 'A';

  void loading() => emit(AuthLoading());
  void guest() => emit(AuthUnauthenticated());

  void setUser(String id, {bool renewed = false}) {
    owner = id;
    emit(_state(id, renewed: renewed));
  }

  static AuthAuthenticated _state(String id, {bool renewed = false}) =>
      AuthAuthenticated(
        user: UserEntity(
          id: id,
          fullName: 'Deportista $id',
          email: '${renewed ? 'renovado' : id}@example.test',
          role: 'user',
          createdAt: DateTime(2026, 10, 1),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BirthDates implements ProfileBirthDateRepository {
  _BirthDates(this.auth);
  final _Auth auth;
  final reads = <String>[];
  final pending = <String, Completer<DateTime?>>{};

  @override
  Future<DateTime?> get() {
    final owner = auth.owner;
    reads.add(owner);
    return (pending[owner] ??= Completer<DateTime?>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Names implements ProfileNameRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Photos implements ProfilePhotoRepository {
  _Photos(this.auth);
  final _Auth auth;
  final reads = <String>[];

  @override
  String get ownerId => auth.owner;

  @override
  Future<ProfilePhotoState> own() async {
    reads.add(auth.owner);
    return const ProfilePhotoState(path: null, revision: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Goals implements PreparationGoalRepository {
  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _History extends Cubit<WorkoutHistoryState>
    implements WorkoutHistoryCubit {
  _History()
    : super(const WorkoutHistoryState(status: WorkoutHistoryStatus.loaded));

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
