import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuration pour les tests
void setupTestEnvironment() {
  // Initialiser les bindings de test
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Désactiver les animations pendant les tests
  TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue = 
      const Size(1080, 1920);
  TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 1.0;
}

/// Crée un widget de test avec un thème de base qui n'utilise pas Google Fonts
Widget createTestableWidget(Widget child) {
  return MaterialApp(
    home: child,
    // Désactiver le chargement des polices à l'exécution
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Arial'),
        displayMedium: TextStyle(fontFamily: 'Arial'),
        displaySmall: TextStyle(fontFamily: 'Arial'),
        headlineMedium: TextStyle(fontFamily: 'Arial'),
        headlineSmall: TextStyle(fontFamily: 'Arial'),
        titleLarge: TextStyle(fontFamily: 'Arial'),
        titleMedium: TextStyle(fontFamily: 'Arial'),
        titleSmall: TextStyle(fontFamily: 'Arial'),
        bodyLarge: TextStyle(fontFamily: 'Arial'),
        bodyMedium: TextStyle(fontFamily: 'Arial'),
        bodySmall: TextStyle(fontFamily: 'Arial'),
        labelLarge: TextStyle(fontFamily: 'Arial'),
        labelMedium: TextStyle(fontFamily: 'Arial'),
        labelSmall: TextStyle(fontFamily: 'Arial'),
      ),
    ),
  );
}

/// Enveloppe un widget avec MaterialApp et un thème personnalisé
Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    home: child,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Arial'),
        displayMedium: TextStyle(fontFamily: 'Arial'),
        displaySmall: TextStyle(fontFamily: 'Arial'),
        headlineMedium: TextStyle(fontFamily: 'Arial'),
        headlineSmall: TextStyle(fontFamily: 'Arial'),
        titleLarge: TextStyle(fontFamily: 'Arial'),
        titleMedium: TextStyle(fontFamily: 'Arial'),
        titleSmall: TextStyle(fontFamily: 'Arial'),
        bodyLarge: TextStyle(fontFamily: 'Arial'),
        bodyMedium: TextStyle(fontFamily: 'Arial'),
        bodySmall: TextStyle(fontFamily: 'Arial'),
        labelLarge: TextStyle(fontFamily: 'Arial'),
        labelMedium: TextStyle(fontFamily: 'Arial'),
        labelSmall: TextStyle(fontFamily: 'Arial'),
      ),
    ),
  );
}
