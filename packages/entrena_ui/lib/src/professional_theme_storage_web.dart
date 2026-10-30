import 'package:web/web.dart' as web;

const _key = 'entrenaop.professional.appearance.v1';

String? readProfessionalTheme() => web.window.localStorage.getItem(_key);
void writeProfessionalTheme(String value) =>
    web.window.localStorage.setItem(_key, value);
