# FreeOTP Flutter

Un clone de l'application FreeOTP développé avec Flutter. Cette application permet de générer des codes d'authentification à deux facteurs (2FA) en utilisant les protocoles TOTP et HOTP.

## Fonctionnalités

- Génération de codes TOTP (Time-based One-Time Password)
- Génération de codes HOTP (HMAC-based One-Time Password)
- Ajout de comptes via scan de code QR
- Ajout manuel de comptes
- Stockage sécurisé des secrets
- Interface utilisateur moderne et intuitive
- Thème sombre/clair
- Export des comptes
- Compatible avec les services populaires (Google Authenticator, Microsoft Authenticator, etc.)

## Captures d'écran

*(À ajouter: captures d'écran de l'application en fonctionnement)*

## Prérequis

- Flutter SDK (dernière version stable recommandée)
- Android Studio / Xcode (pour le développement natif)
- Un appareil physique ou un émulateur pour les tests

## Installation

1. Clonez le dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/freeotp-clone.git
   cd freeotp-clone
   ```

2. Installez les dépendances :
   ```bash
   flutter pub get
   ```

3. Lancez l'application :
   ```bash
   flutter run
   ```

## Comment utiliser

1. **Ajouter un compte** :
   - Appuyez sur le bouton "+" en bas à droite
   - Scannez le code QR ou entrez manuellement les détails du compte
   - Le code OTP sera généré automatiquement

2. **Copier un code** :
   - Appuyez sur un compte pour copier le code actuel dans le presse-papiers
   - Le code est automatiquement rafraîchi selon l'intervalle défini

3. **Voir les détails d'un compte** :
   - Appuyez sur un compte pour voir ses détails
   - Modifiez les informations si nécessaire

4. **Exporter les comptes** :
   - Allez dans Paramètres > Comptes > Exporter les comptes
   - Les détails de vos comptes seront partagés au format texte

## Sécurité

- Les secrets sont stockés de manière sécurisée sur l'appareil
- Aucune donnée n'est envoyée sur Internet
- L'application ne demande aucune permission inutile

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## Remerciements

- [FreeOTP](https://freeotp.github.io/) - L'application originale qui a inspiré ce projet
- [Flutter](https://flutter.dev/) - Le framework utilisé pour développer cette application
- [OTP Dart](https://pub.dev/packages/otp) - Bibliothèque pour la génération de codes OTP

## Contribuer

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## Auteur

Votre nom - [@votre-compte](https://github.com/votre-utilisateur)
