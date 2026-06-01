// lib/pages/customer_executors_page.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/application_decision_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class CustomerExecutorsPage extends StatefulWidget {
  const CustomerExecutorsPage({Key? key}) : super(key: key);

  @override
  State<CustomerExecutorsPage> createState() => _CustomerExecutorsPageState();
}

class _CustomerExecutorsPageState extends State<CustomerExecutorsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  bool _silentRefreshing = false;
  String? _error;
  String? _busyExecutorId;

  String? _role;
  String? _name;
  String? _photo;

  Timer? _refreshDebounce;

  List<Map<String, dynamic>> _executors = [];
  List<Map<String, dynamic>> _openOrders = [];

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
    pb.collection('users').unsubscribe('*');
    pb.collection('orders').unsubscribe('*');
    pb.collection('tasks').unsubscribe('*');
    pb.collection('applications').unsubscribe('*');
    pb.collection('feedbacks').unsubscribe('*');
    pb.collection('payment_requests').unsubscribe('*');
    pb.collection('payment_statuses').unsubscribe('*');
    pb.collection('task_statuses').unsubscribe('*');

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _subscribeRealtime() async {
    final pb = PocketBaseService.instance.pb;

    Future<void> onAnyChange(dynamic _) async {
      _scheduleSilentRefresh();
    }

    await pb.collection('users').subscribe('*', onAnyChange);
    await pb.collection('orders').subscribe('*', onAnyChange);
    await pb.collection('tasks').subscribe('*', onAnyChange);
    await pb.collection('applications').subscribe('*', onAnyChange);
    await pb.collection('feedbacks').subscribe('*', onAnyChange);
    await pb.collection('payment_requests').subscribe('*', onAnyChange);
    await pb.collection('payment_statuses').subscribe('*', onAnyChange);
    await pb.collection('task_statuses').subscribe('*', onAnyChange);
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
    return ApplicationDecisionService.relationId(value);
  }

  String? _roleFromUser(Map<String, dynamic> data) {
    return ApplicationDecisionService.roleFromUser(data);
  }

  bool _isPaidStatus(String value) {
    final normalized = value.trim().toLowerCase();

    return normalized == 'paid' ||
        normalized == 'approved' ||
        normalized == 'done' ||
        normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'оплачено' ||
        normalized == 'выполнено' ||
        normalized == 'завершено';
  }

  bool _isPendingPaymentStatus(String value) {
    final normalized = value.trim().toLowerCase();

    return normalized == 'pending' ||
        normalized == 'ожидает' ||
        normalized == 'ожидает оплаты';
  }

  Future<List<dynamic>> _getAllRecords(String collection) async {
    final result = await PocketBaseService.instance.pb
        .collection(collection)
        .getList(page: 1, perPage: 200);

    return result.items;
  }

  String _statusNameById(List<dynamic> records, String? id) {
    if (id == null || id.isEmpty) return '';

    for (final record in records) {
      if (record.id == id) {
        return (record.data['name'] as String? ?? '').trim().toLowerCase();
      }
    }

    return '';
  }

  Map<String, dynamic>? _latestTaskForOrder(
    List<dynamic> tasks,
    String orderId,
  ) {
    final related =
        tasks.where((task) {
          final taskOrderId = _relationId(task.data['order_id']);
          return taskOrderId == orderId;
        }).toList();

    if (related.isEmpty) return null;

    related.sort((a, b) {
      final da = DateTime.tryParse(a.get<String>('created') ?? '');
      final db = DateTime.tryParse(b.get<String>('created') ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    final task = related.first;

    return {
      'id': task.id,
      'created': task.get<String>('created') ?? '',
      ...task.data,
    };
  }

  bool _isArchivedTask({
    required Map<String, dynamic>? task,
    required List<dynamic> taskStatuses,
    required List<dynamic> paymentStatuses,
    required Set<String> paidTaskIdsByRequest,
  }) {
    if (task == null) return false;

    final taskStatusId = _relationId(task['status_id']);
    final paymentStatusId = _relationId(task['payment_status_id']);

    final taskStatus = _statusNameById(taskStatuses, taskStatusId);
    final paymentStatus = _statusNameById(paymentStatuses, paymentStatusId);

    return _isPaidStatus(taskStatus) ||
        _isPaidStatus(paymentStatus) ||
        paidTaskIdsByRequest.contains(task['id']);
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
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final currentUser = await pb.collection('users').getOne(currentUserId);

      final role = _roleFromUser(currentUser.data) ?? 'customer';
      final name =
          currentUser.data['name'] as String? ??
          currentUser.data['email'] as String? ??
          'User';

      final photo = PocketBaseFileService.fileUrl(
        collectionName: 'users',
        recordId: currentUser.id,
        fileValue: currentUser.data['photo'],
      );

      final users = await _getAllRecords('users');
      final orders = await _getAllRecords('orders');
      final tasks = await _getAllRecords('tasks');
      final feedbacks = await _getAllRecords('feedbacks');
      final applications = await _getAllRecords('applications');
      final paymentRequests = await _getAllRecords('payment_requests');
      final paymentStatuses = await _getAllRecords('payment_statuses');
      final taskStatuses = await _getAllRecords('task_statuses');

      final paidTaskIdsByRequest = <String>{};
      final pendingPaymentTaskIdsByRequest = <String>{};

      for (final request in paymentRequests) {
        final taskId = _relationId(request.data['task_id']);
        if (taskId == null) continue;

        final status = (request.data['status'] as String? ?? '').trim();

        if (_isPaidStatus(status)) {
          paidTaskIdsByRequest.add(taskId);
        } else if (_isPendingPaymentStatus(status)) {
          pendingPaymentTaskIdsByRequest.add(taskId);
        }
      }

      final openOrders = <Map<String, dynamic>>[];

      for (final order in orders) {
        final customerId = _relationId(order.data['customer_id']);
        final executorId = _relationId(order.data['executor_id']);

        if (customerId != currentUserId) continue;
        if (executorId != null && executorId.isNotEmpty) continue;

        final latestTask = _latestTaskForOrder(tasks, order.id);

        final archived = _isArchivedTask(
          task: latestTask,
          taskStatuses: taskStatuses,
          paymentStatuses: paymentStatuses,
          paidTaskIdsByRequest: paidTaskIdsByRequest,
        );

        if (archived) continue;

        openOrders.add({
          'id': order.id,
          'created': order.get<String>('created') ?? '',
          'title': order.data['task_description'] as String? ?? '',
          'price': order.data['price'],
          'deadline': order.data['deadline'],
        });
      }

      openOrders.sort((a, b) {
        final da = DateTime.tryParse(a['created'] as String? ?? '');
        final db = DateTime.tryParse(b['created'] as String? ?? '');

        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;

        return db.compareTo(da);
      });

      final executors = <Map<String, dynamic>>[];

      for (final user in users) {
        final userData = Map<String, dynamic>.from(user.data);
        final userRole = _roleFromUser(userData);

        if (userRole != 'executor') continue;
        if (user.id == currentUserId) continue;

        final feedbackStats = _feedbackStatsForExecutor(
          executorId: user.id,
          feedbacks: feedbacks,
          orders: orders,
          tasks: tasks,
        );

        final workloadStats = _workloadStatsForExecutor(
          executorId: user.id,
          tasks: tasks,
          taskStatuses: taskStatuses,
          paymentStatuses: paymentStatuses,
          paidTaskIdsByRequest: paidTaskIdsByRequest,
          pendingPaymentTaskIdsByRequest: pendingPaymentTaskIdsByRequest,
        );

        final inviteStats = _inviteStatsForExecutor(
          executorId: user.id,
          customerId: currentUserId,
          applications: applications,
        );

        final avatarUrl = PocketBaseFileService.fileUrl(
          collectionName: 'users',
          recordId: user.id,
          fileValue: user.data['photo'],
        );

        executors.add({
          'id': user.id,
          'name':
              user.data['name'] as String? ??
              user.data['email'] as String? ??
              'Исполнитель',
          'email': user.data['email'] as String? ?? '',
          'description': user.data['description'] as String? ?? '',
          'avatar_url': avatarUrl,
          'avg_rating': feedbackStats.avgRating,
          'feedback_count': feedbackStats.count,
          'active_tasks_count': workloadStats.activeTasksCount,
          'pending_payment_count': workloadStats.pendingPaymentCount,
          'completed_tasks_count': workloadStats.completedTasksCount,
          'pending_invites_count': inviteStats.pendingCount,
          'approved_invites_count': inviteStats.approvedCount,
        });
      }

      executors.sort((a, b) {
        final ratingA = (a['avg_rating'] as double?) ?? 0;
        final ratingB = (b['avg_rating'] as double?) ?? 0;

        final ratingCompare = ratingB.compareTo(ratingA);
        if (ratingCompare != 0) return ratingCompare;

        final feedbackA = (a['feedback_count'] as int?) ?? 0;
        final feedbackB = (b['feedback_count'] as int?) ?? 0;

        return feedbackB.compareTo(feedbackA);
      });

      if (!mounted) return;

      setState(() {
        _role = role;
        _name = name;
        _photo = photo;
        _executors = executors;
        _openOrders = openOrders;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить исполнителей: $e';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  _FeedbackStats _feedbackStatsForExecutor({
    required String executorId,
    required List<dynamic> feedbacks,
    required List<dynamic> orders,
    required List<dynamic> tasks,
  }) {
    final executorOrderIds = <String>{};

    for (final order in orders) {
      final orderExecutorId = _relationId(order.data['executor_id']);

      if (orderExecutorId == executorId) {
        executorOrderIds.add(order.id);
      }
    }

    for (final task in tasks) {
      final taskExecutorId = _relationId(task.data['executor_id']);
      final orderId = _relationId(task.data['order_id']);

      if (taskExecutorId == executorId && orderId != null) {
        executorOrderIds.add(orderId);
      }
    }

    final estimates = <double>[];

    for (final feedback in feedbacks) {
      final reviewedUserId = _relationId(feedback.data['reviewed_user_id']);
      final orderId = _relationId(feedback.data['order_id']);

      final isNewFormat = reviewedUserId == executorId;
      final isLegacyExecutorFeedback =
          reviewedUserId == null &&
          orderId != null &&
          executorOrderIds.contains(orderId);

      if (!isNewFormat && !isLegacyExecutorFeedback) continue;

      final estimate = (feedback.data['estimate'] as num?)?.toDouble();
      if (estimate == null || estimate <= 0) continue;

      estimates.add(estimate);
    }

    if (estimates.isEmpty) {
      return const _FeedbackStats(avgRating: 0, count: 0);
    }

    final avg = estimates.reduce((a, b) => a + b) / estimates.length;

    return _FeedbackStats(avgRating: avg, count: estimates.length);
  }

  _WorkloadStats _workloadStatsForExecutor({
    required String executorId,
    required List<dynamic> tasks,
    required List<dynamic> taskStatuses,
    required List<dynamic> paymentStatuses,
    required Set<String> paidTaskIdsByRequest,
    required Set<String> pendingPaymentTaskIdsByRequest,
  }) {
    var active = 0;
    var pendingPayment = 0;
    var completed = 0;

    for (final task in tasks) {
      final taskExecutorId = _relationId(task.data['executor_id']);
      if (taskExecutorId != executorId) continue;

      final taskStatusId = _relationId(task.data['status_id']);
      final paymentStatusId = _relationId(task.data['payment_status_id']);

      final taskStatus = _statusNameById(taskStatuses, taskStatusId);
      final paymentStatus = _statusNameById(paymentStatuses, paymentStatusId);

      final isCompleted =
          _isPaidStatus(taskStatus) ||
          _isPaidStatus(paymentStatus) ||
          paidTaskIdsByRequest.contains(task.id);

      final isPendingPayment =
          !isCompleted &&
          (_isPendingPaymentStatus(paymentStatus) ||
              pendingPaymentTaskIdsByRequest.contains(task.id));

      if (isCompleted) {
        completed++;
      } else {
        active++;

        if (isPendingPayment) {
          pendingPayment++;
        }
      }
    }

    return _WorkloadStats(
      activeTasksCount: active,
      pendingPaymentCount: pendingPayment,
      completedTasksCount: completed,
    );
  }

  _InviteStats _inviteStatsForExecutor({
    required String executorId,
    required String customerId,
    required List<dynamic> applications,
  }) {
    var pending = 0;
    var approved = 0;

    for (final app in applications) {
      final appExecutorId = _relationId(app.data['executor_id']);
      final initiatorId = _relationId(app.data['initiator_id']);
      final source = app.data['source']?.toString();
      final status = app.data['status']?.toString().trim().toLowerCase();

      if (appExecutorId != executorId) continue;
      if (initiatorId != customerId) continue;
      if (source != 'customer_invite') continue;

      if (status == 'pending') {
        pending++;
      } else if (status == 'approved') {
        approved++;
      }
    }

    return _InviteStats(pendingCount: pending, approvedCount: approved);
  }

  List<Map<String, dynamic>> get _filteredExecutors {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _executors;

    return _executors.where((executor) {
      final name = (executor['name'] as String? ?? '').toLowerCase();
      final email = (executor['email'] as String? ?? '').toLowerCase();
      final description =
          (executor['description'] as String? ?? '').toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          description.contains(query);
    }).toList();
  }

  Future<void> _openInviteSheet(Map<String, dynamic> executor) async {
    if (_openOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала создайте заказ без назначенного исполнителя'),
        ),
      );
      return;
    }

    await showAppBottomSheet(
      context: context,
      title: 'Пригласить исполнителя',
      child: _InviteExecutorSheet(
        executorName: executor['name'] as String? ?? 'Исполнитель',
        orders: _openOrders,
        onInvite: (orderId, message) async {
          await _sendInvite(
            orderId: orderId,
            executorId: executor['id'] as String,
            message: message,
          );
        },
      ),
    );
  }

  Future<void> _sendInvite({
    required String orderId,
    required String executorId,
    required String message,
  }) async {
    if (_busyExecutorId != null) return;

    setState(() => _busyExecutorId = executorId);

    try {
      final customerId = PocketBaseService.instance.currentUserId;

      if (customerId == null) {
        throw 'Неавторизован';
      }

      await ApplicationDecisionService.createCustomerInvite(
        orderId: orderId,
        executorId: executorId,
        customerId: customerId,
        message: message,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Приглашение отправлено')));

      await _loadAll(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка приглашения: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyExecutorId = null);
      }
    }
  }

  void _openProfile(String userId) {
    context.push('/account/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final executors = _filteredExecutors;
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
                        title: 'Исполнители',
                        subtitle: 'Просмотр профилей и приглашение на заказ',
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
                                  child: _ExecutorsOverviewCard(
                                    customerName: _name ?? 'Заказчик',
                                    avatarUrl: _photo,
                                    executorsCount: _executors.length,
                                    openOrdersCount: _openOrders.length,
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
                                    hint: 'Поиск по имени, email, описанию',
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
                                          icon: CupertinoIcons.person_2,
                                          label:
                                              'Исполнители ${_executors.length}',
                                          active: true,
                                          onTap: () {},
                                        ),
                                        const SizedBox(width: 8),
                                        AppFilterChip(
                                          icon: CupertinoIcons.doc_text,
                                          label:
                                              'Открытые заказы ${_openOrders.length}',
                                          active: _openOrders.isNotEmpty,
                                          onTap: () {},
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
                                    title: 'Список исполнителей',
                                    count: executors.length,
                                  ),
                                ),
                              ),
                              if (executors.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon:
                                        hasSearch
                                            ? CupertinoIcons.search
                                            : CupertinoIcons.person_2,
                                    title:
                                        hasSearch
                                            ? 'Ничего не найдено'
                                            : 'Исполнителей нет',
                                    subtitle:
                                        hasSearch
                                            ? 'Измените поисковый запрос.'
                                            : 'В список попадают только пользователи с ролью исполнителя.',
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

                                      final executorIndex = index ~/ 2;
                                      final executor = executors[executorIndex];
                                      final executorId =
                                          executor['id'] as String;

                                      return _ExecutorCard(
                                        executor: executor,
                                        busy: _busyExecutorId == executorId,
                                        onOpenProfile:
                                            () => _openProfile(executorId),
                                        onInvite:
                                            () => _openInviteSheet(executor),
                                      );
                                    }, childCount: executors.length * 2 - 1),
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

class _FeedbackStats {
  final double avgRating;
  final int count;

  const _FeedbackStats({required this.avgRating, required this.count});
}

class _WorkloadStats {
  final int activeTasksCount;
  final int pendingPaymentCount;
  final int completedTasksCount;

  const _WorkloadStats({
    required this.activeTasksCount,
    required this.pendingPaymentCount,
    required this.completedTasksCount,
  });
}

class _InviteStats {
  final int pendingCount;
  final int approvedCount;

  const _InviteStats({required this.pendingCount, required this.approvedCount});
}

class _ExecutorsOverviewCard extends StatelessWidget {
  final String customerName;
  final String? avatarUrl;
  final int executorsCount;
  final int openOrdersCount;

  const _ExecutorsOverviewCard({
    required this.customerName,
    required this.avatarUrl,
    required this.executorsCount,
    required this.openOrdersCount,
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
                      customerName,
                      style: AppTextStyles.cardTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text('Заказчик', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'executors',
                color: AppColors.accent,
                icon: CupertinoIcons.person_2,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Здесь можно посмотреть профили исполнителей, отзывы, текущую загруженность и отправить приглашение на открытый заказ.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: CupertinoIcons.person_2,
                  label: 'Исполнители',
                  value: executorsCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: CupertinoIcons.doc_text,
                  label: 'Открытые заказы',
                  value: openOrdersCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutorCard extends StatelessWidget {
  final Map<String, dynamic> executor;
  final bool busy;
  final VoidCallback onOpenProfile;
  final VoidCallback onInvite;

  const _ExecutorCard({
    required this.executor,
    required this.busy,
    required this.onOpenProfile,
    required this.onInvite,
  });

  int get _activeTasksCount {
    return (executor['active_tasks_count'] as int?) ?? 0;
  }

  int get _pendingPaymentCount {
    return (executor['pending_payment_count'] as int?) ?? 0;
  }

  int get _completedTasksCount {
    return (executor['completed_tasks_count'] as int?) ?? 0;
  }

  int get _pendingInvitesCount {
    return (executor['pending_invites_count'] as int?) ?? 0;
  }

  double get _avgRating {
    return (executor['avg_rating'] as double?) ?? 0;
  }

  int get _feedbackCount {
    return (executor['feedback_count'] as int?) ?? 0;
  }

  Color get _workloadColor {
    final count = _activeTasksCount;

    if (count == 0) return Colors.green;
    if (count <= 2) return AppColors.accent;
    if (count <= 4) return Colors.orange;
    return AppColors.danger;
  }

  String get _workloadText {
    final count = _activeTasksCount;

    if (count == 0) return 'Свободен';
    if (count <= 2) return 'Нормальная загрузка';
    if (count <= 4) return 'Высокая загрузка';
    return 'Перегруз';
  }

  @override
  Widget build(BuildContext context) {
    final name = executor['name'] as String? ?? 'Исполнитель';
    final description = executor['description'] as String? ?? '';
    final avatarUrl = executor['avatar_url'] as String?;

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppProfileAvatar(avatarUrl: avatarUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.trim().isEmpty ? 'Исполнитель' : name,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _feedbackCount == 0
                          ? 'Отзывов пока нет'
                          : '${_avgRating.toStringAsFixed(1)} / 5 · отзывов: $_feedbackCount',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: AppTextStyles.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatusPill(
                text: _workloadText,
                color: _workloadColor,
                icon: CupertinoIcons.speedometer,
              ),
              AppTag(
                icon: Icons.work_outline_rounded,
                label: 'В работе $_activeTasksCount',
              ),
              AppTag(
                icon: Icons.schedule_rounded,
                label: 'Ожидают оплаты $_pendingPaymentCount',
              ),
              AppTag(
                icon: CupertinoIcons.checkmark_seal,
                label: 'Завершено $_completedTasksCount',
              ),
              if (_pendingInvitesCount > 0)
                AppTag(
                  icon: CupertinoIcons.paperplane,
                  label: 'Приглашений $_pendingInvitesCount',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onOpenProfile,
                  icon: const Icon(CupertinoIcons.person_crop_circle),
                  label: const Text('Профиль'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onInvite,
                  icon:
                      busy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(busy ? 'Отправляем...' : 'Пригласить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteExecutorSheet extends StatefulWidget {
  final String executorName;
  final List<Map<String, dynamic>> orders;
  final Future<void> Function(String orderId, String message) onInvite;

  const _InviteExecutorSheet({
    required this.executorName,
    required this.orders,
    required this.onInvite,
  });

  @override
  State<_InviteExecutorSheet> createState() => _InviteExecutorSheetState();
}

class _InviteExecutorSheetState extends State<_InviteExecutorSheet> {
  final _messageController = TextEditingController();
  String? _selectedOrderId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    if (widget.orders.isNotEmpty) {
      _selectedOrderId = widget.orders.first['id'] as String?;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _formatMoney(dynamic raw) {
    final value = (raw as num?) ?? 0;

    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  Future<void> _send() async {
    final orderId = _selectedOrderId;
    if (orderId == null || orderId.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await widget.onInvite(orderId, _messageController.text.trim());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Исполнитель: ${widget.executorName}',
            style: AppTextStyles.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageController,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Сообщение исполнителю',
              hintText: 'Например: хочу предложить вам этот заказ',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Выберите заказ',
            style: AppTextStyles.small.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: widget.orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = widget.orders[index];
                final orderId = order['id'] as String;
                final selected = orderId == _selectedOrderId;
                final title = order['title'] as String? ?? '';

                return AppSurfaceCard(
                  onTap:
                      _sending
                          ? null
                          : () {
                            setState(() {
                              _selectedOrderId = orderId;
                            });
                          },
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  radius: AppRadii.sm,
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        color:
                            selected ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.trim().isEmpty
                                  ? 'Заказ без описания'
                                  : title,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Бюджет: ${_formatMoney(order['price'])}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon:
                  _sending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(CupertinoIcons.paperplane_fill),
              label: Text(_sending ? 'Отправляем...' : 'Отправить приглашение'),
            ),
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
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
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
