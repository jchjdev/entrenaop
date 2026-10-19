import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget adminTotpQr(String svg) => SizedBox.square(
  dimension: 220,
  child: HtmlElementView.fromTagName(
    tagName: 'img',
    onElementCreated: (element) {
      final image = element as web.HTMLImageElement;
      image.alt = 'Código QR para tu aplicación de autenticación';
      image.src = Uri.dataFromString(
        svg,
        mimeType: 'image/svg+xml',
        encoding: utf8,
      ).toString();
      image.style
        ..width = '220px'
        ..height = '220px'
        ..backgroundColor = 'white'
        ..padding = '8px'
        ..boxSizing = 'border-box';
    },
  ),
);
