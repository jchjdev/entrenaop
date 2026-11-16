import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';

List<ProfessionalGuideStep> adminGuideSteps({
  required bool accounts,
  required bool operations,
  required bool guided,
  required bool directory,
}) => [
  if (operations)
    const ProfessionalGuideStep(
      topic: 'Trabajo diario',
      title: 'Mira qué queda pendiente',
      text: 'En Pendientes puedes retomar borradores y ver qué necesita revisión.',
      destination: 'Pendientes',
      path: '/home',
      icon: Icons.dashboard_outlined,
    ),
  const ProfessionalGuideStep(
    topic: 'Catálogo oficial',
    title: 'Publica un ejercicio oficial',
    text: 'En Ejercicios, pulsa «Nuevo ejercicio». Añade la explicación, los músculos y el material. La foto o el vídeo ayudan a mostrar cómo se hace.',
    destination: 'Ejercicios',
    path: '/exercises',
    icon: Icons.fitness_center_rounded,
  ),
  const ProfessionalGuideStep(
    topic: 'Catálogo oficial',
    title: 'Organiza el catálogo',
    text: 'Usa los filtros de músculo y material o la carpeta de una tarjeta para agrupar ejercicios. En Papelera puedes recuperar los que hayas retirado.',
    destination: 'Ejercicios',
    path: '/exercises',
    icon: Icons.folder_outlined,
  ),
  const ProfessionalGuideStep(
    topic: 'Catálogo oficial',
    title: 'Crea una sesión oficial',
    text: 'En Sesiones, pulsa «Nueva sesión». Elige Carrera o Fuerza, prepara el entrenamiento y revisa la ficha antes de publicar.',
    destination: 'Sesiones',
    path: '/sessions',
    icon: Icons.view_agenda_outlined,
  ),
  if (guided)
    const ProfessionalGuideStep(
      topic: 'Programas y pruebas',
      title: 'Prepara un calentamiento',
      text: 'En Calentamientos, pulsa «Crear calentamiento» y añade los ejercicios. Después podrás insertarlo en el creador de sesiones.',
      destination: 'Calentamientos',
      path: '/warmups',
      icon: Icons.self_improvement_rounded,
    ),
  if (guided)
    const ProfessionalGuideStep(
      topic: 'Programas y pruebas',
      title: 'Publica un programa guiado',
      text: 'Pulsa «Crear programa guiado», organiza las sesiones por fases y revisa la vista previa. Al publicarlo estará disponible en Biblioteca.',
      destination: 'Programas guiados',
      path: '/guided-programs',
      icon: Icons.auto_stories_outlined,
    ),
  const ProfessionalGuideStep(
    topic: 'Programas y pruebas',
    title: 'Revisa una preparación deportiva',
    text: 'En Preparaciones, abre una prueba para consultar sus sesiones, baremos y simulación cuando estén disponibles.',
    destination: 'Preparaciones',
    path: '/programs',
    icon: Icons.account_tree_outlined,
  ),
  if (accounts)
    const ProfessionalGuideStep(
      topic: 'Cuentas y revisión',
      title: 'Da acceso a un entrenador',
      text: 'Busca su correo en Cuentas y Pro. En su ficha puedes conceder acceso regalado a Trainer y elegir si puede publicar su ficha en el directorio.',
      destination: 'Cuentas y Pro',
      path: '/accounts',
      icon: Icons.manage_accounts_outlined,
    ),
  if (accounts && directory)
    const ProfessionalGuideStep(
      topic: 'Cuentas y revisión',
      title: 'Revisa una denuncia',
      text: 'En Denuncias del directorio, abre la incidencia para revisar la ficha o conversación denunciada.',
      destination: 'Denuncias del directorio',
      path: '/directory-reports',
      icon: Icons.flag_outlined,
    ),
  if (operations)
    const ProfessionalGuideStep(
      topic: 'Cuentas y revisión',
      title: 'Comprueba el catálogo y el historial',
      text: 'En Calidad del catálogo puedes revisar avisos de contenido. En Historial editorial puedes consultar los cambios que ya se hicieron.',
      destination: 'Calidad del catálogo',
      path: '/quality',
      icon: Icons.fact_check_outlined,
    ),
  if (operations)
    const ProfessionalGuideStep(
      topic: 'Cuentas y revisión',
      title: 'Consulta el estado del sistema',
      text: 'En Estado del sistema puedes comprobar los servicios y revisar la información de las copias.',
      destination: 'Estado del sistema',
      path: '/system',
      icon: Icons.monitor_heart_outlined,
    ),
];
