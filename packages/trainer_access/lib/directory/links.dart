/// El portal usa rutas en el fragmento, igual que las invitaciones.
/// Así el alojamiento recibe la raíz y Flutter abre la ficha del directorio.
final trainerDirectoryPublicBase = Uri.https(
  'trainer.entrenaop.es',
  '/',
).replace(fragment: '/directory');
