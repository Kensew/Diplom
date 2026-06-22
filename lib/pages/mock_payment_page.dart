// lib/pages/mock_payment_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/prepayment_service.dart';
import 'package:flutter_freelance_platform/widgets/cloudpayments_embed.dart';

class MockPaymentPage extends StatefulWidget {
  final String paymentRequestId;

  const MockPaymentPage({required this.paymentRequestId, Key? key})
    : super(key: key);

  @override
  State<MockPaymentPage> createState() => _MockPaymentPageState();
}

class _MockPaymentPageState extends State<MockPaymentPage> {
  bool _loading = true;
  bool _finalizing = false;
  String? _error;

  String? _taskId;
  String? _orderId;
  String? _title;
  String? _paymentStatus;
  String? _paymentType;
  double _amount = 0;

  @override
  void initState() {
    super.initState();
    _loadPayment();
  }

  String? _relationId(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) {
        final trimmed = first.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _getRecordData(
    String collection,
    String? id,
  ) async {
    if (id == null || id.isEmpty) return null;

    try {
      final record = await PocketBaseService.instance.pb
          .collection(collection)
          .getOne(id);

      return {'id': record.id, 'created': record.created, ...record.data};
    } catch (_) {
      return null;
    }
  }

  Future<String?> _firstIdFromCollection(
    String collection,
    List<String> preferredNames,
  ) async {
    final result = await PocketBaseService.instance.pb
        .collection(collection)
        .getList(page: 1, perPage: 200);

    if (result.items.isEmpty) return null;

    for (final name in preferredNames) {
      for (final item in result.items) {
        final itemName =
            (item.data['name'] as String? ?? '').trim().toLowerCase();

        if (itemName == name.trim().toLowerCase()) {
          return item.id;
        }
      }
    }

    return result.items.first.id;
  }

  Future<void> _loadPayment() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final payment = await service.pb
          .collection('payment_requests')
          .getOne(widget.paymentRequestId);

      final taskId = _relationId(payment.data['task_id']);
      final task = await _getRecordData('tasks', taskId);

      if (task == null) {
        throw 'Задача не найдена';
      }

      final orderId = _relationId(task['order_id']);
      final order = await _getRecordData('orders', orderId);

      if (order == null) {
        throw 'Заказ не найден';
      }

      final customerId = _relationId(order['customer_id']);

      if (customerId != currentUserId) {
        throw 'Оплатить может только заказчик этого заказа';
      }

      final status =
          payment.data['status']?.toString().trim().toLowerCase() ?? 'pending';

      if (status != 'pending') {
        throw 'Этот запрос оплаты уже обработан';
      }

      final rawAmount =
          (payment.data['payment_amount'] as num?) ??
          (task['payment_amount'] as num?) ??
          0;

      _taskId = taskId;
      _orderId = orderId;
      _title = order['task_description'] as String? ?? 'Оплата заказа';
      _paymentStatus = status;
      _paymentType = PrepaymentService.normalizedPaymentType(
        payment.data['payment_type'],
      );
      _amount = rawAmount.toDouble();
    } catch (e) {
      _error = 'Ошибка загрузки оплаты: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _finalizePayment(Map<String, dynamic> result) async {
    if (_finalizing) return;

    final taskId = _taskId;

    if (taskId == null) {
      _showSnack('Задача не найдена');
      return;
    }

    setState(() => _finalizing = true);

    try {
      final service = PocketBaseService.instance;

      final paidStatusId = await _firstIdFromCollection(
        'payment_statuses',
        _paymentType == 'prepayment'
            ? ['prepayment_paid', 'pending', 'paid']
            : ['paid', 'approved', 'done'],
      );

      await service.pb
          .collection('payment_requests')
          .update(
            widget.paymentRequestId,
            body: {'status': 'approved', 'payment_amount': _amount},
          );

      await service.pb
          .collection('tasks')
          .update(
            taskId,
            body: {if (paidStatusId != null) 'payment_status_id': paidStatusId},
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _paymentType == 'prepayment'
                ? 'Предоплата подтверждена: ${_amountForWidget.toStringAsFixed(2)} ₽'
                : 'Оплата подтверждена: ${_amountForWidget.toStringAsFixed(2)} ₽',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка сохранения оплаты: $e');
    } finally {
      if (mounted) {
        setState(() => _finalizing = false);
      }
    }
  }

  void _handlePaymentFail(Map<String, dynamic> result) {
    final message = result['message']?.toString();

    _showSnack(
      message == null || message.trim().isEmpty
          ? 'Платёж не был подтверждён'
          : 'Платёж не подтверждён: $message',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double get _amountForWidget {
    if (_amount <= 0) return 1;
    return double.parse(_amount.toStringAsFixed(2));
  }

  String get _descriptionForWidget {
    final title = _title?.trim();

    if (title == null || title.isEmpty) {
      return 'Оплата заказа';
    }

    if (title.length <= 120) {
      return title;
    }

    return '${title.substring(0, 120)}...';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          _paymentType == 'prepayment' ? 'Предоплата заказа' : 'Оплата заказа',
        ),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error),
                  ),
                ),
              )
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title ?? 'Оплата заказа',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            PrepaymentService.paymentTypeLabel(
                              _paymentType ?? 'final',
                            ),
                          ),
                          Text('Запрос: ${_paymentStatus ?? 'pending'}'),
                          if (_orderId != null) Text('Заказ: $_orderId'),
                          const SizedBox(height: 12),
                          Text(
                            '${_amountForWidget.toStringAsFixed(2)} ₽',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_finalizing)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Сохраняем результат оплаты...'),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    if (!_finalizing)
                      SizedBox(
                        height: 720,
                        child: CloudPaymentsEmbed(
                          amount: _amountForWidget,
                          description: _descriptionForWidget,
                          externalId: widget.paymentRequestId,
                          onSuccess: _finalizePayment,
                          onFail: _handlePaymentFail,
                        ),
                      )
                    else
                      Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 64),
                            SizedBox(height: 12),
                            Text(
                              'Оплата подтверждена',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
