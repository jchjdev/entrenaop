import 'dart:convert';

String adminTotpQrImageSource(String qrCode) {
  // GoTrue Dart añade este prefijo al SVG de Auth. Se retira antes de
  // codificarlo: envolver la URI completa produce una imagen SVG inválida.
  const sdkPrefix = 'data:image/svg+xml;utf-8,';
  final svg = qrCode.startsWith(sdkPrefix)
      ? qrCode.substring(sdkPrefix.length)
      : qrCode;
  return Uri.dataFromString(
    svg,
    mimeType: 'image/svg+xml',
    encoding: utf8,
    base64: true,
  ).toString();
}
