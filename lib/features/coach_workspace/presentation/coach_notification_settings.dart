import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart' show trainerError;
import 'package:trainer_access/trainer_notifications.dart';

import '../../notifications/push_notifications_scope.dart';

class CoachNotificationSettings extends StatefulWidget {
  const CoachNotificationSettings({super.key, required this.repository});
  final CoachNotificationRepository repository;
  @override
  State<CoachNotificationSettings> createState() =>
      _CoachNotificationSettingsState();
}

class _CoachNotificationSettingsState extends State<CoachNotificationSettings> {
  CoachPushPreferences? _value;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.repository.preferences();
      if (mounted) setState(() => _value = value);
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(CoachPushPreferences value) async {
    final push = PushNotificationsScope.readOf(context);
    if (push == null) return;
    final owner = push.accountId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (value.enabled && !push.enabled) {
        await push.enable(professionalOnly: true);
      }
      if (!mounted || push.accountId != owner) return;
      if (value.enabled && !push.enabled) {
        setState(
          () => _error =
              push.error ??
              'Permite las notificaciones en los ajustes del teléfono.',
        );
        return;
      }
      final saved = await widget.repository.save(value);
      if (mounted && push.accountId == owner) setState(() => _value = saved);
    } catch (e) {
      if (mounted && push.accountId == owner) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final push = PushNotificationsScope.maybeOf(context);
    if (push == null || !push.available) return const SizedBox.shrink();
    final value = _value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Avisos de mis alumnos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Mensajes y vídeos agrupados, sin nombres ni contenido en la pantalla bloqueada. No cambia tus avisos personales.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (value != null && !value.available)
              const Text(
                'El envío profesional todavía no está habilitado en este entorno.',
              ),
            if (value != null && value.available) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recibir avisos en el teléfono'),
                value: value.enabled && push.enabled,
                onChanged: _busy || push.busy
                    ? null
                    : (on) => _save(value.copyWith(enabled: on)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mensajes de alumnos'),
                value: value.messages,
                onChanged: _busy || !value.enabled
                    ? null
                    : (on) => _save(value.copyWith(messages: on)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vídeos de técnica compartidos'),
                value: value.videos,
                onChanged: _busy || !value.enabled
                    ? null
                    : (on) => _save(value.copyWith(videos: on)),
              ),
              const StudentPushSettings(professional: true),
            ],
            if (_error != null) Text(_error!),
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Recargar ajustes de alumnos'),
            ),
          ],
        ),
      ),
    );
  }
}
