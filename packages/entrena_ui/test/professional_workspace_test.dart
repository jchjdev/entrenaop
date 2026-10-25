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
}
