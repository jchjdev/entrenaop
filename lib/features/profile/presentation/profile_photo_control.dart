import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:trainer_access/profile_photo/domain.dart';
import 'package:trainer_access/profile_photo/presentation.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_editor_ui/profile_photo_picker.dart';

class ProfilePhotoControl extends StatefulWidget {
  const ProfilePhotoControl({
    super.key,
    required this.repository,
    required this.name,
    this.pick,
  });
  final ProfilePhotoRepository repository;
  final String name;
  final Future<Uint8List?> Function(BuildContext context)? pick;
  @override
  State<ProfilePhotoControl> createState() => _ProfilePhotoControlState();
}

class _ProfilePhotoControlState extends State<ProfilePhotoControl>
    with WidgetsBindingObserver {
  ProfilePhotoState? _state;
  bool _busy = true, _pending = false;
  String? _id, _target;
  Uint8List? _bytes;
  int _revision = 0, _refresh = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && !_pending) {
      setState(() => _busy = true);
      _load();
    }
  }

  void _notice(String text, {bool retry = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 8),
          action: retry
              ? SnackBarAction(label: 'Reintentar', onPressed: _commit)
              : null,
        ),
      );
  }

  Future<void> _load() async {
    try {
      final state = await widget.repository.own();
      if (mounted) {
        setState(() {
          _state = state;
          _refresh++;
        });
      }
    } catch (error) {
      _notice(profilePhotoError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(ProfilePhotoState state) async {
    if (!mounted) return;
    final previous = _state?.path;
    setState(() {
      _state = state;
      _pending = false;
      _id = null;
      _target = null;
      _bytes = null;
    });
    _notice(state.path == null ? 'Foto quitada.' : 'Foto de perfil guardada.');
    if (previous != null && previous != state.path) {
      try {
        await widget.repository.discard(previous);
      } catch (_) {
        /* La foto retirada ya no se sirve a otros usuarios. */
      }
    }
  }

  Future<void> _commit() async {
    if (_busy || !_pending) return;
    setState(() => _busy = true);
    try {
      if (_bytes != null) await widget.repository.upload(_bytes!, _id!);
      ProfilePhotoState saved;
      try {
        saved = await widget.repository.save(_target, revision: _revision);
      } catch (_) {
        // Una respuesta perdida puede seguir a un guardado correcto. Confirmar
        // la referencia evita duplicar subidas o sobrescribir otra sesión.
        final actual = await widget.repository.own();
        if (actual.path != _target || actual.revision <= _revision) rethrow;
        saved = actual;
      }
      await _finish(saved);
    } catch (error) {
      _notice(profilePhotoError(error), retry: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardPending() async {
    setState(() => _busy = true);
    try {
      final current = await widget.repository.own();
      if (current.path == _target && current.revision > _revision) {
        await _finish(current);
      } else {
        if (_target != null) await widget.repository.discard(_target!);
        if (mounted) {
          setState(() {
            _state = current;
            _pending = false;
            _id = null;
            _target = null;
            _bytes = null;
          });
        }
      }
    } catch (error) {
      _notice(profilePhotoError(error), retry: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    if (_state == null) {
      setState(() => _busy = true);
      await _load();
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tu foto será visible para ti y tus preparadores o alumnos vinculados.',
                ),
              ),
              if (_pending) ...[
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reintentar cambio de foto'),
                  onTap: () => Navigator.pop(context, 'retry'),
                ),
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: const Text('Descartar cambio pendiente'),
                  onTap: () => Navigator.pop(context, 'discard'),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Elegir foto'),
                  onTap: () => Navigator.pop(context, 'pick'),
                ),
                if (_state?.path != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Quitar foto'),
                    onTap: () => Navigator.pop(context, 'remove'),
                  ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Limpiar subidas pendientes'),
                  onTap: () => Navigator.pop(context, 'cleanup'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'retry') return _commit();
    if (action == 'discard') return _discardPending();
    if (action == 'cleanup') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limpiar subidas pendientes'),
          content: const Text(
            'Se conservan tu foto actual y tus datos. Se eliminan solo las fotos subidas que no se han guardado.',
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
        await widget.repository.cleanup();
        _notice('Subidas pendientes limpiadas.');
      } catch (error) {
        _notice(profilePhotoError(error));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (action == 'pick') {
      setState(() => _busy = true);
      try {
        final bytes = await (widget.pick ?? pickProfilePhoto)(context);
        if (!mounted || bytes == null) return;
        _bytes = bytes;
        _id = const Uuid().v4();
        _target = '${widget.repository.ownerId}/$_id.jpg';
      } catch (error) {
        _notice(profilePhotoError(error));
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quitar foto'),
          content: const Text('Volverán a mostrarse tus iniciales.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      _bytes = null;
      _id = null;
      _target = null;
    }
    _revision = _state!.revision;
    _pending = true;
    await _commit();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: _pending ? 'Cambio de foto pendiente' : 'Cambiar foto de perfil',
    child: Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: InkResponse(
        onTap: _busy ? null : _choose,
        child: SizedBox(
          width: 74,
          height: 74,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ProfilePhotoAvatar(
                key: ValueKey('${widget.repository.ownerId}-$_refresh'),
                name: widget.name,
                radius: 34,
                path: _state?.path,
                load: widget.repository.download,
              ),
              if (_busy)
                const SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 13,
                  child: Icon(
                    _pending
                        ? Icons.error_outline
                        : Icons.photo_camera_outlined,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
