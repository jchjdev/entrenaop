import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain.dart';
import 'policy_presentation.dart';

typedef DirectoryPhotoLoader = Future<Uint8List> Function(String path);

class DirectoryPhoto extends StatefulWidget {
  const DirectoryPhoto({
    super.key,
    required this.path,
    required this.load,
    this.size = 72,
  });
  final String? path;
  final DirectoryPhotoLoader load;
  final double size;
  @override
  State<DirectoryPhoto> createState() => _DirectoryPhotoState();
}

class _DirectoryPhotoState extends State<DirectoryPhoto> {
  Future<Uint8List>? _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DirectoryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) _load();
  }

  void _load() {
    _bytes = widget.path == null ? null : widget.load(widget.path!);
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (_, state) => state.hasData
              ? Image.memory(
                  state.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
                )
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.person_outline),
                ),
        ),
      ),
    ),
  );
}

class TrainerDirectoryPage extends StatefulWidget {
  const TrainerDirectoryPage({
    super.key,
    required this.repository,
    required this.loadPhoto,
    required this.onOpen,
    required this.onContact,
    required this.publicBase,
    this.profileId,
    this.onContactInApp,
    this.onContacts,
  });
  final DirectoryRepository repository;
  final DirectoryPhotoLoader loadPhoto;
  final void Function(String id) onOpen;
  final Future<bool> Function(Uri uri) onContact;
  final Uri publicBase;
  final String? profileId;
  final ValueChanged<String>? onContactInApp;
  final VoidCallback? onContacts;
  @override
  State<TrainerDirectoryPage> createState() => _TrainerDirectoryPageState();
}

