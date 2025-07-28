import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/otp_provider.dart';
import '../models/otp_account.dart';
import '../widgets/otp_code_display.dart';

class AccountDetailsScreen extends StatefulWidget {
  final String accountId;

  const AccountDetailsScreen({
    Key? key,
    required this.accountId,
  }) : super(key: key);

  @override
  _AccountDetailsScreenState createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _issuerController;
  late OTPAccount _account;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final otpProvider = Provider.of<OTPProvider>(context, listen: false);
      final account = otpProvider.getAccount(widget.accountId);
      
      if (account == null) {
        throw Exception('Compte non trouvé');
      }
      
      setState(() {
        _account = account;
        _nameController = TextEditingController(text: _account.name);
        _issuerController = TextEditingController(text: _account.issuer);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur lors du chargement du compte: $e';
      });
      
      // Afficher un message d'erreur à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
        
        // Revenir à l'écran précédent si le chargement échoue
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _issuerController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Save changes
        _saveChanges();
      }
    });
  }

  void _saveChanges() {
    if (_nameController.text.isNotEmpty) {
      final otpProvider = Provider.of<OTPProvider>(context, listen: false);
      final updatedAccount = _account.copyWith(
        name: _nameController.text,
        issuer: _issuerController.text,
      );
      otpProvider.updateAccount(updatedAccount);
      setState(() {
        _account = updatedAccount;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: Text(
            'Voulez-vous vraiment supprimer le compte ${_account.issuer} (${_account.name}) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      final otpProvider = Provider.of<OTPProvider>(context, listen: false);
      await otpProvider.deleteAccount(_account.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _shareAccount() {
    final otpProvider = Provider.of<OTPProvider>(context, listen: false);
    final code = otpProvider.generateCode(_account);
    final remaining = otpProvider.getRemainingSeconds(_account);
    
    Share.share(
      '${_account.issuer} (${_account.name}): $code (Expire dans ${remaining}s)',
      subject: 'Code OTP pour ${_account.issuer}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otpProvider = Provider.of<OTPProvider>(context);
    
    // Afficher un indicateur de chargement pendant le chargement du compte
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Afficher un message d'erreur si le chargement a échoué
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
        ),
        body: Center(
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
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Obtenir le code actuel et le temps restant
    final code = otpProvider.generateCode(_account);
    final remaining = otpProvider.getRemainingSeconds(_account);
    final progress = otpProvider.getProgress(_account);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le compte' : 'Détails du compte'),
        actions: [
          if (!_isEditing) ...{
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEdit,
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareAccount,
              tooltip: 'Partager',
            ),
          },
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code OTP avec animation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: OTPCodeDisplay(
                  account: _account,
                  codeStyle: theme.textTheme.headlineMedium,
                  labelStyle: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Détails du compte
            Text(
              'Informations du compte',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Éditeur de nom
                    TextFormField(
                      controller: _nameController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Nom du compte',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Éditeur d'émetteur
                    TextFormField(
                      controller: _issuerController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Émetteur',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type de compte
                    TextFormField(
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _account.type == OTPType.TOTP ? 'TOTP' : 'HOTP',
                    ),
                    const SizedBox(height: 16),
                    // Algorithme
                    TextFormField(
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Algorithme',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _account.algorithm.toUpperCase(),
                    ),
                    const SizedBox(height: 16),
                    // Chiffres
                    TextFormField(
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Chiffres',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _account.digits.toString(),
                    ),
                    if (_account.type == OTPType.TOTP) ...{
                      const SizedBox(height: 16),
                      // Période (uniquement pour TOTP)
                      TextFormField(
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Période (secondes)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _account.period.toString(),
                      ),
                    },
                    if (_account.type == OTPType.HOTP) ...{
                      const SizedBox(height: 16),
                      // Compteur (uniquement pour HOTP)
                      TextFormField(
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Compteur',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _account.counter.toString(),
                      ),
                    },
                    const SizedBox(height: 16),
                    // Clé secrète
                    TextFormField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Clé secrète',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _account.secret));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Clé secrète copiée dans le presse-papier'),
                              ),
                            );
                          },
                        ),
                      ),
                      obscureText: true,
                      initialValue: _account.secret,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isEditing
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggleEdit,
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _saveChanges();
                        _toggleEdit();
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButton: _isEditing
          ? null
          : FloatingActionButton.extended(
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete),
              label: const Text('Supprimer'),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
    );
  }
}
