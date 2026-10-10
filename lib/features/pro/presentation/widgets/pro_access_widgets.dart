import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pro_access.dart';
import '../../domain/pro_offer.dart';
import '../pages/pro_pages.dart';

typedef LoadProAccess = Future<ProAccess> Function();

/// No conserva concesiones locales ni convierte un fallo de consulta en Free.
class ProAccessBuilder extends StatefulWidget {
  const ProAccessBuilder({
    required this.load,
    required this.builder,
    this.showRefresh = false,
    super.key,
  });
  final LoadProAccess load;
  final Widget Function(BuildContext, ProAccess) builder;
  final bool showRefresh;
  @override
  State<ProAccessBuilder> createState() => _ProAccessBuilderState();
}

class _ProAccessBuilderState extends State<ProAccessBuilder>
    with WidgetsBindingObserver {
  late Future<ProAccess> _access;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  void _reload() {
    _access = Future.sync(widget.load);
  }

  @override
  void didUpdateWidget(covariant ProAccessBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProAccess>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No se ha podido comprobar tu acceso. Vuelve a intentarlo.',
            ),
            TextButton(
              onPressed: () => setState(_reload),
              child: const Text('Reintentar'),
            ),
          ],
        );
      }
      final content = widget.builder(context, snapshot.requireData);
      if (!widget.showRefresh) return content;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          TextButton(
            onPressed: () => setState(_reload),
            child: const Text('Actualizar acceso'),
          ),
        ],
      );
    },
  );
}

class ProAccessGate extends StatelessWidget {
  const ProAccessGate({
    required this.load,
    required this.child,
    this.offerContext = const ProOfferContext(),
    super.key,
  });
  final LoadProAccess load;
  final Widget child;
  final ProOfferContext offerContext;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ProAccessBuilder(
        load: load,
        builder: (_, access) =>
            access.isPro ? child : ProOfferPage(offerContext: offerContext),
      ),
    ),
  );
}

class PersonalQuotaBanner extends StatelessWidget {
  const PersonalQuotaBanner({
    required this.load,
    required this.sessions,
    super.key,
  });
  final LoadProAccess load;
  final bool sessions;
  @override
  Widget build(BuildContext context) => ProAccessBuilder(
    load: load,
    builder: (_, access) {
      final count = sessions
          ? access.personalSessions
          : access.personalExercises;
      final limit = sessions ? access.sessionLimit : access.exerciseLimit;
      final label = sessions ? 'Sesiones propias' : 'Ejercicios propios';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          limit == null
              ? '$label: $count · Pro'
              : '$label: $count/$limit · Free',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
    },
  );
}

Future<void> showProRestriction(
  BuildContext context,
  ProAccessDenied denied,
) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Amplía tu acceso con Pro'),
      content: Text(
        '${denied.message}\n\nTu borrador y lo que ya has guardado se conservan.',
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => context.pop(true),
          child: const Text('Ver Pro'),
        ),
      ],
    ),
  );
  if (open == true && context.mounted) await context.push('/pro');
}
