import 'dart:async';

import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/login_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/sign_up_page.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RouterNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  RouterNotifier(AuthCubit authCubit) {
    _subscription = authCubit.stream.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

class AppRouter {
  final RouterNotifier _notifier;
  late final GoRouter config;

  AppRouter(AuthCubit authCubit) : _notifier = RouterNotifier(authCubit) {
    // Hace que `push` actualice también la URL web. Sin esta opción la pantalla
    // cambiaba, pero el navegador seguía mostrando /home.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    config = GoRouter(
      refreshListenable: _notifier,
      redirect: (context, state) {
        final authState = authCubit.state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isLoading = authState is AuthLoading || authState is AuthInitial;
        final isPublicRoute =
            state.matchedLocation == '/' || state.matchedLocation == '/sign-up';

        if (isLoading) return null;
        if (!isAuthenticated && !isPublicRoute) return '/';
        if (isAuthenticated && isPublicRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/sign-up',
          builder: (context, state) => const SignUpPage(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/assessment/initial',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<PhysicalAssessmentCubit>(),
            child: const InitialAssessmentPage(),
          ),
        ),
        GoRoute(
          path: '/assessment/history',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<PhysicalAssessmentHistoryCubit>(),
            child: const PhysicalAssessmentHistoryPage(),
          ),
        ),
      ],
    );
  }

  void dispose() {
    config.dispose();
    _notifier.dispose();
  }
}
