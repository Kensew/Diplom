// lib/widgets/cloudpayments_embed_stub.dart

import 'package:flutter/material.dart';

typedef CloudPaymentsResultCallback =
    void Function(Map<String, dynamic> result);

class CloudPaymentsEmbed extends StatelessWidget {
  final double amount;
  final String description;
  final String externalId;
  final CloudPaymentsResultCallback onSuccess;
  final CloudPaymentsResultCallback onFail;

  const CloudPaymentsEmbed({
    required this.amount,
    required this.description,
    required this.externalId,
    required this.onSuccess,
    required this.onFail,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments, size: 48),
          const SizedBox(height: 12),
          const Text(
            'CloudPayments-виджет работает в Flutter Web.\n'
            'Для мобильной/desktop-сборки используется учебная имитация.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              onSuccess({
                'status': 'success',
                'source': 'stub',
                'amount': amount,
                'externalId': externalId,
              });
            },
            icon: const Icon(Icons.check_circle),
            label: Text('Имитировать оплату ${amount.toStringAsFixed(2)} ₽'),
          ),
        ],
      ),
    );
  }
}
