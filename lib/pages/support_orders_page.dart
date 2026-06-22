// lib/pages/support_orders_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/support_moderation_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/utils/pocketbase_date.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class SupportOrdersPage extends StatefulWidget {
  const SupportOrdersPage({Key? key}) : super(key: key);

  @override
  State<SupportOrdersPage> createState() => _SupportOrdersPageState();
}

class _SupportOrdersPageState extends State<SupportOrdersPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  String _sort = 'Newest';
  bool _loading = true;
  String? _error;

  String? _role;
  String? _name;
  String? _photo;

  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
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

  String? _firstFileName(dynamic value) {
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

  String? _fileUrl({
    required String collectionName,
    required String recordId,
    required dynamic fileValue,
  }) {
    final fileName = _firstFileName(fileValue);
    if (fileName == null) return null;

    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }

    final encodedName = Uri.encodeComponent(fileName);

    return '${PocketBaseService.baseUrl}/api/files/$collectionName/$recordId/$encodedName';
  }

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' || normalized == 'dev1@test.local') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' || normalized == 'dev3@test.local') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' || normalized == 'dev2@test.local') {
      return 'executor';
    }

    return 'support';
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

      return {
        'id': record.id,
        'created': record.get<String>('created') ?? '',
        ...record.data,
      };
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
      await _loadOrders();
    } catch (e) {
      _error = 'Ошибка загрузки заказов: $e';
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
        user.data['name'] as String? ??
        user.data['email'] as String? ??
        'Support';

    _photo = _fileUrl(
      collectionName: 'users',
      recordId: user.id,
      fileValue: user.data['photo'],
    );
  }

  Future<void> _loadOrders() async {
    final pb = PocketBaseService.instance.pb;

    final records = await pb
        .collection('orders')
        .getList(page: 1, perPage: 200, sort: '-id');

    final tasks = await pb.collection('tasks').getFullList(sort: '-id');
    final taskStatuses = await pb.collection('task_statuses').getFullList();

    final statusById = <String, String>{};
    for (final status in taskStatuses) {
      statusById[status.id] = status.data['name'] as String? ?? '';
    }

    final taskByOrderId = <String, dynamic>{};
    for (final task in tasks) {
      final orderId = _relationId(task.data['order_id']);
      if (orderId == null || taskByOrderId.containsKey(orderId)) continue;
      taskByOrderId[orderId] = task;
    }

    final result = <Map<String, dynamic>>[];

    for (final record in records.items) {
      final frameworkId = _relationId(record.data['framework_id']);
      final languageId = _relationId(record.data['language_id']);
      final customerId = _relationId(record.data['customer_id']);
      final executorId = _relationId(record.data['executor_id']);

      final framework = await _getRecordData('frameworks', frameworkId);
      final language = await _getRecordData('languages', languageId);
      final customer = await _getRecordData('users', customerId);
      final executor = await _getRecordData('users', executorId);

      final task = taskByOrderId[record.id];
      final taskStatusId = task == null ? null : _relationId(task.data['status_id']);
      final taskStatusName =
          taskStatusId == null ? null : statusById[taskStatusId];

      result.add({
        'id': record.id,
        'created': record.created,
        'task_description': record.data['task_description'] as String? ?? '',
        'deadline': record.data['deadline'] as String?,
        'price': record.data['price'],
        'framework_name': framework?['name'] as String? ?? 'Не указан',
        'language_name': language?['name'] as String? ?? 'Не указан',
        'customer_id': customerId,
        'customer_name':
            customer?['name'] as String? ??
            customer?['email'] as String? ??
            'Заказчик',
        'executor_id': executorId,
        'executor_name':
            executor?['name'] as String? ?? executor?['email'] as String?,
        'task_status': taskStatusName,
        'has_task': task != null,
      });
    }

    result.sort(
      (a, b) => PocketBaseDate.compareDescWithId(
        createdA: a['created'] as String?,
        createdB: b['created'] as String?,
        idA: a['id'] as String?,
        idB: b['id'] as String?,
      ),
    );

    _orders = result;
  }

  Future<void> _delete(Map<String, dynamic> order) async {
    final id = order['id'] as String;
    final assigned = _hasExecutor(order);
    final inProgress =
        assigned &&
        !{'done', 'cancelled'}.contains(
          (order['task_status'] as String? ?? '').toLowerCase(),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Удалить заказ?'),
            content: Text(
              inProgress
                  ? 'Заказ уже в работе. Будут удалены связанные задачи, отклики, переписка, оплаты и отзывы. Это действие нельзя отменить.'
                  : 'Заказ и все связанные данные будут удалены из базы.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      await SupportModerationService.instance.deleteOrderCascade(id);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  String _taskStatusLabel(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'new':
        return 'Новая';
      case 'in_progress':
        return 'В работе';
      case 'checking':
        return 'На проверке';
      case 'done':
        return 'Завершена';
      case 'cancelled':
        return 'Отменена';
      default:
        return raw == null || raw.isEmpty ? 'Не указан' : raw;
    }
  }

  DateTime? _parseDate(String? raw) => PocketBaseDate.parse(raw);

  String _formatDate(String? raw) {
    final dt = _parseDate(raw);
    if (dt == null) return 'Не указан';

    return _fmt.format(dt.toLocal());
  }

  String _formatCreated(String? raw) => _formatDate(raw);

  String _executorLabel(String? executor) {
    if (executor == null || executor.trim().isEmpty) {
      return 'Не назначен';
    }

    return executor;
  }

  num _priceOf(Map<String, dynamic> order) {
    return (order['price'] as num?) ?? 0;
  }

  String _formatMoney(num value) {
    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  bool _hasExecutor(Map<String, dynamic> order) {
    return order['executor_id'] != null;
  }

  int get _assignedCount {
    return _orders.where(_hasExecutor).length;
  }

  int get _waitingCount {
    return _orders.where((order) => !_hasExecutor(order)).length;
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'Oldest':
        return 'Старые';
      case 'By deadline':
        return 'По дедлайну';
      case 'Price ↑':
        return 'Цена ↑';
      case 'Price ↓':
        return 'Цена ↓';
      case 'Newest':
      default:
        return 'Новые';
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();

    final list =
        _orders.where((order) {
          final desc =
              (order['task_description'] as String? ?? '').toLowerCase();
          final framework =
              (order['framework_name'] as String? ?? '').toLowerCase();
          final language =
              (order['language_name'] as String? ?? '').toLowerCase();
          final customer =
              (order['customer_name'] as String? ?? '').toLowerCase();
          final executor =
              (order['executor_name'] as String? ?? '').toLowerCase();

          return desc.contains(query) ||
              framework.contains(query) ||
              language.contains(query) ||
              customer.contains(query) ||
              executor.contains(query);
        }).toList();

    switch (_sort) {
      case 'Oldest':
        list.sort((a, b) {
          return PocketBaseDate.compareAscWithId(
            createdA: a['created'] as String?,
            createdB: b['created'] as String?,
            idA: a['id'] as String?,
            idB: b['id'] as String?,
          );
        });
        return list;

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

      case 'Price ↑':
        list.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        return list;

      case 'Price ↓':
        list.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        return list;

      case 'Newest':
      default:
        list.sort((a, b) {
          return PocketBaseDate.compareDescWithId(
            createdA: a['created'] as String?,
            createdB: b['created'] as String?,
            idA: a['id'] as String?,
            idB: b['id'] as String?,
          );
        });
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
            'Price ↑',
            'Price ↓',
          ].map(
            (value) => AppBottomSheetOption(
              title: _sortLabel(value),
              selected: _sort == value,
              onTap: () {
                Navigator.pop(context);
                setState(() => _sort = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openOrder(String id) {
    context.push('/orders/details/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : const AppDrawer(role: 'support', displayName: 'Support'),
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
                        title: 'Все заказы',
                        subtitle: 'Контроль заказов платформы',
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
                                  child: _SupportOrdersOverviewCard(
                                    name: _name ?? 'Support',
                                    avatarUrl: _photo,
                                    totalCount: _orders.length,
                                    assignedCount: _assignedCount,
                                    waitingCount: _waitingCount,
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
                                    hint: 'Поиск по заказам',
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
                                          label: _sortLabel(_sort),
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
                                    title: 'Заказы',
                                    count: filtered.length,
                                  ),
                                ),
                              ),
                              if (filtered.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon:
                                        hasSearch
                                            ? CupertinoIcons.search
                                            : CupertinoIcons.tray,
                                    title:
                                        hasSearch
                                            ? 'Ничего не найдено'
                                            : 'Заказов нет',
                                    subtitle:
                                        hasSearch
                                            ? 'Измени поисковый запрос.'
                                            : 'Когда пользователи создадут заказы, они появятся здесь.',
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
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      if (index.isOdd) {
                                        return const SizedBox(height: 8);
                                      }

                                      final orderIndex = index ~/ 2;
                                      final order = filtered[orderIndex];
                                      final id = order['id'] as String;

                                      return _SupportOrderCard(
                                        title:
                                            order['task_description']
                                                as String? ??
                                            '',
                                        framework:
                                            order['framework_name']
                                                as String? ??
                                            'Не указан',
                                        language:
                                            order['language_name'] as String? ??
                                            'Не указан',
                                        customer:
                                            order['customer_name'] as String? ??
                                            'Заказчик',
                                        executor: _executorLabel(
                                          order['executor_name'] as String?,
                                        ),
                                        created: _formatCreated(
                                          order['created'] as String?,
                                        ),
                                        deadline: _formatDate(
                                          order['deadline'] as String?,
                                        ),
                                        price: _formatMoney(_priceOf(order)),
                                        assigned: _hasExecutor(order),
                                        taskStatus: _taskStatusLabel(
                                          order['task_status'] as String?,
                                        ),
                                        hasTask: order['has_task'] == true,
                                        onTap: () => _openOrder(id),
                                        onDelete: () => _delete(order),
                                      );
                                    }, childCount: filtered.length * 2 - 1),
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

class _SupportOrdersOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int totalCount;
  final int assignedCount;
  final int waitingCount;

  const _SupportOrdersOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.totalCount,
    required this.assignedCount,
    required this.waitingCount,
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
                    Text('Сотрудник поддержки', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'Заказы',
                color: AppColors.accent,
                icon: Icons.view_list_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Список всех заказов платформы. Можно удалить заказ, в том числе уже выполняющийся, если он нарушает правила.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Всего',
                  value: totalCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Назначены',
                  value: assignedCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Ожидают',
                  value: waitingCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
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
          Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SupportOrderCard extends StatelessWidget {
  final String title;
  final String framework;
  final String language;
  final String customer;
  final String executor;
  final String created;
  final String deadline;
  final String price;
  final bool assigned;
  final String taskStatus;
  final bool hasTask;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SupportOrderCard({
    required this.title,
    required this.framework,
    required this.language,
    required this.customer,
    required this.executor,
    required this.created,
    required this.deadline,
    required this.price,
    required this.assigned,
    required this.taskStatus,
    required this.hasTask,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.trim().isEmpty ? 'Без описания' : title,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 34,
                onPressed: onDelete,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppTag(icon: Icons.view_in_ar_outlined, label: framework),
              AppTag(icon: Icons.code_rounded, label: language),
              assigned
                  ? AppStatusPill.success('Исполнитель назначен')
                  : const AppStatusPill(
                    text: 'Ожидает исполнителя',
                    color: AppColors.textMuted,
                    icon: CupertinoIcons.clock,
                  ),
              if (hasTask)
                AppTag(
                  icon: Icons.task_alt_rounded,
                  label: taskStatus,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppMetaItem(
                  icon: CupertinoIcons.time,
                  label: 'Создан',
                  value: created,
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
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppMetaItem(
                  icon: Icons.currency_ruble_rounded,
                  label: 'Бюджет',
                  value: price,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppMetaItem(
                  icon: CupertinoIcons.person_crop_circle,
                  label: 'Заказчик',
                  value: customer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetaItem(
                  icon: Icons.engineering_outlined,
                  label: 'Исполнитель',
                  value: executor,
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
        ],
      ),
    );
  }
}
