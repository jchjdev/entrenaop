import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';
import 'package:flutter/material.dart';
import 'package:workout_editor_ui/program_cover_image_draft.dart';

class ProgramCoverEditor extends StatefulWidget {
  const ProgramCoverEditor({
    super.key,
    required this.programId,
    required this.programName,
    required this.repository,
    this.pickImage,
  });
  final String programId, programName;
  final ProgramCoverRepository repository;
  final Future<ProgramCoverImageDraft?> Function()? pickImage;
  @override
  State<ProgramCoverEditor> createState() => _ProgramCoverEditorState();
}

class _ProgramCoverEditorState extends State<ProgramCoverEditor> {
  ProgramCover? _cover;
  ProgramCoverImageDraft? _draft;
  bool _loading = true,
      _busy = false,
      _dirty = false,
      _remove = false,
      _desktop = false,
      _conflict = false;
  double _x = 0.5, _y = 0.5, _headerX = 0.5, _headerY = 0.5;
  bool _framingHeader = false;
  double get _focusX => _framingHeader ? _headerX : _x;
  double get _focusY => _framingHeader ? _headerY : _y;
  String? _error, _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cover = await widget.repository.load(widget.programId);
      if (!mounted) return;
      setState(() {
        _cover = cover;
        _x = cover.focalX;
        _y = cover.focalY;
        _headerX = cover.headerFocalX;
        _headerY = cover.headerFocalY;
        _draft = null;
        _remove = false;
        _dirty = false;
        _conflict = false;
        _message = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la portada.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _discard() async =>
      !_dirty ||
      await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Descartar cambios de portada?'),
              content: const Text(
                'La imagen y el encuadre todavía no se han guardado.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Seguir editando'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ) ==
          true;

  Future<void> _close() async {
    if (_busy) return;
    if (await _discard() && mounted) {
      setState(() => _dirty = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final image = await (widget.pickImage ?? pickProgramCoverImage)();
      if (image == null || !mounted) return;
      setState(() {
        _draft = image;
        _remove = false;
        _dirty = true;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo preparar la fotografía.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final cover = _cover;
    if (cover == null || !_dirty || _busy || _conflict) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final saved = await widget.repository.save(
        cover,
        focalX: _x,
        focalY: _y,
        headerFocalX: _headerX,
        headerFocalY: _headerY,
        removeImage: _remove,
        upload: _draft == null
            ? null
            : ProgramCoverUpload(card: _draft!.card, header: _draft!.header),
      );
      if (!mounted) return;
      setState(() {
        _cover = saved;
        _draft = null;
        _remove = false;
        _dirty = false;
        _x = saved.focalX;
        _y = saved.focalY;
        _headerX = saved.headerFocalX;
        _headerY = saved.headerFocalY;
        _message = 'Portada guardada. Se mostrará al actualizar el catálogo de la app.';
      });
    } on ProgramCoverConflict {
      if (mounted) {
        setState(() {
          _conflict = true;
          _error = 'Otra edición ha cambiado esta portada. Recarga antes de guardar.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Tus cambios siguen aquí; comprueba la conexión y los permisos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _hasImage =>
      _draft != null || (!_remove && _cover?.hasImage == true);
  ImageProvider? get _headerImage => !_hasImage
      ? null
      : _draft != null
      ? MemoryImage(_draft!.header)
      : _cover?.headerUrl == null
      ? null
      : NetworkImage(_cover!.headerUrl!);
  ImageProvider? get _cardImage => !_hasImage
      ? null
      : _draft != null
      ? MemoryImage(_draft!.card)
      : _cover?.cardUrl == null
      ? null
      : NetworkImage(_cover!.cardUrl!);

  void _focus(double x, double y) {
    if (_busy || !_hasImage) return;
    setState(() {
      if (_framingHeader) {
        _headerX = x;
        _headerY = y;
      } else {
        _x = x;
        _y = y;
      }
      _dirty = true;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Imagen de preparación',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar editor',
                    onPressed: _busy ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.programName),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_cover == null) ...[
                Text(_error ?? 'No se pudo cargar la portada.'),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ] else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final settings = _settings(context);
                    final preview = _preview(context);
                    return constraints.maxWidth >= 720
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 300, child: settings),
                              const SizedBox(width: 28),
                              Expanded(child: preview),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              settings,
                              const SizedBox(height: 28),
                              preview,
                            ],
                          );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _settings(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Imagen de portada'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            key: const ValueKey('cover-frame-card'),
            label: const Text('Tarjeta'),
            selected: !_framingHeader,
            onSelected: _busy
                ? null
                : (_) => setState(() => _framingHeader = false),
          ),
          ChoiceChip(
            key: const ValueKey('cover-frame-header'),
            label: const Text('Cabecera'),
            selected: _framingHeader,
            onSelected: _busy
                ? null
                : (_) => setState(() => _framingHeader = true),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _framingHeader
            ? 'Editando encuadre de la cabecera'
            : 'Editando encuadre de la tarjeta',
        style: const TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (_hasImage)
        CoverFocusPicker(
          image: (_framingHeader ? _headerImage : _cardImage)!,
          focalX: _focusX,
          focalY: _focusY,
          onChanged: _busy ? null : _focus,
        )
      else
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: context.visuals.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Icon(Icons.image_outlined, size: 44)),
        ),
      const SizedBox(height: 8),
      const Text(
        'Cada formato guarda su propio encuadre. La foto es común.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _busy
                  ? 'Procesando…'
                  : _hasImage
                  ? 'Cambiar imagen'
                  : 'Subir imagen',
            ),
          ),
          if (_hasImage)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _remove = true;
                      _draft = null;
                      _dirty = true;
                      _message = null;
                    }),
              child: const Text('Quitar imagen'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Encuadre horizontal'),
      Slider(
        key: const ValueKey('cover-focus-x'),
        value: _focusX,
        divisions: 100,
        label: '${(_focusX * 100).round()} %',
        onChanged: _hasImage && !_busy
            ? (value) => _focus(value, _focusY)
            : null,
      ),
      const Text('Encuadre vertical'),
      Slider(
        key: const ValueKey('cover-focus-y'),
        value: _focusY,
        divisions: 100,
        label: '${(_focusY * 100).round()} %',
        onChanged: _hasImage && !_busy
            ? (value) => _focus(_focusX, value)
            : null,
      ),
      const Divider(),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.contrast),
        title: Text('Tratamiento automático'),
        subtitle: Text('Velo oscuro y contraste de EntrenaOP'),
      ),
      const Text(
        'Se generan versiones ligeras para tarjeta y cabecera. Original recomendado: horizontal, 1920 × 1080.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _dirty && !_busy && !_conflict ? _save : null,
        icon: const Icon(Icons.check),
        label: const Text('Guardar portada'),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      if (_conflict)
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  if (await _discard() && mounted) _load();
                },
          child: const Text('Recargar portada'),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(liveRegion: true, child: Text(_message!)),
        ),
    ],
  );

