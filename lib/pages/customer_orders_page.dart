// lib/pages/customer_orders_page.dart

import 'dart:async';

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
  bool _silentRefreshing = false;
  bool _showArchive = false;
  String? _error;

  String _sort = 'Newest';
  String? _filterFramework;
  String? _filterLanguage;
  String? _filterDeadline;

  String? _role;
  String? _name;
  String? _photo;

  Timer? _refreshDebounce;

  List<Map<String, dynamic>> _orders = [];
  List<String> _frameworks = [];
  List<String> _languages = [];

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
    pb.collection('payment_requests').unsubscribe('*');
    pb.collection('frameworks').unsubscribe('*');
    pb.collection('languages').unsubscribe('*');
    pb.collection('task_statuses').unsubscribe('*');
    pb.collection('payment_statuses').unsubscribe('*');

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
    await pb.collection('payment_requests').subscribe('*', onAnyChange);
    await pb.collection('frameworks').subscribe('*', onAnyChange);
    await pb.collection('languages').subscribe('*', onAnyChange);
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

  Future<List<dynamic>> _getAllRecords(String collection) async {
    final result = await PocketBaseService.instance.pb
        .collection(collection)
        .getList(page: 1, perPage: 200);

    return result.items;
  }

  DateTime? _parseDateTime(String? raw) {
    return DateTime.tryParse(raw ?? '');
  }

  dynamic _latestTaskForOrder(List<dynamic> tasks, String orderId) {
    final related =
        tasks.where((task) {
          final taskOrderId = _relationId(task.data['order_id']);
          return taskOrderId == orderId;
        }).toList();

    if (related.isEmpty) return null;

    related.sort((a, b) {
      final da = _parseDateTime(a.get<String>('created') ?? '');
      final db = _parseDateTime(b.get<String>('created') ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    return related.first;
  }

  String? _nameById(List<dynamic> records, String? id) {
    if (id == null || id.isEmpty) return null;

    for (final record in records) {
      if (record.id == id) {
        return record.data['name'] as String?;
      }
    }

    return null;
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

      final photo = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final ordersResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final tasks = await _getAllRecords('tasks');
      final taskStatuses = await _getAllRecords('task_statuses');
      final paymentStatuses = await _getAllRecords('payment_statuses');

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
        final executor = await _getRecordData('users', executorId);

        final latestTask = _latestTaskForOrder(tasks, record.id);
        final taskId = latestTask?.id as String?;
        final taskStatusId = _relationId(latestTask?.data['status_id']);
        final paymentStatusId = _relationId(
          latestTask?.data['payment_status_id'],
        );

        final taskStatusName = _nameById(taskStatuses, taskStatusId);
        final paymentStatusName = _nameById(paymentStatuses, paymentStatusId);

        final frameworkName = framework?['name'] as String? ?? '—';
        final languageName = language?['name'] as String? ?? '—';
        final executorName =
            executor?['name'] as String? ?? executor?['email'] as String?;

        if (frameworkName != '—') frameworkSet.add(frameworkName);
        if (languageName != '—') languageSet.add(languageName);

        result.add({
          'id': record.id,
          'created': record.get<String>('created') ?? '',
          'updated': record.get<String>('updated') ?? '',
          'task_description': record.data['task_description'] as String? ?? '',
          'deadline': record.data['deadline'] as String?,
          'executor_id': executorId,
          'executor_name': executorName,
          'price': record.data['price'],
          'framework_name': frameworkName,
          'language_name': languageName,
          'task_id': taskId,
          'task_status': taskStatusName,
          'payment_status': paymentStatusName,
        });
      }

      result.sort((a, b) {
        final da = _parseDateTime(a['created'] as String?);
        final db = _parseDateTime(b['created'] as String?);

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
        _error = 'Не удалось загрузить заказы: $e';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Удалить заказ?'),
            content: const Text(
              'Заказ и связанные заявки, задачи, оплаты, сообщения, вложения и отзывы будут удалены.',
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

    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      await _deleteRelatedData(orderId);
      await PocketBaseService.instance.pb.collection('orders').delete(orderId);
      await _loadAll(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteRelatedData(String orderId) async {
    final pb = PocketBaseService.instance.pb;

    final tasks = await _getAllRecords('tasks');
    for (final task in tasks) {
      final taskOrderId = _relationId(task.data['order_id']);
      if (taskOrderId != orderId) continue;

      final taskId = task.id;

      final paymentRequests = await _getAllRecords('payment_requests');
      for (final payment in paymentRequests) {
        final paymentTaskId = _relationId(payment.data['task_id']);
        if (paymentTaskId == taskId) {
          await pb.collection('payment_requests').delete(payment.id);
        }
      }

      final messages = await _getAllRecords('tasks_messages');
      for (final message in messages) {
        final messageTaskId = _relationId(message.data['task_id']);
        if (messageTaskId != taskId) continue;

        final attachments = await _getAllRecords('task_message_attachments');
        for (final attachment in attachments) {
          final attachmentMessageId = _relationId(
            attachment.data['task_message_id'],
          );
          if (attachmentMessageId == message.id) {
            await pb
                .collection('task_message_attachments')
                .delete(attachment.id);
          }
        }

        await pb.collection('tasks_messages').delete(message.id);
      }

      await pb.collection('tasks').delete(taskId);
    }

    final applications = await _getAllRecords('applications');
    for (final application in applications) {
      final appOrderId = _relationId(application.data['order_id']);
      if (appOrderId == orderId) {
        await pb.collection('applications').delete(application.id);
      }
    }

    final orderAttachments = await _getAllRecords('order_attachments');
    for (final attachment in orderAttachments) {
      final attachmentOrderId = _relationId(attachment.data['order_id']);
      if (attachmentOrderId == orderId) {
        await pb.collection('order_attachments').delete(attachment.id);
      }
    }

    final feedbacks = await _getAllRecords('feedbacks');
    for (final feedback in feedbacks) {
      final feedbackOrderId = _relationId(feedback.data['order_id']);
      if (feedbackOrderId == orderId) {
        await pb.collection('feedbacks').delete(feedback.id);
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

  bool _hasExecutor(Map<String, dynamic> order) {
    return order['executor_id'] != null;
  }

  String _normalized(dynamic value) {
    return (value as String? ?? '').trim().toLowerCase();
  }

  bool _isArchivedOrder(Map<String, dynamic> order) {
    final taskStatus = _normalized(order['task_status']);
    final paymentStatus = _normalized(order['payment_status']);

    return taskStatus == 'done' ||
        taskStatus == 'completed' ||
        taskStatus == 'complete' ||
        taskStatus == 'выполнено' ||
        taskStatus == 'завершено' ||
        paymentStatus == 'paid' ||
        paymentStatus == 'approved' ||
        paymentStatus == 'оплачено';
  }

  int get _activeCount {
    return _orders.where((order) => !_isArchivedOrder(order)).length;
  }

  int get _archivedCount {
    return _orders.where(_isArchivedOrder).length;
  }

  int get _assignedCount {
    return _orders
        .where((order) => !_isArchivedOrder(order) && _hasExecutor(order))
        .length;
  }

  int get _waitingCount {
    return _orders
        .where((order) => !_isArchivedOrder(order) && !_hasExecutor(order))
        .length;
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
    final executorName = order['executor_name'] as String? ?? '';
    final taskStatus = order['task_status'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';
    final status =
        _hasExecutor(order)
            ? 'исполнитель назначен назначен $executorName'
            : 'ожидает исполнителя без исполнителя';

    final haystack =
        [
          description,
          framework,
          language,
          deadline,
          price,
          executorName,
          taskStatus,
          paymentStatus,
          status,
        ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  List<Map<String, dynamic>> get _baseVisibleOrders {
    return _orders.where((order) {
      final archived = _isArchivedOrder(order);
      return _showArchive ? archived : !archived;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();

    final list =
        _baseVisibleOrders.where((order) {
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
        list.sort((a, b) {
          final da = _parseDateTime(a['created'] as String?);
          final db = _parseDateTime(b['created'] as String?);

          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;

          return da.compareTo(db);
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
          final da = _parseDateTime(a['created'] as String?);
          final db = _parseDateTime(b['created'] as String?);

          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;

          return db.compareTo(da);
        });
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

  void _openExecutors() {
    context.push('/customer/executors');
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

    final emptyTitle =
        hasActiveFilters
            ? 'Ничего не найдено'
            : _showArchive
            ? 'Архив пуст'
            : 'Заказов пока нет';

    final emptySubtitle =
        hasActiveFilters
            ? 'Измени фильтры или поисковый запрос.'
            : _showArchive
            ? 'Оплаченные и выполненные заказы будут отображаться здесь.'
            : 'Создай первый заказ, чтобы исполнитель смог подать заявку.';

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
        label: const Text('Новый заказ'),
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
                        title: _showArchive ? 'Архив заказов' : 'Мои заказы',
                        subtitle:
                            _showArchive
                                ? 'Оплаченные и выполненные задачи'
                                : 'Созданные заказы и назначенные исполнители',
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
                                    name: _name ?? 'Заказчик',
                                    avatarUrl: _photo,
                                    activeCount: _activeCount,
                                    archivedCount: _archivedCount,
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
                                    hint: 'Поиск по описанию, языку, статусу',
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
                                    showArchive: _showArchive,
                                    activeCount: _activeCount,
                                    archivedCount: _archivedCount,
                                    hasActiveFilters: hasActiveFilters,
                                    onActive: () {
                                      setState(() => _showArchive = false);
                                    },
                                    onArchive: () {
                                      setState(() => _showArchive = true);
                                    },
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
                                    title:
                                        _showArchive
                                            ? 'Архивные заказы'
                                            : 'Текущие заказы',
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
                                            : _showArchive
                                            ? CupertinoIcons.archivebox
                                            : CupertinoIcons.doc_text,
                                    title: emptyTitle,
                                    subtitle: emptySubtitle,
                                    action:
                                        _showArchive
                                            ? null
                                            : ElevatedButton.icon(
                                              onPressed: _openCreateOrder,
                                              icon: const Icon(Icons.add),
                                              label: const Text(
                                                'Создать заказ',
                                              ),
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
                                        final assigned = _hasExecutor(order);
                                        final archived = _isArchivedOrder(
                                          order,
                                        );

                                        return _CustomerOrderCard(
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
                                          assigned: assigned,
                                          archived: archived,
                                          executorName:
                                              order['executor_name'] as String?,
                                          taskStatus:
                                              order['task_status'] as String?,
                                          paymentStatus:
                                              order['payment_status']
                                                  as String?,
                                          onTap: () => _openOrder(id),
                                          onDelete: () => _deleteOrder(id),
                                          onFindExecutor:
                                              !assigned && !archived
                                                  ? _openExecutors
                                                  : null,
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
  final int activeCount;
  final int archivedCount;
  final int assignedCount;
  final int waitingCount;

  const _CustomerOrdersOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.activeCount,
    required this.archivedCount,
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
                    Text('Заказчик', style: AppTextStyles.caption),
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
            'Текущие заказы отделены от архива, чтобы оплаченные и завершённые работы не мешали просмотру активных задач.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Текущие',
                  value: activeCount.toString(),
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Назначены',
                  value: assignedCount.toString(),
                  icon: Icons.person_add_alt_1_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Архив',
                  value: archivedCount.toString(),
                  icon: CupertinoIcons.archivebox,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatCard(
            title: 'Ожидают исполнителя',
            value: waitingCount.toString(),
            icon: Icons.schedule_rounded,
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
  final bool showArchive;
  final int activeCount;
  final int archivedCount;
  final bool hasActiveFilters;
  final VoidCallback onActive;
  final VoidCallback onArchive;
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
    required this.showArchive,
    required this.activeCount,
    required this.archivedCount,
    required this.hasActiveFilters,
    required this.onActive,
    required this.onArchive,
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
            icon: CupertinoIcons.briefcase,
            label: 'Текущие $activeCount',
            active: !showArchive,
            onTap: onActive,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            icon: CupertinoIcons.archivebox,
            label: 'Архив $archivedCount',
            active: showArchive,
            onTap: onArchive,
          ),
          const SizedBox(width: 8),
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

class _CustomerOrderCard extends StatelessWidget {
  final String title;
  final String framework;
  final String language;
  final String deadline;
  final String price;
  final bool assigned;
  final bool archived;
  final String? executorName;
  final String? taskStatus;
  final String? paymentStatus;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onFindExecutor;

  const _CustomerOrderCard({
    required this.title,
    required this.framework,
    required this.language,
    required this.deadline,
    required this.price,
    required this.assigned,
    required this.archived,
    required this.executorName,
    required this.taskStatus,
    required this.paymentStatus,
    required this.onTap,
    required this.onDelete,
    required this.onFindExecutor,
  });

  @override
  Widget build(BuildContext context) {
    final assignedLabel =
        executorName == null || executorName!.trim().isEmpty
            ? 'Исполнитель назначен'
            : 'Исполнитель: $executorName';

    final normalizedTaskStatus = (taskStatus ?? '').trim();
    final normalizedPaymentStatus = (paymentStatus ?? '').trim();

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
                  ? AppStatusPill.success(assignedLabel)
                  : const AppStatusPill(
                    text: 'Ожидает исполнителя',
                    color: AppColors.textMuted,
                    icon: CupertinoIcons.clock,
                  ),
              if (archived)
                const AppTag(
                  icon: CupertinoIcons.archivebox,
                  label: 'В архиве',
                ),
              if (normalizedTaskStatus.isNotEmpty)
                AppTag(
                  icon: CupertinoIcons.checkmark_circle,
                  label: 'Задача: $normalizedTaskStatus',
                ),
              if (normalizedPaymentStatus.isNotEmpty)
                AppTag(
                  icon: CupertinoIcons.creditcard,
                  label: 'Оплата: $normalizedPaymentStatus',
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
          if (onFindExecutor != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onFindExecutor,
                icon: const Icon(Icons.person_search_rounded),
                label: const Text('Найти исполнителя'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
