import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late Logger _logger;
  String? _deviceInfo;
  String? _appVersion;
  bool _isInitialized = false;
  
  // Niveaux de log
  static const String LEVEL_DEBUG = 'DEBUG';
  static const String LEVEL_INFO = 'INFO';
  static const String LEVEL_WARNING = 'WARNING';
  static const String LEVEL_ERROR = 'ERROR';
  static const String LEVEL_FATAL = 'FATAL';
  
  // Clé pour stocker les logs
  static const String _logStorageKey = 'app_logs';
  static const int _maxLogs = 1000; // Nombre maximum de logs à conserver
  
  factory LoggerService() {
    return _instance;
  }
  
  LoggerService._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 5,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );
  }
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Récupérer les informations sur l'appareil
      final deviceInfo = await _getDeviceInfo();
      _deviceInfo = deviceInfo;
      
      // Récupérer les informations sur l'application
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      
      _isInitialized = true;
      
      // Log du démarrage de l'application
      i('Application démarrée', tag: 'AppLifecycle');
    } catch (e) {
      // En cas d'erreur, on utilise quand même le logger mais sans les infos supplémentaires
      _isInitialized = true;
      debugPrint('Erreur lors de l\'initialisation du logger: $e');
    }
  }
  
  // Méthodes de log
  void d(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LEVEL_DEBUG, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  void i(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LEVEL_INFO, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  void w(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LEVEL_WARNING, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  void e(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LEVEL_ERROR, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  void f(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LEVEL_FATAL, message, tag: tag, error: error, stackTrace: stackTrace);
    // En cas d'erreur fatale, on peut ajouter une logique supplémentaire
    // comme envoyer un rapport de crash
  }
  
  // Méthode interne pour le logging
  void _log(String level, String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (!_isInitialized) {
      // Si le logger n'est pas encore initialisé, on utilise print
      print('[$level]${tag != null ? ' [$tag]' : ''} $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
      return;
    }
    
    // Formater le message avec le tag si fourni
    final formattedMessage = tag != null ? '[$tag] $message' : message;
    
    // Log avec le logger approprié selon le niveau
    switch (level) {
      case LEVEL_DEBUG:
        _logger.d(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case LEVEL_INFO:
        _logger.i(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case LEVEL_WARNING:
        _logger.w(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case LEVEL_ERROR:
      case LEVEL_FATAL:
        _logger.e(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      default:
        _logger.d(formattedMessage, error: error, stackTrace: stackTrace);
    }
    
    // Sauvegarder le log pour consultation ultérieure
    _saveLog(level, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  // Récupérer les logs sauvegardés
  Future<List<Map<String, dynamic>>> getLogs({int limit = 50}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getStringList(_logStorageKey) ?? [];
      
      // Parser les logs
      final logs = logsJson.map((logJson) {
        try {
          return Map<String, dynamic>.from(jsonDecode(logJson));
        } catch (e) {
          return {
            'timestamp': DateTime.now().toIso8601String(),
            'level': LEVEL_ERROR,
            'message': 'Erreur lors de la lecture du log: $e',
            'tag': 'Logger',
          };
        }
      }).toList();
      
      // Trier par date (du plus récent au plus ancien) et limiter le nombre de résultats
      logs.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
      
      return logs.take(limit).toList();
    } catch (e) {
      _logger.e('Erreur lors de la récupération des logs', error: e);
      return [];
    }
  }
  
  // Effacer les logs
  Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logStorageKey);
    } catch (e) {
      _logger.e('Erreur lors de la suppression des logs', error: e);
    }
  }
  
  // Méthode interne pour sauvegarder un log
  Future<void> _saveLog(
    String level,
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_logStorageKey) ?? [];
      
      // Créer l'objet log
      final log = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
        if (tag != null) 'tag': tag,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        'deviceInfo': _deviceInfo,
        'appVersion': _appVersion,
      };
      
      // Ajouter le nouveau log
      logs.add(jsonEncode(log));
      
      // Limiter le nombre de logs stockés
      if (logs.length > _maxLogs) {
        logs.removeRange(0, logs.length - _maxLogs);
      }
      
      // Sauvegarder les logs
      await prefs.setStringList(_logStorageKey, logs);
    } catch (e) {
      // En cas d'erreur, on ne fait rien pour éviter les boucles infinies
      debugPrint('Erreur lors de la sauvegarde du log: $e');
    }
  }
  
  // Méthode pour obtenir des informations sur l'appareil
  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return 'Mac (macOS ${macInfo.osRelease})';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return 'Windows (${windowsInfo.computerName})';
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return 'Linux (${linuxInfo.prettyName})';
      } else {
        return 'Plateforme inconnue';
      }
    } catch (e) {
      return 'Impossible de récupérer les informations de l\'appareil: $e';
    }
  }
  
  // Méthode pour obtenir un résumé des logs d'erreur
  Future<String> getErrorSummary() async {
    try {
      final logs = await getLogs(limit: 50);
      final errorLogs = logs.where((log) => 
        [LEVEL_ERROR, LEVEL_FATAL].contains(log['level'] as String)
      ).toList();
      
      if (errorLogs.isEmpty) {
        return 'Aucune erreur récente';
      }
      
      final buffer = StringBuffer();
      buffer.writeln('Résumé des erreurs (${errorLogs.length} erreurs récentes):');
      buffer.writeln('Appareil: $_deviceInfo');
      buffer.writeln('Version: $_appVersion');
      buffer.writeln('---');
      
      for (final log in errorLogs.take(10)) { // Limiter à 10 erreurs
        buffer.writeln('${log['timestamp']} [${log['level']}]${log['tag'] != null ? ' [${log['tag']}]' : ''}');
        buffer.writeln('Message: ${log['message']}');
        if (log['error'] != null) {
          buffer.writeln('Erreur: ${log['error']}');
        }
        buffer.writeln('---');
      }
      
      if (errorLogs.length > 10) {
        buffer.writeln('... et ${errorLogs.length - 10} erreurs supplémentaires');
      }
      
      return buffer.toString();
    } catch (e) {
      return 'Erreur lors de la génération du résumé: $e';
    }
  }
}

// Extension pour un accès plus facile au logger
extension LoggerExtension on Object {
  static final LoggerService _logger = LoggerService();
  
  void logD(String message, {String? tag}) => _logger.d(message, tag: tag);
  void logI(String message, {String? tag}) => _logger.i(message, tag: tag);
  void logW(String message, {String? tag, dynamic error, StackTrace? stackTrace}) => 
      _logger.w(message, tag: tag, error: error, stackTrace: stackTrace);
  void logE(String message, {String? tag, dynamic error, StackTrace? stackTrace}) => 
      _logger.e(message, tag: tag, error: error, stackTrace: stackTrace);
  void logF(String message, {String? tag, dynamic error, StackTrace? stackTrace}) => 
      _logger.f(message, tag: tag, error: error, stackTrace: stackTrace);
}
