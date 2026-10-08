import 'dart:async';

import 'package:entrenaop/core/config/app_config.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  runApp(EntrenaOpApp(authCubit: authCubit));
}

class EntrenaOpApp extends StatefulWidget {
  final AuthCubit authCubit;

  const EntrenaOpApp({super.key, required this.authCubit});

  @override
  State<EntrenaOpApp> createState() => _EntrenaOpAppState();
}

class _EntrenaOpAppState extends State<EntrenaOpApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authCubit);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    unawaited(widget.authCubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authCubit,
      child: MaterialApp.router(
        title: 'EntrenaOP',
        debugShowCheckedModeBanner: false,
        theme: EntrenaTheme.dark,
        routerConfig: _appRouter.config,
      ),
    );
  }
}
