import 'dart:async';

import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/core/navigation/workspace_navigation_scope.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_controller.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_scope.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/data/profile_name_repository.dart';
import 'package:entrenaop/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:entrenaop/features/profile/presentation/profile_photo_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trainer_access/profile_photo/domain.dart';

import '../../../support/coach_workspace_fixture.dart';

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'EntrenaOP',
      packageName: 'test.entrenaop',
      version: '1.0.0',
      buildNumber: '3',
      buildSignature: '',
    ),
  );

  testWidgets(
    'Perfil conserva identidad y Dispositivos sin cargar los datos de editar',
    (tester) async {
      final auth = await _auth();
      final birth = _BirthDateRepository()..fail = true;
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(home: ProfilePage(birthDateRepository: birth)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Javier'), findsOneWidget);
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Mi evolución'), findsOneWidget);
      expect(find.text('Dispositivos y conexiones'), findsOneWidget);
      expect(find.byTooltip('Ajustes'), findsOneWidget);
      expect(find.text('javier@example.com'), findsNothing);
      expect(find.textContaining('En EntrenaOP desde'), findsNothing);
      expect(find.text('Fecha de nacimiento'), findsNothing);
      expect(find.text('Mi suscripción'), findsNothing);
      expect(find.text('Versión de la app'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.text('Entrar como preparador'), findsNothing);
      expect(birth.loads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Perfil compacto conserva foto, editar, Evolución, dispositivos y Ajustes a texto doble',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = await _auth();
      final birth = _BirthDateRepository(DateTime(2000, 9, 11));
      final router = _router(birth: birth, photos: _Photos());
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Javier')).top,
        greaterThan(tester.getRect(find.byType(ProfilePhotoControl)).bottom),
      );
      expect(birth.loads, 0);
      await tester.tap(find.byTooltip('Cambiar foto de perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir foto'), findsOneWidget);
      Navigator.of(tester.element(find.text('Elegir foto'))).pop();
      await tester.pumpAndSettle();
      await _press(tester, 'Editar perfil');
      expect(router.state.uri.path, '/profile/edit');
      expect(find.text('javier@example.com'), findsOneWidget);
      expect(find.text('Fecha de nacimiento'), findsOneWidget);
      expect(
        tester.getRect(find.text('Fecha de nacimiento')).width,
        greaterThan(220),
      );
      expect(find.byType(ProfilePhotoControl), findsNothing);
      await _press(tester, 'Cambiar nombre');
      expect(find.text('Guardar nombre'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _press(tester, 'Cancelar');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');
      await _press(tester, 'Mi evolución');
      expect(router.state.uri.path, '/assessment/history');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _press(tester, 'Dispositivos y conexiones');
      expect(router.state.uri.path, '/profile/connections');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/settings');
      expect(find.text('Mi suscripción'), findsOneWidget);
      expect(find.text('Versión de la app'), findsOneWidget);
      expect(
        tester.getRect(find.text('Mi suscripción')).width,
        greaterThan(220),
      );
      expect(
        tester.getRect(find.text('Versión de la app')).width,
        greaterThan(220),
      );
      expect(
        tester.getRect(find.textContaining('compilación 3')).width,
        greaterThan(220),
      );
      expect(find.text('Dispositivos y conexiones'), findsNothing);
      await _press(tester, 'Mi suscripción');
      expect(router.state.uri.path, '/pro/subscription');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/settings');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guardar la fecha en Editar actualiza el dato sin un falso error',
    (tester) async {
      final auth = await _auth();
      final birth = _BirthDateRepository(DateTime(2000, 9, 11));
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(home: EditProfilePage(birthDateRepository: birth)),
        ),
      );
      await tester.pumpAndSettle();
      await _press(tester, 'Fecha de nacimiento');
      await _press(tester, 'OK');
      expect(birth.saveCalls, 1);
      expect(birth.loads, 2);
      expect(
        find.text('No se pudo guardar la fecha de nacimiento.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambiar identidad con el selector de fecha abierto no escribe en la otra cuenta',
    (tester) async {
      final repository = _AuthRepository();
      final auth = await _auth(repository);
      auth.watchAuthState();
      final birth = _BirthDateRepository(DateTime(2000, 9, 11));
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(home: EditProfilePage(birthDateRepository: birth)),
        ),
      );
      await tester.pumpAndSettle();
      await _press(tester, 'Fecha de nacimiento');
      repository.changes.add(
        AuthSessionChange(
          UserEntity(
            id: 'another',
            fullName: 'Ana',
            email: 'ana@example.com',
            role: 'user',
            createdAt: DateTime(2026, 9),
          ),
        ),
      );
      await tester.pump();
      await _press(tester, 'OK');
      expect(birth.saveCalls, 0);
      expect((auth.state as AuthAuthenticated).user.id, 'another');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editar bloquea salidas sólo mientras se guarda la fecha', (
    tester,
  ) async {
    final auth = await _auth();
    final pending = Completer<void>();
    final birth = _BirthDateRepository(DateTime(2000, 9, 11))
      ..pendingSave = pending;
    final router = _router(birth: birth);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await _press(tester, 'Editar perfil');
    await _press(tester, 'Fecha de nacimiento');
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(router.state.uri.path, '/profile/edit');
    router.go('/profile');
    await tester.pump();
    expect(router.state.uri.path, '/profile/edit');
    pending.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
    expect(birth.saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un error al cargar la fecha no oculta el nombre y puede reintentarse',
    (tester) async {
      final auth = await _auth();
      final birth = _BirthDateRepository()..fail = true;
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(
            home: EditProfilePage(
              birthDateRepository: birth,
              nameRepository: _Names(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Javier'), findsOneWidget);
      expect(find.text('Cambiar nombre'), findsOneWidget);
      expect(
        find.text('No pudimos cargar tu fecha de nacimiento'),
        findsOneWidget,
      );
      birth.fail = false;
      await _press(tester, 'No pudimos cargar tu fecha de nacimiento');
      expect(find.text('Fecha de nacimiento'), findsOneWidget);
      expect(birth.saveCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final enabled in [false, true]) {
    testWidgets(
      'acceso profesional y contador respetan habilitación $enabled',
      (tester) async {
        final auth = await _auth();
        final controller = CoachWorkspaceController(
          repository: FakeCoach()..enabled = enabled,
          security: FakeSecurity(),
        );
        await controller.refresh();
        addTearDown(controller.dispose);
        var entries = 0;
        await tester.pumpWidget(
          BlocProvider.value(
            value: auth,
            child: MaterialApp(
              home: WorkspaceNavigationScope(
                enterProfessional: () => entries++,
                returnToAthlete: () {},
                child: CoachWorkspaceScope(
                  controller: controller,
                  messages: FakeMessages(),
                  video: FakeVideo(),
                  child: ProfilePage(
                    birthDateRepository: _BirthDateRepository(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (enabled) {
          expect(find.text('2 novedades profesionales'), findsOneWidget);
          await _press(tester, 'Entrar como preparador');
          expect(entries, 1);
        } else {
          expect(find.text('Entrar como preparador'), findsNothing);
          expect(find.textContaining('novedades profesionales'), findsNothing);
          expect(entries, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('refluir Perfil conserva el control y su estado de foto', (
    tester,
  ) async {
    final auth = await _auth();
    final scale = ValueNotifier(1.0);
    addTearDown(scale.dispose);
    final photos = _Photos();
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(value)),
              child: child!,
            ),
          ),
          home: ProfilePage(
            birthDateRepository: _BirthDateRepository(),
            photoRepository: photos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final previous = tester.state(find.byType(ProfilePhotoControl));
    scale.value = 2;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ProfilePhotoControl)), same(previous));
    expect(photos.loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renovar sesión conserva nombre y estado de foto; otra cuenta lo descarta',
    (tester) async {
      final repository = _AuthRepository();
      final auth = await _auth(repository);
      final photos = _Photos();
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(
            home: ProfilePage(
              birthDateRepository: _BirthDateRepository(),
              photoRepository: photos,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final previous = tester.state(find.byType(ProfilePhotoControl));
      final pending = Completer<UserEntity?>();
      repository.onGet = () => pending.future;
      final refreshing = auth.checkCurrentUser();
      await tester.pump();
      expect(auth.state, isA<AuthLoading>());
      expect(find.text('Javier'), findsOneWidget);
      expect(tester.state(find.byType(ProfilePhotoControl)), same(previous));
      expect(photos.loads, 1);
      pending.complete(repository.user);
      await refreshing;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ProfilePhotoControl)), same(previous));
      repository
        ..onGet = null
        ..user = UserEntity(
          id: 'another',
          fullName: 'Ana',
          email: 'ana@example.com',
          role: 'user',
          createdAt: DateTime(2026, 10),
        );
      await auth.checkCurrentUser();
      await tester.pumpAndSettle();
      expect(find.text('Javier'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
      expect(
        tester.state(find.byType(ProfilePhotoControl)),
        isNot(same(previous)),
      );
      expect(photos.loads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renovar la sesión mantiene los datos visibles del editor', (
    tester,
  ) async {
    final repository = _AuthRepository();
    final auth = await _auth(repository);
    final birth = _BirthDateRepository(DateTime(2000, 9, 11));
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp(home: EditProfilePage(birthDateRepository: birth)),
      ),
    );
    await tester.pumpAndSettle();
    final pending = Completer<UserEntity?>();
    repository.onGet = () => pending.future;
    final refreshing = auth.checkCurrentUser();
    await tester.pump();
    expect(auth.state, isA<AuthLoading>());
    expect(find.text('Javier'), findsOneWidget);
    expect(find.text('javier@example.com'), findsOneWidget);
    expect(find.textContaining('11/09/2000'), findsOneWidget);
    expect(birth.loads, 1);
    pending.complete(repository.user);
    await refreshing;
    await tester.pumpAndSettle();
    expect(find.text('Javier'), findsOneWidget);
    expect(birth.loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cerrar sesión se conserva dentro de Ajustes', (tester) async {
    final repository = _AuthRepository();
    final auth = await _auth(repository);
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: const MaterialApp(home: ProfileSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _press(tester, 'Cerrar sesión');
    expect(repository.signOutCalls, 1);
    expect(auth.state, isA<AuthUnauthenticated>());
    expect(tester.takeException(), isNull);
  });
}

Future<void> _press(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<AuthCubit> _auth([_AuthRepository? repository]) async {
  final authRepository = repository ?? _AuthRepository();
  addTearDown(authRepository.changes.close);
  final cubit = AuthCubit(
    signInUseCase: SignInUseCase(authRepository),
    signUpUseCase: SignUpUseCase(authRepository),
    signOutUseCase: SignOutUseCase(authRepository),
    getCurrentUserUseCase: GetCurrentUserUseCase(authRepository),
    watchCurrentUserUseCase: WatchCurrentUserUseCase(authRepository),
  );
  await cubit.checkCurrentUser();
  addTearDown(cubit.close);
  return cubit;
}

GoRouter _router({required _BirthDateRepository birth, _Photos? photos}) {
  final exits = WorkflowExitRegistry();
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfilePage(
          birthDateRepository: birth,
          nameRepository: _Names(),
          photoRepository: photos,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            onExit: (_, state) => exits.requestExit(state.pageKey),
            builder: (_, state) => WorkflowExitScope(
              controller: exits.controller(state.pageKey),
              child: EditProfilePage(
                birthDateRepository: birth,
                nameRepository: _Names(),
              ),
            ),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, _) => const ProfileSettingsPage(),
          ),
          GoRoute(
            path: 'connections',
            builder: (_, _) =>
                Scaffold(appBar: AppBar(title: const Text('Tus dispositivos'))),
          ),
        ],
      ),
      GoRoute(
        path: '/assessment/history',
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Tu evolución')),
          body: const Text('Resultados y marcas'),
        ),
      ),
      GoRoute(
        path: '/pro/subscription',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(title: const Text('Suscripción'))),
      ),
    ],
  );
}

class _Names extends Fake implements ProfileNameRepository {
  @override
  Future<String> save(String ownerId, String name) async => name.trim();
}

class _Photos extends Fake implements ProfilePhotoRepository {
  int loads = 0;
  @override
  String get ownerId => 'user-1';
  @override
  Future<ProfilePhotoState> own() async {
    loads++;
    return const ProfilePhotoState(path: null, revision: 0);
  }
}

class _BirthDateRepository implements ProfileBirthDateRepository {
  _BirthDateRepository([this.value]);
  DateTime? value;
  int saveCalls = 0, loads = 0;
  bool fail = false;
  Completer<void>? pendingSave;
  @override
  Future<DateTime?> get() async {
    loads++;
    if (fail) throw StateError('Sin conexión');
    return value;
  }

  @override
  Future<void> save(DateTime birthDate) async {
    saveCalls++;
    await pendingSave?.future;
    value = birthDate;
  }
}

class _AuthRepository implements AuthRepository {
  final changes = StreamController<AuthSessionChange>.broadcast(sync: true);
  int signOutCalls = 0;
  Future<UserEntity?> Function()? onGet;
  UserEntity user = UserEntity(
    id: 'user-1',
    fullName: 'Javier',
    email: 'javier@example.com',
    role: 'user',
    createdAt: DateTime(2026, 9),
  );
  @override
  Future<UserEntity?> getCurrentUser() async => onGet?.call() ?? user;
  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => throw UnimplementedError();
  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Stream<AuthSessionChange> watchCurrentUser() => changes.stream;
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> updateRecoveredPassword(String password) async {}
  @override
  Future<void> finishPasswordRecovery() async {}
}
