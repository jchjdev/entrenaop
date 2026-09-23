import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements AdminProgramRepository {
  _FakeRepository({required this.allowed});

  final bool allowed;
  int listCalls = 0;
  int createCalls = 0;
  final programs = <AdminProgram>[];

  @override
  Future<bool> hasAccess() async => allowed;

  @override
  Future<List<AdminProgram>> listPrograms() async {
    listCalls++;
    return List.of(programs);
  }

  @override
  Future<void> createDraft({required String name, required String kind}) async {
    createCalls++;
    programs.add(
      AdminProgram(id: 'new', name: name, kind: kind, enabled: false),
    );
  }
}

void main() {
  testWidgets('sin permiso no consulta ni muestra borradores', (tester) async {
    final repository = _FakeRepository(allowed: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminProgramsPage(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no tiene permiso'), findsOneWidget);
    expect(find.text('Nuevo programa'), findsNothing);
    expect(repository.listCalls, 0);
  });

  testWidgets('administración crea un borrador y vuelve a listarlo', (
    tester,
  ) async {
    final repository = _FakeRepository(allowed: true);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminProgramsPage(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo programa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Guardia Civil');
    await tester.tap(find.text('Crear borrador'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.programs.single.kind, 'access');
    expect(repository.programs.single.enabled, false);
    expect(find.text('Guardia Civil'), findsOneWidget);
    expect(find.text('Borrador'), findsOneWidget);
    expect(repository.listCalls, 2);
  });
}
