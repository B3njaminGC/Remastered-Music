/// Datos para la pantalla "Colaborá con el proyecto".
///
/// Completá los que quieras mostrar; los que dejes vacíos no aparecen.
/// Si los dos están vacíos, la pantalla dice que las donaciones llegarán pronto.
class DonationConfig {
  const DonationConfig._();

  /// Alias de Mercado Pago (se muestra con botón "Copiar").
  static const String mercadoPagoAlias = '';

  /// Link de pago de Mercado Pago, p. ej. `https://mpago.la/xxxxxxx`
  /// (se abre desde el botón "Donar con Mercado Pago").
  static const String mercadoPagoLink = '';

  /// Nombre del titular, opcional (ayuda a verificar que el alias es el correcto).
  static const String holderName = '';
}
