import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/shared_prefs_service.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  Future<DecorationImage?> _loadBackground() async {
    final bgPath = await SharedPrefsService.getBackgroundPath();
    if (bgPath != null && File(bgPath).existsSync()) {
      return DecorationImage(
        image: FileImage(File(bgPath)),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withOpacity(0.3),
          BlendMode.darken,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DecorationImage?>(
      future: _loadBackground(),
      builder: (context, snapshot) {
        return Container(
          decoration: BoxDecoration(
            image: snapshot.data,
          ),
          child: child,
        );
      },
    );
  }
}
