import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/pages/login_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/sign_up_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el acceso móvil usa el wordmark y valida antes de enviar', (
    tester,
  ) async {
    await _setSurface(tester, const Size(390, 844));
    final repository = _FakeAuthRepository();
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit: cubit, child: const LoginPage()));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Te damos la bienvenida'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsNothing);
    await tester.tap(find.text('Entrar en EntrenaOP'));
    await tester.pump();

    expect(find.text('Introduce un correo válido.'), findsOneWidget);
    expect(find.text('Introduce tu contraseña.'), findsOneWidget);
    expect(repository.lastSignInEmail, isNull);
  });

  testWidgets('el acceso envía credenciales válidas', (tester) async {
    final repository = _FakeAuthRepository();
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, child: const LoginPage()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'persona@example.com');
    await tester.enterText(fields.at(1), 'clave-segura');
    await tester.tap(find.text('Entrar en EntrenaOP'));
    await tester.pump();

    expect(repository.lastSignInEmail, 'persona@example.com');
    expect(repository.lastSignInPassword, 'clave-segura');
  });

  testWidgets('el registro comparte la identidad en escritorio', (
    tester,
  ) async {
    await _setSurface(tester, const Size(1200, 820));
    final repository = _FakeAuthRepository();
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit: cubit, child: const SignUpPage()));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Tu preparación, más clara.'), findsOneWidget);
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Widget _app({required AuthCubit cubit, required Widget child}) {
  return BlocProvider<AuthCubit>.value(
    value: cubit,
    child: MaterialApp(theme: EntrenaTheme.dark, home: child),
  );
}

AuthCubit _createCubit(AuthRepository repository) {
  return AuthCubit(
    signInUseCase: SignInUseCase(repository),
    signUpUseCase: SignUpUseCase(repository),
    signOutUseCase: SignOutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
    watchCurrentUserUseCase: WatchCurrentUserUseCase(repository),
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? lastSignInEmail;
  String? lastSignInPassword;

  final _user = UserEntity(
    id: 'user-id',
    email: 'persona@example.com',
    role: 'free',
    createdAt: DateTime.utc(2026, 10, 3),
  );

  @override
  Future<UserEntity?> getCurrentUser() async => null;

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    return _user;
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async => SignUpConfirmationRequired(email);

  @override
  Future<void> signOut() async {}

  @override
  Stream<UserEntity?> watchCurrentUser() => const Stream.empty();
}
