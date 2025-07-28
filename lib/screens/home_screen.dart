import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/otp_provider.dart';
import '../widgets/otp_account_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final otpProvider = Provider.of<OTPProvider>(context, listen: false);
      
      // Initialisation du fournisseur OTP sans le service de sécurité pour le moment
      await otpProvider.init(null);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Erreur lors du chargement des comptes. Veuillez réessayer.';
        });
        
        // Afficher un message d'erreur à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: () => _initializeApp(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FreeOTP Clone'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddAccount(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<OTPProvider>(
      builder: (context, otpProvider, _) {
        final accounts = otpProvider.accounts;

        if (otpProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (otpProvider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    otpProvider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeApp,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        if (accounts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_clock,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun compte configuré',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Appuyez sur + pour ajouter un compte',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Rafraîchir les comptes
            final otpProvider = Provider.of<OTPProvider>(context, listen: false);
            await otpProvider.init(null);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return OTPAccountCard(
                key: ValueKey(account.id),
                account: account,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/account-details',
                    arguments: {'accountId': account.id},
                  );
                },
                onDelete: () {
                  _showDeleteDialog(context, otpProvider, account);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _navigateToAddAccount(BuildContext context) async {
    // Créer une copie locale du contexte avant le gap asynchrone
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final result = await Navigator.pushNamed(
      context,
      '/add-account',
    );

    if (result == true && mounted) {
      // Afficher un indicateur de chargement
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Mise à jour de la liste des comptes...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Rafraîchir la liste des comptes
      await _initializeApp();
    }
  }

  // Méthode supprimée car non utilisée

  Future<void> _showDeleteDialog(
    BuildContext context,
    OTPProvider otpProvider,
    dynamic account,
  ) async {
    bool isDeleting = false;
    
    // Créer une copie locale du contexte avant le gap asynchrone
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Supprimer le compte'),
              content: Text(
                  'Voulez-vous vraiment supprimer le compte ${account.issuer} (${account.name}) ?'),
              actions: <Widget>[
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => navigator.pop(),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () async {
                      setState(() => isDeleting = true);
                      try {
                        await otpProvider.deleteAccount(account.id);
                        if (mounted) {
                          navigator.pop();
                          // Afficher un message de confirmation
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Compte supprimé avec succès'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Erreur lors de la suppression: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          navigator.pop();
                        }
                      }
                    },
                    child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
