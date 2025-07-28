// Fichier de mock pour Google Fonts
// Ce fichier remplace l'implémentation de Google Fonts pendant les tests

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Style de texte par défaut pour les tests
const TextStyle _testTextStyle = TextStyle(fontFamily: 'Arial');

// Fonction de mock pour robotoMono
TextStyle mockRobotoMono({
  TextStyle? textStyle,
  Color? color,
  FontWeight? fontWeight,
  double? fontSize,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return _testTextStyle.copyWith(
    color: color,
    fontWeight: fontWeight,
    fontSize: fontSize,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

// Configuration des mocks pour Google Fonts
void setupGoogleFontsMocks() {
  // Remplacer la fonction robotoMono par notre mock
  GoogleFonts.robotoMono = mockRobotoMono;
  
  // Désactiver le chargement des polices à l'exécution
  GoogleFonts.config.allowRuntimeFetching = false;
}
