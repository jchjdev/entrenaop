import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// go_router 18 detecta MaterialApp de material_ui, no el de Flutter utilizado
/// por EntrenaOP. Una página explícita conserva las transiciones y el gesto.
GoRoute materialAppRoute({
  required String path,
  GoRouterWidgetBuilder? builder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  GoRouterRedirect? redirect,
  ExitCallback? onExit,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  parentNavigatorKey: parentNavigatorKey,
  redirect: redirect,
  onExit: onExit,
  routes: routes,
  pageBuilder: builder == null
      ? null
      : (context, state) => _AppMaterialPage(
          key: state.pageKey,
          name: state.name ?? state.path,
          arguments: <String, String>{
            ...state.pathParameters,
            ...state.uri.queryParameters,
          },
          restorationId: state.pageKey.value,
          guarded: onExit != null,
          child: builder(context, state),
        ),
);

class _AppMaterialPage extends MaterialPage<Object?> {
  const _AppMaterialPage({
    required super.child,
    required this.guarded,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });
  final bool guarded;

  @override
  Route<Object?> createRoute(BuildContext context) =>
      _AppMaterialPageRoute(this);
}

class _AppMaterialPageRoute extends PageRoute<Object?>
    with MaterialRouteTransitionMixin<Object?> {
  _AppMaterialPageRoute(_AppMaterialPage page) : super(settings: page);
  _AppMaterialPage get _page => settings as _AppMaterialPage;

  @override
  Widget buildContent(BuildContext context) => _page.child;
  @override
  bool get maintainState => _page.maintainState;
  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  // onExit es asíncrono: mover la página antes de su permiso deja la animación
  // a cero si se cancela. El gesto protegido consulta go_router sin moverla.
  @override
  bool get popGestureEnabled => !_page.guarded && super.popGestureEnabled;
}
