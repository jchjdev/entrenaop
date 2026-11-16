import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';

abstract final class TrainerGuideTargets {
  static const invite = 'invite';
  static const weekView = 'weekView';
  static const copyWeek = 'copyWeek';
  static const appointment = 'appointment';
  static const repeatWeeks = 'repeatWeeks';
  static const exercise = 'exercise';
  static const session = 'session';
  static const video = 'video';
  static const program = 'program';
  static const form = 'form';
  static const group = 'group';
  static const assessment = 'assessment';
  static const selfAssignment = 'selfAssignment';
  static const billing = 'billing';
}

const trainerGuideSteps = [
  ProfessionalGuideStep(
    topic: 'Alumnos y agenda',
    title: 'Invita a tu primer alumno',
    target: TrainerGuideTargets.invite,
    text: 'En Alumnos, pulsa «Invitar alumno» y comparte el enlace. Cuando lo acepte, abre su ficha desde la lista.',
    destination: 'Alumnos',
    path: '/clients',
    icon: Icons.people_outline,
  ),
  ProfessionalGuideStep(
    topic: 'Alumnos y agenda',
    title: 'Pauta un entrenamiento',
    text: 'En Agenda, arrastra una sesión al día que quieras y elige el alumno. También puedes abrir su ficha y pulsar «Asignar sesión» en Planificación.',
    destination: 'Agenda',
    path: '/agenda',
    icon: Icons.calendar_month_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Alumnos y agenda',
    title: 'Cambia de semana, mueve o retira una sesión',
    target: TrainerGuideTargets.weekView,
    text: 'Elige la vista Semana y usa las flechas para cambiar de semana. Arrastra una sesión pendiente a otro día o ábrela y usa «Mover fecha» o «Retirar sesión».',
    destination: 'Agenda',
    path: '/agenda',
    icon: Icons.calendar_month_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Alumnos y agenda',
    title: 'Copia una semana',
    target: TrainerGuideTargets.copyWeek,
    text: 'Sitúate en la semana que quieres repetir. Pulsa «Copiar semana», elige la semana de destino y revisa las pautas antes de confirmar.',
    destination: 'Agenda',
    path: '/agenda',
    icon: Icons.calendar_month_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Alumnos y agenda',
    title: 'Crea una cita',
    target: TrainerGuideTargets.appointment,
    text: 'Pulsa «Crear cita», elige alumno, día y hora, y pulsa «Guardar cita». Para cambiarla, ábrela en Agenda.',
    destination: 'Agenda',
    path: '/agenda',
    icon: Icons.calendar_month_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Alumnos y agenda',
    title: 'Repite sesiones varias semanas',
    target: TrainerGuideTargets.repeatWeeks,
    text: 'En Programar semanas, pulsa «Planificar serie finita». Elige alumnos, sesión, días y cuántas semanas quieres programar. Revisa las fechas antes de confirmar.',
    destination: 'Programar semanas',
    path: '/recurrence',
    icon: Icons.event_repeat_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Tu biblioteca',
    title: 'Crea y organiza ejercicios',
    target: TrainerGuideTargets.exercise,
    text: 'Pulsa «Crear ejercicio privado». Añade el nombre, el material y, si te ayuda a explicarlo, una foto o vídeo. La carpeta de cada ejercicio abre sus colecciones.',
    destination: 'Ejercicios',
    path: '/exercises',
    icon: Icons.sports_gymnastics,
  ),
  ProfessionalGuideStep(
    topic: 'Tu biblioteca',
    title: 'Crea una sesión de fuerza',
    target: TrainerGuideTargets.session,
    text: 'Pulsa «Crear sesión privada» y elige Fuerza. Añade un bloque, busca ejercicios y pon las series, repeticiones y descansos. Si lo necesitas, pulsa «Insertar calentamiento».',
    destination: 'Sesiones',
    path: '/workouts',
    icon: Icons.fitness_center,
  ),
  ProfessionalGuideStep(
    topic: 'Tu biblioteca',
    title: 'Crea una sesión de carrera',
    target: TrainerGuideTargets.session,
    text: 'En «Crear sesión privada», elige Carrera. Añade los tramos y ajusta distancia o tiempo, ritmo y recuperación según el entrenamiento.',
    destination: 'Sesiones',
    path: '/workouts',
    icon: Icons.directions_run,
  ),
  ProfessionalGuideStep(
    topic: 'Tu biblioteca',
    title: 'Sube un vídeo de demostración',
    target: TrainerGuideTargets.video,
    text: 'En Vídeos, pulsa «Subir demostración». Cuando esté listo, puedes reutilizarlo en un ejercicio o usar «Crear ejercicio con este vídeo».',
    destination: 'Vídeos',
    path: '/media',
    icon: Icons.video_library_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Tu biblioteca',
    title: 'Pauta un programa',
    target: TrainerGuideTargets.program,
    text: 'En Programas, pulsa «Crear programa privado» y reúne tus sesiones por fases. Después, abre Planificación en la ficha del alumno y pulsa «Pautar programa».',
    destination: 'Programas',
    path: '/programs',
    icon: Icons.view_week_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Tu biblioteca',
    title: 'Actualiza un programa ya pautado',
    text: 'Guarda una nueva versión y abre «Actualizar pautas». Elige alumnos y revisa las sesiones pendientes que recibirán el cambio. Las ya iniciadas o adaptadas a mano se conservan.',
    destination: 'Programas',
    path: '/programs',
    icon: Icons.update,
  ),
  ProfessionalGuideStep(
    topic: 'Seguimiento',
    title: 'Revisa cómo le ha ido',
    text: 'Abre la ficha del alumno y entra en Resultados. Desde ahí puedes ver el entrenamiento realizado. En Conversación puedes comentarlo con él.',
    destination: 'Alumnos',
    path: '/clients',
    icon: Icons.fact_check_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Seguimiento',
    title: 'Responde y revisa vídeos',
    text: 'En Conversaciones puedes responder a cada alumno. En Revisiones encontrarás el trabajo pendiente. En la ficha del alumno, abre Técnica para ver sus vídeos.',
    destination: 'Conversaciones',
    path: '/messages',
    icon: Icons.chat_bubble_outline,
  ),
  ProfessionalGuideStep(
    topic: 'Seguimiento',
    title: 'Recoge información del alumno',
    target: TrainerGuideTargets.form,
    text: 'En Formularios, pulsa «Crear formulario» para preparar preguntas. Para enviarlo o consultar respuestas, abre Formularios en la ficha del alumno.',
    destination: 'Formularios',
    path: '/forms',
    icon: Icons.assignment_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Seguimiento',
    title: 'Trabaja con varios alumnos',
    target: TrainerGuideTargets.group,
    text: 'En Grupos, usa «Crear grupo» para reunir alumnos con un objetivo común. Con «Nuevo envío» puedes preparar el mismo envío para varios de ellos.',
    destination: 'Grupos',
    path: '/groups',
    icon: Icons.groups_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Seguimiento',
    title: 'Consulta pruebas e informes',
    target: TrainerGuideTargets.assessment,
    text: 'En Pruebas y simulacros, pulsa «Crear batería» para reunir evaluaciones. En Informes, elige un alumno para revisar su seguimiento.',
    destination: 'Pruebas y simulacros',
    path: '/assessments',
    icon: Icons.timer_outlined,
  ),
  ProfessionalGuideStep(
    topic: 'Tu espacio',
    title: 'Pruébalo contigo',
    target: TrainerGuideTargets.selfAssignment,
    text: 'En Para mí puedes pautarte entrenamientos y hacerlos desde tu app de deportista. Tu cuenta no ocupa plaza.',
    destination: 'Para mí',
    path: '/self',
    icon: Icons.person_outline,
  ),
  ProfessionalGuideStep(
    topic: 'Tu espacio',
    title: 'Revisa tu plan y tu ficha pública',
    target: TrainerGuideTargets.billing,
    text: 'En Mi cuenta puedes gestionar tu plan y plazas. Si tienes acceso al directorio, en Mi ficha pública puedes preparar y publicar tu perfil.',
    destination: 'Mi cuenta',
    path: '/settings',
    icon: Icons.settings_outlined,
  ),
];
