import 'package:flutter/material.dart';

import 'policy.dart';
import '../contact/policy.dart';

class DirectoryPrivacyButton extends StatelessWidget {
  const DirectoryPrivacyButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.privacy_tip_outlined),
    label: const Text('Privacidad y condiciones del directorio'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacidad y condiciones'),
        scrollable: true,
        content: const SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(directoryPrivacyInformation),
              SizedBox(height: 20),
              SelectableText(directoryPublicationConditions),
              SizedBox(height: 20),
              SelectableText(contactPrivacyInformation),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
}