  Widget _preview(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          const Text('Vista previa del deportista'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Móvil'),
                selected: !_desktop,
                onSelected: (_) => setState(() => _desktop = false),
              ),
              ChoiceChip(
                label: const Text('Escritorio'),
                selected: _desktop,
                onSelected: (_) => setState(() => _desktop = true),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 24),
      Align(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _desktop ? 650 : 360),
          child: EntrenaCard(
            tone: EntrenaCardTone.progress,
            coverImage: _cardImage,
            focalX: _x,
            focalY: _y,
            child: _previewContent(context),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text('Cabecera de la preparación'),
      const SizedBox(height: 12),
      EntrenaCard(
        coverImage: _headerImage,
        focalX: _headerX,
        focalY: _headerY,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            widget.programName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Datos de ejemplo. El cambio afecta a la imagen, no a las reglas de la preparación.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );

  Widget _previewContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.flag_outlined,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Por configurar')),
        ],
      ),
      const SizedBox(height: 20),
      Text(widget.programName, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Sin fecha objetivo'),
      const SizedBox(height: 28),
      Text(
        'Gestionar preparación →',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// El punto se elige sobre la imagen completa, no sobre una miniatura ya recortada.
class CoverFocusPicker extends StatefulWidget {
  const CoverFocusPicker({
    super.key,
    required this.image,
    required this.focalX,
    required this.focalY,
    this.onChanged,
  });
  final ImageProvider image;
  final double focalX, focalY;
  final void Function(double x, double y)? onChanged;
  @override
  State<CoverFocusPicker> createState() => _CoverFocusPickerState();
}

class _CoverFocusPickerState extends State<CoverFocusPicker> {
  ImageStream? _stream;
  late final ImageStreamListener _listener;
  Size _size = const Size(16, 9);
  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(
          () => _size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
        );
      }
      info.dispose();
    }, onError: (_, _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CoverFocusPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    _stream = widget.image.resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 210,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final fitted = applyBoxFit(
          BoxFit.contain,
          _size,
          Size(constraints.maxWidth, 210),
        ).destination;
        final offset = Offset(
          (constraints.maxWidth - fitted.width) / 2,
          (210 - fitted.height) / 2,
        );
        void choose(Offset position) {
          if (widget.onChanged != null) {
            widget.onChanged!(
              ((position.dx - offset.dx) / fitted.width).clamp(0, 1),
              ((position.dy - offset.dy) / fitted.height).clamp(0, 1),
            );
          }
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onTapDown: widget.onChanged == null
                ? null
                : (details) => choose(details.localPosition),
            onPanUpdate: widget.onChanged == null
                ? null
                : (details) => choose(details.localPosition),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: widget.image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('No se pudo cargar la imagen.')),
                ),
                Positioned(
                  left: offset.dx + fitted.width * widget.focalX - 10,
                  top: offset.dy + fitted.height * widget.focalY - 10,
                  child: IgnorePointer(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
