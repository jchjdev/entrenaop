import 'package:entrenaop_admin/features/auth/presentation/admin_totp_qr_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Imagen sintética sin URI de autenticación, clave ni datos de una cuenta.
  const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="21" height="21">'
      '<rect width="21" height="21" fill="#ffffff"/>'
      '<path fill="#000000" d="M1 1h7v7H1z"/></svg>';

  test('normaliza el formato de GoTrue sin codificar la URI como SVG', () {
    final result = UriData.parse(
      adminTotpQrImageSource('data:image/svg+xml;utf-8,$svg'),
    );
    expect(result.mimeType, 'image/svg+xml');
    expect(result.contentAsString(), svg);
    expect(result.isBase64, isTrue);
  });

  test('admite el SVG sin prefijo y conserva colores con almohadilla', () {
    final result = UriData.parse(adminTotpQrImageSource(svg));
    expect(result.contentAsString(), svg);
    expect(result.uri.fragment, isEmpty);
  });
}
