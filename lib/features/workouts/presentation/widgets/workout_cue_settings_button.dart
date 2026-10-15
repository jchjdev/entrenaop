import 'dart:async';
import 'dart:math' as math;

import 'package:entrena_ui/entrena_ui.dart';

import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WorkoutCueSettingsButton extends StatefulWidget {
  const WorkoutCueSettingsButton({required this.cueService, super.key});

  final WorkoutCueService cueService;

  @override
  State<WorkoutCueSettingsButton> createState() =>
      _WorkoutCueSettingsButtonState();
}

class _WorkoutCueSettingsButtonState extends State<WorkoutCueSettingsButton> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.cueService.prepare());
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Avisos del temporizador',
    icon: const Icon(Icons.notifications_active_outlined),
    onPressed: () async {
      final selected = await showDialog<WorkoutCuePreferences>(
        context: context,
        builder: (_) => _CueSettingsDialog(cueService: widget.cueService),
      );
      if (selected != null) await widget.cueService.savePreferences(selected);
    },
  );
}

class _CueSettingsDialog extends StatefulWidget {
  const _CueSettingsDialog({required this.cueService});

  final WorkoutCueService cueService;

  @override
  State<_CueSettingsDialog> createState() => _CueSettingsDialogState();
}

class _CueSettingsDialogState extends State<_CueSettingsDialog> {
  late bool _sound = widget.cueService.preferences.soundEnabled;
  late bool _haptics = widget.cueService.preferences.hapticsEnabled;
  bool _testingSound = false;
  bool _testingHaptics = false;
  String? _error;

  Future<void> _preview() async {
    setState(() {
      _testingSound = true;
      _error = null;
    });
    final success = await widget.cueService.previewSound();
    if (!mounted) return;
    setState(() {
      _testingSound = false;
      if (!success) {
        _error = 'No se ha podido reproducir el sonido. Vuelve a probarlo.';
      }
    });
  }

  Future<void> _previewHaptics() async {
    setState(() {
      _testingHaptics = true;
      _error = null;
    });
    final success = await widget.cueService.previewHaptics();
    if (!mounted) return;
    setState(() {
      _testingHaptics = false;
      if (!success) {
        _error =
            'No se ha podido activar la vibración. '
            'Revisa los permisos y ajustes del dispositivo.';
      }
    });
  }

  Widget _buildPreviewButtons(BuildContext context) {
    final theme = Theme.of(context);
    final buttonTheme = theme.outlinedButtonTheme.style;
    final direction = Directionality.of(context);
    final labelStyle =
        buttonTheme?.textStyle?.resolve({}) ?? theme.textTheme.labelLarge!;
    final padding =
        buttonTheme?.padding?.resolve({})?.resolve(direction) ??
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final iconSize = buttonTheme?.iconSize?.resolve({}) ?? 20;
    final minimumHeight = buttonTheme?.minimumSize?.resolve({})?.height ?? 48;
    final availableWidth = EntrenaDialog.contentWidthOf(context);
    var height = minimumHeight;
    // Reservar la etiqueta más alta evita tamaños distintos al ampliar texto
    // o cambiar temporalmente a «Probando…», sin recortar ninguna línea.
    for (final label in ['Probar sonido', 'Probar vibración', 'Probando…']) {
      final painter =
          TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: direction,
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          )..layout(
            maxWidth: math.max(
              1,
              availableWidth - padding.horizontal - iconSize - 8,
            ),
          );
      height = math.max(height, painter.height + padding.vertical);
      painter.dispose();
    }
    final style = OutlinedButton.styleFrom(
      minimumSize: Size(48, height),
      textStyle: labelStyle,
      padding: padding,
      iconSize: iconSize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          style: style,
          onPressed: _sound && !_testingSound && !_testingHaptics
              ? _preview
              : null,
          icon: const Icon(Icons.volume_up_outlined),
          label: Text(
            _testingSound ? 'Probando…' : 'Probar sonido',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: style,
          onPressed: _haptics && !_testingHaptics && !_testingSound
              ? _previewHaptics
              : null,
          icon: const Icon(Icons.vibration),
          label: Text(
            _testingHaptics ? 'Probando…' : 'Probar vibración',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => EntrenaDialog(
    title: const Text('Sonido y vibración'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _sound,
          title: const Text('Sonido'),
          subtitle: const Text('Señales en cada fase del temporizador.'),
          onChanged: (value) => setState(() => _sound = value),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _haptics,
          title: const Text('Vibración'),
          subtitle: const Text('En dispositivos compatibles.'),
          onChanged: (value) => setState(() => _haptics = value),
        ),
        const SizedBox(height: 16),
        _buildPreviewButtons(context),
        const SizedBox(height: 16),
        Text(
          'Mantén la sesión en pantalla y ajusta el volumen multimedia.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: const Text('Cómo funcionan los avisos'),
          children: [
            const Text(
              'Preparación, inicio, mitad y final. Últimos 10 segundos de '
              'trabajo y descanso; 3, 2, 1 al terminar el trabajo. '
              'Los intervalos cortos tienen menos avisos; '
              'los que coinciden suenan una sola vez.',
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              const SizedBox(height: 12),
              const Text(
                'Pulsa Probar vibración y permite las notificaciones de '
                'EntrenaOP. Si las bloqueaste, actívalas en Ajustes → '
                'Aplicaciones → EntrenaOP → Notificaciones.',
              ),
            ],
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      EntrenaDialogActions(
        primaryLabel: 'Guardar',
        onPrimary: () => Navigator.pop(
          context,
          WorkoutCuePreferences(soundEnabled: _sound, hapticsEnabled: _haptics),
        ),
        secondary: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', textAlign: TextAlign.center),
          ),
        ],
      ),
    ],
  );
}
