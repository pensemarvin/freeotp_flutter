import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/otp_provider.dart';
import '../services/security_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
    
    // Initialiser l'application et naviguer vers l'écran principal
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialiser le service de sécurité
      final securityService = Provider.of<SecurityService>(context, listen: false);
      
      // Initialiser le fournisseur OTP avec le service de sécurité
      final otpProvider = Provider.of<OTPProvider>(context, listen: false);
      await otpProvider.init(securityService);
      
      // Attendre que l'animation soit terminée
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        // Vérifier si l'authentification biométrique est activée
        final config = await securityService.getAutoLockConfig();
        final isBiometricAvailable = await securityService.isBiometricAvailable();
        final isBiometricEnabled = isBiometricAvailable && config['enabled'] as bool;
        
        if (isBiometricEnabled) {
          // Si l'authentification biométrique est activée, afficher l'écran de verrouillage
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // Sinon, aller directement à l'écran d'accueil
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation: $e');
      
      if (mounted) {
        // En cas d'erreur, afficher un message à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement de l\'application'),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Réessayer après un délai
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _initializeApp();
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône de l'application
              Icon(
                Icons.lock_clock,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              // Nom de l'application
              Text(
                'FreeOTP Clone',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              // Version
              Text(
                'Version 1.0.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 48),
              // Indicateur de chargement
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
