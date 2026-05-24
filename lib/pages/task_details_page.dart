// lib/pages/task_details_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import '../widgets/app_drawer.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;

  const TaskDetailsPage({required this.taskId, Key? key}) : super(key: key);

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  bool _loading = true;
  String? _error;

  String? _title;
  String? _deadline;
  String? _status;
  String? _paymentStatus;
  String? _estimatedTime;
  String? _timeSpent;
  String? _paymentAmount;

  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Map<String, dynamic>? _expandData(dynamic record, String fieldName) {
    final items = record.expand[fieldName];

    if (items is List && items.isNotEmpty) {
      return items.first.data as Map<String, dynamic>;
    }

    return null;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDrawerData();
      await _loadDetail();
    } catch (e) {
      _error = 'Ошибка: $e';
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

    _role = user.data['role'] as String? ?? 'executor';
    _name =
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';
    _photo = user.data['photo'] as String?;
  }

  Future<void> _loadDetail() async {
    final pb = PocketBaseService.instance.pb;

    final task = await pb
        .collection('tasks')
        .getOne(widget.taskId, expand: 'order_id,status_id,payment_status_id');

    final order = _expandData(task, 'order_id');
    final status = _expandData(task, 'status_id');
    final paymentStatus = _expandData(task, 'payment_status_id');

    _title = order?['task_description'] as String? ?? '—';

    final rawDeadline = order?['deadline'] as String?;
    final parsedDeadline = DateTime.tryParse(rawDeadline ?? '');
    _deadline =
        parsedDeadline == null
            ? '—'
            : DateFormat('dd.MM.yyyy').format(parsedDeadline.toLocal());

    _status = status?['name'] as String? ?? '—';
    _paymentStatus = paymentStatus?['name'] as String? ?? '—';

    _estimatedTime = '${task.data['estimated_time']?.toString() ?? '—'}h';
    _timeSpent = '${task.data['time_spent']?.toString() ?? '—'}h';
    _paymentAmount = '\$${task.data['payment_amount']?.toString() ?? '—'}';
  }

  Future<void> _requestPayment() async {
    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      await service.pb
          .collection('payment_requests')
          .create(
            body: {
              'task_id': widget.taskId,
              'requested_by': userId,
              'status': 'pending',
            },
          );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment request sent')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending request: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        drawer:
            (_role != null && _name != null)
                ? AppDrawer(
                  role: _role!,
                  displayName: _name!,
                  avatarUrl: _photo,
                )
                : null,
        appBar: AppBar(
          title: const Text('Загрузка…'),
          backgroundColor: cs.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: cs.surface,
      );
    }

    if (_error != null) {
      return Scaffold(
        drawer:
            (_role != null && _name != null)
                ? AppDrawer(
                  role: _role!,
                  displayName: _name!,
                  avatarUrl: _photo,
                )
                : null,
        appBar: AppBar(
          title: const Text('Ошибка'),
          backgroundColor: cs.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
        backgroundColor: cs.surface,
      );
    }

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        title: Text(_title ?? 'Task', style: theme.textTheme.headlineSmall),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Status: $_status', style: theme.textTheme.bodyLarge),
              Text(
                'Payment status: $_paymentStatus',
                style: theme.textTheme.bodyLarge,
              ),
              Text(
                'Estimated: $_estimatedTime, Spent: $_timeSpent',
                style: theme.textTheme.bodyLarge,
              ),
              Text('Amount: $_paymentAmount', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.schedule),
                  const SizedBox(width: 8),
                  Text(
                    'Deadline: $_deadline',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    () => context.push('/tasks/communication/${widget.taskId}'),
                child: const Text('Open Chat'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _requestPayment,
                style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
                child: const Text('Request Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
