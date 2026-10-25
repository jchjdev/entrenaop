import 'package:flutter/material.dart';

import 'push_notifications.dart';
import 'notice_preferences.dart';

class PushNotificationsScope
    extends InheritedNotifier<PushNotificationCoordinator> {
  const PushNotificationsScope({
    super.key,
    required PushNotificationCoordinator? coordinator,
    required super.child,
  }) : super(notifier: coordinator);
  static PushNotificationCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PushNotificationsScope>()
      ?.notifier;
  static PushNotificationCoordinator? readOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PushNotificationsScope>()?.notifier;
}

class StudentPushSettings extends StatefulWidget {
  const StudentPushSettings({super.key});
  @override
  State<StudentPushSettings> createState() => _StudentPushSettingsState();
}

class _StudentPushSettingsState extends State<StudentPushSettings> {
  String? _owner, _formError;
  NoticePreferences? _draft;
  List<String> _zones = [];
  bool _dirty = false, _loadingZones = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final push = PushNotificationsScope.maybeOf(context);
    if (_owner != push?.accountId) {
      _owner = push?.accountId;
      _draft = push?.preferences;
      _zones = [];
      _loadingZones = false;
      _dirty = false;
      _formError = null;
    }
    if (!_dirty && push != null) _draft = push.preferences;
    if (push != null &&
        push.serverAvailable &&
        _zones.isEmpty &&
        !_loadingZones) {
      _loadZones(push);
    }
  }

  Future<void> _loadZones(PushNotificationCoordinator push) async {
    _loadingZones = true;
    final owner = push.accountId;
    try {
      final zones = await push.timezones();
      if (mounted && owner == _owner) setState(() => _zones = zones);
    } catch (_) {
      if (mounted && owner == _owner) {
        setState(
          () => _formError =
              'No se pudieron cargar las zonas horarias. Reintenta.',
        );
      }
    } finally {
      if (owner == _owner) _loadingZones = false;
    }
  }

  void _change(NoticePreferences value) => setState(() {
    _draft = value;
    _dirty = true;
    _formError = null;
  });

  String _clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

  Future<void> _time(int value, void Function(int) changed) async {
    final owner = _owner;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    if (result != null &&
        mounted &&
        owner == _owner &&
        owner == PushNotificationsScope.readOf(context)?.accountId) {
      changed(result.hour * 60 + result.minute);
    }
  }

  Future<void> _save(PushNotificationCoordinator push) async {
    final draft = _draft!;
    if (draft.validationError case final error?) {
      setState(() => _formError = error);
      return;
    }
    final owner = _owner;
    await push.savePreferences(draft);
    if (!mounted || owner != _owner || owner != push.accountId) return;
    if (push.error == null && push.preferences.revision > draft.revision) {
      setState(() {
        _draft = push.preferences;
        _dirty = false;
        _formError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias de avisos guardadas.')),
      );
    } else {
      setState(
        () => _formError = 'No se pudieron guardar. Comprueba la conexión o recarga los ajustes si los cambiaste en otro dispositivo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final push = PushNotificationsScope.maybeOf(context);
    if (push == null || !push.available || !push.serverAvailable) {
      return const SizedBox.shrink();
    }
    final value = _draft ?? push.preferences;
    final editable = !push.busy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisos del preparador'),
            subtitle: Text(
              push.denied
                  ? 'Permite las notificaciones en los ajustes del teléfono y vuelve a comprobarlo.'
                  : 'La planificación y los mensajes consecutivos llegan agrupados.',
            ),
            value: push.enabled,
            onChanged: editable
                ? (on) {
                    on ? push.enable() : push.disable();
                  }
                : null,
          ),
          if (push.busy) const LinearProgressIndicator(),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Recordatorios y descanso'),
            subtitle: Text(
              value.reminderMode == 'off'
                  ? 'Sin recordatorios de entrenamiento'
                  : '${value.reminderMode == 'sameDay' ? 'El mismo día' : 'El día anterior'} · ${_clock(value.reminderMinute)}',
            ),
            childrenPadding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Text(
                'Un recordatorio por día de entrenamiento, aunque tengas varias sesiones o preparadores. Los entrenamientos completados o cancelados se omiten.',
              ),
              if (!push.enabled)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Para recibirlos, activa también los avisos en este dispositivo.',
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'mode-$_owner-${value.revision}-${value.reminderMode}',
                ),
                isExpanded: true,
                initialValue: value.reminderMode,
                decoration: const InputDecoration(
                  labelText: 'Cuándo recordarme el entrenamiento',
                ),
                items: const [
                  DropdownMenuItem(value: 'off', child: Text('No recordarme')),
                  DropdownMenuItem(
                    value: 'sameDay',
                    child: Text('El mismo día'),
                  ),
                  DropdownMenuItem(
                    value: 'previousDay',
                    child: Text('El día anterior'),
                  ),
                ],
                onChanged: editable
                    ? (mode) {
                        if (mode != null) {
                          _change(value.copyWith(reminderMode: mode));
                        }
                      }
                    : null,
              ),
              if (value.reminderMode != 'off')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora del recordatorio'),
                  subtitle: Text(_clock(value.reminderMinute)),
                  trailing: const Icon(Icons.schedule),
                  onTap: editable
                      ? () => _time(
                          value.reminderMinute,
                          (minute) =>
                              _change(value.copyWith(reminderMinute: minute)),
                        )
                      : null,
                ),
              const SizedBox(height: 12),
              if (_zones.isNotEmpty)
                DropdownMenu<String>(
                  key: ValueKey('zone-$_owner-${value.timezone}'),
                  initialSelection: value.timezone,
                  expandedInsets: EdgeInsets.zero,
                  enableFilter: true,
                  label: const Text('Zona horaria'),
                  enabled: editable,
                  dropdownMenuEntries: _zones
                      .map(
                        (zone) => DropdownMenuEntry(value: zone, label: zone),
                      )
                      .toList(),
                  onSelected: (zone) {
                    if (zone != null) _change(value.copyWith(timezone: zone));
                  },
                ),
              if (_zones.isEmpty)
                TextButton(
                  onPressed: _loadingZones ? null : () => _loadZones(push),
                  child: Text(
                    _loadingZones
                        ? 'Cargando zonas horarias…'
                        : 'Cargar zonas horarias',
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Respetar mi descanso'),
                subtitle: Text('Horarios en ${value.timezone}'),
                value: value.quietEnabled,
                onChanged: editable
                    ? (on) => _change(value.copyWith(quietEnabled: on))
                    : null,
              ),
              if (value.quietEnabled)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: editable
                          ? () => _time(
                              value.quietStart,
                              (minute) =>
                                  _change(value.copyWith(quietStart: minute)),
                            )
                          : null,
                      child: Text('Desde ${_clock(value.quietStart)}'),
                    ),
                    OutlinedButton(
                      onPressed: editable
                          ? () => _time(
                              value.quietEnd,
                              (minute) =>
                                  _change(value.copyWith(quietEnd: minute)),
                            )
                          : null,
                      child: Text('Hasta ${_clock(value.quietEnd)}'),
                    ),
                  ],
                ),
              if (_formError case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(error),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: editable && _dirty ? () => _save(push) : null,
                    child: const Text('Guardar preferencias'),
                  ),
                  TextButton(
                    onPressed: editable
                        ? () async {
                            await push.refresh();
                            if (mounted && push.accountId == _owner) {
                              setState(() {
                                _draft = push.preferences;
                                _dirty = false;
                                _formError = null;
                              });
                            }
                          }
                        : null,
                    child: const Text('Recargar ajustes'),
                  ),
                ],
              ),
            ],
          ),
          if (push.error case final error?) ...[
            Text(error),
            TextButton(
              onPressed: push.busy ? null : push.refresh,
              child: const Text('Comprobar avisos'),
            ),
          ],
        ],
      ),
    );
  }
}
