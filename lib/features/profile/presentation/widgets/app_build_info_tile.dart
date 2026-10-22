import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:entrena_ui/entrena_ui.dart';

import '../../../../core/config/app_build_info.dart';

class AppBuildInfoTile extends StatefulWidget {
  const AppBuildInfoTile({super.key, this.load = AppBuildInfo.load});

  final Future<AppBuildInfo> Function() load;

  @override
  State<AppBuildInfoTile> createState() => _AppBuildInfoTileState();
}

class _AppBuildInfoTileState extends State<AppBuildInfoTile> {
  late final Future<AppBuildInfo> _info = widget.load();

  Future<void> _showInfo(AppBuildInfo info) => showDialog<void>(
    context: context,
    builder: (dialogContext) => EntrenaDialog(
      title: const Text('Versión de EntrenaOP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(info.diagnosticText),
          const SizedBox(height: 16),
          const Text(
            'Estos datos identifican tu instalación. No se comprueba automáticamente si hay una versión más reciente.',
          ),
          const SizedBox(height: 20),
          EntrenaDialogActions(
            primaryLabel: 'Cerrar',
            onPrimary: () => Navigator.pop(dialogContext),
            secondary: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar datos de versión'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: info.diagnosticText),
                  );
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Datos de versión copiados.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      actions: const [],
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<AppBuildInfo>(
    future: _info,
    builder: (context, snapshot) => Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Versión de la app'),
        subtitle: Text(
          snapshot.data == null
              ? (snapshot.hasError
                    ? 'Versión no disponible'
                    : 'Consultando versión…')
              : '${snapshot.data!.versionLabel}\n${snapshot.data!.environment} · ${snapshot.data!.revisionLabel}',
        ),
        isThreeLine: snapshot.data != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: snapshot.data == null ? null : () => _showInfo(snapshot.data!),
      ),
    ),
  );
}
