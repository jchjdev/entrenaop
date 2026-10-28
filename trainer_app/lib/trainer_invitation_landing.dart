import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trainer_access/trainer_invitation_link.dart';
import 'package:url_launcher/url_launcher.dart';

/// Página pública sin lecturas de cuentas ni datos del preparador.
class TrainerInvitationLanding extends StatefulWidget {
  const TrainerInvitationLanding({super.key, required this.secret, this.open});
  final String? secret;
  final Future<bool> Function(Uri)? open;
  @override
  State<TrainerInvitationLanding> createState() =>
      _TrainerInvitationLandingState();
}

class _TrainerInvitationLandingState extends State<TrainerInvitationLanding> {
  String? _notice;
  bool _busy = false;
  Future<void> _open() async {
    final code = widget.secret;
    if (_busy || code == null) return;
    setState(() => _busy = true);
    try {
      final uri = TrainerInvitationLink.openApp(code);
      final opened =
          await (widget.open?.call(uri) ??
              launchUrl(uri, webOnlyWindowName: '_self'));
      if (mounted) {
        setState(
          () => _notice = opened
              ? 'Si no se abre, comprueba que tienes una versión actualizada de EntrenaOP.'
              : 'No se pudo abrir EntrenaOP. Si aún no tienes la beta, pídele acceso a tu preparador.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'No se pudo abrir la app desde este navegador. Prueba a abrir este enlace en el navegador del teléfono.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EntrenaOP')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.person_add_alt_1, size: 56),
            const SizedBox(height: 20),
            Text(
              widget.secret == null
                  ? 'Invitación incompleta'
                  : 'Tu preparador te invita a EntrenaOP',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (widget.secret == null)
              const Text(
                'Pide al preparador que te vuelva a enviar el enlace completo.',
              )
            else ...[
              const Text(
                'Ábrela en la app, entra con el correo al que te invitaron y revisa quién te invita. Solo os vincularemos cuando aceptes.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _open,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir EntrenaOP'),
              ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_notice!),
                ),
              const SizedBox(height: 20),
              const Text(
                '¿Todavía no tienes la app?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'EntrenaOP está en pruebas. Pide al preparador el acceso a la beta. Después de instalarla, vuelve a este enlace.',
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Si tu versión no abre el enlace'),
                children: [
                  const Text(
                    'En la app: Perfil → Mi preparador → Código de invitación. Puedes usar el código de respaldo de esta invitación.',
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.secret!),
                      );
                      if (mounted) {
                        setState(
                          () => _notice =
                              'Código copiado. Pégalo en la app con tu cuenta.',
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar código de respaldo'),
                  ),
                ],
              ),
              const Text(
                'La invitación caduca a los siete días de su creación. Si ya se usó o se canceló, pide otra.',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
