// lib/pages/tasks_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({Key? key}) : super(key: key);

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  String _sortOrder = 'Newest';

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _tasks = [];

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
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      _role = user.data['role'] as String? ?? 'executor';
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _photo = user.data['photo'] as String?;

      final taskResult = await pb
          .collection('tasks')
          .getList(page: 1, perPage: 200);

      final records = taskResult.items;
      final result = <Map<String, dynamic>>[];

      for (final record in records) {
        final executorId = _relationId(record.data['executor_id']);

        if (executorId != userId) continue;

        final orderId = _relationId(record.data['order_id']);
        final statusId = _relationId(record.data['status_id']);
        final paymentStatusId = _relationId(record.data['payment_status_id']);

        final order = await _getRecordData('orders', orderId);
        final status = await _getRecordData('task_statuses', statusId);
        final paymentStatus = await _getRecordData(
          'payment_statuses',
          paymentStatusId,
        );

        result.add({
          'id': record.id,
          'created': record.created,
          'title': order?['task_description'] as String? ?? '—',
          'deadline': order?['deadline'] as String?,
          'status': status?['name'] as String? ?? '—',
          'payment_status': paymentStatus?['name'] as String? ?? '—',
          'estimated_time': record.data['estimated_time'],
          'time_spent': record.data['time_spent'],
          'payment_amount': record.data['payment_amount'],
        });
      }

      result.sort((a, b) {
        final da = DateTime.tryParse(a['created'] as String? ?? '');
        final db = DateTime.tryParse(b['created'] as String? ?? '');

        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;

        return db.compareTo(da);
      });

      _tasks = result;
    } catch (e) {
      _error = 'Не удалось загрузить задачи: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    final q = _searchController.text.trim().toLowerCase();

    final list =
        _tasks.where((task) {
          final title = (task['title'] as String? ?? '').toLowerCase();
          return title.contains(q);
        }).toList();

    switch (_sortOrder) {
      case 'Oldest':
        return list.reversed.toList();

      case 'By deadline':
        list.sort((a, b) {
          final da = DateTime.tryParse(a['deadline'] as String? ?? '');
          final db = DateTime.tryParse(b['deadline'] as String? ?? '');

          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;

          return da.compareTo(db);
        });
        return list;

      case 'Newest':
      default:
        return list;
    }
  }

  String _formatDeadline(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';
    return _fmt.format(dt.toLocal());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final borderColor = Colors.white12;

    final filteredTasks = _filteredTasks;
    final switcherKey = '${filteredTasks.length}::$_sortOrder';

    return Scaffold(
      backgroundColor: cs.background,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.task_alt_outlined, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              'My tasks',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
                : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search tasks…',
                                    hintStyle: tt.bodyMedium?.copyWith(
                                      color: cs.onSurface.withOpacity(0.6),
                                    ),
                                    filled: true,
                                    fillColor: cs.surfaceVariant,
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: cs.onSurface,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sortOrder,
                                    dropdownColor: cs.surfaceVariant,
                                    iconEnabledColor: cs.onSurface,
                                    style: tt.bodyMedium?.copyWith(
                                      color: cs.onSurface,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Newest',
                                        child: Text('Newest'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Oldest',
                                        child: Text('Oldest'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'By deadline',
                                        child: Text('By deadline'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _sortOrder = v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child:
                                filteredTasks.isEmpty
                                    ? Center(
                                      child: Text(
                                        'No tasks yet',
                                        style: tt.bodyMedium?.copyWith(
                                          color: cs.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      key: ValueKey(switcherKey),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      itemCount: filteredTasks.length,
                                      itemBuilder: (ctx, i) {
                                        final task = filteredTasks[i];

                                        final id = task['id'] as String;
                                        final title =
                                            task['title'] as String? ?? '—';
                                        final status =
                                            task['status'] as String? ?? '—';
                                        final payStatus =
                                            task['payment_status'] as String? ??
                                            '—';
                                        final est =
                                            task['estimated_time']
                                                ?.toString() ??
                                            '0';
                                        final spent =
                                            task['time_spent']?.toString() ??
                                            '0';
                                        final amount =
                                            task['payment_amount']
                                                ?.toString() ??
                                            '0';

                                        return _TaskCard(
                                          title: title,
                                          status: status,
                                          paymentStatus: payStatus,
                                          details:
                                              'Estimate: ${est}h · Spent: ${spent}h · \$$amount',
                                          deadline: _formatDeadline(
                                            task['deadline'] as String?,
                                          ),
                                          onTap: () {
                                            context.push('/tasks/details/$id');
                                          },
                                        );
                                      },
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String status;
  final String paymentStatus;
  final String details;
  final String deadline;
  final VoidCallback onTap;

  const _TaskCard({
    required this.title,
    required this.status,
    required this.paymentStatus,
    required this.details,
    required this.deadline,
    required this.onTap,
  });

  Color _statusColor(ColorScheme cs) {
    final s = status.toLowerCase();

    if (s.contains('done') || s.contains('completed')) {
      return Colors.greenAccent.withOpacity(0.9);
    }

    if (s.contains('progress') || s.contains('active')) {
      return Colors.amberAccent.withOpacity(0.9);
    }

    return cs.onSurface.withOpacity(0.7);
  }

  Color _paymentColor(ColorScheme cs) {
    final s = paymentStatus.toLowerCase();

    if (s.contains('paid') || s.contains('approved')) {
      return Colors.greenAccent.withOpacity(0.9);
    }

    if (s.contains('pending')) {
      return Colors.orangeAccent.withOpacity(0.9);
    }

    return cs.onSurface.withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Card(
          color: cs.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.white10),
          ),
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface.withOpacity(0.9),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Icon(Icons.task_alt, color: cs.onSurface),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: _StatusChip(
                              icon: Icons.circle,
                              label: status,
                              color: _statusColor(cs),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _StatusChip(
                              icon: Icons.payments,
                              label: paymentStatus,
                              color: _paymentColor(cs),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        details,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 14,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Deadline: $deadline',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 8 : 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
