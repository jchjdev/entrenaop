import 'package:entrenaop/features/preparation_goal/data/models/preparation_goal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final program = <String, dynamic>{
    'id': 'fas',
    'name': 'FAS',
    'kind': 'internal_assessment',
  };
  final cover = <String, dynamic>{
    'card_image_path': 'card.jpg',
    'header_image_path': 'header.jpg',
    'focal_x': 0.8,
    'focal_y': 0.3,
  };
  String resolve(String path) => 'https://example.test/$path';
  test(
    'resuelve rutas editoriales fuera del dominio y admite relación uno a uno',
    () {
      for (final relation in [
        cover,
        [cover],
      ]) {
        final result = PreparationProgramModel.fromJson({
          ...program,
          'preparation_program_covers': relation,
        }, resolveCoverUrl: resolve);
        expect(result.cover!.cardUrl, 'https://example.test/card.jpg');
        expect(result.cover!.headerUrl, 'https://example.test/header.jpg');
        expect(result.cover!.focalX, 0.8);
        expect(result.cover!.focalY, 0.3);
        expect(result.cover!.headerFocalX, 0.8);
        expect(result.cover!.headerFocalY, 0.3);
        expect(result.currentAssessmentCatalogVersion, isNull);
      }
    },
  );
  test('una retirada, relación ausente o catálogo antiguo conserva la preparación sin foto', () {
    for (final relation in [
      null,
      [],
      {'card_image_path': null, 'header_image_path': null},
    ]) {
      final result = PreparationProgramModel.fromJson({
        ...program,
        'preparation_program_covers': relation,
      }, resolveCoverUrl: resolve);
      expect(result.cover, isNull);
      expect(result.name, 'FAS');
    }
    expect(
      PreparationProgramModel.fromJson({
        ...program,
        'preparation_program_covers': cover,
      }).cover,
      isNull,
    );
  });
  test('el nuevo catálogo conserva el encuadre propio de cabecera sin cambiar la tarjeta', () {
    final result = PreparationProgramModel.fromJson({
      ...program,
      'preparation_program_covers': {
        ...cover,
        'header_focal_x': 0.6,
        'header_focal_y': 0.7,
      },
    }, resolveCoverUrl: resolve);
    expect([result.cover!.focalX, result.cover!.focalY], [0.8, 0.3]);
    expect(
      [result.cover!.headerFocalX, result.cover!.headerFocalY],
      [0.6, 0.7],
    );
  });
}
