/// Fecha visible. El llamador conserva la zona civil del recurso;
/// los parámetros de rutas y las peticiones mantienen su formato ISO.
String formatAppDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().padLeft(4, '0')}';

String formatAppDateTime(DateTime date) =>
    '${formatAppDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
