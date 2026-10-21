import 'package:flutter/material.dart';

import 'catalog_search.dart';
import 'program_session_catalog.dart';

class ProgramSessionPicker extends StatefulWidget {
  const ProgramSessionPicker({
    super.key,
    required this.sessions,
    required this.statusBuilder,
    this.professional = false,
  });
  final List<ProgramSessionSummary> sessions;
  final Widget Function(ProgramSessionSummary?) statusBuilder;
  final bool professional;

  @override
  State<ProgramSessionPicker> createState() => _ProgramSessionPickerState();
}

class _ProgramSessionPickerState extends State<ProgramSessionPicker> {
  final _search = TextEditingController();
  bool _drafts = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.sessions
        .where(
          (s) =>
              s.status == (_drafts ? 'draft' : 'published') &&
              matchesCatalogSearch(_search.text, [
                s.name,
                s.isRunning ? 'Carrera' : 'Fuerza',
              ]),
        )
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.professional
                          ? 'Elegir sesión privada'
                          : 'Elegir sesión del catálogo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Buscar sesiones',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!widget.professional)
                          ChoiceChip(
                            label: const Text('Publicadas'),
                            selected: !_drafts,
                            onSelected: (_) => setState(() => _drafts = false),
                          ),
                        if (!widget.professional)
                          ChoiceChip(
                            label: const Text('Borradores'),
                            selected: _drafts,
                            onSelected: (_) => setState(() => _drafts = true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _drafts
                          ? 'Puedes incorporar un borrador y publicarlo con el programa. No crea otra copia.'
                          : 'Se reutiliza la versión seleccionada, sin crear otra copia.',
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No hay sesiones con esta búsqueda y estado.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final s = visible[index];
                  return ListTile(
                    title: Text(s.name),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Versión ${s.version} · ${s.isRunning ? 'Carrera' : 'Fuerza'}${_drafts ? ' · Revisar y publicar' : ''}',
                        ),
                        const SizedBox(height: 4),
                        widget.statusBuilder(s),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver al programa'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
