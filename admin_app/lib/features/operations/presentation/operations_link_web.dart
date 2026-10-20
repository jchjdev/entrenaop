import 'package:web/web.dart' as web;

void openOperationsUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
