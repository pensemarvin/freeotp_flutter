import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  _SecuritySettingsScreenState createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityService _securityService = SecurityService();
  final List<int> _timeoutOptions = [30, 60, 180, 300]; // secondes
  
  bool _isBiometricAvailable = false;
  bool _isLoading = true;
  bool _isBiometricEnabled = false;
  bool _isAutoLockEnabled = false;
  int _autoLockTimeout = 60; // secondes

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Vérifier si la biométrique est disponible
      _isBiometricAvailable = await _securityService.isBiometricAvailable();
      
      // Si la biométrique est disponible, charger son état
      if (_isBiometricAvailable) {
        final prefs = await SharedPreferences.getInstance();
        _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      }
      
      final config = await _securityService.getAutoLockConfig();
      setState(() {
        _isAutoLockEnabled = config['enabled'] as bool;
        _autoLockTimeout = config['timeout'] as int;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des paramètres: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometricAuth(bool value) async {
    if (value) {
      // Vérifier d'abord si la biométrique est disponible
      final isAvailable = await _securityService.isBiometricAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune méthode biométrique disponible sur cet appareil'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Essayer de s'authentifier avant d'activer
      final isAuthenticated = await _securityService.authenticate();
      if (!isAuthenticated) return;
    }
    
    // Enregistrer la préférence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    
    if (mounted) {
      setState(() {
        _isBiometricEnabled = value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
            ? 'Authentification biométrique activée' 
            : 'Authentification biométrique désactivée'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleAutoLock(bool value) async {
    await _securityService.configureAutoLock(
      enabled: value,
      timeoutInSeconds: _autoLockTimeout,
    );
    
    setState(() {
      _isAutoLockEnabled = value;
    });
  }

  Future<void> _changeAutoLockTimeout(int? value) async {
    if (value == null) return;
    
    await _securityService.configureAutoLock(
      enabled: _isAutoLockEnabled,
      timeoutInSeconds: value,
    );
    
    setState(() {
      _autoLockTimeout = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de sécurité'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Section biométrie conditionnelle
                FutureBuilder<bool>(
                  future: _securityService.isBiometricAvailable(),
                  builder: (context, snapshot) {
                    debugPrint('Statut de la vérification biométrique: ${snapshot.connectionState}');
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      debugPrint('En attente du résultat de la vérification biométrique...');
                      return const SizedBox.shrink();
                    }
                    
                    final isBiometricAvailable = snapshot.data ?? false;
                    debugPrint('isBiometricAvailable: $isBiometricAvailable');
                    
                    if (!isBiometricAvailable) {
                      debugPrint('Aucune méthode biométrique disponible ou erreur de vérification');
                      return const SizedBox.shrink();
                    }
                    
                    debugPrint('Affichage de la section biométrique');
                    return Column(
                      children: _buildBiometricSection(),
                    );
                  },
                ),
                _buildAutoLockSection(),
                _buildSecurityInfo(),
              ],
            ),
    );
  }

  List<Widget> _buildBiometricSection() {
    return [
      const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Authentification biométrique',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      FutureBuilder<List<BiometricType>>(
        future: _getAvailableBiometricTypes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final availableBiometrics = snapshot.data ?? [];
          final hasBiometrics = availableBiometrics.isNotEmpty;
          
          if (!hasBiometrics) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Aucune méthode biométrique disponible. Veuillez configurer une empreinte digitale ou une reconnaissance faciale dans les paramètres de votre appareil.',
                style: TextStyle(color: Colors.orange),
              ),
            );
          }
          
          return Column(
            children: [
              SwitchListTile(
                title: const Text('Activer la biométrie'),
                subtitle: const Text('Utiliser les méthodes biométriques configurées'),
                secondary: const Icon(Icons.fingerprint, color: Colors.blue),
                value: _isBiometricEnabled,
                onChanged: _toggleBiometricAuth,
              ),
              if (_isBiometricEnabled) ..._buildBiometricOptions(availableBiometrics),
              const Divider(),
            ],
          );
        },
      ),
    ];
  }
  
  Future<List<BiometricType>> _getAvailableBiometricTypes() async {
    try {
      debugPrint('Vérification de la disponibilité biométrique...');
      final localAuth = LocalAuthentication();
      final canCheckBiometrics = await localAuth.canCheckBiometrics;
      debugPrint('canCheckBiometrics: $canCheckBiometrics');
      
      if (!canCheckBiometrics) {
        debugPrint('L\'appareil ne prend pas en charge la biométrie');
        return [];
      }
      
      debugPrint('Récupération des méthodes biométriques disponibles...');
      final biometrics = await localAuth.getAvailableBiometrics();
      debugPrint('Méthodes biométriques disponibles: ${biometrics.map((b) => b.toString()).toList()}');
      
      return biometrics;
    } catch (e, stackTrace) {
      debugPrint('Erreur lors de la récupération des types biométriques: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }
  
  List<Widget> _buildBiometricOptions(List<BiometricType> availableBiometrics) {
    final options = <Widget>[];
    
    if (availableBiometrics.contains(BiometricType.fingerprint)) {
      options.add(
        ListTile(
          leading: const Icon(Icons.fingerprint, color: Colors.blue),
          title: const Text('Empreinte digitale'),
          subtitle: const Text('Déverrouiller avec votre empreinte digitale'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
          onTap: () => _showBiometricInfo('Empreinte digitale'),
        ),
      );
    }
    
    if (availableBiometrics.contains(BiometricType.face)) {
      options.add(
        ListTile(
          leading: const Icon(Icons.face, color: Colors.blue),
          title: const Text('Reconnaissance faciale'),
          subtitle: const Text('Déverrouiller avec la reconnaissance faciale'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
          onTap: () => _showBiometricInfo('Reconnaissance faciale'),
        ),
      );
    }
    
    if (availableBiometrics.contains(BiometricType.iris)) {
      options.add(
        ListTile(
          leading: const Icon(Icons.remove_red_eye, color: Colors.blue),
          title: const Text('Reconnaissance de l\'iris'),
          subtitle: const Text('Déverrouiller par balayage de l\'iris'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
          onTap: () => _showBiometricInfo('Reconnaissance de l\'iris'),
        ),
      );
    }
    
    return options;
  }
  
  void _showBiometricInfo(String method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$method activée'),
        content: Text('Cette méthode de déverrouillage est activée et sera utilisée pour sécuriser votre application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoLockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Verrouillage automatique',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Activer le verrouillage automatique'),
          subtitle: const Text('Verrouiller l\'application après une période d\'inactivité'),
          value: _isAutoLockEnabled,
          onChanged: _toggleAutoLock,
        ),
        if (_isAutoLockEnabled) ...[
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: Text('Délai avant verrouillage automatique'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<int>(
              value: _autoLockTimeout,
              items: _timeoutOptions.map((seconds) {
                final minutes = seconds ~/ 60;
                return DropdownMenuItem(
                  value: seconds,
                  child: Text('$minutes minute${minutes > 1 ? 's' : ''}'),
                );
              }).toList(),
              onChanged: _changeAutoLockTimeout,
              isExpanded: true,
            ),
          ),
        ],
        const Divider(),
      ],
    );
  }

  Widget _buildSecurityInfo() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sécurité des données',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Toutes vos données sensibles sont chiffrées et stockées de manière sécurisée sur votre appareil.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _securityService.dispose();
    super.dispose();
  }
}
