import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/otp_account.dart';
import 'security_service.dart';

class OTPService with ChangeNotifier {
  static const String _boxName = 'otp_accounts';
  static const String _encryptedBoxName = 'encrypted_otp_accounts';
  
  // Les boîtes sont initialisées de manière asynchrone dans la méthode init
  Box<OTPAccount>? _box;
  Box<String>? _encryptedBox;
  bool _isEncrypted = false;
  SecurityService? _securityService;

  Future<void> init(SecurityService? securityService) async {
    try {
      _securityService = securityService;
      
      // Vérifier si Hive est initialisé
      if (!Hive.isBoxOpen(_encryptedBoxName)) {
        _encryptedBox = await Hive.openBox<String>(
          _encryptedBoxName,
          // Configuration pour gérer les erreurs d'ouverture de boîte
          crashRecovery: true,
        );
      } else {
        _encryptedBox = Hive.box<String>(_encryptedBoxName);
      }
      
      // Vérifier si des données chiffrées existent
      _isEncrypted = _encryptedBox?.isNotEmpty ?? false;
      
      // Si des données chiffrées existent, on ne charge pas la boîte non chiffrée
      if (!_isEncrypted) {
        if (!Hive.isBoxOpen(_boxName)) {
          _box = await Hive.openBox<OTPAccount>(
            _boxName,
            crashRecovery: true,
          );
        } else {
          _box = Hive.box<OTPAccount>(_boxName);
        }
        
        // Migrer les données non chiffrées vers le stockage chiffré si nécessaire
        if ((_box?.isNotEmpty ?? false) && _securityService != null) {
          await _migrateToEncryptedStorage();
        }
      } else {
        // Si des données chiffrées existent, on initialise une boîte vide
        final tempBoxName = '${_boxName}_temp';
        if (!Hive.isBoxOpen(tempBoxName)) {
          _box = await Hive.openBox<OTPAccount>(
            tempBoxName,
            crashRecovery: true,
          );
        } else {
          _box = Hive.box<OTPAccount>(tempBoxName);
        }
        
        // Décrypter et charger les données si le service de sécurité est disponible
        if (_securityService != null) {
          await _loadFromEncryptedStorage();
        } else {
          debugPrint('Avertissement: SecurityService non disponible, impossible de charger les données chiffrées');
        }
      }
      
      // Si l'encryption est activée, supprimer les données non chiffrées
      if (_isEncrypted && _box != null && _box!.isNotEmpty) {
        try {
          await _box!.clear();
        } catch (e) {
          debugPrint('Erreur lors du nettoyage des données non chiffrées: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Erreur critique lors de l\'initialisation de OTPService: $e');
      debugPrint(stackTrace.toString());
      
      // Tenter une récupération en cas d'échec
      await _recoverFromError();
      
      // Relancer l'erreur pour que l'application soit au courant de l'échec
      rethrow;
    }
  }

  Future<void> addAccount(OTPAccount account) async {
    if (_box == null) {
      throw StateError('La boîte Hive n\'a pas été initialisée. Appelez init() d\'abord.');
    }
    
    if (_isEncrypted) {
      await _saveEncryptedAccount(account);
    } else {
      await _box?.put(account.id, account);
    }
    notifyListeners();
  }

  Future<void> updateAccount(OTPAccount account) async {
    if (_box == null) {
      throw StateError('La boîte Hive n\'a pas été initialisée. Appelez init() d\'abord.');
    }
    
    if (_isEncrypted) {
      await _saveEncryptedAccount(account);
    } else {
      await _box?.put(account.id, account);
    }
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    if (_box == null) {
      throw StateError('La boîte Hive n\'a pas été initialisée. Appelez init() d\'abord.');
    }
    
    if (_isEncrypted) {
      if (_encryptedBox == null) {
        throw StateError('La boîte chiffrée Hive n\'a pas été initialisée. Appelez init() d\'abord.');
      }
      await _encryptedBox?.delete(id);
    } else {
      await _box?.delete(id);
    }
    notifyListeners();
  }

  Future<List<OTPAccount>> getAccounts() async {
    if (_box == null) {
      throw StateError('La boîte Hive n\'a pas été initialisée. Appelez init() d\'abord.');
    }
    
    if (_isEncrypted) {
      if (_encryptedBox == null) {
        throw StateError('La boîte chiffrée Hive n\'a pas été initialisée. Appelez init() d\'abord.');
      }
      
      final List<OTPAccount> accounts = [];
      for (final encrypted in _encryptedBox?.values ?? []) {
        final account = await _decryptAccount(encrypted);
        if (account != null) {
          accounts.add(account);
        }
      }
      return accounts;
    } else {
      return _box?.values.toList() ?? [];
    }
  }

  Future<OTPAccount?> getAccount(String id) async {
    if (_box == null) {
      throw StateError('La boîte Hive n\'a pas été initialisée. Appelez init() d\'abord.');
    }
    
    if (_isEncrypted) {
      if (_encryptedBox == null) {
        throw StateError('La boîte chiffrée Hive n\'a pas été initialisée. Appelez init() d\'abord.');
      }
      
      final encrypted = _encryptedBox?.get(id);
      if (encrypted != null) {
        return await _decryptAccount(encrypted);
      }
      return null;
    } else {
      return _box?.get(id);
    }
  }

  Stream<BoxEvent> watchAccounts() {
    if (_box == null) {
      throw StateError('La boîte Hive n\'a pas été initialisée. Appelez init() d\'abord.');
    }
    
    // Pour la simplicité, nous utilisons un StreamController pour émettre des événements
    // lorsque les données changent. Dans une application réelle, vous pourriez vouloir
    // implémenter une solution plus sophistiquée.
    final controller = StreamController<BoxEvent>.broadcast();
    
    void notifyListeners() {
      controller.add(BoxEvent('all', null, false));
    }
    
    // Écouter les changements sur la boîte non chiffrée
    final subscription = _box?.watch().listen(controller.add);
    
    // Nettoyer lors de la fermeture
    if (subscription != null) {
      controller.onCancel = () {
        subscription.cancel();
      };
    } else {
      controller.close();
    }
    
    return controller.stream;
  }

  Future<void> close() async {
    try {
      await _box?.close();
      await _encryptedBox?.close();
    } catch (e) {
      debugPrint('Erreur lors de la fermeture des boîtes Hive: $e');
    }
  }
  
  // Tente de récupérer d'une erreur en réinitialisant les boîtes
  Future<void> _recoverFromError() async {
    try {
      // Fermer les boîtes existantes si elles sont ouvertes
      await close();
      
      // Réinitialiser les états
      _box = null;
      _encryptedBox = null;
      _isEncrypted = false;
      
      // Réessayer d'ouvrir les boîtes avec des paramètres de récupération
      _encryptedBox = await Hive.openBox<String>(
        _encryptedBoxName,
        crashRecovery: true,
      );
      
      _box = await Hive.openBox<OTPAccount>(
        '${_boxName}_recovery',
        crashRecovery: true,
      );
      
      debugPrint('Récupération réussie après une erreur');
    } catch (e) {
      debugPrint('Échec de la récupération après une erreur: $e');
      rethrow;
    }
  }
  
  // Active le chiffrement pour tous les comptes
  Future<void> enableEncryption() async {
    if (_isEncrypted || _box == null) return;
    
    await _migrateToEncryptedStorage();
    _isEncrypted = true;
    await _box?.clear();
    notifyListeners();
  }
  
  // Désactive le chiffrement pour tous les comptes
  Future<void> disableEncryption() async {
    if (!_isEncrypted || _box == null || _encryptedBox == null) return;
    
    try {
      // Décrypter et sauvegarder dans la boîte non chiffrée
      final accounts = await getAccounts();
      await _box?.clear();
      
      for (final account in accounts) {
        await _box?.put(account.id, account);
      }
      
      _isEncrypted = false;
      await _encryptedBox?.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la désactivation du chiffrement: $e');
      rethrow;
    }
  }
  
  // Vérifie si le chiffrement est activé
  bool get isEncryptionEnabled => _isEncrypted;
  
  // Méthodes privées pour le chiffrement/déchiffrement
  
  Future<void> _migrateToEncryptedStorage() async {
    if (_securityService == null || _box == null) return;
    
    final accounts = _box?.values.toList() ?? [];
    
    for (final account in accounts) {
      await _saveEncryptedAccount(account);
    }
    
    _isEncrypted = true;
  }
  
  Future<void> _loadFromEncryptedStorage() async {
    if (_securityService == null) return;
    
    // La boîte chiffrée contient les données, nous les chargeons à la volée
    // via getAccounts() et getAccount()
  }
  
  Future<void> _saveEncryptedAccount(OTPAccount account) async {
    if (_securityService == null) return;
    
    try {
      // Convertir le compte en JSON
      final jsonString = jsonEncode(account.toJson());
      
      // Chiffrer les données
      final encryptedData = await _securityService!.encryptData(jsonString);
      
      // Stocker les données chiffrées
      if (_encryptedBox != null) {
        await _encryptedBox!.put(account.id, encryptedData);
      }
    } catch (e) {
      debugPrint('Erreur lors du chiffrement du compte: $e');
      rethrow;
    }
  }
  
  Future<OTPAccount?> _decryptAccount(String encryptedData) async {
    if (_securityService == null) return null;
    
    try {
      // Décrypter les données (attendre le résultat asynchrone)
      final decryptedData = await _securityService!.decryptData(encryptedData);
      
      // Convertir de JSON vers OTPAccount
      final jsonData = jsonDecode(decryptedData) as Map<String, dynamic>;
      return OTPAccount.fromJson(jsonData);
    } catch (e) {
      debugPrint('Erreur lors du déchiffrement du compte: $e');
      return null;
    }
  }
}
