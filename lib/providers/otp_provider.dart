import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:otp/otp.dart';
import 'package:base32/base32.dart';
import 'dart:convert';
import '../models/otp_account.dart';
import '../services/otp_service.dart';
import '../services/security_service.dart';

class OTPProvider with ChangeNotifier {
  // Initialisation directe de _otpService
  final OTPService _otpService = OTPService();
  
  List<OTPAccount> _accounts = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  List<OTPAccount> get accounts => List.unmodifiable(_accounts);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  set error(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> init([SecurityService? securityService]) async {
    debugPrint('\n===== DÉBUT OTPProvider.init =====');
    debugPrint('Appelé depuis: ${StackTrace.current.toString().split('\n').take(4).join('\n')}');
    debugPrint('Paramètres d\'entrée:');
    debugPrint('  - securityService: ${securityService != null ? 'fourni' : 'non fourni'}');
    debugPrint('  - _isInitialized avant vérification: $_isInitialized');
    
    if (_isInitialized) {
      debugPrint('OTPProvider déjà initialisé - sortie de la méthode');
      return;
    }
    
    // Ne pas réinitialiser _otpService car il est déjà initialisé
    debugPrint('Utilisation de l\'instance existante de OTPService');
    
    try {
      _setLoading(true);
      debugPrint('Chargement activé dans init');
      
      // Vérifier si le service de sécurité est disponible
      if (securityService != null) {
        debugPrint('Vérification de l\'authentification biométrique...');
        // Vérifier si l'authentification biométrique est configurée
        try {
          final isBiometricConfigured = await securityService.isBiometricConfigured();
          debugPrint('Résultat de isBiometricConfigured: $isBiometricConfigured');
          if (!isBiometricConfigured) {
            debugPrint('Avertissement: L\'authentification biométrique n\'est pas configurée sur cet appareil');
          } else {
            debugPrint('Authentification biométrique configurée');
          }
        } catch (e) {
          debugPrint('Erreur lors de la vérification de l\'authentification biométrique: $e');
          // On continue malgré l'erreur
        }
      } else {
        debugPrint('Aucun service de sécurité fourni');
      }
      
      // Initialiser le service OTP
      debugPrint('Initialisation du service OTP...');
      try {
        await _otpService.init(securityService);
        debugPrint('Service OTP initialisé avec succès');
      } catch (e) {
        debugPrint('Erreur lors de l\'initialisation du service OTP: $e');
        rethrow;
      }
      
      // Charger les comptes (chargement initial)
      debugPrint('\n=== Début du chargement initial des comptes depuis init ===');
      try {
        await _loadAccounts(isInitialLoad: true);
        debugPrint('Chargement des comptes terminé avec succès');
      } catch (e) {
        debugPrint('Erreur lors du chargement initial des comptes: $e');
        rethrow;
      }
      
      _isInitialized = true;
      _error = null;
      debugPrint('\n=== OTPProvider initialisé avec succès ===');
      debugPrint('  - _isInitialized: $_isInitialized');
      debugPrint('  - _error: $_error');
      debugPrint('  - _otpService: ${_otpService != null ? 'initialisé' : 'null'}');
      debugPrint('  - Nombre de comptes chargés: ${_accounts.length}');
    } catch (e) {
      _error = 'Erreur système lors de l\'initialisation: $e';
      debugPrint('Erreur dans OTPProvider.init: $e');
      
      // Tenter de récupérer d'une erreur d'authentification
      if (e is Exception && (e.toString().contains('NotAvailable') || 
                           e.toString().contains('NotEnrolled') || 
                           e.toString().contains('PasscodeNotSet'))) {
        debugPrint('Erreur d\'authentification biométrique: $e');
        // On continue malgré l'erreur d'authentification biométrique
        _isInitialized = true;
        _error = null;
        return;
      }
      
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Erreur inattendue lors de l\'initialisation: $e';
      debugPrint('Erreur dans OTPProvider.init: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // Méthode pour mettre à jour le service de sécurité
  Future<void> updateSecurityService(SecurityService securityService) async {
    debugPrint('=== DÉBUT updateSecurityService ===');
    debugPrint('_isInitialized avant réinitialisation: $_isInitialized');
    
    try {
      _setLoading(true);
      debugPrint('Chargement activé dans updateSecurityService');
      
      // Réinitialiser l'état d'initialisation
      _isInitialized = false;
      debugPrint('_isInitialized après réinitialisation: $_isInitialized');
      
      // Utiliser l'instance existante de OTPService et la réinitialiser
      debugPrint('Réinitialisation du service OTP avec le nouveau service de sécurité...');
      await _otpService.init(securityService);
      debugPrint('Service OTP réinitialisé avec succès');
      
      // Charger les comptes (chargement initial)
      debugPrint('Chargement initial des comptes depuis updateSecurityService...');
      await _loadAccounts(isInitialLoad: true);
      debugPrint('Chargement des comptes terminé avec succès');
      
      _isInitialized = true;
      _error = null;
      debugPrint('_isInitialized après chargement des comptes: $_isInitialized');
      notifyListeners();
      debugPrint('=== FIN updateSecurityService avec succès ===');
    } catch (e, stackTrace) {
      _error = 'Erreur lors de la mise à jour du service de sécurité: $e';
      debugPrint('Erreur dans OTPProvider.updateSecurityService: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _loadAccounts({bool isInitialLoad = false}) async {
    try {
      debugPrint('\n===== DÉBUT _loadAccounts =====');
      debugPrint('Appelé depuis: ${StackTrace.current.toString().split('\n').take(4).join('\n')}');
      debugPrint('Paramètres d\'entrée:');
      debugPrint('  - isInitialLoad: $isInitialLoad');
      debugPrint('  - _isInitialized: $_isInitialized');
      debugPrint('  - _otpService: ${_otpService != null ? 'initialisé' : 'null'}');
      
      _setLoading(true);
      debugPrint('Chargement activé dans _loadAccounts');
      
      // Ne pas vérifier _isInitialized lors du chargement initial
      debugPrint('\nVérification de la condition:');
      debugPrint('  - !isInitialLoad: ${!isInitialLoad}');
      debugPrint('  - !_isInitialized: ${!_isInitialized}');
      debugPrint('  - !isInitialLoad && !_isInitialized: ${!isInitialLoad && !_isInitialized}');
      
      if (!isInitialLoad && !_isInitialized) {
        debugPrint('\n!!! ERREUR: Le fournisseur OTP n\'est pas initialisé et ce n\'est pas un chargement initial !!!');
        debugPrint('Stack trace complet:');
        debugPrint(StackTrace.current.toString());
        throw StateError('Le fournisseur OTP n\'est pas initialisé');
      }
      
      // Récupérer les comptes
      _accounts = await _otpService.getAccounts();
      
      // Trier par date d'ajout (du plus ancien au plus récent)
      _accounts.sort((a, b) => a.addedDate.compareTo(b.addedDate));
      
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur système lors du chargement des comptes: $e';
      debugPrint('\n!!! ERREUR dans _loadAccounts !!!');
      debugPrint('Type d\'erreur: ${e.runtimeType}');
      debugPrint('Message d\'erreur: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      
      // Gestion des erreurs spécifiques
      if (e is Exception && (e.toString().contains('NotAvailable') || 
                           e.toString().contains('NotEnrolled') || 
                           e.toString().contains('PasscodeNotSet'))) {
        _error = 'Erreur d\'authentification: $e';
        return;
      }
      
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Erreur inattendue lors du chargement des comptes: $e';
      debugPrint('Erreur dans _loadAccounts: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addAccount(OTPAccount account) async {
    try {
      _setLoading(true);
      await _otpService.addAccount(account);
      await _loadAccounts();
      _error = null;
    } catch (e) {
      _error = 'Erreur lors de l\'ajout du compte: $e';
      debugPrint(_error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAccount(OTPAccount account) async {
    try {
      _setLoading(true);
      await _otpService.updateAccount(account);
      await _loadAccounts();
      _error = null;
    } catch (e) {
      _error = 'Erreur lors de la mise à jour du compte: $e';
      debugPrint(_error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      _setLoading(true);
      await _otpService.deleteAccount(id);
      await _loadAccounts();
      _error = null;
    } catch (e) {
      _error = 'Erreur lors de la suppression du compte: $e';
      debugPrint(_error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  OTPAccount? getAccount(String id) {
    try {
      return _accounts.firstWhere((account) => account.id == id);
    } catch (e) {
      return null;
    }
  }

  String generateCode(OTPAccount account) {
    try {
      final algorithm = _getAlgorithm(account.algorithm);
      
      if (account.type == OTPType.TOTP) {
        // Pour TOTP, utiliser l'heure actuelle
        return OTP.generateTOTPCodeString(
          _normalizeSecret(account.secret),
          DateTime.now().millisecondsSinceEpoch,
          algorithm: algorithm,
          isGoogle: true,
          length: account.digits,
          interval: account.period,
        );
      } else {
        // Pour HOTP, utiliser le compteur du compte
        final counter = account.counter;
        final code = OTP.generateHOTPCodeString(
          _normalizeSecret(account.secret),
          counter,
          algorithm: algorithm,
          length: account.digits,
        );
        
        // Incrémenter le compteur pour le prochain code
        account.counter = counter + 1;
        updateAccount(account);
        
        return code;
      }
    } catch (e) {
      debugPrint('Erreur lors de la génération du code: $e');
      return 'ERROR';
    }
  }
  
  String _normalizeSecret(String secret) {
    // Vérifier si la clé est déjà en base32 valide
    try {
      // Essayer de décoder la clé pour vérifier si c'est du base32 valide
      base32.decode(secret);
      return secret; // La clé est déjà en base32
    } catch (e) {
      // Si ce n'est pas du base32 valide, encoder la chaîne en base32
      return base32.encode(utf8.encode(secret));
    }
  }

  int getRemainingSeconds(OTPAccount account) {
    if (account.type == OTPType.TOTP) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return account.period - (now % account.period);
    }
    // Pour HOTP, on retourne 0 car il n'y a pas de délai d'expiration
    return 0;
  }

  double getProgress(OTPAccount account) {
    if (account.type == OTPType.TOTP) {
      final remaining = getRemainingSeconds(account);
      return 1.0 - (remaining / account.period);
    }
    return 0.0;
  }

  Algorithm _getAlgorithm(String algorithm) {
    switch (algorithm.toLowerCase()) {
      case 'sha256':
        return Algorithm.SHA256;
      case 'sha512':
        return Algorithm.SHA512;
      case 'sha1':
      default:
        return Algorithm.SHA1;
    }
  }

  @override
  void dispose() {
    try {
      _otpService.close();
      debugPrint('OTPProvider désinitialisé');
    } catch (e) {
      debugPrint('Erreur lors de la fermeture de OTPProvider: $e');
    } finally {
      super.dispose();
    }
  }
}
