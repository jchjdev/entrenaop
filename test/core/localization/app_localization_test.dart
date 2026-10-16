import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la app traduce los controles aunque el dispositivo use inglés', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(EntrenaOpApp(authCubit: _Auth()));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context), const Locale('es', 'ES'));
    final labels = MaterialLocalizations.of(context);
    expect(labels.saveButtonLabel, 'Guardar');
    expect(labels.cancelButtonLabel, 'Cancelar');
    expect(labels.formatMonthYear(DateTime(2026, 10)), 'octubre de 2026');
    expect(tester.takeException(), isNull);
  });
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(AuthUnauthenticated());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
