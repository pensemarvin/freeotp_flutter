import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeotp_clone/main.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:freeotp_clone/providers/otp_provider.dart';
import '../test_helpers.dart';

// Classe de test pour le PathProvider
class TestPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String> getApplicationDocumentsPath() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test_widget');
    return tempDir.path;
  }
}

void main() {
  // Initialisation pour les tests
  setUpAll(() async {
    // Configurer l'environnement de test
    setupTestEnvironment();
    
    // Configurer le PathProvider de test
    PathProviderPlatform.instance = TestPathProviderPlatform();
    
    // Initialiser Hive avec un chemin temporaire
    final appDocDir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
    Hive.init('$appDocDir/test_hive_widget');
    
    // S'assurer que la box est ouverte
    await Hive.openBox('otp_accounts');
  });

  // Nettoyage après les tests
  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('Vérifie que l\'application se lance correctement', (WidgetTester tester) async {
    // Exécution du widget principal avec les providers nécessaires
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OTPProvider()),
        ],
        child: createTestableWidget(const MyApp()),
      ),
    );

    // Attendre que l'interface utilisateur soit prête
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Vérifier que l'application s'est lancée correctement
    // En fonction de l'état de l'application, on peut vérifier différents éléments
    // Par exemple, si l'utilisateur n'a pas encore défini de mot de passe :
    expect(
      find.byType(Scaffold),
      findsOneWidget,
      reason: 'Le Scaffold principal devrait être affiché',
    );
  });
}
