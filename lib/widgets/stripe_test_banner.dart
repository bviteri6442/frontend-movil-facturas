import 'package:flutter/material.dart';

/// Aviso visible de que la app usa Stripe en modo prueba (sin cobros reales).
class StripeTestBanner extends StatelessWidget {
  const StripeTestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: Color(0xFFC2410C), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo prueba Stripe',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sin cobros reales. Solo se aceptan tarjetas de prueba en el formulario seguro de abajo.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7C2D12)),
          ),
        ],
      ),
    );
  }
}
