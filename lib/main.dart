import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher, Locale;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/otp_account.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'providers/otp_provider.dart';
import 'services/security_service.dart';
import 'services/logger_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_account_screen.dart';
import 'screens/account_details_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_settings_screen.dart';
import 'screens/lock_screen.dart';

// Référence globale au logger
globalLogger() => LoggerService();

// Gestionnaire d'erreurs global
void setupErrorHandling() {
  // Capturer les erreurs Flutter
  FlutterError.onError = (FlutterErrorDetails details) async {
    // Enregistrer l'erreur
    globalLogger().e(
      'Erreur Flutter non gérée',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'FlutterError',
    );
    
    // Afficher une notification à l'utilisateur
    await _showErrorNotification('Une erreur est survenue dans l\'interface utilisateur');
  };
  
  // Capturer les erreurs Dart non gérées
  PlatformDispatcher.instance.onError = (error, stack) {
    globalLogger().e(
      'Erreur Dart non gérée',
      error: error,
      stackTrace: stack,
      tag: 'DartError',
    );
    
    // Afficher une notification à l'utilisateur
    _showErrorNotification('Une erreur critique est survenue');
    
    // Ne pas empêcher l'application de planter si c'est une erreur critique
    return false;
  };
}

// Afficher une notification d'erreur
Future<void> _showErrorNotification(String message) async {
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Initialiser les notifications si ce n'est pas déjà fait
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Gérer le clic sur la notification si nécessaire
      },
    );
    
    // Afficher la notification
    await flutterLocalNotificationsPlugin.show(
      0,
      'Erreur',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'error_channel',
          'Erreurs',
          channelDescription: 'Notifications d\'erreur de l\'application',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  } catch (e) {
    // Si l'envoi de la notification échoue, on log l'erreur
    globalLogger().e(
      'Erreur lors de l\'envoi de la notification',
      error: e,
      tag: 'NotificationError',
    );
  }
}

Future<void> _initializeApp() async {
  // S'assurer que les liaisons Flutter sont initialisées
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Configurer la gestion des erreurs
    setupErrorHandling();
    
    // Initialiser les fuseaux horaires
    tz.initializeTimeZones();
    
    // Initialiser le logger
    await globalLogger().init();
    globalLogger().i('Démarrage de l\'application');
    
    // Initialiser Hive
    await _initializeHive();
    
    globalLogger().i('Initialisation de l\'application terminée avec succès');
  } catch (e, stackTrace) {
    globalLogger().e(
      'Échec critique lors de l\'initialisation de l\'application',
      error: e,
      stackTrace: stackTrace,
      tag: 'AppInitialization',
    );
    
    // Afficher une notification d'erreur à l'utilisateur
    await _showErrorNotification('Impossible de démarrer l\'application. Veuillez réessayer.');
    
    // Quitter l'application en cas d'échec critique
    SystemNavigator.pop();
    rethrow;
  }
}

Future<void> _initializeHive() async {
  try {
    // Initialiser Hive
    await Hive.initFlutter();
    
    // Enregistrer les adaptateurs Hive avec gestion des erreurs
    try {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(OTPAccountAdapter());
      }
    } catch (e) {
      globalLogger().e(
        'Erreur lors de l\'enregistrement de OTPAccountAdapter',
        error: e,
        tag: 'HiveInitialization',
      );
      // Continuer malgré l'erreur, l'application pourrait quand même fonctionner
    }
    
    try {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(OTPTypeAdapter());
      }
    } catch (e) {
      globalLogger().e(
        'Erreur lors de l\'enregistrement de OTPTypeAdapter',
        error: e,
        tag: 'HiveInitialization',
      );
      // Continuer malgré l'erreur
    }
    
    globalLogger().i('Hive initialisé avec succès');
  } catch (e, stackTrace) {
    globalLogger().e(
      'Échec de l\'initialisation de Hive',
      error: e,
      stackTrace: stackTrace,
      tag: 'HiveInitialization',
    );
    rethrow;
  }
}

void main() {
  // Démarrer l'application avec une zone d'erreur
  runZonedGuarded<Future<void>>(
    () async {
      try {
        await _initializeApp();
        runApp(const MyApp());
      } catch (e, stackTrace) {
        globalLogger().e(
          'Échec critique lors du démarrage de l\'application',
          error: e,
          stackTrace: stackTrace,
          tag: 'AppStartup',
        );
        
        // Tenter de redémarrer l'application
        Future.delayed(const Duration(seconds: 2), () {
          SystemNavigator.pop();
        });
      }
    },
    (error, stackTrace) async {
      // Enregistrer les erreurs non capturées
      globalLogger().f(
        'Erreur non capturée dans la zone d\'exécution principale',
        error: error,
        stackTrace: stackTrace,
        tag: 'UncaughtError',
      );
      
      // Afficher une notification à l'utilisateur
      await _showErrorNotification('Une erreur inattendue est survenue');
      
      // Essayer de redémarrer l'application si possible
      if (error is! Error) {
        Future.delayed(const Duration(seconds: 2), () {
          SystemNavigator.pop();
        });
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Initialisation du service de journalisation
        Provider<LoggerService>(
          create: (_) => globalLogger(),
        ),
        
        // Initialisation du service de sécurité
        Provider<SecurityService>(
          create: (context) => SecurityService(),
        ),
        
        // Initialisation du service OTP qui dépend du service de sécurité
        ChangeNotifierProxyProvider<SecurityService, OTPProvider>(
          create: (context) {
            final securityService = context.read<SecurityService>();
            final provider = OTPProvider();
            // Initialisation asynchrone
            Future.microtask(() async {
              try {
                await provider.init(securityService);
                debugPrint('OTPProvider initialisé avec succès');
              } catch (error, stackTrace) {
                debugPrint('Erreur critique lors de l\'initialisation du fournisseur OTP: $error');
                debugPrint(stackTrace.toString());
                // Mettre à jour l'état d'erreur du provider
                provider.error = 'Erreur d\'initialisation: $error';
                provider.notifyListeners();
              }
            });
            return provider;
          },
          update: (context, securityService, otpProvider) {
            // Mise à jour asynchrone
            if (otpProvider != null) {
              Future.microtask(() async {
                try {
                  await otpProvider.updateSecurityService(securityService);
                } catch (error, stackTrace) {
                  debugPrint('Erreur lors de la mise à jour du fournisseur OTP: $error');
                  debugPrint(stackTrace.toString());
                  // Mettre à jour l'état d'erreur du provider
                  otpProvider.error = 'Erreur de mise à jour: $error';
                  otpProvider.notifyListeners();
                }
              });
            }
            return otpProvider!;
          },
        ),
      ],
      child: MaterialApp(
        title: 'FreeOTP Clone',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          // Utiliser un TextTheme de base pour les tests, Google Fonts en production
          textTheme: const bool.fromEnvironment('dart.vm.product')
              ? GoogleFonts.robotoTextTheme(Theme.of(context).textTheme)
              : Theme.of(context).textTheme,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => LockScreen(
                child: const HomeScreen(),
              ),
          '/add-account': (context) => LockScreen(
                child: const AddAccountScreen(),
              ),
          // La route /account-details est gérée par onGenerateRoute ci-dessous
          // pour passer le paramètre accountId requis
          '/settings': (context) => LockScreen(
                child: const SettingsScreen(),
              ),
          '/security-settings': (context) => LockScreen(
                child: const SecuritySettingsScreen(),
              ),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/account-details') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => LockScreen(
                child: AccountDetailsScreen(
                  accountId: args['accountId'],
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
