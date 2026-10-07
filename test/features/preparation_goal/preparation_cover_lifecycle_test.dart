import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la portada web sigue pintando tras ocultar y volver a la ruta', (
    tester,
  ) async {
    const url =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAE0lEQVR4nGP8n8KAFTBhFx6sEgAaqAFzazWjegAAAABJRU5ErkJggg==';
    late StateSetter rebuild;
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TickerMode(
              enabled: visible,
              child: SizedBox(
                width: 200,
                height: 200,
                child: EntrenaCoverImage(image: preparationCoverProvider(url)),
              ),
            );
          },
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      final raw = tester.widget<RawImage>(find.byType(RawImage));
      expect(raw.image, isNotNull, reason: 'vuelta $i');
      expect(tester.takeException(), isNull);
      rebuild(() => visible = false);
      await tester.pump();
      rebuild(() => visible = true);
      await tester.pump();
    }
    await tester.pumpWidget(const SizedBox());
  }, skip: !kIsWeb);
}
