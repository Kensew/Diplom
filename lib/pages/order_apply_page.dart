// lib/pages/order_apply_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class OrderApplyPage extends StatefulWidget {
  final String orderId;

  const OrderApplyPage({required this.orderId, Key? key}) : super(key: key);

  @override
  State<OrderApplyPage> createState() => _OrderApplyPageState();
}

class _OrderApplyPageState extends State<OrderApplyPage> {
  final _fmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  String? _role;
  String? _name;
  String? _photo;

  String? _customerId;
  String? _executorId;
  String? _description;
  String? _deadline;
  num? _price;
  bool _alreadyApplied = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
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

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' || normalized == 'dev1@test.local') {
      return 'customer';
    }

    if (normalized == 'executor@test.ru' || normalized == 'dev2@test.local') {
      return 'executor';
    }

    if (normalized == 'support@test.ru' || normalized == 'dev3@test.local') {
      return 'support';
    }

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

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await service.pb.collection('users').getOne(userId);

      _role = _roleFromUser(user.data);
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';

      _photo = PocketBaseFileService.fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final order = await service.pb
          .collection('orders')
          .getOne(widget.orderId);

      _customerId = _relationId(order.data['customer_id']);
      _executorId = _relationId(order.data['executor_id']);
      _description = order.data['task_description'] as String? ?? '—';
      _price = order.data['price'] as num?;

      final rawDeadline = order.data['deadline'] as String?;
      final parsedDeadline = DateTime.tryParse(rawDeadline ?? '');
      _deadline =
          parsedDeadline == null ? '—' : _fmt.format(parsedDeadline.toLocal());

      await _checkAlreadyApplied();
    } catch (e) {
      _error = 'Ошибка загрузки заявки: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkAlreadyApplied() async {
    final service = PocketBaseService.instance;
    final userId = service.currentUserId;

    if (userId == null) {
      _alreadyApplied = false;
      return;
    }

    final apps = await service.pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    _alreadyApplied = apps.items.any((app) {
      final orderId = _relationId(app.data['order_id']);
      final executorId = _relationId(app.data['executor_id']);

      return orderId == widget.orderId && executorId == userId;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      if (_role != 'executor') {
        throw 'Заявки могут подавать только исполнители';
      }

      if (_customerId == userId) {
        throw 'Нельзя подать заявку на свой заказ';
      }

      if (_executorId != null) {
        throw 'Заказ уже назначен исполнителю';
      }

      await _checkAlreadyApplied();

      if (_alreadyApplied) {
        throw 'Вы уже подали заявку на этот заказ';
      }

      await service.pb
          .collection('applications')
          .create(
            body: {
              'order_id': widget.orderId,
              'executor_id': userId,
              'status': 'pending',
            },
          );

      if (!mounted) return;

      setState(() {
        _alreadyApplied = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Ошибка подачи заявки: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool get _canSubmit {
    final currentUserId = PocketBaseService.instance.currentUserId;

    return _role == 'executor' &&
        _customerId != currentUserId &&
        _executorId == null &&
        !_alreadyApplied;
  }

  String get _disabledReason {
    final currentUserId = PocketBaseService.instance.currentUserId;

    if (_role != 'executor') return 'Подавать заявки может только исполнитель';
    if (_customerId == currentUserId) return 'Это ваш заказ';
    if (_executorId != null) return 'Заказ уже назначен';
    if (_alreadyApplied) return 'Заявка уже отправлена';

    return 'Заявку нельзя отправить';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        title: const Text('Подать заявку'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(_description ?? '—', style: tt.headlineSmall),

                      const SizedBox(height: 16),

                      Text('Дедлайн: ${_deadline ?? '—'}'),
                      Text('Цена: ${_price == null ? '—' : '\$$_price'}'),

                      const SizedBox(height: 24),

                      if (_canSubmit)
                        ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon:
                              _submitting
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.send),
                          label: Text(
                            _submitting ? 'Отправка...' : 'Подать заявку',
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.info_outline),
                          label: Text(_disabledReason),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: () {
                          context.go('/orders/details/${widget.orderId}');
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Открыть детали заказа'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
