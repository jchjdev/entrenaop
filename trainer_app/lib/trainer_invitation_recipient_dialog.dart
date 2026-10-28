import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_invitation_link.dart';

class TrainerInvitationRecipientDialog extends StatefulWidget {
  const TrainerInvitationRecipientDialog({super.key});
  @override
  State<TrainerInvitationRecipientDialog> createState() => _RecipientState();
}

class _RecipientState extends State<TrainerInvitationRecipientDialog> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _email.text.trim().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invitar alumno'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Indica el correo que utiliza en EntrenaOP. Si aún no tiene cuenta, deberá registrarse con ese correo y confirmarlo.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 254,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Correo del alumno',
                ),
                validator: (value) =>
                    TrainerInvitationLink.validEmail((value ?? '').trim())
                    ? null
                    : 'Escribe un correo válido.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Crear enlace')),
    ],
  );
}
