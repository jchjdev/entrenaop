import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';

/// Una preparación guardada no acredita que su programa se haya iniciado.
String preparationStatusLabel(AdaptiveProgramProgress? progress) =>
    switch (progress?.status) {
      null || 'draft' => 'Por configurar',
      'paused' => 'Pausada',
      'needs_review' => 'Revisión pendiente',
      'complete' => 'Finalizada',
      'training' => 'En curso',
      _ => 'Estado sin confirmar',
    };
