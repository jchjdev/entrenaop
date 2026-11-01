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
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/data/profile_name_repository.dart';
import 'package:entrenaop/features/profile/presentation/profile_photo_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/profile_photo/domain.dart';

void main() {
  testWidgets(
    'guardar la fecha actualiza el perfil sin mostrar un falso error',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final authRepository = _AuthRepository();
      final authCubit = AuthCubit(
        signInUseCase: SignInUseCase(authRepository),
        signUpUseCase: SignUpUseCase(authRepository),
        signOutUseCase: SignOutUseCase(authRepository),
        getCurrentUserUseCase: GetCurrentUserUseCase(authRepository),
        watchCurrentUserUseCase: WatchCurrentUserUseCase(authRepository),
      );
      await authCubit.checkCurrentUser();
      addTearDown(authCubit.close);
      final birthDateRepository = _BirthDateRepository(DateTime(2000, 9, 11));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: BlocProvider.value(
            value: authCubit,
            child: ProfilePage(birthDateRepository: birthDateRepository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fecha de nacimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(birthDateRepository.saveCalls, 1);
      expect(
        find.text('No se pudo guardar la fecha de nacimiento.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Perfil conserva identidad y cuenta y aloja Evolución sin duplicar Entrenar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final authRepository = _AuthRepository();
      final authCubit = AuthCubit(
        signInUseCase: SignInUseCase(authRepository),
        signUpUseCase: SignUpUseCase(authRepository),
        signOutUseCase: SignOutUseCase(authRepository),
        getCurrentUserUseCase: GetCurrentUserUseCase(authRepository),
        watchCurrentUserUseCase: WatchCurrentUserUseCase(authRepository),
      );
      await authCubit.checkCurrentUser();
      addTearDown(authCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: BlocProvider.value(
            value: authCubit,
            child: ProfilePage(birthDateRepository: _BirthDateRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Javier'), findsOneWidget);
      expect(find.text('javier@example.com'), findsOneWidget);
      expect(find.text('Mi evolución'), findsOneWidget);
      expect(find.text('Mis preparaciones'), findsNothing);
      expect(find.text('Disponibilidad y material'), findsNothing);
      expect(find.text('Mi preparador'), findsNothing);
      expect(find.text('Herramientas para tus pruebas'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Free'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Evolución abre su destino y volver recupera Perfil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _AuthRepository();
    final auth = AuthCubit(
      signInUseCase: SignInUseCase(repository),
      signUpUseCase: SignUpUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      watchCurrentUserUseCase: WatchCurrentUserUseCase(repository),
    );
    await auth.checkCurrentUser();
    addTearDown(auth.close);
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => ProfilePage(
            birthDateRepository: _BirthDateRepository(DateTime(2000, 9, 11)),
            nameRepository: _Names(),
            photoRepository: _Photos(),
          ),
        ),
        GoRoute(
          path: '/assessment/history',
          builder: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Tu evolución')),
            body: const Text('Resultados y marcas'),
          ),
        ),
      ],
    );
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
    expect(tester.takeException(), isNull, reason: 'Perfil con texto ampliado');
    await tester.tap(find.text('Cambiar nombre'));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Editor del nombre ampliado',
    );
    expect(find.text('Guardar nombre'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cambiar foto de perfil'));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Opciones de foto ampliadas',
    );
    expect(find.text('Elegir foto'), findsOneWidget);
    Navigator.of(tester.element(find.text('Elegir foto'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mi evolución'));
    expect(
      tester.getRect(find.text('Historial, resultados y marcas')).width,
      greaterThan(200),
    );
    await tester.tap(find.text('Mi evolución'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/assessment/history');
    expect(find.text('Resultados y marcas'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
    expect(find.text('Javier'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Names extends Fake implements ProfileNameRepository {
  @override
  Future<String> save(String ownerId, String name) async => name.trim();
}

class _Photos extends Fake implements ProfilePhotoRepository {
  @override
  String get ownerId => 'user-1';

  @override
  Future<ProfilePhotoState> own() async =>
      const ProfilePhotoState(path: null, revision: 0);
}

class _BirthDateRepository implements ProfileBirthDateRepository {
  _BirthDateRepository([this.value]);

  DateTime? value;
  int saveCalls = 0;

  @override
  Future<DateTime?> get() async => value;

  @override
  Future<void> save(DateTime birthDate) async {
    saveCalls++;
    value = birthDate;
  }
}

class _AuthRepository implements AuthRepository {
  @override
  Future<UserEntity?> getCurrentUser() async => UserEntity(
    id: 'user-1',
    fullName: 'Javier',
    email: 'javier@example.com',
    role: 'user',
    createdAt: DateTime(2026, 9),
  );

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
  Future<void> signOut() async {}

  @override
  Stream<AuthSessionChange> watchCurrentUser() => const Stream.empty();
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> updateRecoveredPassword(String password) async {}
  @override
  Future<void> finishPasswordRecovery() async {}
}
