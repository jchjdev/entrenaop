import 'dart:typed_data';

import 'package:flutter/material.dart';

typedef ProfilePhotoLoader = Future<Uint8List> Function(String path);

class ProfilePhotoAvatar extends StatefulWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.name,
    this.path,
    this.load,
    this.radius = 24,
  });
  final String name;
  final String? path;
  final ProfilePhotoLoader? load;
  final double radius;
  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar>
    with WidgetsBindingObserver {
  Future<Uint8List?>? _bytes;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  void _reload() {
    _bytes = widget.path != null && widget.load != null ? _read() : null;
  }

  Future<Uint8List?> _read() async {
    try {
      return await widget.load!(widget.path!);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.load != widget.load) {
      _reload();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    final fallback = Text(initials.isEmpty ? '?' : initials);
    return Semantics(
      label: 'Foto de ${widget.name}',
      image: true,
      child: CircleAvatar(
        radius: widget.radius,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (_, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null ||
                bytes.isEmpty ||
                snapshot.hasError ||
                snapshot.connectionState != ConnectionState.done) {
              return fallback;
            }
            return ClipOval(
              child: Image.memory(
                bytes,
                width: widget.radius * 2,
                height: widget.radius * 2,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
              ),
            );
          },
        ),
      ),
    );
  }
}
