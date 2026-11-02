import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../domain/app_support.dart';

class ProfileSupportPage extends StatefulWidget {
  const ProfileSupportPage({
    required this.resources,
    required this.openLink,
    required this.loadDiagnostic,
    super.key,
  });
  final AppSupportResources resources;
  final OpenSupportLink openLink;
  final Future<String> Function() loadDiagnostic;
  @override
  State<ProfileSupportPage> createState() => _ProfileSupportPageState();
}

class _ProfileSupportPageState extends State<ProfileSupportPage> {
  final _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _includeDiagnostic = false, _busy = false;
  String? _error, _message;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final diagnostic = _includeDiagnostic
          ? await widget.loadDiagnostic()
          : null;
      if (!mounted) return;
      final opened = await widget.openLink(
        widget.resources.reportUri(_description.text, diagnostic: diagnostic),
      );
      if (!mounted) return;
      setState(() {
        if (opened) {
          _message = 'Revisa el borrador en tu aplicación de correo y envíalo cuando quieras.';
        } else {
          _error =
              'No hemos podido abrir tu aplicación de correo. Puedes copiar el mensaje y enviarlo a ${widget.resources.email}.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No hemos podido preparar el correo. Conservamos tu mensaje para que puedas reintentarlo o copiarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Informar de un problema'),
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile/settings'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: EntrenaCard(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cuéntanos qué ha pasado',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Indica en qué pantalla estabas, qué intentabas hacer y qué ocurrió. Se abrirá un borrador que podrás revisar antes de enviarlo.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _description,
                        enabled: !_busy,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          labelText: 'Tu mensaje',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Cuéntanos el problema antes de preparar el correo.'
                            : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _includeDiagnostic,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _includeDiagnostic = value ?? false,
                              ),
                        title: const Text('Incluir datos de la instalación'),
                        subtitle: const Text(
                          'Versión de EntrenaOP y plataforma. No incluye entrenamientos, mensajes ni credenciales.',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, semanticsLabel: _error),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _prepare,
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: Text(_busy ? 'Preparando…' : 'Preparar correo'),
                      ),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        '${widget.resources.email}\n\n${_description.text}',
                                  ),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Contacto y mensaje copiados.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copiar contacto y mensaje'),
                      ),
                      SelectableText(
                        widget.resources.email,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
