import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'features/trainers/presentation/trainer_invitation_entry.dart';

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
import 'features/apple_watch/data/apple_training_adapters.dart';
import 'features/apple_watch/presentation/apple_results_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  // Supabase se suscribe primero: su retorno de Auth no se consume aquí.
  final invitationEntry = TrainerInvitationEntry();
  if (!kIsWeb) {
    final links = AppLinks();
    invitationEntry.attach(links.uriLinkStream);
    try {
      final initial = await links.getInitialLink().timeout(
        const Duration(seconds: 3),
      );
      if (initial != null) invitationEntry.receive(initial);
    } catch (_) {
      /* La escucha sigue disponible; no bloquea el acceso normal. */
    }
  }
  await initDependencies();

  final authCubit = sl<AuthCubit>();
  // El SDK emite initialSession y passwordRecovery. Otra consulta al arrancar
  // podría tratar el enlace de recuperación como un acceso normal.

  runApp(
    EntrenaOpApp(
      authCubit: authCubit,
      invitations: invitationEntry,
      appleResults: AppleResultsCoordinator(
        (owner) =>
            SupabaseAppleResultsRepository(Supabase.instance.client, owner),
        const NativeAppleResultsReader(),
      ),
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
  final TrainerInvitationEntry? invitations;
  final AppleResultsCoordinator? appleResults;

  const EntrenaOpApp({
    super.key,
    required this.authCubit,
    this.push,
    this.invitations,
    this.appleResults,
  });

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
    _appRouter = AppRouter(
      widget.authCubit,
      invitationEntry: widget.invitations,
      appleResults: widget.appleResults,
    );
    widget.invitations?.addListener(_openInvitation);
    WidgetsBinding.instance.addObserver(this);
    _pushOpens = widget.push?.opens.listen((_) => unawaited(_openPush()));
    _pushAuth = widget.authCubit.stream.listen(_syncPush);
    _syncPush(widget.authCubit.state);
  }

  void _openInvitation() {
    if (!mounted ||
        widget.invitations?.pending != true ||
        widget.authCubit.state is! AuthAuthenticated) {
      return;
    }
    _appRouter.config.go('/trainer-invitation');
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
    widget.appleResults?.setAccount(
      state is AuthAuthenticated ? state.user.id : null,
    );
    if (state is AuthAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInvitation());
    }
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
    widget.appleResults?.foreground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed && widget.push != null) {
      unawaited(widget.push!.refresh());
    }
  }

  @override
  void dispose() {
    widget.invitations?.removeListener(_openInvitation);
    widget.invitations?.dispose();
    _appRouter.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pushAuth?.cancel());
    unawaited(_pushOpens?.cancel());
    widget.push?.dispose();
    widget.appleResults?.dispose();
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
