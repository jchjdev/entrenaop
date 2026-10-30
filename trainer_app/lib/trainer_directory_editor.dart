import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:trainer_access/directory/domain.dart';
import 'package:trainer_access/directory/presentation.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_editor_ui/program_cover_image_draft.dart';

class TrainerDirectoryEditor extends StatefulWidget {
  const TrainerDirectoryEditor({
    super.key,
    required this.repository,
    required this.photo,
    required this.uploadPhoto,
    required this.discardPhoto,
    required this.cleanupPhotoDrafts,
  });
  final DirectoryRepository repository;
  final DirectoryPhotoLoader photo;
  final Future<String> Function(Uint8List, String) uploadPhoto;
  final Future<void> Function(String) discardPhoto;
  final Future<void> Function() cleanupPhotoDrafts;
  @override
  State<TrainerDirectoryEditor> createState() => _TrainerDirectoryEditorState();
}

class _TrainerDirectoryEditorState extends State<TrainerDirectoryEditor> {
  final _fields = List.generate(9, (_) => TextEditingController());
  DirectoryOwnerProfile? _state;
  DirectoryMode _mode = DirectoryMode.online;
  DirectoryVisibility _visibility = DirectoryVisibility.app;
  String? _photo, _savedPhoto, _error;
  bool _accepting = true,
      _published = false,
      _consent = false,
      _busy = false,
      _dirty = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _accept(DirectoryOwnerProfile state) {
    _state = state;
    final p = state.profile;
    final values = [
      p?.name ?? '',
      p?.description ?? '',
      p?.specialties.join(', ') ?? '',
      p?.services.join(', ') ?? '',
      p?.city ?? '',
      p?.email ?? '',
      p?.website ?? '',
      p?.whatsapp ?? '',
      p?.price ?? '',
    ];
    for (var i = 0; i < values.length; i++) {
      _fields[i].text = values[i];
    }
    _mode = p?.mode ?? DirectoryMode.online;
    _visibility = p?.visibility ?? DirectoryVisibility.app;
    _photo = p?.photoPath;
    _savedPhoto = _photo;
    _accepting = p?.accepting ?? true;
    _published = state.published;
    _consent = state.consent;
    _dirty = false;
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final value = await widget.repository.own();
      if (mounted) setState(() => _accept(value));
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    String? uploaded;
    try {
      final image = await pickProgramCoverImage();
      if (image == null) return;
      uploaded = await widget.uploadPhoto(image.card, const Uuid().v4());
      if (!mounted) {
        await widget.discardPhoto(uploaded);
        return;
      }
      final previous = _photo;
      setState(() {
        _photo = uploaded;
        _dirty = true;
        _error = null;
      });
      if (previous != null && previous != _savedPhoto) {
        try {
          await widget.discardPhoto(previous);
        } catch (_) {
          /* El cupo de servidor limita los archivos pendientes. */
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar fotos no guardadas'),
        content: const Text(
          'Se eliminarán las fotos subidas que no formen parte de tu ficha guardada, incluida una selección pendiente. La foto guardada se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.cleanupPhotoDrafts();
      if (mounted) {
        setState(() {
          _photo = _savedPhoto;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DirectoryProfile _draft() => DirectoryProfile(
    id: _state?.profile?.id ?? '',
    name: _fields[0].text.trim(),
    description: _fields[1].text.trim(),
    specialties: _fields[2].text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    services: _fields[3].text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    city: _fields[4].text.trim(),
    email: _fields[5].text.trim(),
    website: _fields[6].text.trim(),
    whatsapp: _fields[7].text.trim(),
    price: _fields[8].text.trim(),
    mode: _mode,
    visibility: _visibility,
    photoPath: _photo,
    accepting: _accepting,
  );
  Future<void> _save() async {
    if (_busy || _state == null) return;
    final profile = _draft();
    final error = profile.validate(publishing: _published, consent: _consent);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final previous = _savedPhoto;
    try {
      final value = await widget.repository.save(
        profile,
        revision: _state!.revision,
        published: _published,
        consent: _consent,
      );
      if (!mounted) return;
      setState(() => _accept(value));
      if (previous != null && previous != _photo) {
        try {
          await widget.discardPhoto(previous);
        } catch (_) {
          /* El guardado confirmado prevalece sobre la limpieza. */
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ficha guardada.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _dirty,
    isBusy: () => _busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Mi ficha del directorio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) Text(_error!),
              if (_state == null)
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Reintentar'),
                ),
              if (_state case final state?) ...[
                if (!state.enabled)
                  const Text(
                    'La publicación del directorio está en preparación. Puedes guardar tu ficha como borrador.',
                  ),
                if (!state.eligible)
                  const Text(
                    'Anunciarse requiere un plan profesional pagado con directorio incluido. El acceso manual o el plan básico no lo habilitan.',
                  ),
                if (state.blocked)
                  const Text(
                    'Ficha suspendida por moderación. Editarla no levanta la suspensión.',
                  ),
                const SizedBox(height: 12),
                DirectoryPhoto(
                  key: ValueKey(_photo),
                  path: _photo,
                  load: widget.photo,
                  size: 120,
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Elegir foto'),
                ),
                TextButton(
                  onPressed: _busy ? null : _cleanup,
                  child: const Text('Limpiar fotos no guardadas'),
                ),
                for (final entry in [
                  (0, 'Nombre profesional', 80, 1),
                  (1, 'Presentación', 1200, 5),
                  (
                    2,
                    'Especialidades o preparaciones (separadas por comas)',
                    480,
                    2,
                  ),
                  (3, 'Servicios (separados por comas)', 480, 2),
                  (4, 'Zona o localidad', 80, 1),
                  (5, 'Correo profesional de contacto', 254, 1),
                  (6, 'Web HTTPS', 500, 1),
                  (7, 'WhatsApp con prefijo, solo números', 15, 1),
                  (8, 'Precio orientativo (opcional)', 120, 1),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextField(
                      controller: _fields[entry.$1],
                      maxLength: entry.$3,
                      maxLines: entry.$4,
                      enabled: !_busy,
                      decoration: InputDecoration(labelText: entry.$2),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ),
                DropdownButtonFormField<DirectoryMode>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Modalidad'),
                  items: DirectoryMode.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _mode = v!;
                          _dirty = true;
                        }),
                ),
                DropdownButtonFormField<DirectoryVisibility>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Dónde quieres aparecer',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DirectoryVisibility.app,
                      child: Text('Solo dentro de la app'),
                    ),
                    DropdownMenuItem(
                      value: DirectoryVisibility.web,
                      child: Text('App y web pública'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _visibility = v!;
                          _consent = false;
                          _dirty = true;
                        }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Admito nuevos alumnos'),
                  value: _accepting,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _accepting = v;
                          _dirty = true;
                        }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Acepto publicar mi foto, presentación y contactos ${_visibility == DirectoryVisibility.web ? 'en la app y en la web pública, accesible sin cuenta' : 'dentro de la app para usuarios identificados'}. Puedo retirar la publicación.',
                  ),
                  value: _consent,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _consent = v!;
                          _dirty = true;
                        }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicar ficha'),
                  subtitle: const Text(
                    'Publicación directa con posibilidad de denuncia y revisión posterior.',
                  ),
                  value: _published,
                  onChanged:
                      _busy ||
                          (!state.eligible || !state.enabled) && !_published
                      ? null
                      : (v) => setState(() {
                          _published = v;
                          _dirty = true;
                        }),
                ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Guardar ficha'),
                ),
                TextButton(
                  onPressed: _busy || _dirty ? null : _load,
                  child: const Text('Actualizar estado'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
