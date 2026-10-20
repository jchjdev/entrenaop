import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_config.dart';

/// Solo códigos cerrados y contexto de pantalla; nunca excepción, traza, URL,
/// credencial ni contenido del formulario. Un fallo al informar se descarta.
class AdminErrorReporter {
  AdminErrorReporter({required this.send, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final Future<void> Function(String code, String component) send;
  final DateTime Function() _clock;
  final _last = <String, DateTime>{};
  bool _closed = false;
  VoidCallback? _detach;

  factory AdminErrorReporter.forClient(SupabaseClient client) =>
      AdminErrorReporter(
        send: (code, component) async {
          if (!AppConfig.isDevelopment ||
              AppConfig.supabaseUrl !=
                  'https://sxbxfjqgoddzhtcyhalw.supabase.co' ||
              client.auth.currentSession == null) {
            return;
          }
          await client.rpc(
            'report_admin_client_error',
            params: {
              'p_code': code,
              'p_component': component,
              'p_release': AppConfig.revision,
            },
          );
        },
      );

  Future<void> report(String code, String component) async {
    if (_closed ||
        !const {
          'framework_error',
          'unhandled_async',
          'network_error',
          'server_error',
        }.contains(code)) {
      return;
    }
    final group =
        const {
          'admin',
          'programs',
          'guided_programs',
          'sessions',
          'exercises',
          'warmups',
          'accounts',
          'operations',
        }.contains(component)
        ? component
        : 'admin';
    final key = '$code/$group';
    final when = _clock();
    final previous = _last[key];
    if (previous != null &&
        when.difference(previous) < const Duration(minutes: 1)) {
      return;
    }
    _last[key] = when;
    try {
      await send(code, group);
    } catch (_) {
      /* No crear otro error al informar del primero. */
    }
  }

  void attach(String Function() component) {
    final previousFramework = FlutterError.onError;
    final previousAsync = PlatformDispatcher.instance.onError;
    void framework(FlutterErrorDetails details) {
      unawaited(report('framework_error', component()));
      (previousFramework ?? FlutterError.presentError)(details);
    }

    bool asynchronous(Object error, StackTrace trace) {
      unawaited(report('unhandled_async', component()));
      return previousAsync?.call(error, trace) ?? false;
    }

    FlutterError.onError = framework;
    PlatformDispatcher.instance.onError = asynchronous;
    _detach = () {
      if (identical(FlutterError.onError, framework)) {
        FlutterError.onError = previousFramework;
      }
      if (identical(PlatformDispatcher.instance.onError, asynchronous)) {
        PlatformDispatcher.instance.onError = previousAsync;
      }
    };
  }

  void dispose() {
    _closed = true;
    _detach?.call();
  }
}
