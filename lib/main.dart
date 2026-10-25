import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart' show EntrenaInputPolicy;

import 'package:entrenaop/core/config/app_config.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/navigation/app_back_gesture.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:uuid/uuid.dart';

import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/notifications/push_notifications.dart';
import 'features/notifications/push_data.dart';
import 'features/notifications/firebase_push_transport.dart';
import 'features/notifications/push_notifications_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  await initDependencies();

  final authCubit = sl<AuthCubit>();
  // El SDK emite initialSession y passwordRecovery. Otra consulta al arrancar
  // podría tratar el enlace de recuperación como un acceso normal.

  runApp(
    EntrenaOpApp(
      authCubit: authCubit,
      push: PushNotificationCoordinator(
        transport: FirebasePushTransport(),
        backend: SupabasePushBackend(Supabase.instance.client),
        store: LocalPushStore(),
        newId: const Uuid().v4,
      ),
    ),
  );
}

class EntrenaOpApp extends StatefulWidget {
  final AuthCubit authCubit;
  final PushNotificationCoordinator? push;

  const EntrenaOpApp({super.key, required this.authCubit, this.push});

  @override
  State<EntrenaOpApp> createState() => _EntrenaOpAppState();
}

class _EntrenaOpAppState extends State<EntrenaOpApp>
    with WidgetsBindingObserver {
  late final AppRouter _appRouter;
  StreamSubscription<AuthState>? _pushAuth;
  StreamSubscription<void>? _pushOpens;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authCubit);
    WidgetsBinding.instance.addObserver(this);
    _pushOpens = widget.push?.opens.listen((_) => unawaited(_openPush()));
    _pushAuth = widget.authCubit.stream.listen(_syncPush);
    _syncPush(widget.authCubit.state);
  }

  int _pushOpenRequest = 0;
  Future<void> _openPush() async {
    final request = ++_pushOpenRequest;
    final route = await widget.push?.routeForOpen();
    if (mounted &&
        request == _pushOpenRequest &&
        route != null &&
        widget.authCubit.state is AuthAuthenticated) {
      _appRouter.config.go(route);
    }
  }

  void _syncPush(AuthState state) {
    final push = widget.push;
    if (push == null) return;
    if (state is AuthAuthenticated) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user.id == state.user.id) {
        unawaited(
          push.setAccount(PushAccount(state.user.id, session!.accessToken)),
        );
      }
    } else if (state is AuthUnauthenticated || state is AuthPasswordRecovery) {
      unawaited(push.setAccount(null));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.push != null) {
      unawaited(widget.push!.refresh());
    }
  }

  @override
  void dispose() {
    _appRouter.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pushAuth?.cancel());
    unawaited(_pushOpens?.cancel());
    widget.push?.dispose();
    unawaited(widget.authCubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authCubit,
      child: PushNotificationsScope(
        coordinator: widget.push,
        child: MaterialApp.router(
          title: 'EntrenaOP',
          debugShowCheckedModeBanner: false,
          locale: const Locale('es', 'ES'),
          supportedLocales: const [Locale('es', 'ES')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: withAppBackGesture(EntrenaTheme.dark),
          builder: (context, child) => EntrenaInputPolicy(child: child!),
          routerConfig: _appRouter.config,
        ),
      ),
    );
  }
}
