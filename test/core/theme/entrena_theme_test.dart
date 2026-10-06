import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el tema concentra la identidad visual de la app', (
    tester,
  ) async {
    late ThemeData theme;
    late EntrenaVisuals visuals;

    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            visuals = context.visuals;
            return const Scaffold(body: Card(child: Text('Contenido')));
          },
        ),
      ),
    );

    expect(theme.scaffoldBackgroundColor, EntrenaTheme.canvas);
    expect(theme.colorScheme.primary, EntrenaTheme.brandOrange);
    expect(theme.cardTheme.color, visuals.surface);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.navigationBarTheme.indicatorColor, visuals.accentSoft);
  });

  testWidgets('el wordmark oscuro usa el recurso de marca correcto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EntrenaWordmark())),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(
      provider.assetName,
      'assets/branding/entrenaop_wordmark_on_dark.png',
    );
    expect(provider.package, 'entrena_ui');
  });

  testWidgets('la tarjeta de marca conserva una interaccion unica', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: Scaffold(
          body: EntrenaCard(onTap: () => taps++, child: const Text('Abrir')),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    expect(taps, 1);
  });
}
