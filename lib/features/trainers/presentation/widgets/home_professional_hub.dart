import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/student_notice_repository.dart';
import 'professional_resources.dart';

class HomeProfessionalHub extends StatefulWidget {
  const HomeProfessionalHub({
    super.key,
    required this.repository,
    required this.userId,
    required this.refreshVersion,
    required this.onOpen,
  });
  final StudentNoticeRepository repository;
  final String userId;
  final int refreshVersion;
  final Future<void> Function(String) onOpen;

  @override
  State<HomeProfessionalHub> createState() => _HomeProfessionalHubState();
}

class _HomeProfessionalHubState extends State<HomeProfessionalHub>
    with WidgetsBindingObserver {
  StudentNoticeSnapshot? _data;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeProfessionalHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.repository != widget.repository) {
      _data = null;
      _failed = false;
      _load();
    } else if (oldWidget.refreshVersion != widget.refreshVersion) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (GoRouter.maybeOf(context)?.state.uri.path ?? '/home') == '/home') {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final data = await widget.repository.snapshot();
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data?.resources.hasContent != true) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data?.resources.hasContent == true) ...[
            HomeSectionHeading(
              title: 'Con mi preparador',
              action: TextButton(
                onPressed: () => widget.onOpen('/my-trainer'),
                child: const Text('Ver seguimiento'),
              ),
            ),
            const SizedBox(height: 8),
            if (data!.unreadCount > 0)
              EntrenaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${data.unreadCount} ${data.unreadCount == 1 ? 'aviso sin leer' : 'avisos sin leer'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onOpen('/my-trainer'),
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('Consultar avisos'),
                    ),
                  ],
                ),
              ),
            ProfessionalResources(
              resources: data.resources,
              onOpen: widget.onOpen,
            ),
          ],
          if (_failed)
            EntrenaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('No se pudieron actualizar tus novedades.'),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar novedades'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
