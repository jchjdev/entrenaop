import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  test(
    'preferencia conserva oscuro inicial y restaura la elección guardada',
    () {
      String? stored;
      final first = ProfessionalThemeController(
        read: () => stored,
        write: (value) => stored = value,
      );
      addTearDown(first.dispose);
      expect(first.value, ThemeMode.dark);
      first.toggle();
      expect(stored, 'light');
      final restored = ProfessionalThemeController(read: () => stored);
      addTearDown(restored.dispose);
      expect(restored.value, ThemeMode.light);
      expect(
        ProfessionalThemeController(read: () => 'desconocido').value,
        ThemeMode.dark,
      );
    },
  );

  test('almacenamiento bloqueado no impide alternar durante la visita', () {
    final controller = ProfessionalThemeController(
      read: () => throw StateError('bloqueado'),
      write: (_) => throw StateError('bloqueado'),
    );
    addTearDown(controller.dispose);
    expect(controller.value, ThemeMode.dark);
    controller.toggle();
    expect(controller.value, ThemeMode.light);
  });

  for (final dark in [true, false]) {
    for (final desktop in [true, false]) {
      test(
        'contraste legible en ${dark ? 'oscuro' : 'claro'} y escritorio=$desktop',
        () {
          final base = dark ? EntrenaTheme.dark : EntrenaTheme.light;
          final theme = desktop ? ProfessionalAppearance.desktop(base) : base;
          final scheme = theme.colorScheme;
          final visuals = theme.extension<EntrenaVisuals>()!;
          expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
          for (final surface in [
            visuals.surface,
            visuals.surfaceHigh,
            visuals.surfaceLow,
          ]) {
            expect(
              contrast(surface, scheme.onSurface),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              contrast(surface, scheme.onSurfaceVariant),
              greaterThanOrEqualTo(4.5),
            );
          }
          expect(
            contrast(scheme.primary, scheme.onPrimary),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
            greaterThanOrEqualTo(4.5),
          );
          final style = theme.filledButtonTheme.style!;
          expect(
            contrast(
              style.backgroundColor!.resolve({})!,
              style.foregroundColor!.resolve({})!,
            ),
            greaterThanOrEqualTo(4.5),
          );
        },
      );
    }
  }

  testWidgets('cambiar de tema conserva la ruta abierta y su borrador', (
    t,
  ) async {
    final controller = ProfessionalThemeController(
      read: () => 'dark',
      write: (_) {},
    );
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      ProfessionalThemeScope(
        controller: controller,
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorKey: navigator,
            theme: EntrenaTheme.light,
            darkTheme: EntrenaTheme.dark,
            themeMode: ProfessionalThemeScope.maybeOf(context)!.value,
            home: const Scaffold(body: Text('Inicio')),
          ),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(actions: const [ProfessionalThemeButton()]),
          body: const TextField(
            decoration: InputDecoration(labelText: 'Mi borrador'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Sesión sin guardar');
    final before = navigator.currentState;
    await t.tap(find.byTooltip('Cambiar a modo claro'));
    await t.pumpAndSettle();
    expect(navigator.currentState, same(before));
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Sesión sin guardar'), findsOneWidget);
    expect(
      Theme.of(t.element(find.byType(TextField))).brightness,
      Brightness.light,
    );
    expect(find.byTooltip('Cambiar a modo oscuro'), findsOneWidget);
  });

  testWidgets('logo y acentos del calendario son legibles en claro', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.light,
        home: const Scaffold(body: EntrenaWordmark.adaptive()),
      ),
    );
    final image = t.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, endsWith('on_light.png'));
    final context = t.element(find.byType(EntrenaWordmark));
    for (final color in [
      Colors.yellow,
      Colors.cyanAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.blueAccent,
    ]) {
      expect(
        contrast(
          context.readableAccent(color),
          Theme.of(context).colorScheme.surface,
        ),
        greaterThanOrEqualTo(5.5),
      );
    }
  });
}
