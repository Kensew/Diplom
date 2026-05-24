// lib/pages/customer_applications_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

enum _ReqType { application, payment }

class _ReqItem {
  final String id;
  final _ReqType type;
  final String title;
  final String actorName;
  final String? actorPhoto;
  final String status;
  final DateTime createdAt;
  final double? amount;
  final String? orderId;
  final String? executorId;
  final String? taskId;

  _ReqItem({
    required this.id,
    required this.type,
    required this.title,
    required this.actorName,
    this.actorPhoto,
    required this.status,
    required this.createdAt,
    this.amount,
    this.orderId,
    this.executorId,
    this.taskId,
  });
}

class CustomerApplicationsPage extends StatefulWidget {
  const CustomerApplicationsPage({Key? key}) : super(key: key);

  @override
  State<CustomerApplicationsPage> createState() =>
      _CustomerApplicationsPageState();
}

class _CustomerApplicationsPageState extends State<CustomerApplicationsPage> {
  final _fmt = DateFormat('dd.MM.yyyy HH:mm');

  bool _loading = true;
  String? _error;

  String? _busyItemId;

  String? _role;
  String? _displayName;
  String? _photo;

  bool _sortNewest = true;
  List<_ReqItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru') return 'customer';
    if (normalized == 'support@test.ru') return 'support';
    if (normalized == 'executor@test.ru') return 'executor';

