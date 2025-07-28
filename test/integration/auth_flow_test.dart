import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeotp_clone/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:freeotp_clone/providers/otp_provider.dart';
import 'package:freeotp_clone/screens/splash_screen.dart';
import 'package:freeotp_clone/services/security_service.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import '../test_helpers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Classe mock pour SecurityService avec mocktail
class MockSecurityService extends Mock implements SecurityService {
  // Implémentation des méthodes nécessaires pour les tests
  
  @override
  Future<bool> isBiometricAvailable() => 
      Future.value(false);
      
  @override
  @Deprecated('Utilisez isBiometricAvailable() à la place')
  Future<bool> isBiometricConfigured() => 
      isBiometricAvailable();
  
  @override
  Future<bool> authenticate() => 
      Future.value(true);
      
  @override
  Future<String> encryptData(String data) async {
    // Simulation simple du chiffrement pour les tests
    // Utilisation d'une clé de test fixe pour les tests
    final key = encrypt.Key.fromBase64('test_key_123456789012345678901234567890');
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(data, iv: iv);
    return '${iv.base64}.${encrypted.base64}';
  }
      
  @override
  Future<String> decryptData(String encryptedData) async {
    try {
      final parts = encryptedData.split('.');
      if (parts.length != 2) throw Exception('Données chiffrées invalides');
      
      final key = encrypt.Key.fromBase64('test_key_123456789012345678901234567890');
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      return encrypter.decrypt(
        encrypt.Encrypted.fromBase64(parts[1]),
        iv: iv,
      );
    } catch (e) {
      debugPrint('Erreur lors du déchiffrement dans le test: $e');
      rethrow;
    }
  }
      
  @override
  void updateInteractionTime() {
    // Ne rien faire pour les tests
  }
      
  @override
  Future<Map<String, dynamic>> getAutoLockConfig() async => 
      {'enabled': false, 'timeout': 60};
      
  @override
  Future<void> configureAutoLock({
    required bool enabled, 
    int? timeoutInSeconds,
  }) async {
    // Ne rien faire pour les tests
  }
      
  @override
  Stream<bool> get authStream => const Stream<bool>.empty();
      
  @override
  void dispose() {
    // Nettoyage pour les tests
  }
  

}

// Classe de test pour le PathProvider
class TestPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String> getApplicationDocumentsPath() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
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
    try {
      final appDocDir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
      Hive.init('$appDocDir/test_hive');
      
      // S'assurer que la box est ouverte
      if (!Hive.isBoxOpen('otp_accounts')) {
        await Hive.openBox('otp_accounts');
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de Hive: $e');
      rethrow;
    }
  });

  // Nettoyage après les tests
  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('Test du flux d\'authentification de base', (WidgetTester tester) async {
    // Configuration initiale pour les tests
    SharedPreferences.setMockInitialValues({'password_set': false});
    debugPrint('✅ Configuration initiale terminée');

    // Créer un mock du SecurityService avec mocktail
    final securityService = MockSecurityService();
    
    // Les méthodes sont déjà implémentées dans la classe MockSecurityService
    // Aucun besoin de les reconfigurer avec when()
    
    // Exécution du widget principal avec les providers nécessaires
    debugPrint('⏳ Démarrage du test...');
    
    // Créer un OTPProvider personnalisé avec un init qui loggue
    final otpProvider = OTPProvider();
    debugPrint('🔧 Initialisation du OTPProvider...');
    
    try {
      await otpProvider.init(securityService);
      debugPrint('✅ OTPProvider initialisé avec succès');
    } catch (e, stack) {
      debugPrint('❌ Erreur lors de l\'initialisation du OTPProvider: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
    
    // Configuration du thème pour les tests
    final testApp = MaterialApp(
      home: MultiProvider(
        providers: [
          Provider<SecurityService>.value(value: securityService),
          ChangeNotifierProvider<OTPProvider>.value(value: otpProvider),
        ],
        child: Builder(
          builder: (context) {
            return const SplashScreen();
          },
        ),
      ),
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
    
    await tester.pumpWidget(testApp);
    debugPrint('✅ Widget principal monté');

    // Attendre que l'écran de démarrage se charge
    debugPrint('⏳ Attente du chargement de l\'écran de démarrage...');
    
    // Donner du temps pour que l'initialisation asynchrone se termine
    await tester.pump(const Duration(seconds: 1));
    debugPrint('✅ Premier frame rendu');
    
    // Vérifier si l'écran de démarrage est présent
    expect(find.byType(SplashScreen), findsOneWidget);
    debugPrint('✅ Écran de démarrage détecté');
    
    // Attendre la fin des animations
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    debugPrint('✅ Animations terminées');
    
    // Simuler la fin de l'initialisation
    debugPrint('⏳ Simulation de la fin de l\'initialisation...');
    await tester.pump(const Duration(seconds: 1));
    debugPrint('✅ Initialisation simulée');

    // Vérifier que l'écran de création de mot de passe est affiché
    debugPrint('🔍 Vérification de l\'affichage de l\'écran de création de mot de passe...');
    expect(find.text('Créer un mot de passe'), findsOneWidget);
    debugPrint('✅ Test réussi !');
  });
}