class _TrainerDirectoryPageState extends State<TrainerDirectoryPage>
    with WidgetsBindingObserver {
  final _query = TextEditingController(), _city = TextEditingController();
  DirectoryMode? _mode;
  bool _favorites = false, _busy = false, _action = false;
  String? _error, _next;
  List<DirectoryProfile> _items = [];
  DirectoryProfile? _profile;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(TrainerDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository ||
        widget.profileId != oldWidget.profileId) {
      _items = [];
      _profile = null;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _query.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _profile = null;
        _items = [];
        _next = null;
      }
    });
    try {
      if (widget.profileId case final id?) {
        final profile = await widget.repository.profile(id);
        if (mounted && generation == _generation) {
          setState(() => _profile = profile);
        }
      } else {
        final page = await widget.repository.search(
          query: _query.text,
          city: _city.text,
          mode: _mode,
          favorites: _favorites,
          after: more ? _next : null,
        );
        if (mounted && generation == _generation) {
          setState(() {
            _items = [if (more) ..._items, ...page.items];
            _next = page.next;
          });
        }
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = directoryError(e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_action) return;
    setState(() {
      _action = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _report(DirectoryProfile profile) async {
    final details = TextEditingController();
    DirectoryReportReason? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Denunciar perfil'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'La denuncia se revisará. No oculta automáticamente el perfil.',
                  ),
                  DropdownButtonFormField<DirectoryReportReason>(
                    itemHeight: null,
                    initialValue: reason,
                    decoration: const InputDecoration(
                      labelText: 'Elige el motivo',
                    ),
                    isExpanded: true,
                    items: DirectoryReportReason.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(directoryReportLabel(v)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => reason = v!),
                  ),
                  TextField(
                    controller: details,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Explica qué debemos revisar',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Enviar denuncia'),
            ),
          ],
        ),
      ),
    );
    final text = details.text;
    details.dispose();
    if (confirmed != true || !mounted) return;
    await _run(() => widget.repository.report(profile.id, reason!, text));
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denuncia recibida para revisión.')),
      );
    }
  }

  Future<void> _contact(Uri uri) async {
    try {
      if (!await widget.onContact(uri)) throw StateError('No disponible');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir el contacto. Puedes copiarlo y utilizarlo en otra aplicación.',
        );
      }
    }
  }

  Widget _tile(DirectoryProfile p) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DirectoryPhoto(
                key: ValueKey(p.photoPath),
                path: p.photoPath,
                load: widget.loadPhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '${p.mode.name}${p.city.isEmpty ? '' : ' · ${p.city}'}',
                    ),
                    Text(
                      p.accepting
                          ? 'Admite nuevos alumnos'
                          : 'No admite nuevos alumnos',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.specialties.map((s) => Chip(label: Text(s))).toList(),
          ),
          Text(
            p.description,
            maxLines: widget.profileId == null ? 3 : null,
            overflow: widget.profileId == null ? TextOverflow.ellipsis : null,
          ),
          if (widget.profileId == null)
            TextButton(
              onPressed: () => widget.onOpen(p.id),
              child: const Text('Ver ficha'),
            ),
          if (widget.profileId != null) ...[
            const SizedBox(height: 12),
            Text('Servicios: ${p.services.join(', ')}'),
            if (p.price.isNotEmpty) Text('Precio orientativo: ${p.price}'),
            if (p.appContactEnabled &&
                p.accepting &&
                !p.isOwner &&
                widget.repository.signedIn &&
                widget.onContactInApp != null)
              FilledButton.icon(
                onPressed: () => widget.onContactInApp!(p.id),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contactar en EntrenaOP'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Contactar no crea un vínculo ni da acceso a tus datos. El acuerdo se realiza con el profesional.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final contact in p.contacts)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => _contact(contact.uri),
                        child: Text(contact.label),
                      ),
                      IconButton(
                        tooltip: 'Copiar ${contact.label}',
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: contact.uri.toString()),
                        ),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
              ],
            ),
            if (p.visibility == DirectoryVisibility.web)
              TextButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text('Copiar enlace de la ficha'),
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: '${widget.publicBase}/${p.id}'),
                ),
              ),
          ],
          if (widget.repository.signedIn)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _action
                      ? null
                      : () => _run(
                          () => widget.repository.favorite(p.id, !p.favorite),
                        ),
                  icon: Icon(
                    p.favorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: Text(
                    p.favorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                  ),
                ),
                if (widget.profileId != null)
                  TextButton(
                    onPressed: _action ? null : () => _report(p),
                    child: const Text('Denunciar perfil'),
                  ),
              ],
            )
          else
            const Text(
              'Entra en la app para guardar favoritos o denunciar un perfil.',
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.profileId == null ? 'Buscar preparador' : 'Ficha del preparador',
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const DirectoryPrivacyButton(),
              if (widget.repository.signedIn && widget.onContacts != null)
                TextButton.icon(
                  onPressed: widget.onContacts,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Mis contactos y solicitudes'),
                ),
              if (widget.profileId == null) ...[
                TextField(
                  controller: _query,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Nombre, preparación o especialidad',
                  ),
                  onSubmitted: (_) => _load(),
                ),
                TextField(
                  controller: _city,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Zona o localidad',
                  ),
                  onSubmitted: (_) => _load(),
                ),
                DropdownButtonFormField<DirectoryMode?>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Modalidad'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...DirectoryMode.values.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _mode = v);
                          _load();
                        },
                ),
                if (widget.repository.signedIn)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo mis favoritos'),
                    value: _favorites,
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() => _favorites = v!);
                            _load();
                          },
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _load(),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
                const SizedBox(height: 12),
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: () => _load(),
                  child: const Text('Reintentar'),
                ),
              ],
              if (!_busy &&
                  _error == null &&
                  _items.isEmpty &&
                  _profile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No hay preparadores disponibles con estos criterios. Prueba otra búsqueda.',
                  ),
                ),
              if (_profile case final p?) _tile(p),
              for (final p in _items) _tile(p),
              if (_next != null)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Ver más preparadores'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

String directoryReportLabel(DirectoryReportReason r) => switch (r) {
  DirectoryReportReason.explicit => 'Contenido sexual o violento',
  DirectoryReportReason.harassment => 'Acoso u odio',
  DirectoryReportReason.impersonation => 'Suplantación',
  DirectoryReportReason.spam => 'Spam o enlaces engañosos',
  DirectoryReportReason.misleading => 'Información profesional falsa',
  DirectoryReportReason.other => 'Otro motivo',
};
