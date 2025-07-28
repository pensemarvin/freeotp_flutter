import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/otp_provider.dart';
import '../models/otp_account.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _exportAccounts(BuildContext context) async {
    final otpProvider = Provider.of<OTPProvider>(context, listen: false);
    final accounts = otpProvider.accounts;
    
    if (accounts.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun compte à exporter')),
        );
      }
      return;
    }

    final exportData = StringBuffer();
    for (final account in accounts) {
      exportData.writeln('=== Compte OTP ===');
      exportData.writeln('Émetteur: ${account.issuer}');
      exportData.writeln('Nom: ${account.name}');
      exportData.writeln('Type: ${account.type == OTPType.TOTP ? 'TOTP' : 'HOTP'}');
      exportData.writeln('Algorithme: ${account.algorithm.toUpperCase()}');
      exportData.writeln('Chiffres: ${account.digits}');
      if (account.type == OTPType.TOTP) {
        exportData.writeln('Période: ${account.period} secondes');
      } else {
        exportData.writeln('Compteur: ${account.counter}');
      }
      exportData.writeln('Date d\'ajout: ${DateTime.fromMillisecondsSinceEpoch(account.addedDate).toString()}');
      exportData.writeln('');
    }

    // Partager les données exportées
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      exportData.toString(),
      subject: 'Export des comptes OTP',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }

  void _showAboutDialog(BuildContext context) {
    final theme = Theme.of(context);
    
    showAboutDialog(
      context: context,
      applicationName: 'FreeOTP Clone',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.lock_clock,
        size: 50,
        color: theme.colorScheme.primary,
      ),
      applicationLegalese: '© 2025 FreeOTP Clone. Tous droits réservés.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Une application de génération de codes OTP (TOTP/HOTP) simple et sécurisée.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Développé avec ❤️ en utilisant Flutter',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Impossible d\'ouvrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          // Section Comptes
          _buildSectionHeader('Comptes', theme),
          _buildListTile(
            icon: Icons.import_export,
            title: 'Exporter les comptes',
            subtitle: 'Générer un rapport de tous vos comptes OTP',
            onTap: () => _exportAccounts(context),
          ),
          const Divider(height: 1),
          
          // Section Sécurité
          _buildSectionHeader('Sécurité', theme),
          _buildListTile(
            icon: Icons.security,
            title: 'Paramètres de sécurité',
            subtitle: 'Authentification biométrique et verrouillage automatique',
            onTap: () {
              Navigator.pushNamed(context, '/security-settings');
            },
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          
          // Section Aide et support
          _buildSectionHeader('Aide et support', theme),
          _buildListTile(
            icon: Icons.help_outline,
            title: 'Centre d\'aide',
            onTap: () => _launchUrl('https://github.com/yourusername/freeotp-clone/wiki'),
          ),
          _buildListTile(
            icon: Icons.bug_report,
            title: 'Signaler un problème',
            onTap: () => _launchUrl('https://github.com/yourusername/freeotp-clone/issues'),
          ),
          _buildListTile(
            icon: Icons.email,
            title: 'Nous contacter',
            onTap: () => _launchUrl('mailto:support@example.com'),
          ),
          const Divider(height: 1),
          
          // Section À propos
          _buildSectionHeader('À propos', theme),
          _buildListTile(
            icon: Icons.info_outline,
            title: 'À propos de FreeOTP Clone',
            onTap: () => _showAboutDialog(context),
          ),
          _buildListTile(
            icon: Icons.privacy_tip,
            title: 'Politique de confidentialité',
            onTap: () => _launchUrl('https://github.com/yourusername/freeotp-clone/privacy'),
          ),
          _buildListTile(
            icon: Icons.description,
            title: 'Conditions d\'utilisation',
            onTap: () => _launchUrl('https://github.com/yourusername/freeotp-clone/terms'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Version 1.0.0 (build 1)',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.textTheme.bodySmall?.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 24,
    );
  }
}
