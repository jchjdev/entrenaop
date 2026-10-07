import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlanPreviewScope extends StatelessWidget {
  const PlanPreviewScope({required this.cubit, required this.child, super.key});
  final PlanPreviewCubit cubit;
  final Widget child;

  static PlanPreviewState? stateOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PreviewScope>()?.state;

  static PlanPreviewCubit? controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PreviewScope>()?.controller;

  static bool isFree(BuildContext context) => stateOf(context)?.isFree ?? false;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PlanPreviewCubit, PlanPreviewState>(
        bloc: cubit,
        builder: (context, state) =>
            _PreviewScope(state: state, controller: cubit, child: child),
      );
}

class _PreviewScope extends InheritedWidget {
  const _PreviewScope({
    required this.state,
    required this.controller,
    required super.child,
  });
  final PlanPreviewState state;
  final PlanPreviewCubit controller;

  @override
  bool updateShouldNotify(_PreviewScope oldWidget) => state != oldWidget.state;
}
