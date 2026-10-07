// Reproducción web local sin autenticación: compara el proveedor anterior con
// el actual utilizando un PNG de color, sin red ni datos personales.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _url =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAE0lEQVR4nGP8n8KAFTBhFx6sEgAaqAFzazWjegAAAABJRU5ErkJggg==';
void main() => runApp(const _Probe());

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final GoRouter _router;
  int _returns = 0;
  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Regresión de portadas web · código actual'),
            ),
            body: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              i == 0
                                  ? 'Proveedor anterior'
                                  : 'Proveedor corregido',
                            ),
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: EntrenaCoverImage(
                                image: i == 0
                                    ? const CachedNetworkImageProvider(_url)
                                    : preparationCoverProvider(_url),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                FilledButton(
                  onPressed: _run,
                  child: const Text('Entrar en otra pantalla'),
                ),
                Text('Entradas y salidas completadas: $_returns'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/away',
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => _router.pop(),
                child: const Text('Volver a las imágenes'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _run() async {
    await _router.push('/away');
    if (mounted) setState(() => _returns++);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: _router);
}
