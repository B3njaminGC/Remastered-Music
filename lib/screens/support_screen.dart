import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/donation_config.dart';

/// "Colaborá con el proyecto": alias y link de Mercado Pago.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  bool get _hasAlias => DonationConfig.mercadoPagoAlias.trim().isNotEmpty;
  bool get _hasLink => DonationConfig.mercadoPagoLink.trim().isNotEmpty;

  Future<void> _copyAlias(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      const ClipboardData(text: DonationConfig.mercadoPagoAlias),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Alias copiado. ¡Gracias!')));
  }

  Future<void> _openLink(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(DonationConfig.mercadoPagoLink.trim());
    var opened = false;
    if (uri != null && uri.scheme == 'https') {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el link de pago.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Colaborá con el proyecto')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.favorite, size: 64, color: Colors.deepOrange),
          const SizedBox(height: 16),
          Text(
            '¡Gracias por usar Reproductor FOSS!',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Es una app gratuita, sin anuncios, sin cuentas y sin recolección '
            'de datos. Si te gusta y querés ayudar a que siga mejorando, '
            'podés colaborar con un aporte voluntario. Es totalmente opcional.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 24),
          if (!_hasAlias && !_hasLink)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Próximamente vas a encontrar acá los datos para donar.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_hasAlias)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ALIAS DE MERCADO PAGO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            DonationConfig.mercadoPagoAlias,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar alias',
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyAlias(context),
                        ),
                      ],
                    ),
                    if (DonationConfig.holderName.trim().isNotEmpty)
                      Text(
                        'Titular: ${DonationConfig.holderName}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          if (_hasLink) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _openLink(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Donar con Mercado Pago'),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Otras formas de ayudar',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Compartí la app con alguien que le pueda servir.\n'
            '• Avisá si encontrás un error o tenés una idea.\n'
            '• Dejá una estrella al repositorio en GitHub.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}
