import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundProvider extends ChangeNotifier {
  File? _backgroundImage;

  File? getBackgroundFile() => _backgroundImage;
  String? get backgroundImagePath => _backgroundImage?.path;

  Future<void> loadBackground() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/background.png';
    final file = File(path);
    if (await file.exists()) {
      _backgroundImage = file;
      notifyListeners();
    }
  }

  Future<void> pickNewBackground() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final saved = await File(picked.path).copy('${dir.path}/background.png');
      _backgroundImage = saved;
      notifyListeners();
    }
  }
}
