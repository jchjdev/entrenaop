import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop_trainer/main.dart';

class _Auth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

class _Client extends Fake implements SupabaseClient {
  @override
  final GoTrueClient auth = _Auth();
}

void main() {
  testWidgets('el calendario del portal usa fechas y acciones en castellano', (
    tester,
  ) async {
    final client = _Client();
    await tester.pumpWidget(TrainerApp(client: client));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    final selected = showDatePicker(
      context: context,
      initialDate: DateTime(2026, 10, 26),
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(
      find.textContaining(RegExp('octubre', caseSensitive: false)),
      findsWidgets,
    );
    expect(find.text('Select date'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await selected;
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
