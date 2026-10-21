import 'trainer_csv_export_stub.dart'
    if (dart.library.js_interop) 'trainer_csv_export_web.dart'
    as platform;

/// CSV estándar con coma, CRLF y campos textuales entre comillas. Los números
/// siguen siendo números; los textos que podrían ser fórmulas se neutralizan.
String trainerCsvEncode(Iterable<Iterable<Object?>> rows) => rows
    .map(
      (row) => row
          .map((value) {
            if (value == null) return '';
            if (value is num) {
              if (!value.isFinite) {
                throw const FormatException(
                  'El CSV no admite números no finitos.',
                );
              }
              return value.toString();
            }
            var text = value.toString();
            if (RegExp(r'^[=+\-@]').hasMatch(text.trimLeft())) {
              text = "'$text";
            }
            return '"${text.replaceAll('"', '""')}"';
          })
          .join(','),
    )
    .join('\r\n');

Future<bool> downloadTrainerCsv(String filename, String csv) =>
    platform.downloadTrainerCsv(filename, csv);
