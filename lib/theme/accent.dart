import 'package:flutter/material.dart';

/// Color de acento vigente (el elegido en Ajustes, o el de la carátula en
/// "Sonando"). Reemplaza al naranja fijo de antes.
extension AccentColor on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
}
