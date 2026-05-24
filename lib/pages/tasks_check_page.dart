// lib/pages/tasks_check_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class TaskCheckPage extends StatefulWidget {
  final String taskId;

  const TaskCheckPage({required this.taskId, Key? key}) : super(key: key);

  @override
  State<TaskCheckPage> createState() => _TaskCheckPageState();
}

class _TaskCheckPageState extends State<TaskCheckPage> {
  bool _loading = true;
  String? _error;

  String? _description;
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
      await _loadTask();
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

  Future<void> _loadTask() async {
    final task = await PocketBaseService.instance.pb
        .collection('tasks')
        .getOne(widget.taskId, expand: 'order_id,status_id,payment_status_id');

    final order = _expandData(task, 'order_id');
    final status = _expandData(task, 'status_id');
    final paymentStatus = _expandData(task, 'payment_status_id');

    _description = order?['task_description'] as String? ?? '—';

    final rawDeadline = order?['deadline'] as String?;
    final parsedDeadline = DateTime.tryParse(rawDeadline ?? '');
    _deadline =
        parsedDeadline == null
            ? '—'
            : DateFormat('dd.MM.yyyy').format(parsedDeadline.toLocal());

    _status = status?['name'] as String? ?? '—';
    _paymentStatus = paymentStatus?['name'] as String? ?? '—';
    _estimatedTime = task.data['estimated_time']?.toString() ?? '—';
    _timeSpent = task.data['time_spent']?.toString() ?? '—';
    _paymentAmount = task.data['payment_amount']?.toString() ?? '—';
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
                : const SizedBox.shrink(),
        appBar: AppBar(
          title: const Text('Loading…'),
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
                : const SizedBox.shrink(),
        appBar: AppBar(
          title: const Text('Error'),
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
              : const SizedBox.shrink(),
      appBar: AppBar(
        title: const Text('Check Order'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      backgroundColor: cs.surface,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_description ?? '—', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('Status: $_status', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Payment status: $_paymentStatus',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated time: ${_estimatedTime}h, Spent: ${_timeSpent}h',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Payment amount: \$$_paymentAmount',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 8),
                Text('Deadline: $_deadline', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
