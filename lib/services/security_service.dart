import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final StreamController<bool> _authStream = StreamController<bool>.broadcast();
  
  // Clé pour le stockage sécurisé
  static const String _encryptionKeyKey = 'encryption_key';
  static const String _autoLockKey = 'auto_lock_enabled';
  static const String _autoLockTimeoutKey = 'auto_lock_timeout';
  
  // Valeurs par défaut
  static const bool _defaultAutoLock = true;
  static const int _defaultAutoLockTimeout = 60; // secondes
  
  // Délai avant verrouillage automatique
  Timer? _autoLockTimer;
  DateTime? _lastInteractionTime;
  
  // Singleton
  factory SecurityService() {
    return _instance;
  }
  
  SecurityService._internal();
  
  // Flux pour écouter les changements d'état d'authentification
  Stream<bool> get authStream => _authStream.stream;
  
  // Vérifier si l'authentification biométrique est disponible et configurée
  Future<bool> isBiometricAvailable() async {
    try {
      // Vérifier d'abord si l'appareil prend en charge la biométrie
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        debugPrint('L\'appareil ne prend pas en charge l\'authentification biométrique');
        return false;
      }
      
      // Vérifier s'il y a des méthodes biométriques enregistrées
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      final hasBiometricEnrolled = availableBiometrics.isNotEmpty;
      
      if (!hasBiometricEnrolled) {
        debugPrint('Aucune méthode biométrique enregistrée sur l\'appareil');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la biométrie: $e');
      return false;
    }
  }
  
  // Méthode dépréciée - à supprimer dans une future version
  @Deprecated('Utilisez isBiometricAvailable() à la place')
  Future<bool> isBiometricConfigured() async {
    return isBiometricAvailable();
  }

  // Authentifier l'utilisateur avec biométrie
  Future<bool> authenticate() async {
    try {
      // Vérifier d'abord si l'authentification biométrique est configurée
      final isConfigured = await isBiometricConfigured();
      if (!isConfigured) {
        debugPrint('L\'authentification biométrique n\'est pas configurée sur cet appareil');
        return false;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour accéder à l\'application',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      
      if (didAuthenticate) {
        _resetAutoLockTimer();
        _authStream.add(true);
      }
      
      return didAuthenticate;
    } catch (e) {
      debugPrint('Erreur lors de l\'authentification: $e');
      
      // Gérer les erreurs spécifiques
      if (e is Exception && e.toString().contains('NotAvailable')) {
        debugPrint('L\'authentification biométrique n\'est pas disponible sur cet appareil.');
      } else if (e is Exception && e.toString().contains('PasscodeNotSet')) {
        debugPrint('Aucun code PIN/verrouillage d\'écran configuré sur l\'appareil');
      } else if (e is Exception && e.toString().contains('NotEnrolled')) {
        debugPrint('Aucune empreinte digitale/visage enregistré sur l\'appareil');
      }
      
      return false;
    } catch (e) {
      debugPrint('Erreur inattendue lors de l\'authentification: $e');
      return false;
    }
  }
  
  // Obtenir ou générer une clé de chiffrement sécurisée
  Future<encrypt.Key> _getOrCreateEncryptionKey() async {
    String? keyString = await _secureStorage.read(key: _encryptionKeyKey);
    
    if (keyString == null) {
      final key = encrypt.Key.fromSecureRandom(32); // 256 bits
      keyString = key.base64;
      await _secureStorage.write(key: _encryptionKeyKey, value: keyString);
    }
    
    return encrypt.Key.fromBase64(keyString);
  }
  
  // Chiffrer une chaîne de caractères
  Future<String> encryptData(String data) async {
    try {
      final key = await _getOrCreateEncryptionKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(data, iv: iv);
      
      // Retourne les données chiffrées avec l'IV au format: iv.encryptedData
      return '${iv.base64}.${encrypted.base64}';
    } catch (e) {
      debugPrint('Erreur lors du chiffrement: $e');
      rethrow;
    }
  }
  
  // Déchiffrer une chaîne de caractères
  Future<String> decryptData(String encryptedData) async {
    try {
      final parts = encryptedData.split('.');
      if (parts.length != 2) throw Exception('Données chiffrées invalides');
      
      final key = await _getOrCreateEncryptionKey();
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      return encrypter.decrypt(
        encrypt.Encrypted.fromBase64(parts[1]),
        iv: iv,
      );
    } catch (e) {
      debugPrint('Erreur lors du déchiffrement: $e');
      rethrow;
    }
  }
  
  // Gestion du verrouillage automatique
  void updateInteractionTime() {
    _lastInteractionTime = DateTime.now();
    _resetAutoLockTimer();
  }
  
  Future<void> _resetAutoLockTimer() async {
    _autoLockTimer?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    final autoLockEnabled = prefs.getBool(_autoLockKey) ?? _defaultAutoLock;
    
    if (autoLockEnabled) {
      final timeout = prefs.getInt(_autoLockTimeoutKey) ?? _defaultAutoLockTimeout;
      
      _autoLockTimer = Timer(Duration(seconds: timeout), () {
        _authStream.add(false);
      });
    }
  }
  
  // Configuration du verrouillage automatique
  Future<void> configureAutoLock({
    required bool enabled,
    int? timeoutInSeconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLockKey, enabled);
    
    if (timeoutInSeconds != null) {
      await prefs.setInt(_autoLockTimeoutKey, timeoutInSeconds);
    }
    
    if (enabled) {
      _resetAutoLockTimer();
    } else {
      _autoLockTimer?.cancel();
    }
  }
  
  // Obtenir la configuration actuelle du verrouillage automatique
  Future<Map<String, dynamic>> getAutoLockConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_autoLockKey) ?? _defaultAutoLock,
      'timeout': prefs.getInt(_autoLockTimeoutKey) ?? _defaultAutoLockTimeout,
    };
  }
  
  // Nettoyage
  void dispose() {
    _authStream.close();
    _autoLockTimer?.cancel();
  }
}
