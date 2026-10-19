import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_catalog_panel.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';

import '../../helpers/performance_visual_review.dart';
import '../../support/guided_program_fixture.dart';

const strength = GuidedProgramCategory(id: 'strength', name: 'Fuerza');
const beginner = GuidedProgramCategory(id: 'beginner', name: 'Iniciación');
GuidedProgram categorized({
  String id = 'program',
  String? primary = 'strength',
  List<GuidedProgramCategory> categories = const [strength, beginner],
}) => GuidedProgram(
  id: id,
  name: 'Mejora de glúteo y tirón',
  mode: guidedFixture.mode,
  phases: guidedFixture.phases,
  categories: categories,
  primaryCategoryId: primary,
);

void main() {
  setUpAll(loadReviewFont);
  test(
    'clasificación múltiple con una principal y fuera de la receta deportiva',
    () {
      final program = categorized();
      validateGuidedProgram(program);
      expect(program.primaryCategory!.name, 'Fuerza');
      final json = guidedProgramToJson(program);
      expect(json.containsKey('categories'), isFalse);
      expect(json.containsKey('primary_category_id'), isFalse);
      expect(
        () => validateGuidedProgram(categorized(primary: 'absent')),
        throwsFormatException,
      );
      expect(
        () => validateGuidedProgram(
          categorized(categories: [strength, strength]),
        ),
        throwsFormatException,
      );
      validateGuidedProgram(categorized(primary: null, categories: []));
    },
  );

  for (final view in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets('Biblioteca ocupa su ancho y conserva etiquetas a $view', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(view.$1, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(view.$2)),
            child: RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: child!,
            ),
          ),
          home: Scaffold(body: GuidedCatalogPanel(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      final cards = find.byType(GuidedProgramCard);
      final available = view.$1 - 40;
      expect(
        tester.getSize(cards.first).width,
        view.$1 < 640 ? available : (available - 12) / 2,
      );
      expect(find.text('Rutina'), findsNWidgets(2));
      expect(find.text('Fuerza'), findsNWidgets(3));
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar'),
        'gluteo fuerza',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final category = find.byKey(const ValueKey('guided-category-beginner'));
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      expect(repo.lastQuery, 'gluteo fuerza');
      expect(repo.lastCategory, 'beginner');
      expect(repo.lastPage, 0);
      expect(tester.takeException(), isNull);
      await capturePerformanceWidget(
        tester,
        'biblioteca-categorias-${view.$1}-${view.$2}',
      );
    });
  }

  testWidgets(
    'muchas categorías se deslizan y filtran junto con texto y modalidad',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repository()
        ..extraCategories = [
          for (var i = 0; i < 8; i++)
            GuidedProgramCategory(id: 'extra-$i', name: 'Categoría $i'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(body: GuidedCatalogPanel(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gluteo');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por fases').last);
      await tester.pumpAndSettle();
      final strip = find.byKey(const PageStorageKey('guided-category-strip'));
      final last = find.byKey(const ValueKey('guided-category-extra-7'));
      expect(last.hitTestable(), findsNothing);
      await tester.drag(strip, const Offset(-1800, 0));
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(repo.lastCategory, 'extra-7');
      expect(repo.lastQuery, 'gluteo');
      expect(repo.lastMode, GuidedProgramMode.phased);
      expect(tester.widget<ChoiceChip>(last).selected, isTrue);
      await tester.drag(strip, const Offset(1800, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      expect(repo.lastCategory, isNull);
      expect(repo.lastQuery, 'gluteo');
      expect(repo.lastMode, GuidedProgramMode.phased);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallar categorías permite consultar programas y reintentar opciones',
    (tester) async {
      final repo = _Repository()..failCategories = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GuidedCatalogPanel(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuidedProgramCard), findsNWidgets(2));
      expect(find.text('Reintentar categorías'), findsOneWidget);
      repo.failCategories = false;
      await tester.tap(find.text('Reintentar categorías'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Todos'), findsOneWidget);
    },
  );
}

class _Repository extends GuidedTestRepository {
  String? lastCategory, lastQuery;
  GuidedProgramMode? lastMode;
  List<GuidedProgramCategory> extraCategories = [];
  int? lastPage;
  bool failCategories = false;
  @override
  Future<List<GuidedProgramCategory>> categories() async {
    if (failCategories) throw StateError('Sin conexión');
    return [strength, beginner, ...extraCategories];
  }

  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  }) async {
    lastCategory = categoryId;
    lastQuery = query;
    lastPage = page;
    lastMode = mode;
    return GuidedCatalogPage([
      categorized(),
      categorized(id: 'other'),
    ], hasMore: false);
  }
}
