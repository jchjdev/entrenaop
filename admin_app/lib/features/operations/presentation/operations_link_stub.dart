import 'package:flutter/services.dart';

void openOperationsUrl(String url) {
  Clipboard.setData(ClipboardData(text: url));
}
