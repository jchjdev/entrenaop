import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/native_running_health.dart';
import 'domain/local_running_health.dart';
import 'presentation/health_probe_cubit.dart';
import 'presentation/health_probe_page.dart';

void main() {
  final platform = kIsWeb
      ? LocalHealthPlatform.unsupported
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS => LocalHealthPlatform.appleHealth,
          TargetPlatform.android => LocalHealthPlatform.healthConnect,
          _ => LocalHealthPlatform.unsupported,
        };
  runApp(HealthProbeApp(source: NativeRunningHealth(platform: platform)));
}

class HealthProbeApp extends StatelessWidget {
  const HealthProbeApp({super.key, required this.source});
  final LocalRunningHealth source;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EntrenaOP · Ensayo Salud',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
    home: BlocProvider(
      create: (_) => HealthProbeCubit(source),
      child: const HealthProbePage(),
    ),
  );
}
