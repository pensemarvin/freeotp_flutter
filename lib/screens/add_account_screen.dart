import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/otp_provider.dart';
import '../models/otp_account.dart';
import 'package:uuid/uuid.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({Key? key}) : super(key: key);

  @override
  _AddAccountScreenState createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrViewController;
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _qrViewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un compte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: _buildQrView(context),
          ),
          if (_errorMessage != null) ...{
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          },
          Expanded(
            flex: 1,
            child: Center(
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : Text(
                      _isScanning
                          ? 'Scannez un code QR OTP'
                          : 'En attente de scan...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).primaryColor,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: MediaQuery.of(context).size.width * 0.8,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrViewController = controller;
    _qrViewController?.scannedDataStream.listen((scanData) {
      if (_isScanning && !_isProcessing) {
        _processScannedData(scanData.code);
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas de permission pour accéder à la caméra')),
      );
    }
  }

  Future<void> _processScannedData(String? data) async {
    if (data == null || data.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(data);
      if (uri.scheme != 'otpauth') {
        throw const FormatException('Format de code QR non supporté');
      }

      final account = _parseOtpAuthUri(uri);
      final otpProvider = Provider.of<OTPProvider>(context, listen: false);
      await otpProvider.addAccount(account);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = 'Erreur: ${e.message}';
        _isScanning = false;
      });
      // Réactiver le scan après un délai
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isScanning = true;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur inattendue: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  OTPAccount _parseOtpAuthUri(Uri uri) {
    final type = uri.host.toLowerCase();
    if (type != 'totp' && type != 'hotp') {
      throw const FormatException('Type OTP non supporté. Seuls TOTP et HOTP sont supportés.');
    }

    final params = uri.queryParameters;
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) {
      throw const FormatException('Format de code QR invalide');
    }

    final label = pathSegments.last;
    String issuer = '';
    String name = label;

    // Extraire l'émetteur et le nom du label (format: "issuer:name" ou "name")
    final labelParts = label.split(':');
    if (labelParts.length > 1) {
      issuer = labelParts[0];
      name = labelParts.sublist(1).join(':');
    }

    // Utiliser le paramètre issuer s'il est fourni (il a priorité)
    if (params.containsKey('issuer')) {
      issuer = params['issuer']!;
    }

    if (!params.containsKey('secret')) {
      throw const FormatException('Clé secrète manquante');
    }

    final secret = params['secret']!;
    final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
    final period = int.tryParse(params['period'] ?? '30') ?? 30;
    final algorithm = (params['algorithm'] ?? 'SHA1').toLowerCase();

    return OTPAccount(
      id: const Uuid().v4(),
      issuer: issuer,
      name: name,
      secret: secret,
      digits: digits,
      period: period,
      type: type == 'totp' ? OTPType.TOTP : OTPType.HOTP,
      algorithm: algorithm,
    );
  }

  Future<void> _showManualEntryDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _ManualEntryDialog(),
    );

    if (result != null) {
      try {
        final account = OTPAccount(
          id: const Uuid().v4(),
          issuer: result['issuer'] ?? '',
          name: result['name'] ?? '',
          secret: result['secret'] ?? '',
        );
        
        final otpProvider = Provider.of<OTPProvider>(context, listen: false);
        await otpProvider.addAccount(account);
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Erreur: $e';
          });
        }
      }
    }
  }
}

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({Key? key}) : super(key: key);

  @override
  _ManualEntryDialogState createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _issuerController = TextEditingController();
  final _nameController = TextEditingController();
  final _secretController = TextEditingController();
  final _digitsController = TextEditingController(text: '6');
  final _periodController = TextEditingController(text: '30');
  String _algorithm = 'sha1';
  String _type = 'totp';

  @override
  void dispose() {
    _issuerController.dispose();
    _nameController.dispose();
    _secretController.dispose();
    _digitsController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter manuellement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(
                  labelText: 'Émetteur (optionnel)',
                  hintText: 'ex: Google, GitHub',
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du compte',
                  hintText: 'ex: john.doe@example.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom de compte';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Clé secrète',
                  hintText: 'Entrez la clé secrète',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une clé secrète';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'totp',
                          child: Text('TOTP'),
                        ),
                        DropdownMenuItem(
                          value: 'hotp',
                          child: Text('HOTP'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _type = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _digitsController,
                      decoration: const InputDecoration(
                        labelText: 'Chiffres',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        final digits = int.tryParse(value);
                        if (digits == null || digits <= 0) {
                          return 'Invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _algorithm,
                      decoration: const InputDecoration(
                        labelText: 'Algorithme',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'sha1',
                          child: Text('SHA-1'),
                        ),
                        DropdownMenuItem(
                          value: 'sha256',
                          child: Text('SHA-256'),
                        ),
                        DropdownMenuItem(
                          value: 'sha512',
                          child: Text('SHA-512'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _algorithm = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _periodController,
                      decoration: const InputDecoration(
                        labelText: 'Période (s)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        final period = int.tryParse(value);
                        if (period == null || period <= 0) {
                          return 'Invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop({
                'issuer': _issuerController.text,
                'name': _nameController.text,
                'secret': _secretController.text,
                'digits': _digitsController.text,
                'period': _periodController.text,
                'algorithm': _algorithm,
                'type': _type,
              });
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
