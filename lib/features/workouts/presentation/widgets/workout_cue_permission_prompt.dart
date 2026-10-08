import 'dart:async';

import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/material.dart';

class WorkoutCuePermissionPrompt extends StatefulWidget {
  const WorkoutCuePermissionPrompt({
    required this.cueService,
    required this.child,
    super.key,
  });

  final WorkoutCueService cueService;
  final Widget child;

  @override
  State<WorkoutCuePermissionPrompt> createState() =>
      _WorkoutCuePermissionPromptState();
}

class _WorkoutCuePermissionPromptState
    extends State<WorkoutCuePermissionPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_offerPermission());
    });
  }

  bool get _isCurrent => mounted && ModalRoute.of(context)?.isCurrent == true;

  Future<void> _offerPermission() async {
    try {
      if (!_isCurrent) return;
      final shouldOffer = await widget.cueService
          .shouldOfferHapticsPermission();
      if (!shouldOffer || !_isCurrent) return;
      // Se recuerda la oferta, incluso al elegir Ahora no o cerrar con atrás.
      // El botón de prueba conserva la posibilidad de solicitarlo después.
      await widget.cueService.markHapticsPermissionOffered();
      if (!mounted || !_isCurrent) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Avisos de la sesión'),
          content: const Text(
            'Permite las notificaciones de EntrenaOP para que el móvil vibre '
            'en los avisos del temporizador. Puedes seguir entrenando sin '
            'vibración y activarla después en Avisos del temporizador.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Permitir avisos'),
            ),
          ],
        ),
      );
      if (allow != true || !_isCurrent) return;
      final allowed = await widget.cueService.requestHapticsPermission();
      if (!mounted) return;
      if (!allowed && _isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Puedes seguir sin vibración. Para activarla, permite las '
              'notificaciones de EntrenaOP en los ajustes del móvil.',
            ),
          ),
        );
      }
    } catch (error) {
      // La preparación de permisos nunca impide entrar en la sesión.
      debugPrint('No se ha podido preparar el permiso de avisos: $error');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
