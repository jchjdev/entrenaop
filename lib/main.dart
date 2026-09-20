import 'dart:async';

import 'package:entrenaop/core/config/app_config.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
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
  unawaited(authCubit.checkCurrentUser());

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE65100),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routerConfig: _appRouter.config,
      ),
    );
  }
}
