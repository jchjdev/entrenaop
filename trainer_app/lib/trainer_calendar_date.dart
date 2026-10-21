/// Una fecha pautada es civil: no se convierte a UTC para enviarla al servidor.
String trainerCalendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
