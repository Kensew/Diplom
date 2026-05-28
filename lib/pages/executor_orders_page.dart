// lib/pages/executor_orders_page.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class ExecutorOrdersPage extends StatefulWidget {
  const ExecutorOrdersPage({Key? key}) : super(key: key);

  @override
  State<ExecutorOrdersPage> createState() => _ExecutorOrdersPageState();
}

class _ExecutorOrdersPageState extends State<ExecutorOrdersPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  String _sort = 'Newest';
  String? _filterFramework;
  String? _filterLanguage;
  String? _filterDeadline;

  bool _loading = true;
  bool _silentRefreshing = false;
  String? _error;

  Timer? _refreshDebounce;

  List<Map<String, dynamic>> _orders = [];
  List<String> _frameworks = [];
  List<String> _languages = [];

  String? _role;
  String? _name;
  String? _photo;

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
    pb.collection('orders').unsubscribe('*');
    pb.collection('applications').unsubscribe('*');
    pb.collection('tasks').unsubscribe('*');
    pb.collection('frameworks').unsubscribe('*');
    pb.collection('languages').unsubscribe('*');

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _subscribeRealtime() async {
    final pb = PocketBaseService.instance.pb;

    Future<void> onAnyChange(dynamic _) async {
      _scheduleSilentRefresh();
    }

    await pb.collection('orders').subscribe('*', onAnyChange);
    await pb.collection('applications').subscribe('*', onAnyChange);
    await pb.collection('tasks').subscribe('*', onAnyChange);
    await pb.collection('frameworks').subscribe('*', onAnyChange);
    await pb.collection('languages').subscribe('*', onAnyChange);
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

  Future<Set<String>> _appliedOrderIdsForExecutor(String executorId) async {
    final result = await PocketBaseService.instance.pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    final ids = <String>{};

    for (final app in result.items) {
      final appExecutorId = _relationId(app.data['executor_id']);
      final orderId = _relationId(app.data['order_id']);

      if (appExecutorId == executorId && orderId != null) {
        ids.add(orderId);
      }
    }

    return ids;
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

      final alreadyAppliedOrderIds = await _appliedOrderIdsForExecutor(userId);

      final orderResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];
      final frameworkSet = <String>{};
      final languageSet = <String>{};

      for (final record in orderResult.items) {
        final orderId = record.id;
        final executorId = _relationId(record.data['executor_id']);
        final customerId = _relationId(record.data['customer_id']);

        if (executorId != null) continue;
        if (customerId == userId) continue;
        if (alreadyAppliedOrderIds.contains(orderId)) continue;

        final frameworkId = _relationId(record.data['framework_id']);
        final languageId = _relationId(record.data['language_id']);

        final framework = await _getRecordData('frameworks', frameworkId);
        final language = await _getRecordData('languages', languageId);

        final frameworkName = framework?['name'] as String? ?? '—';
        final languageName = language?['name'] as String? ?? '—';

        if (frameworkName != '—') frameworkSet.add(frameworkName);
        if (languageName != '—') languageSet.add(languageName);

        result.add({
          'id': orderId,
          'created': record.get<String>('created') ?? '',
          'task_description': record.data['task_description'] as String? ?? '',
          'deadline': record.data['deadline'] as String?,
          'price': record.data['price'],
          'framework_name': frameworkName,
          'language_name': languageName,
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
        _orders = result;
        _frameworks = frameworkSet.toList()..sort();
        _languages = languageSet.toList()..sort();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить данные: $e';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickFilterDeadline() async {
    final now = DateTime.now();
    DateTime initial = now;

    if (_filterDeadline != null) {
      try {
        initial = _fmt.parse(_filterDeadline!);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _filterDeadline = _fmt.format(picked);
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterFramework = null;
      _filterLanguage = null;
      _filterDeadline = null;
      _searchController.clear();
    });
  }

  DateTime? _parseDate(String? raw) {
    return DateTime.tryParse(raw ?? '');
  }

  String _formatDate(String? raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '—';

    return _fmt.format(dt.toLocal());
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

  bool _matchesSearch(Map<String, dynamic> order, String query) {
    if (query.isEmpty) return true;

    final description = order['task_description'] as String? ?? '';
    final framework = order['framework_name'] as String? ?? '';
    final language = order['language_name'] as String? ?? '';
    final deadline = _formatDate(order['deadline'] as String?);
    final price = _formatMoney(_priceOf(order));

    final haystack =
        [
          description,
          framework,
          language,
          deadline,
          price,
          'свободный заказ без исполнителя',
        ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();

    final list =
        _orders.where((order) {
          final framework = order['framework_name'] as String? ?? '';
          final language = order['language_name'] as String? ?? '';
          final deadline = _formatDate(order['deadline'] as String?);

          return _matchesSearch(order, query) &&
              (_filterFramework == null || framework == _filterFramework) &&
              (_filterLanguage == null || language == _filterLanguage) &&
              (_filterDeadline == null || deadline == _filterDeadline);
        }).toList();

    switch (_sort) {
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

      case 'Price ↑':
        list.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        return list;

      case 'Price ↓':
        list.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        return list;

      case 'Newest':
      default:
        return list;
    }
  }

  Future<void> _selectFromList({
    required String title,
    required List<String> values,
    required String? currentValue,
    required ValueChanged<String?> onSelected,
    bool allowNull = true,
    bool isSort = false,
  }) async {
    await showAppBottomSheet(
      context: context,
      title: title,
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          if (allowNull)
            AppBottomSheetOption(
              title: 'Все',
              selected: currentValue == null,
              onTap: () {
                Navigator.pop(context);
                onSelected(null);
              },
            ),
          ...values.map(
            (value) => AppBottomSheetOption(
              title: isSort ? _sortLabel(value) : value,
              selected: currentValue == value,
              onTap: () {
                Navigator.pop(context);
                onSelected(value);
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
    final filteredOrders = _filteredOrders;
    final hasActiveFilters =
        _filterFramework != null ||
        _filterLanguage != null ||
        _filterDeadline != null ||
        _searchController.text.trim().isNotEmpty;

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
                        title: 'Доступные заказы',
                        subtitle: 'Лента задач для исполнителя',
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
                                  child: _ExecutorOverviewCard(
                                    name: _name ?? 'Исполнитель',
                                    avatarUrl: _photo,
                                    totalCount: _orders.length,
                                    visibleCount: filteredOrders.length,
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
                                    hint: 'Поиск по описанию, языку, цене',
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
                                  child: _ExecutorFilterBar(
                                    sortLabel: _sortLabel(_sort),
                                    framework: _filterFramework,
                                    language: _filterLanguage,
                                    deadline: _filterDeadline,
                                    hasActiveFilters: hasActiveFilters,
                                    onSort: () {
                                      _selectFromList(
                                        title: 'Сортировка',
                                        values: const [
                                          'Newest',
                                          'Oldest',
                                          'By deadline',
                                          'Price ↑',
                                          'Price ↓',
                                        ],
                                        currentValue: _sort,
                                        allowNull: false,
                                        isSort: true,
                                        onSelected: (value) {
                                          if (value != null) {
                                            setState(() => _sort = value);
                                          }
                                        },
                                      );
                                    },
                                    onFramework: () {
                                      _selectFromList(
                                        title: 'Фреймворк',
                                        values: _frameworks,
                                        currentValue: _filterFramework,
                                        onSelected: (value) {
                                          setState(() {
                                            _filterFramework = value;
                                          });
                                        },
                                      );
                                    },
                                    onLanguage: () {
                                      _selectFromList(
                                        title: 'Язык',
                                        values: _languages,
                                        currentValue: _filterLanguage,
                                        onSelected: (value) {
                                          setState(() {
                                            _filterLanguage = value;
                                          });
                                        },
                                      );
                                    },
                                    onDeadline: _pickFilterDeadline,
                                    onClear: _clearFilters,
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
                                    count: filteredOrders.length,
                                  ),
                                ),
                              ),
                              if (filteredOrders.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon:
                                        hasActiveFilters
                                            ? CupertinoIcons.search
                                            : CupertinoIcons.briefcase,
                                    title:
                                        hasActiveFilters
                                            ? 'Ничего не найдено'
                                            : 'Нет свободных заказов',
                                    subtitle:
                                        hasActiveFilters
                                            ? 'Измени фильтры или поисковый запрос.'
                                            : 'Свободные заказы без твоей заявки будут показаны здесь.',
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

                                        final orderIndex = index ~/ 2;
                                        final order =
                                            filteredOrders[orderIndex];
                                        final id = order['id'] as String;

                                        return _ExecutorOrderCard(
                                          title:
                                              order['task_description']
                                                  as String? ??
                                              '',
                                          framework:
                                              order['framework_name']
                                                  as String? ??
                                              '—',
                                          language:
                                              order['language_name']
                                                  as String? ??
                                              '—',
                                          deadline: _formatDate(
                                            order['deadline'] as String?,
                                          ),
                                          price: _formatMoney(_priceOf(order)),
                                          onTap: () => _openOrder(id),
                                        );
                                      },
                                      childCount: filteredOrders.length * 2 - 1,
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

class _ExecutorOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int totalCount;
  final int visibleCount;

  const _ExecutorOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.totalCount,
    required this.visibleCount,
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
                    Text('Панель исполнителя', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'online',
                color: AppColors.accent,
                icon: CupertinoIcons.circle_fill,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Выбирай свободные заказы и откликайся на подходящие задачи.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Свободно',
                  value: totalCount.toString(),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Показано',
                  value: visibleCount.toString(),
                  icon: Icons.filter_list_rounded,
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
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.cardTitle),
                Text(title, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutorFilterBar extends StatelessWidget {
  final String sortLabel;
  final String? framework;
  final String? language;
  final String? deadline;
  final bool hasActiveFilters;
  final VoidCallback onSort;
  final VoidCallback onFramework;
  final VoidCallback onLanguage;
  final VoidCallback onDeadline;
  final VoidCallback onClear;

  const _ExecutorFilterBar({
    required this.sortLabel,
    required this.framework,
    required this.language,
    required this.deadline,
    required this.hasActiveFilters,
    required this.onSort,
    required this.onFramework,
    required this.onLanguage,
    required this.onDeadline,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          AppFilterChip(
            icon: CupertinoIcons.sort_down,
            label: sortLabel,
            active: true,
            onTap: onSort,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            icon: Icons.view_in_ar_outlined,
            label: framework ?? 'Фреймворк',
            active: framework != null,
            onTap: onFramework,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            icon: Icons.code_rounded,
            label: language ?? 'Язык',
            active: language != null,
            onTap: onLanguage,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            icon: CupertinoIcons.calendar,
            label: deadline ?? 'Дедлайн',
            active: deadline != null,
            onTap: onDeadline,
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            AppFilterChip(
              icon: CupertinoIcons.clear,
              label: 'Сбросить',
              danger: true,
              onTap: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExecutorOrderCard extends StatelessWidget {
  final String title;
  final String framework;
  final String language;
  final String deadline;
  final String price;
  final VoidCallback onTap;

  const _ExecutorOrderCard({
    required this.title,
    required this.framework,
    required this.language,
    required this.deadline,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              AppTag(icon: Icons.view_in_ar_outlined, label: framework),
              AppTag(icon: Icons.code_rounded, label: language),
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
                  label: 'Бюджет',
                  value: price,
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
        ],
      ),
    );
  }
}
