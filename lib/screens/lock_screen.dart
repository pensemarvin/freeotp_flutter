import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security_service.dart';
import 'create_password_screen.dart';

class LockScreen extends StatefulWidget {
  final Widget child;
  
  const LockScreen({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final SecurityService _securityService = SecurityService();
  final TextEditingController _passwordController = TextEditingController();
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _isBiometricAvailable = false;
  bool _isPasswordSet = false;
  String _errorMessage = '';
  
  // Clé pour le stockage de la préférence biométrique
  static const String _biometricEnabledKey = 'biometric_enabled';

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    _securityService.dispose();
    super.dispose();
  }
  
  Future<void> _checkInitialState() async {
    try {
      // Vérifier si un mot de passe est défini
      final prefs = await SharedPreferences.getInstance();
      _isPasswordSet = prefs.getBool('password_set') ?? false;
      
      if (!_isPasswordSet) {
        // Rediriger vers l'écran de création de mot de passe si aucun n'est défini
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const CreatePasswordScreen()),
          );
        }
        return;
      }
      
      // Vérifier si la biométrique est disponible et activée
      _isBiometricAvailable = await _securityService.isBiometricAvailable();
      
      // Si la biométrique est disponible, vérifier si elle est activée
      bool isBiometricEnabled = false;
      if (_isBiometricAvailable) {
        isBiometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      }
      
      // Si la biométrique est disponible et activée, l'utiliser
      if (_isBiometricAvailable && isBiometricEnabled) {
        await _authenticateWithBiometrics();
      } else {
        // Sinon, afficher directement le formulaire de mot de passe
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la vérification de l\'état initial';
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final bool didAuthenticate = await _securityService.authenticate();
      
      setState(() {
        _isAuthenticated = didAuthenticate;
        _isLoading = false;
        
        if (!didAuthenticate) {
          _errorMessage = 'Échec de l\'authentification';
        }
      });
      
      if (didAuthenticate && mounted) {
        // Mettre à jour l'état pour afficher le contenu protégé
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de l\'authentification: $e';
      });
    }
  }
  
  Future<void> _authenticateWithPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer votre mot de passe';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Ici, vous devrez implémenter la vérification du mot de passe
      // avec votre service de sécurité
      // Pour l'instant, on simule une vérification réussie après 1 seconde
      await Future.delayed(const Duration(seconds: 1));
      
      // TODO: Implémenter la vérification réelle du mot de passe
      final bool isPasswordCorrect = true; // À remplacer par la vérification réelle
      
      if (isPasswordCorrect) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Mot de passe incorrect';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la vérification du mot de passe';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si authentifié, afficher le contenu protégé
    if (_isAuthenticated) {
      return widget.child;
    }
    
    // Si en cours de chargement, afficher un indicateur de chargement
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => false, // Empêcher de quitter l'écran de verrouillage avec le bouton retour
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Application verrouillée',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty) ...[
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else if (_isBiometricAvailable)
                    ElevatedButton.icon(
                      onPressed: _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Déverrouiller avec biométrie'),
                    ),
                  const SizedBox(height: 16),
                  // Champ de mot de passe
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _authenticateWithPassword(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _authenticateWithPassword,
                    child: const Text('Déverrouiller'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


}
