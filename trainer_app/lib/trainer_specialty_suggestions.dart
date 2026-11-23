import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/directory/domain.dart';

class TrainerSpecialtySuggestions extends StatefulWidget {
  const TrainerSpecialtySuggestions({super.key, required this.repository});
  final DirectorySpecialtySuggestions repository;

  @override
  State<TrainerSpecialtySuggestions> createState() =>
      _TrainerSpecialtySuggestionsState();
}

class _TrainerSpecialtySuggestionsState
    extends State<TrainerSpecialtySuggestions> {
  late var _suggestions = widget.repository.mySpecialtySuggestions();

  void _reload() =>
      setState(() => _suggestions = widget.repository.mySpecialtySuggestions());

  Future<void> _suggest() async {
    var name = '', details = '';
    final form = GlobalKey<FormState>();
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetainedSaveDialog<bool>(
        save: (_) => widget.repository.suggestSpecialty(name, details),
        errorMessage: 'No se pudo enviar. Comprueba si la especialidad ya está en la lista o reintenta.',
        builder: (context, submit, saving, error, markDirty) => AlertDialog(
          scrollable: true,
          title: const Text('Sugerir una especialidad'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Revisaremos si encaja en el directorio. Podrás ver la respuesta aquí.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la especialidad',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Escribe un nombre.'
                        : null,
                    onChanged: (v) {
                      name = v.trim();
                      markDirty(name.isNotEmpty || details.isNotEmpty);
                    },
                  ),
                  TextFormField(
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Qué ofreces (opcional)',
                    ),
                    onChanged: (v) {
                      details = v.trim();
                      markDirty(name.isNotEmpty || details.isNotEmpty);
                    },
                  ),
                  if (error != null) Text(error),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () {
                      if (form.currentState!.validate()) submit(true);
                    },
              child: const Text('Enviar sugerencia'),
            ),
          ],
        ),
      ),
    );
    if (sent == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: _suggest,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Sugerir una especialidad'),
      ),
      FutureBuilder<List<DirectorySpecialtySuggestion>>(
        future: _suggestions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: _reload,
              child: const Text('Reintentar consulta de sugerencias'),
            );
          }
          final suggestions = snapshot.data ?? const [];
          if (suggestions.isEmpty) return const SizedBox.shrink();
          return ExpansionTile(
            title: const Text('Mis sugerencias'),
            initiallyExpanded: suggestions.any(
              (item) => item.state != SpecialtySuggestionState.pending,
            ),
            subtitle: Text(
              '${suggestions.where((item) => item.state != SpecialtySuggestionState.pending).length} respondidas',
            ),
            tilePadding: EdgeInsets.zero,
            children: [
              for (final item in suggestions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    [
                      switch (item.state) {
                        SpecialtySuggestionState.pending =>
                          'Pendiente de revisión',
                        SpecialtySuggestionState.approved =>
                          'Aprobada como ${item.approvedName}. Ya puedes marcarla en tu ficha.',
                        SpecialtySuggestionState.declined => 'No aprobada',
                      },
                      if (item.note.isNotEmpty) item.note,
                    ].join('\n'),
                  ),
                ),
              TextButton(
                onPressed: _reload,
                child: const Text('Actualizar sugerencias'),
              ),
            ],
          );
        },
      ),
    ],
  );
}
