// lib/pages/task_create_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class TaskCreatePage extends StatefulWidget {
  const TaskCreatePage({super.key});

  @override
  State<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends State<TaskCreatePage> {
  bool _loading = false;

  String? _selectedOrderId;
  String? _selectedExecutorId;
  String? _statusId;
  String? _paymentStatusId;

  final _estimatedTimeCtrl = TextEditingController();
  final _timeSpentCtrl = TextEditingController();
  final _paymentAmountCtrl = TextEditingController();

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _executors = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<String?> _firstIdByName(String collection, String name) async {
    final records = await PocketBaseService.instance.pb
        .collection(collection)
        .getList(page: 1, perPage: 1, filter: 'name = "$name"');

    if (records.items.isEmpty) return null;
    return records.items.first.id;
  }

  Future<void> _loadMeta() async {
    setState(() => _loading = true);

    try {
      final pb = PocketBaseService.instance.pb;

      final orders = await pb
          .collection('orders')
          .getFullList(sort: '-created');

      final users = await pb
          .collection('users')
          .getFullList(filter: 'role = "executor"', sort: 'name');

      _statusId = await _firstIdByName('task_statuses', 'new');
      _paymentStatusId = await _firstIdByName('payment_statuses', 'none');

      _orders =
          orders.map((record) {
            return {
              'id': record.id,
              'title': record.data['task_description'] as String? ?? record.id,
            };
          }).toList();

      _executors =
          users.map((record) {
            return {
              'id': record.id,
              'name':
                  record.data['name'] as String? ??
                  record.data['email'] as String? ??
                  record.id,
            };
          }).toList();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите заказ')));
      return;
    }

    setState(() => _loading = true);

    try {
      await PocketBaseService.instance.pb
          .collection('tasks')
          .create(
            body: {
              'order_id': _selectedOrderId,
              if (_selectedExecutorId != null)
                'executor_id': _selectedExecutorId,
              if (_statusId != null) 'status_id': _statusId,
              if (_paymentStatusId != null)
                'payment_status_id': _paymentStatusId,
              'estimated_time':
                  double.tryParse(_estimatedTimeCtrl.text.trim()) ?? 0,
              'time_spent': double.tryParse(_timeSpentCtrl.text.trim()) ?? 0,
              'payment_amount':
                  double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0,
            },
          );

      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при создании задачи: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _estimatedTimeCtrl.dispose();
    _timeSpentCtrl.dispose();
    _paymentAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создание задачи')),
      body:
          _loading && _orders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedOrderId,
                      decoration: const InputDecoration(
                        labelText: 'Заказ',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _orders
                              .map(
                                (order) => DropdownMenuItem<String>(
                                  value: order['id'] as String,
                                  child: Text(
                                    order['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _loading
                              ? null
                              : (value) =>
                                  setState(() => _selectedOrderId = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedExecutorId,
                      decoration: const InputDecoration(
                        labelText: 'Исполнитель',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _executors
                              .map(
                                (executor) => DropdownMenuItem<String>(
                                  value: executor['id'] as String,
                                  child: Text(executor['name'] as String),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _loading
                              ? null
                              : (value) =>
                                  setState(() => _selectedExecutorId = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _estimatedTimeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Оценка времени, ч',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _timeSpentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Потрачено времени, ч',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paymentAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Сумма оплаты',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: const Icon(Icons.add_task),
                        label:
                            _loading
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Создать задачу'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
