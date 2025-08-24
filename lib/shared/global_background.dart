// lib/shared/global_background.dart
import 'package:flutter/material.dart';

class GlobalBackground extends StatelessWidget {
  final Widget child;
  final ThemeMode themeMode; // To adjust overlay based on theme

  const GlobalBackground({
    super.key,
    required this.child,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    // Determine overlay color based on themeMode
    // This helps the background blend and text remain readable
    Color overlayColor;
    if (themeMode == ThemeMode.light) {
      overlayColor = Colors.white.withOpacity(0.5); // Lighter overlay for light theme
    } else if (themeMode == ThemeMode.dark) {
      overlayColor = Colors.black.withOpacity(0.6); // Darker overlay for dark theme
    } else {
      // System theme: Adapt based on current brightness
      final brightness = MediaQuery.platformBrightnessOf(context);
      overlayColor = brightness == Brightness.dark
          ? Colors.black.withOpacity(0.6)
          : Colors.white.withOpacity(0.5);
    }

    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            'assets/images/my_background.jpg', // Your asset image path
            fit: BoxFit.cover,
            // Optional: Apply a color filter directly to the image if needed,
            // but the overlay container is usually more flexible.
            // color: Colors.black.withOpacity(0.1),
            // colorBlendMode: BlendMode.darken,
          ),
        ),
        // Overlay for blending and readability
        Positioned.fill(
          child: Container(
            color: overlayColor,
          ),
        ),
        // Your app's content
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}
