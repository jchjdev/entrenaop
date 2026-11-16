import 'package:web/web.dart' as web;

bool readHiddenGuide(String key) => web.window.localStorage.getItem(key) == '1';

void writeHiddenGuide(String key, bool hidden) {
  if (hidden) {
    web.window.localStorage.setItem(key, '1');
  } else {
    web.window.localStorage.removeItem(key);
  }
}
