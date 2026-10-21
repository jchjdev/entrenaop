import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'totp_qr_source.dart';

Widget totpQr(String svg) => SizedBox.square(
  dimension: 220,
  child: HtmlElementView.fromTagName(
    tagName: 'img',
    onElementCreated: (element) {
      final image = element as web.HTMLImageElement;
      image.alt = 'Código QR para tu aplicación de autenticación';
      image.src = totpQrImageSource(svg);
      image.style
        ..width = '220px'
        ..height = '220px'
        ..backgroundColor = 'white'
        ..padding = '8px'
        ..boxSizing = 'border-box';
    },
  ),
);
