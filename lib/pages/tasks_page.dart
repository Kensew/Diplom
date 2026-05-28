// lib/pages/tasks_page.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({Key? key}) : super(key: key);

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  String _sortOrder = 'Newest';

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _tasks = [];

  String? _role;
  String? _name;
  String? _photo;

  Timer? _refreshDebounce;
  bool _silentRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();

    final pb = PocketBaseService.instance.pb;
    pb.collection('tasks').unsubscribe('*');
    pb.collection('orders').unsubscribe('*');
    pb.collection('payment_requests').unsubscribe('*');
    pb.collection('task_statuses').unsubscribe('*');
    pb.collection('payment_statuses').unsubscribe('*');

    _searchController.dispose();
    super.dispose();
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

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' ||
        normalized == 'dev1@test.local' ||
        normalized == '1') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' ||
        normalized == 'dev3@test.local' ||
        normalized == '3') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' ||
        normalized == 'dev2@test.local' ||
        normalized == '2') {
      return 'executor';
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

  Future<void> _subscribeRealtime() async {
    final pb = PocketBaseService.instance.pb;

    Future<void> onAnyChange(dynamic _) async {
      _scheduleSilentRefresh();
    }

    await pb.collection('tasks').subscribe('*', onAnyChange);
    await pb.collection('orders').subscribe('*', onAnyChange);
    await pb.collection('payment_requests').subscribe('*', onAnyChange);
    await pb.collection('task_statuses').subscribe('*', onAnyChange);
    await pb.collection('payment_statuses').subscribe('*', onAnyChange);
  }

  void _scheduleSilentRefresh() {
    _refreshDebounce?.cancel();

    _refreshDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted || _silentRefreshing) return;

      _silentRefreshing = true;
      try {
        await _loadAll(showLoader: false);
      } finally {
        _silentRefreshing = false;
      }
    });
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

      return {
        'id': record.id,
        'created': record.get<String>('created') ?? '',
        ...record.data,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAll({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      final role = _roleFromUser(user.data);
      final name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';

      final photo = PocketBaseFileService.fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final taskResult = await pb
          .collection('tasks')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];

      for (final record in taskResult.items) {
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
          'created': record.get<String>('created') ?? '',
          'order_id': orderId,
          'title': order?['task_description'] as String? ?? '—',
          'deadline': order?['deadline'] as String?,
          'status': status?['name'] as String? ?? '—',
          'payment_status': paymentStatus?['name'] as String? ?? '—',
          'estimated_time': record.data['estimated_time'],
          'time_spent': record.data['time_spent'],
          'payment_amount': record.data['payment_amount'],
          'complexity_final': _intValue(record.data['complexity_final']),
          'complexity_source': record.data['complexity_source'] as String?,
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

      if (!mounted) return;

      setState(() {
        _role = role;
        _name = name;
        _photo = photo;
        _tasks = result;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить задачи: $e';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime? _parseDate(String? raw) {
    return DateTime.tryParse(raw ?? '');
  }

  String _formatDeadline(String? raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '—';

    return _fmt.format(dt.toLocal());
  }

  num _amountOf(Map<String, dynamic> task) {
    return (task['payment_amount'] as num?) ?? 0;
  }

  String _formatMoney(num value) {
    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'Oldest':
        return 'Старые';
      case 'By deadline':
        return 'По дедлайну';
      case 'Amount ↑':
        return 'Сумма ↑';
      case 'Amount ↓':
        return 'Сумма ↓';
      case 'Newest':
      default:
        return 'Новые';
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    final query = _searchController.text.trim().toLowerCase();

    final list =
        _tasks.where((task) {
          final title = (task['title'] as String? ?? '').toLowerCase();
          final status = (task['status'] as String? ?? '').toLowerCase();
          final payment =
              (task['payment_status'] as String? ?? '').toLowerCase();
          final complexity =
              (task['complexity_final']?.toString() ?? '').toLowerCase();

          return title.contains(query) ||
              status.contains(query) ||
              payment.contains(query) ||
              complexity.contains(query);
        }).toList();

    switch (_sortOrder) {
      case 'Oldest':
        return list.reversed.toList();

      case 'By deadline':
        list.sort((a, b) {
          final da = _parseDate(a['deadline'] as String?);
          final db = _parseDate(b['deadline'] as String?);

          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;

          return da.compareTo(db);
        });
        return list;

      case 'Amount ↑':
        list.sort((a, b) => _amountOf(a).compareTo(_amountOf(b)));
        return list;

      case 'Amount ↓':
        list.sort((a, b) => _amountOf(b).compareTo(_amountOf(a)));
        return list;

      case 'Newest':
      default:
        return list;
    }
  }

  Future<void> _selectSort() async {
    await showAppBottomSheet(
      context: context,
      title: 'Сортировка',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          ...const [
            'Newest',
            'Oldest',
            'By deadline',
            'Amount ↑',
            'Amount ↓',
          ].map(
            (value) => AppBottomSheetOption(
              title: _sortLabel(value),
              selected: _sortOrder == value,
              onTap: () {
                Navigator.pop(context);
                setState(() => _sortOrder = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  int get _pendingPaymentsCount {
    return _tasks.where((task) {
      final status =
          (task['payment_status'] as String? ?? '').trim().toLowerCase();

      return status == 'pending';
    }).length;
  }

  int get _paidTasksCount {
    return _tasks.where((task) {
      final status =
          (task['payment_status'] as String? ?? '').trim().toLowerCase();

      return status == 'paid' || status == 'approved';
    }).length;
  }

  void _openTask(String id) {
    context.push('/tasks/details/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadAll)
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Мои задачи',
                        subtitle: 'Текущие работы, сложность и оплата',
                        onMenu: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        onRefresh: _loadAll,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadAll,
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _TasksOverviewCard(
                                    name: _name ?? 'Исполнитель',
                                    avatarUrl: _photo,
                                    totalCount: _tasks.length,
                                    pendingPaymentsCount: _pendingPaymentsCount,
                                    paidTasksCount: _paidTasksCount,
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: AppSearchField(
                                    controller: _searchController,
                                    hint: 'Поиск по задачам',
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        AppFilterChip(
                                          icon: CupertinoIcons.sort_down,
                                          label: _sortLabel(_sortOrder),
                                          active: true,
                                          onTap: _selectSort,
                                        ),
                                        if (hasSearch) ...[
                                          const SizedBox(width: 8),
                                          AppFilterChip(
                                            icon: CupertinoIcons.clear,
                                            label: 'Сбросить',
                                            danger: true,
                                            onTap: () {
                                              setState(() {
                                                _searchController.clear();
                                              });
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  16,
                                  12,
                                  8,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: AppSectionHeader(
                                    title: 'Задачи',
                                    count: filteredTasks.length,
                                  ),
                                ),
                              ),
                              if (filteredTasks.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon:
                                        hasSearch
                                            ? CupertinoIcons.search
                                            : CupertinoIcons.checkmark_seal,
                                    title:
                                        hasSearch
                                            ? 'Ничего не найдено'
                                            : 'Задач пока нет',
                                    subtitle:
                                        hasSearch
                                            ? 'Измени поисковый запрос.'
                                            : 'Когда заказчик примет твою заявку, задача появится здесь.',
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    20,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index.isOdd) {
                                          return const SizedBox(height: 8);
                                        }

                                        final taskIndex = index ~/ 2;
                                        final task = filteredTasks[taskIndex];
                                        final id = task['id'] as String;

                                        return _TaskCard(
                                          title:
                                              task['title'] as String? ?? '—',
                                          status:
                                              task['status'] as String? ?? '—',
                                          paymentStatus:
                                              task['payment_status']
                                                  as String? ??
                                              '—',
                                          deadline: _formatDeadline(
                                            task['deadline'] as String?,
                                          ),
                                          amount: _formatMoney(_amountOf(task)),
                                          estimatedTime:
                                              task['estimated_time']
                                                  ?.toString() ??
                                              '0',
                                          timeSpent:
                                              task['time_spent']?.toString() ??
                                              '0',
                                          complexityFinal:
                                              task['complexity_final'] as int?,
                                          complexitySource:
                                              task['complexity_source']
                                                  as String?,
                                          onTap: () => _openTask(id),
                                        );
                                      },
                                      childCount: filteredTasks.length * 2 - 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _TasksOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int totalCount;
  final int pendingPaymentsCount;
  final int paidTasksCount;

  const _TasksOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.totalCount,
    required this.pendingPaymentsCount,
    required this.paidTasksCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppProfileAvatar(avatarUrl: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.cardTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text('Исполнитель', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'tasks',
                color: AppColors.accent,
                icon: CupertinoIcons.checkmark_seal,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Здесь собраны задачи, назначенные после принятия заявки заказчиком.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Всего',
                  value: totalCount.toString(),
                  icon: Icons.task_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Ожидают',
                  value: pendingPaymentsCount.toString(),
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Оплачено',
                  value: paidTasksCount.toString(),
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.cardTitle),
          Text(title, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String status;
  final String paymentStatus;
  final String deadline;
  final String amount;
  final String estimatedTime;
  final String timeSpent;
  final int? complexityFinal;
  final String? complexitySource;
  final VoidCallback onTap;

  const _TaskCard({
    required this.title,
    required this.status,
    required this.paymentStatus,
    required this.deadline,
    required this.amount,
    required this.estimatedTime,
    required this.timeSpent,
    required this.complexityFinal,
    required this.complexitySource,
    required this.onTap,
  });

  AppStatusPill _taskStatusPill() {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'done' || normalized == 'completed') {
      return AppStatusPill.success(status);
    }

    if (normalized == 'in_progress' || normalized == 'progress') {
      return AppStatusPill.pending(status);
    }

    return AppStatusPill(
      text: status,
      color: AppColors.textMuted,
      icon: CupertinoIcons.circle,
    );
  }

  AppStatusPill _paymentStatusPill() {
    final normalized = paymentStatus.trim().toLowerCase();

    if (normalized == 'paid' || normalized == 'approved') {
      return AppStatusPill.success(paymentStatus);
    }

    if (normalized == 'pending') {
      return AppStatusPill.pending(paymentStatus);
    }

    if (normalized == 'rejected') {
      return AppStatusPill.error(paymentStatus);
    }

    return AppStatusPill(
      text: paymentStatus,
      color: AppColors.textMuted,
      icon: CupertinoIcons.creditcard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final complexity = complexityFinal?.clamp(1, 5).toInt();

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim().isEmpty ? 'Без описания' : title,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _taskStatusPill(),
              _paymentStatusPill(),
              if (complexity != null)
                AppTag(
                  icon: Icons.bar_chart_rounded,
                  label:
                      'Сложность $complexity/5 · ${OrderComplexityService.sourceLabel(complexitySource)}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppMetaItem(
                  icon: Icons.currency_ruble_rounded,
                  label: 'Сумма',
                  value: amount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetaItem(
                  icon: CupertinoIcons.calendar_today,
                  label: 'Дедлайн',
                  value: deadline,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.arrow_right,
                  size: 17,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'План: ${estimatedTime}ч · Потрачено: ${timeSpent}ч',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
