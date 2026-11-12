import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DraftProbe extends StatefulWidget {
  const DraftProbe({super.key});
  @override
  State<DraftProbe> createState() => _DraftProbeState();
}

class _DraftProbeState extends State<DraftProbe> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final children = <Widget>[
        TextField(key: const ValueKey('draft'), controller: text),
        const SizedBox(height: 1100),
      ];
      return constraints.hasBoundedHeight
          ? ListView(children: children)
          : Column(mainAxisSize: MainAxisSize.min, children: children);
    },
  );
}

void main() {
  testWidgets('el catálogo iguala las tarjetas y centra su contenido', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    var taps = 0;
    Widget app({required bool desktop, double scale = 1}) => MaterialApp(
      home: ProfessionalWorkspaceScope(
        desktop: desktop,
        child: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: ProfessionalCatalogGrid(
                  maxColumns: 3,
                  children: [
                    for (final (index, title) in [
                      'Dominadas',
                      'Face pulls',
                      'Front lever',
                      'Remo con mancuernas\ncon pecho apoyado',
                    ].indexed)
                      ProfessionalResourceCard(
                        key: ValueKey(index),
                        title: Text(title),
                        subtitle: const Text('Versión 1 · espalda'),
                        leading: const Icon(Icons.fitness_center),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => taps++,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Rect card(int index) => t.getRect(find.byKey(ValueKey(index)));

    await t.pumpWidget(app(desktop: true));
    final desktopCard = card(0);
    expect(card(1).top, desktopCard.top);
    for (final index in [1, 2, 3]) {
      expect(card(index).width, closeTo(desktopCard.width, 0.01));
      expect(card(index).height, desktopCard.height);
    }
    expect(card(3).top, desktopCard.bottom + 16);
    void expectCentered(int index) {
      final entry = find.byKey(ValueKey(index));
      Finder within(Finder matching) =>
          find.descendant(of: entry, matching: matching);
      final title = t.getRect(within(find.byType(Text)).first);
      final subtitle = t.getRect(within(find.text('Versión 1 · espalda')));
      final content = title.expandToInclude(subtitle);
      expect(content.center.dy, closeTo(card(index).center.dy, 5));
      for (final icon in [Icons.fitness_center, Icons.chevron_right]) {
        expect(
          t.getCenter(within(find.byIcon(icon))).dy,
          card(index).center.dy,
        );
      }
    }

    expectCentered(0);
    expectCentered(3);
    await t.tapAt(Offset(desktopCard.center.dx, desktopCard.bottom - 8));
    expect(taps, 1, reason: 'También se puede pulsar en el margen interior.');

    await t.binding.setSurfaceSize(const Size(320, 900));
    await t.pumpWidget(app(desktop: false, scale: 2));
    final compactCard = card(0);
    expect(compactCard.width, 320);
    expect(compactCard.height, greaterThan(desktopCard.height));
    expect(card(1).top, compactCard.bottom + 16);
    expect(card(3).size, compactCard.size);
    expectCentered(0);
    expectCentered(3);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'cambiar de paneles a scroll compacto conserva el editor montado',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: ProfessionalWorkspaceViewport(
            builder: (_) => const Scaffold(
              body: ProfessionalEmbeddedScroll(child: DraftProbe()),
            ),
          ),
        ),
      );
      expect(
        Theme.of(t.element(find.byType(DraftProbe)))
            .extension<ProfessionalSurfaceStyle>(),
        isNotNull,
      );
      await t.enterText(
        find.byKey(const ValueKey('draft')),
        'Borrador sin guardar',
      );
      final state = t.state(find.byType(DraftProbe));
      final controller = t
          .widget<TextField>(find.byKey(const ValueKey('draft')))
          .controller;
      await t.binding.setSurfaceSize(const Size(320, 900));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(DraftProbe)))
            .extension<ProfessionalSurfaceStyle>(),
        isNull,
      );
      expect(t.state(find.byType(DraftProbe)), same(state));
      expect(
        t.widget<TextField>(find.byKey(const ValueKey('draft'))).controller,
        same(controller),
      );
      expect(controller!.text, 'Borrador sin guardar');
      await t.binding.setSurfaceSize(const Size(1400, 1000));
      await t.pumpAndSettle();
      expect(t.state(find.byType(DraftProbe)), same(state));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'ampliar una página profesional no amplía diálogos ni el deportista',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1800, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      Widget app(bool desktop) => MaterialApp(
        home: ProfessionalWorkspaceScope(
          desktop: desktop,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: ProfessionalWorkspaceScope.pageConstraints(
                    context,
                    maxWidth: 900,
                  ),
                  child: SizedBox(
                    key: const ValueKey('page'),
                    width: double.infinity,
                    child: Align(
                      child: SizedBox(
                        key: const ValueKey('dialog'),
                        width: 480,
                        child: const Text('Formulario corto'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpWidget(app(false));
      expect(t.getSize(find.byKey(const ValueKey('page'))).width, 900);
      await t.pumpWidget(app(true));
      expect(t.getSize(find.byKey(const ValueKey('page'))).width, 1800);
      expect(t.getSize(find.byKey(const ValueKey('dialog'))).width, 480);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'la ruta no oculta la cabecera ni la navegación al lector de pantalla',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        MaterialApp(
          home: ProfessionalWorkspaceShell(
            scaffoldKey: GlobalKey<ScaffoldState>(),
            navigation: TextButton(
              onPressed: () {},
              child: const Text('Biblioteca profesional'),
            ),
            headerBuilder: (_, _) => AppBar(
              title: const Text('Cabecera profesional'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar cuenta de ensayo',
                  onPressed: () {},
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Text('Contenido de la ruta')),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final labels = t.semantics.simulatedAccessibilityTraversal().map((node) {
        final data = node.getSemanticsData();
        return '${data.label} ${data.tooltip}';
      }).toList();
      for (final label in [
        'Biblioteca profesional',
        'Cerrar cuenta de ensayo',
        'Cabecera profesional',
        'Contenido de la ruta',
      ]) {
        expect(
          labels.any((text) => text.contains(label)),
          isTrue,
          reason: '$label debe convivir en la semántica',
        );
      }
      semantics.dispose();
      expect(
        t.getTopLeft(find.text('Cabecera profesional')).dy,
        lessThan(t.getTopLeft(find.text('Contenido de la ruta')).dy),
      );
      expect(t.takeException(), isNull);
    },
  );
}
