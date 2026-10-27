import 'package:web/web.dart' as web;

void clearTrainerAuthCallbackUrl() {
  // Los códigos y tokens no quedan en la barra ni se entregan a go_router.
  web.window.history.replaceState(null, '', '/');
}
