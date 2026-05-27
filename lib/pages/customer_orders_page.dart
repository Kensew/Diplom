// lib/pages/customer_orders_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({Key? key}) : super(key: key);

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;

  String _sort = 'Newest';
  String? _filterFramework;
  String? _filterLanguage;
  String? _filterDeadline;

  String? _role;
  String? _name;
  String? _photo;

  List<Map<String, dynamic>> _orders = [];
  List<String> _frameworks = [];
  List<String> _languages = [];

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

    return 'customer';
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
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw '?????????????';
      }

      final user = await pb.collection('users').getOne(userId);

      _role = _roleFromUser(user.data);
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';

      _photo = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final ordersResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];
      final frameworkSet = <String>{};
      final languageSet = <String>{};

      for (final record in ordersResult.items) {
        final customerId = _relationId(record.data['customer_id']);

        if (customerId != userId) continue;

        final frameworkId = _relationId(record.data['framework_id']);
        final languageId = _relationId(record.data['language_id']);
        final executorId = _relationId(record.data['executor_id']);

        final framework = await _getRecordData('frameworks', frameworkId);
        final language = await _getRecordData('languages', languageId);

        final frameworkName = framework?['name'] as String? ?? '?';
        final languageName = language?['name'] as String? ?? '?';

        if (frameworkName != '?') frameworkSet.add(frameworkName);
        if (languageName != '?') languageSet.add(languageName);

        result.add({
          'id': record.id,
          'created': record.get<String>('created') ?? '',
          'task_description': record.data['task_description'] as String? ?? '',
          'deadline': record.data['deadline'] as String?,
          'executor_id': executorId,
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

      _orders = result;
      _frameworks = frameworkSet.toList()..sort();
      _languages = languageSet.toList()..sort();
    } catch (e) {
      _error = '?? ??????? ????????? ??????: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('??????? ??????'),
            content: const Text('????? ????? ????? ?? ???? ??????.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('??????'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('???????'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      await PocketBaseService.instance.pb.collection('orders').delete(orderId);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('?????? ??? ????????: $e')));
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

  DateTime? _parseDate(String? raw) {
    return DateTime.tryParse(raw ?? '');
  }

  String _formatDate(String? raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '?';

    return _fmt.format(dt.toLocal());
  }

  num _priceOf(Map<String, dynamic> order) {
    return (order['price'] as num?) ?? 0;
  }

  String _formatMoney(num value) {
    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ?';
    }

    return '${value.toStringAsFixed(2)} ?';
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
        return '??????';
      case 'By deadline':
        return '?? ????????';
      case 'Price ^':
        return '???? ^';
      case 'Price v':
        return '???? v';
      case 'Newest':
      default:
        return '?????';
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();

    final list =
        _orders.where((order) {
          final description =
              (order['task_description'] as String? ?? '').toLowerCase();
          final framework = order['framework_name'] as String? ?? '';
          final language = order['language_name'] as String? ?? '';
          final deadline = _formatDate(order['deadline'] as String?);

          return description.contains(query) &&
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

      case 'Price ^':
        list.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        return list;

      case 'Price v':
        list.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        return list;

      case 'Newest':
      default:
        return list;
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
              title: '???',
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

  Future<void> _openCreateOrder() async {
    await context.push('/customer/create');
    await _loadAll();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOrder,
        icon: const Icon(Icons.add),
        label: const Text('????? ?????'),
      ),
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
                        title: '??? ??????',
                        subtitle: '????????? ?????? ? ??????????? ???????????',
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
                                  child: _CustomerOrdersOverviewCard(
                                    name: _name ?? '????????',
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
                                    hint: '????? ?? ???????',
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
                                  child: _CustomerOrdersFilterBar(
                                    sortLabel: _sortLabel(_sort),
                                    framework: _filterFramework,
                                    language: _filterLanguage,
                                    deadline: _filterDeadline,
                                    hasActiveFilters: hasActiveFilters,
                                    onSort: () {
                                      _selectFromList(
                                        title: '??????????',
                                        values: const [
                                          'Newest',
                                          'Oldest',
                                          'By deadline',
                                          'Price ^',
                                          'Price v',
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
                                        title: '?????????',
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
                                        title: '????',
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
                                    title: '??????',
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
                                            : CupertinoIcons.doc_text,
                                    title:
                                        hasActiveFilters
                                            ? '?????? ?? ???????'
                                            : '??????? ???? ???',
                                    subtitle:
                                        hasActiveFilters
                                            ? '?????? ??????? ??? ????????? ??????.'
                                            : '?????? ?????? ?????, ????? ??????????? ???? ?????? ??????.',
                                    action: ElevatedButton.icon(
                                      onPressed: _openCreateOrder,
                                      icon: const Icon(Icons.add),
                                      label: const Text('??????? ?????'),
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    96,
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

                                        return _CustomerOrderCard(
                                          title:
                                              order['task_description']
                                                  as String? ??
                                              '',
                                          framework:
                                              order['framework_name']
                                                  as String? ??
                                              '?',
                                          language:
                                              order['language_name']
                                                  as String? ??
                                              '?',
                                          deadline: _formatDate(
                                            order['deadline'] as String?,
                                          ),
                                          price: _formatMoney(_priceOf(order)),
                                          assigned: _hasExecutor(order),
                                          onTap: () => _openOrder(id),
                                          onDelete: () => _deleteOrder(id),
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

class _CustomerOrdersOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int totalCount;
  final int assignedCount;
  final int waitingCount;

  const _CustomerOrdersOverviewCard({
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
                    Text('????????', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'orders',
                color: AppColors.accent,
                icon: CupertinoIcons.doc_text,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '????? ??????? ???? ??????, ?????? ???????????? ? ???????? ? ???????.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '?????',
                  value: totalCount.toString(),
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: '?????????',
                  value: assignedCount.toString(),
                  icon: Icons.person_add_alt_1_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: '???????',
                  value: waitingCount.toString(),
                  icon: Icons.schedule_rounded,
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

class _CustomerOrdersFilterBar extends StatelessWidget {
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

  const _CustomerOrdersFilterBar({
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
            label: framework ?? '?????????',
            active: framework != null,
            onTap: onFramework,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            icon: Icons.code_rounded,
            label: language ?? '????',
            active: language != null,
            onTap: onLanguage,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            icon: CupertinoIcons.calendar,
            label: deadline ?? '???????',
            active: deadline != null,
            onTap: onDeadline,
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            AppFilterChip(
              icon: CupertinoIcons.clear,
              label: '????????',
              danger: true,
              onTap: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerOrderCard extends StatelessWidget {
  final String title;
  final String framework;
  final String language;
  final String deadline;
  final String price;
  final bool assigned;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomerOrderCard({
    required this.title,
    required this.framework,
    required this.language,
    required this.deadline,
    required this.price,
    required this.assigned,
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
                  title.trim().isEmpty ? '??? ????????' : title,
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
                  ? AppStatusPill.success('??????????? ????????')
                  : const AppStatusPill(
                    text: '??????? ???????????',
                    color: AppColors.textMuted,
                    icon: CupertinoIcons.clock,
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
                  label: '??????',
                  value: price,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetaItem(
                  icon: CupertinoIcons.calendar_today,
                  label: '???????',
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