    return 'executor';
  }

  String _roleFromUser(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? '';
    final rawRole = data['role']?.toString().trim().toLowerCase();

    if (rawRole == 'customer' ||
        rawRole == 'support' ||
        rawRole == 'executor') {
      return rawRole!;
    }

    return _roleFallbackByEmail(email);
  }

  String _status(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status == 'approved' || status == 'rejected' || status == 'pending') {
      return status!;
    }

    return 'pending';
  }

  bool _isPending(String status) {
    return status.trim().toLowerCase() == 'pending';
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

  Future<bool> _taskExistsForOrder(String orderId) async {
    final result = await PocketBaseService.instance.pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    for (final task in result.items) {
      final taskOrderId = _relationId(task.data['order_id']);
      if (taskOrderId == orderId) return true;
    }

    return false;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _busyItemId = null;
    });

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      _role = _roleFromUser(user.data);
      _displayName =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _photo = user.data['photo'] as String?;

      final loaded = <_ReqItem>[];

      final appsResult = await pb
          .collection('applications')
          .getList(page: 1, perPage: 200);

      for (final app in appsResult.items) {
        final orderId = _relationId(app.data['order_id']);
        final executorId = _relationId(app.data['executor_id']);

        final order = await _getRecordData('orders', orderId);
        if (order == null) continue;

        final customerId = _relationId(order['customer_id']);
        if (customerId != userId) continue;

        final executor = await _getRecordData('users', executorId);

        loaded.add(
          _ReqItem(
            id: app.id,
            type: _ReqType.application,
            title: order['task_description'] as String? ?? '—',
            actorName: executor?['name'] as String? ?? 'Executor',
            actorPhoto: executor?['photo'] as String?,
            status: _status(app.data['status']),
            createdAt:
                DateTime.tryParse(app.created)?.toLocal() ?? DateTime.now(),
            orderId: orderId,
            executorId: executorId,
          ),
        );
      }

      final paymentsResult = await pb
          .collection('payment_requests')
          .getList(page: 1, perPage: 200);

      for (final payment in paymentsResult.items) {
        final taskId = _relationId(payment.data['task_id']);
        final task = await _getRecordData('tasks', taskId);

        if (task == null) continue;

        final orderId = _relationId(task['order_id']);
        final order = await _getRecordData('orders', orderId);

        if (order == null) continue;

        final customerId = _relationId(order['customer_id']);
        if (customerId != userId) continue;

        final requestedById = _relationId(payment.data['requested_by']);
        final requestedBy = await _getRecordData('users', requestedById);

        loaded.add(
          _ReqItem(
            id: payment.id,
            type: _ReqType.payment,
            title: order['task_description'] as String? ?? '—',
            actorName: requestedBy?['name'] as String? ?? 'Executor',
            actorPhoto: requestedBy?['photo'] as String?,
            status: _status(payment.data['status']),
            createdAt:
                DateTime.tryParse(payment.created)?.toLocal() ?? DateTime.now(),
            amount:
                (payment.data['payment_amount'] as num?)?.toDouble() ??
                (task['payment_amount'] as num?)?.toDouble(),
            taskId: taskId,
            orderId: orderId,
          ),
        );
      }

      loaded.sort(
        (a, b) =>
            _sortNewest
                ? b.createdAt.compareTo(a.createdAt)
                : a.createdAt.compareTo(b.createdAt),
      );

      _items = loaded;
    } catch (e) {
      _error = 'Не удалось загрузить заявки: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _decide(_ReqItem item, bool accept) async {
    if (_busyItemId != null) return;

    setState(() {
      _busyItemId = item.id;
      _error = null;
    });

    try {
      final pb = PocketBaseService.instance.pb;
      final newStatus = accept ? 'approved' : 'rejected';

      if (item.type == _ReqType.application) {
        await pb
            .collection('applications')
            .update(item.id, body: {'status': newStatus});

        if (accept && item.orderId != null && item.executorId != null) {
          await pb
              .collection('orders')
              .update(item.orderId!, body: {'executor_id': item.executorId});

          final exists = await _taskExistsForOrder(item.orderId!);

          if (!exists) {
            final statusId = await _firstIdFromCollection('task_statuses', [
              'new',
              'pending',
              'created',
            ]);

            final paymentStatusId = await _firstIdFromCollection(
              'payment_statuses',
              ['none', 'pending', 'unpaid'],
            );

            await pb
                .collection('tasks')
                .create(
                  body: {
                    'order_id': item.orderId,
                    'executor_id': item.executorId,
                    if (statusId != null) 'status_id': statusId,
                    if (paymentStatusId != null)
                      'payment_status_id': paymentStatusId,
                    'estimated_time': 0,
                    'time_spent': 0,
                    'payment_amount': item.amount ?? 0,
                  },
                );
          }
        }
      } else {
        await pb
            .collection('payment_requests')
            .update(item.id, body: {'status': newStatus});

        if (accept && item.taskId != null) {
          final paidStatusId = await _firstIdFromCollection(
            'payment_statuses',
            ['approved', 'paid', 'done'],
          );

          await pb
              .collection('tasks')
              .update(
                item.taskId!,
                body: {
                  if (paidStatusId != null) 'payment_status_id': paidStatusId,
                },
              );
        }
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Ошибка обработки заявки: $e';
      });
    }
  }

  Future<void> _rejectAll() async {
    if (_busyItemId != null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Отклонить все pending-заявки?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Да'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() {
      _busyItemId = '__all__';
      _error = null;
    });

    try {
      final pb = PocketBaseService.instance.pb;

      for (final item in _items.where((e) => _isPending(e.status))) {
        final collection =
            item.type == _ReqType.application
                ? 'applications'
                : 'payment_requests';

        await pb
            .collection(collection)
            .update(item.id, body: {'status': 'rejected'});
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Ошибка отклонения заявок: $e';
      });
    }
  }

  String _typeLabel(_ReqType type) {
    return type == _ReqType.application ? 'Заявка на заказ' : 'Запрос оплаты';
  }

  IconData _typeIcon(_ReqType type) {
    return type == _ReqType.application
        ? Icons.assignment_ind_outlined
        : Icons.payments_rounded;
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return cs.error;
      case 'pending':
      default:
        return cs.primary;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return 'Принято';
      case 'rejected':
        return 'Отклонено';
      case 'pending':
      default:
        return 'Ожидает решения';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasPending = _items.any((item) => _isPending(item.status));
    final pageBusy = _busyItemId != null;

    return Scaffold(
      backgroundColor: cs.background,
      drawer:
          (_role != null && _displayName != null)
              ? AppDrawer(
                role: _role!,
                displayName: _displayName!,
                avatarUrl: _photo,
              )
              : null,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0.5,
        title: const Text('Заявки и оплаты'),
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: tt.bodyLarge?.copyWith(color: cs.error),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<bool>(
                              value: _sortNewest,
                              decoration: InputDecoration(
                                labelText: 'Сортировка',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Новые'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Старые'),
                                ),
                              ],
                              onChanged:
                                  pageBusy
                                      ? null
                                      : (v) async {
                                        if (v == null) return;
                                        setState(() => _sortNewest = v);
                                        await _loadAll();
                                      },
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  hasPending && !pageBusy ? _rejectAll : null,
                              icon:
                                  pageBusy && _busyItemId == '__all__'
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.delete_forever),
                              label: const Text('Отклонить все'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _items.isEmpty
                              ? Center(
                                child: Text(
                                  'Заявок пока нет',
                                  style: tt.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              )
                              : RefreshIndicator(
                                onRefresh: _loadAll,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                                  itemCount: _items.length,
                                  itemBuilder: (_, i) {
                                    final item = _items[i];
                                    final statusColor = _statusColor(
                                      item.status,
                                      cs,
                                    );
                                    final itemBusy = _busyItemId == item.id;
                                    final pending = _isPending(item.status);

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: cs.surface,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: cs.primary
                                                      .withOpacity(0.12),
                                                  backgroundImage:
                                                      item.actorPhoto != null &&
                                                              item.actorPhoto!
                                                                  .trim()
                                                                  .isNotEmpty
                                                          ? NetworkImage(
                                                            item.actorPhoto!,
                                                          )
                                                          : null,
                                                  child:
                                                      item.actorPhoto == null ||
                                                              item.actorPhoto!
                                                                  .trim()
                                                                  .isEmpty
                                                          ? Icon(
                                                            _typeIcon(
                                                              item.type,
                                                            ),
                                                            color: cs.primary,
                                                          )
                                                          : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.actorName,
                                                        style: tt.titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                      Text(
                                                        _typeLabel(item.type),
                                                        style: tt.bodySmall
                                                            ?.copyWith(
                                                              color:
                                                                  cs.onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  _fmt.format(item.createdAt),
                                                  style: tt.bodySmall?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              item.title,
                                              style: tt.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (item.type == _ReqType.payment &&
                                                item.amount != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Сумма: \$${item.amount!.toStringAsFixed(2)}',
                                                style: tt.bodyMedium?.copyWith(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 10),
                                            if (pending)
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed:
                                                          pageBusy
                                                              ? null
                                                              : () => _decide(
                                                                item,
                                                                true,
                                                              ),
                                                      child:
                                                          itemBusy
                                                              ? const SizedBox(
                                                                width: 18,
                                                                height: 18,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                              )
                                                              : Text(
                                                                item.type ==
                                                                        _ReqType
                                                                            .application
                                                                    ? 'Принять'
                                                                    : 'Подтвердить',
                                                              ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed:
                                                          pageBusy
                                                              ? null
                                                              : () => _decide(
                                                                item,
                                                                false,
                                                              ),
                                                      child: const Text(
                                                        'Отклонить',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _statusText(item.status),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}
