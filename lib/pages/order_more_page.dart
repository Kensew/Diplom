// lib/pages/order_more_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class OrderMorePage extends StatefulWidget {
  final String orderId;

  const OrderMorePage({required this.orderId, Key? key}) : super(key: key);

  @override
  State<OrderMorePage> createState() => _OrderMorePageState();
}

class _OrderMorePageState extends State<OrderMorePage> {
  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;
  bool _applying = false;

  String? _description;
  DateTime? _deadline;
  String? _framework;
  String? _language;
  String? _attachmentUrl;
  num? _price;

  String? _customerId;
  String? _customerName;
  String? _customerPhoto;

  String? _executorId;
  String? _taskId;

  String? _role;
  String? _name;
  String? _photo;

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

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDrawerData();
      await _loadOrder();
    } catch (e) {
      _error = 'Ошибка загрузки: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDrawerData() async {
    final service = PocketBaseService.instance;
    final userId = service.currentUserId;

    if (userId == null) return;

    final user = await service.pb.collection('users').getOne(userId);

    _role = _roleFromUser(user.data);
    _name =
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';
    _photo = user.data['photo'] as String?;
  }

  Future<void> _loadOrder() async {
    final pb = PocketBaseService.instance.pb;

    final order = await pb.collection('orders').getOne(widget.orderId);

    _description = order.data['task_description'] as String?;
    _price = order.data['price'] as num?;

    final deadlineRaw = order.data['deadline'] as String?;
    _deadline = DateTime.tryParse(deadlineRaw ?? '')?.toLocal();

    final frameworkId = _relationId(order.data['framework_id']);
    final languageId = _relationId(order.data['language_id']);
    final customerId = _relationId(order.data['customer_id']);
    final executorId = _relationId(order.data['executor_id']);

    final framework = await _getRecordData('frameworks', frameworkId);
    final language = await _getRecordData('languages', languageId);
    final customer = await _getRecordData('users', customerId);

    _framework = framework?['name'] as String?;
    _language = language?['name'] as String?;

    _customerId = customerId;
    _customerName = customer?['name'] as String? ?? 'Customer';
    _customerPhoto = customer?['photo'] as String?;

    _executorId = executorId;

    final attachmentsResult = await pb
        .collection('order_attachments')
        .getList(page: 1, perPage: 200);

    final attachments =
        attachmentsResult.items.where((record) {
          final orderId = _relationId(record.data['order_id']);
          return orderId == widget.orderId;
        }).toList();

    attachments.sort((a, b) {
      final da = DateTime.tryParse(a.created);
      final db = DateTime.tryParse(b.created);

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    _attachmentUrl =
        attachments.isEmpty ? null : attachments.first.data['url'] as String?;

    final tasksResult = await pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final tasks =
        tasksResult.items.where((record) {
          final orderId = _relationId(record.data['order_id']);
          return orderId == widget.orderId;
        }).toList();

    tasks.sort((a, b) {
      final da = DateTime.tryParse(a.created);
      final db = DateTime.tryParse(b.created);

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    _taskId = tasks.isEmpty ? null : tasks.first.id;
  }

  Future<void> _apply() async {
    setState(() => _applying = true);

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));

      context.pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при подаче заявки: $e')));

      setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final currentUserId = PocketBaseService.instance.currentUserId;

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Order Details', style: TextStyle(fontSize: 24)),
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_attachmentUrl != null &&
                          _attachmentUrl!.trim().isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _attachmentUrl!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Text(
                                  'Не удалось загрузить изображение',
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_customerId != null) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => context.push('/account/$_customerId'),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage:
                                    _customerPhoto != null &&
                                            _customerPhoto!.trim().isNotEmpty
                                        ? NetworkImage(_customerPhoto!)
                                        : null,
                                radius: 24,
                                child:
                                    _customerPhoto == null ||
                                            _customerPhoto!.trim().isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _customerName ?? '–',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        _description ?? '–',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 20),
                      _RichDetailRow(
                        label: 'Framework:',
                        value: _framework ?? '–',
                      ),
                      _RichDetailRow(
                        label: 'Language:',
                        value: _language ?? '–',
                      ),
                      _RichDetailRow(
                        label: 'Deadline:',
                        value:
                            _deadline != null
                                ? _dateFmt.format(_deadline!)
                                : '–',
                      ),
                      _RichDetailRow(
                        label: 'Price:',
                        value: _price == null ? '–' : '\$$_price',
                      ),
                      const SizedBox(height: 30),
                      if (_executorId == null && _taskId == null)
                        ElevatedButton.icon(
                          onPressed: _applying ? null : _apply,
                          icon:
                              _applying
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.send),
                          label: Text(
                            _applying ? 'Sending...' : 'Apply for this Order',
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_taskId != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('/tasks/communication/$_taskId');
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Open Chat'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_executorId == currentUserId && _taskId != null)
                        ElevatedButton(
                          onPressed: () {
                            context.push('/tasks/check/$_taskId');
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Check Task'),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _RichDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _RichDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge,
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
