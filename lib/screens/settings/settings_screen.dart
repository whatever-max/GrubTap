import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/background_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bgProvider = Provider.of<BackgroundProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Theme", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButton<ThemeMode>(
            value: themeProvider.themeMode,
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text("System Default"),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text("Light Theme"),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text("Dark Theme"),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) themeProvider.setThemeMode(mode);
            },
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Change Background Image'),
            trailing: const Icon(Icons.image),
            onTap: () {
              bgProvider.pickNewBackground(); // opens image picker
            },
          ),
          if (bgProvider.backgroundImagePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Image.file(
                bgProvider.getBackgroundFile()!,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}
