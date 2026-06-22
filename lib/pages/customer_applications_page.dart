// lib/pages/customer_applications_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/application_decision_service.dart';
import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/prepayment_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

enum _ReqType { application, payment }

class _ReqItem {
  final String id;
  final _ReqType type;
  final String title;
  final String actorName;
  final String? actorId;
  final String? actorPhoto;
  final String status;
  final DateTime createdAt;
  final double? amount;
  final String? orderId;
  final String? executorId;
  final String? taskId;
  final int? orderComplexityAuto;
  final int? complexityProposed;
  final int? complexityFinal;
  final String? complexitySource;
  final String? complexityReason;
  final String source;
  final String message;
  final bool requiresPrepayment;
  final bool orderOffersPrepayment;
  final String prepaymentNote;
  final String? paymentType;

  _ReqItem({
    required this.id,
    required this.type,
    required this.title,
    required this.actorName,
    this.actorId,
    this.actorPhoto,
    required this.status,
    required this.createdAt,
    this.amount,
    this.orderId,
    this.executorId,
    this.taskId,
    this.orderComplexityAuto,
    this.complexityProposed,
    this.complexityFinal,
    this.complexitySource,
    this.complexityReason,
    this.source = 'executor_apply',
    this.message = '',
    this.requiresPrepayment = false,
    this.orderOffersPrepayment = false,
    this.prepaymentNote = '',
    this.paymentType,
  });
}

class CustomerApplicationsPage extends StatefulWidget {
  const CustomerApplicationsPage({Key? key}) : super(key: key);

  @override
  State<CustomerApplicationsPage> createState() =>
      _CustomerApplicationsPageState();
}

class _CustomerApplicationsPageState extends State<CustomerApplicationsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _fmt = DateFormat('dd.MM.yyyy HH:mm');

  bool _loading = true;
  String? _error;
  String? _busyItemId;

  String? _role;
  String? _displayName;
  String? _photo;

  bool _sortNewest = true;
  List<_ReqItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String? _relationId(dynamic value) {
    return ApplicationDecisionService.relationId(value);
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

  String _status(dynamic value) {
    return ApplicationDecisionService.normalizedStatus(value);
  }

  String _source(dynamic value) {
    return ApplicationDecisionService.normalizedApplicationSource(value);
  }

  bool _isPending(String status) {
    return status.trim().toLowerCase() == 'pending';
  }

  bool _isCustomerInvite(_ReqItem item) {
    return item.type == _ReqType.application &&
        item.source == 'customer_invite';
  }

  int? _intValue(dynamic value) {
    return ApplicationDecisionService.intValue(value);
  }

  Future<Map<String, dynamic>?> _getRecordData(
    String collection,
    String? id,
  ) async {
    return ApplicationDecisionService.getRecordData(collection, id);
  }

  String? _userPhotoUrl(Map<String, dynamic>? user) {
    if (user == null) return null;

    final userId = user['id'] as String?;
    if (userId == null || userId.isEmpty) return null;

    return _fileUrl(
      collectionName: 'users',
      recordId: userId,
      fileValue: user['photo'],
    );
  }

  Future<String?> _taskIdForOrder(String orderId) async {
    return ApplicationDecisionService.taskIdForOrder(orderId);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _busyItemId = null;
    });

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      _role = _roleFromUser(user.data);
      _displayName =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';

      _photo = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final loaded = <_ReqItem>[];

      await _loadApplications(pb, userId, loaded);
      await _loadPaymentRequests(pb, userId, loaded);

      loaded.sort(
        (a, b) =>
            _sortNewest
                ? b.createdAt.compareTo(a.createdAt)
                : a.createdAt.compareTo(b.createdAt),
      );

      _items = loaded;
    } catch (e) {
      _error = 'Не удалось загрузить заявки и оплаты: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadApplications(
    dynamic pb,
    String userId,
    List<_ReqItem> loaded,
  ) async {
    final appsResult = await pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    for (final app in appsResult.items) {
      final orderId = _relationId(app.data['order_id']);
      final executorId = _relationId(app.data['executor_id']);

      final order = await _getRecordData('orders', orderId);
      if (order == null) continue;

      final customerId = _relationId(order['customer_id']);
      if (customerId != userId) continue;

      final executor = await _getRecordData('users', executorId);
      final taskId = orderId == null ? null : await _taskIdForOrder(orderId);
      final task = await _getRecordData('tasks', taskId);

      loaded.add(
        _ReqItem(
          id: app.id,
          type: _ReqType.application,
          title: order['task_description'] as String? ?? '—',
          actorName:
              executor?['name'] as String? ??
              executor?['email'] as String? ??
              'Исполнитель',
          actorId: executorId,
          actorPhoto: _userPhotoUrl(executor),
          status: _status(app.data['status']),
          createdAt:
              DateTime.tryParse(app.get<String>('created') ?? '')?.toLocal() ??
              DateTime.now(),
          amount: (order['price'] as num?)?.toDouble(),
          orderId: orderId,
          executorId: executorId,
          taskId: taskId,
          orderComplexityAuto: _intValue(order['complexity_auto']),
          complexityProposed: _intValue(app.data['complexity_proposed']),
          complexityReason: app.data['complexity_reason'] as String?,
          complexityFinal: _intValue(task?['complexity_final']),
          complexitySource: task?['complexity_source'] as String?,
          source: _source(app.data['source']),
          message: app.data['message'] as String? ?? '',
          requiresPrepayment:
              PrepaymentService.applicationRequiresPrepayment(app.data),
          orderOffersPrepayment: PrepaymentService.orderOffersPrepayment(order),
          prepaymentNote: app.data['prepayment_note'] as String? ?? '',
        ),
      );
    }
  }

  Future<void> _loadPaymentRequests(
    dynamic pb,
    String userId,
    List<_ReqItem> loaded,
  ) async {
    final paymentsResult = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    for (final payment in paymentsResult.items) {
      final taskId = _relationId(payment.data['task_id']);
      final task = await _getRecordData('tasks', taskId);

      if (task == null) continue;

      final orderId = _relationId(task['order_id']);
      final order = await _getRecordData('orders', orderId);

      if (order == null) continue;

      final customerId = _relationId(order['customer_id']);
      if (customerId != userId) continue;

      final requestedById = _relationId(payment.data['requested_by']);
      final requestedBy = await _getRecordData('users', requestedById);

      loaded.add(
        _ReqItem(
          id: payment.id,
          type: _ReqType.payment,
          title: order['task_description'] as String? ?? '—',
          actorName:
              requestedBy?['name'] as String? ??
              requestedBy?['email'] as String? ??
              'Исполнитель',
          actorId: requestedById,
          actorPhoto: _userPhotoUrl(requestedBy),
          status: _status(payment.data['status']),
          createdAt:
              DateTime.tryParse(
                payment.get<String>('created') ?? '',
              )?.toLocal() ??
              DateTime.now(),
          amount:
              (payment.data['payment_amount'] as num?)?.toDouble() ??
              (task['payment_amount'] as num?)?.toDouble(),
          taskId: taskId,
          orderId: orderId,
          complexityFinal: _intValue(task['complexity_final']),
          complexitySource: task['complexity_source'] as String?,
          paymentType: PrepaymentService.normalizedPaymentType(
            payment.data['payment_type'],
          ),
        ),
      );
    }
  }

  Future<void> _acceptItem(_ReqItem item) async {
    if (item.type == _ReqType.payment) {
      await _openPayment(item);
      return;
    }

    if (_isCustomerInvite(item)) {
      return;
    }

    await _decide(item, true);
  }

  Future<void> _openPayment(_ReqItem item) async {
    if (_busyItemId != null) return;

    setState(() => _busyItemId = item.id);

    try {
      final result = await context.push('/payments/mock/${item.id}');

      if (result == true) {
        await _loadAll();
      } else if (mounted) {
        setState(() => _busyItemId = null);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Ошибка открытия оплаты: $e';
      });
    }
  }

  Future<void> _decide(_ReqItem item, bool accept) async {
    if (_busyItemId != null) return;

    setState(() {
      _busyItemId = item.id;
      _error = null;
    });

    try {
      final currentUserId = PocketBaseService.instance.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      if (item.type == _ReqType.application) {
        if (accept) {
          await ApplicationDecisionService.acceptApplication(
            applicationId: item.id,
            actorUserId: currentUserId,
          );
        } else {
          await ApplicationDecisionService.rejectApplication(
            applicationId: item.id,
            actorUserId: currentUserId,
          );
        }
      } else {
        await _decidePayment(item, accept ? 'approved' : 'rejected', accept);
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Ошибка обработки заявки: $e';
      });
    }
  }

  Future<void> _decidePayment(
    _ReqItem item,
    String newStatus,
    bool accept,
  ) async {
    final pb = PocketBaseService.instance.pb;

    await pb
        .collection('payment_requests')
        .update(item.id, body: {'status': newStatus});

    if (!accept || item.taskId == null) return;

    final paidStatusId = await ApplicationDecisionService.firstIdFromCollection(
      'payment_statuses',
      item.paymentType == 'prepayment'
          ? ['prepayment_paid', 'pending', 'paid']
          : ['paid', 'approved', 'done'],
    );

    if (paidStatusId == null) return;

    await pb
        .collection('tasks')
        .update(item.taskId!, body: {'payment_status_id': paidStatusId});
  }

  void _openTaskDetails(_ReqItem item) {
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty) return;

    context.push('/tasks/details/$taskId');
  }

  void _openActorProfile(_ReqItem item) {
    final actorId = item.actorId;

    if (actorId == null || actorId.isEmpty) return;

    context.push('/account/$actorId');
  }

  Future<void> _openFeedbackForItem(_ReqItem item) async {
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty) return;

    final result = await context.push('/feedbacks/task/$taskId');

    if (result == true) {
      await _loadAll();
    }
  }

  Future<void> _rejectAll() async {
    if (_busyItemId != null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Отклонить все ожидающие заявки?'),
            content: const Text(
              'Все ожидающие отклики, приглашения и запросы оплаты будут отклонены.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Отклонить'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() {
      _busyItemId = '__all__';
      _error = null;
    });

    try {
      final currentUserId = PocketBaseService.instance.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final pb = PocketBaseService.instance.pb;

      for (final item in _items.where((e) => _isPending(e.status))) {
        if (item.type == _ReqType.application) {
          await ApplicationDecisionService.rejectApplication(
            applicationId: item.id,
            actorUserId: currentUserId,
          );
        } else {
          await pb
              .collection('payment_requests')
              .update(item.id, body: {'status': 'rejected'});
        }
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Ошибка отклонения заявок: $e';
      });
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
          AppBottomSheetOption(
            title: 'Новые',
            selected: _sortNewest,
            onTap: () {
              Navigator.pop(context);
              setState(() => _sortNewest = true);
              _loadAll();
            },
          ),
          AppBottomSheetOption(
            title: 'Старые',
            selected: !_sortNewest,
            onTap: () {
              Navigator.pop(context);
              setState(() => _sortNewest = false);
              _loadAll();
            },
          ),
        ],
      ),
    );
  }

  List<_ReqItem> get _applicationItems {
    return _items.where((item) => item.type == _ReqType.application).toList();
  }

  List<_ReqItem> get _paymentItems {
    return _items.where((item) => item.type == _ReqType.payment).toList();
  }

  int get _pendingCount {
    return _items.where((item) => _isPending(item.status)).length;
  }

  int get _applicationsCount {
    return _applicationItems.length;
  }

  int get _paymentsCount {
    return _paymentItems.length;
  }

  int get _invitesCount {
    return _applicationItems.where((item) => _isCustomerInvite(item)).length;
  }

  String _typeLabel(_ReqItem item) {
    if (item.type == _ReqType.payment) {
      return PrepaymentService.paymentTypeLabel(item.paymentType ?? 'final');
    }

    if (_isCustomerInvite(item)) {
      return 'Приглашение исполнителю';
    }

    return 'Отклик исполнителя';
  }

  IconData _typeIcon(_ReqItem item) {
    if (item.type == _ReqType.payment) {
      return Icons.payments_rounded;
    }

    if (_isCustomerInvite(item)) {
      return CupertinoIcons.paperplane;
    }

    return Icons.assignment_ind_outlined;
  }

  String _positiveButtonText(_ReqItem item) {
    if (item.type == _ReqType.payment) {
      return item.paymentType == 'prepayment' ? 'Оплатить предоплату' : 'Оплатить';
    }

    return 'Принять';
  }

  String _rejectButtonText(_ReqItem item) {
    if (_isCustomerInvite(item)) {
      return 'Отменить';
    }

    return 'Отклонить';
  }

  String _formatMoney(double? amount) {
    final value = amount ?? 0;

    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  AppStatusPill _statusPill(_ReqItem item) {
    if (item.status == 'approved') {
      if (item.type == _ReqType.payment) {
        return AppStatusPill.success('Оплачено');
      }

      return AppStatusPill.success(
        _isCustomerInvite(item) ? 'Приглашение принято' : 'Отклик принят',
      );
    }

    if (item.status == 'rejected') {
      return AppStatusPill.error(
        _isCustomerInvite(item) ? 'Приглашение отклонено' : 'Отклонено',
      );
    }

    if (_isCustomerInvite(item)) {
      return AppStatusPill.pending('Ожидает исполнителя');
    }

    return AppStatusPill.pending('Ожидает решения');
  }

  Widget _requestCard(_ReqItem item, bool pageBusy) {
    return _RequestCard(
      item: item,
      busy: pageBusy,
      itemBusy: _busyItemId == item.id,
      typeLabel: _typeLabel(item),
      typeIcon: _typeIcon(item),
      statusPill: _statusPill(item),
      amountText: _formatMoney(item.amount),
      dateText: _fmt.format(item.createdAt),
      positiveButtonText: _positiveButtonText(item),
      rejectButtonText: _rejectButtonText(item),
      onAccept: () => _acceptItem(item),
      onReject: () => _decide(item, false),
      onOpenTask: () => _openTaskDetails(item),
      onOpenActorProfile:
          item.actorId == null ? null : () => _openActorProfile(item),
      onOpenFeedback: () => _openFeedbackForItem(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _pendingCount > 0;
    final pageBusy = _busyItemId != null;
    final applications = _applicationItems;
    final payments = _paymentItems;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer:
          (_role != null && _displayName != null)
              ? AppDrawer(
                role: _role!,
                displayName: _displayName!,
                avatarUrl: _photo,
              )
              : null,
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
                        title: 'Заявки и оплаты',
                        subtitle: 'Отклики, приглашения и запросы оплаты',
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
                                  child: _ApplicationsOverviewCard(
                                    name: _displayName ?? 'Заказчик',
                                    avatarUrl: _photo,
                                    totalCount: _items.length,
                                    applicationsCount: _applicationsCount,
                                    invitesCount: _invitesCount,
                                    paymentsCount: _paymentsCount,
                                    pendingCount: _pendingCount,
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
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        AppFilterChip(
                                          icon: CupertinoIcons.sort_down,
                                          label:
                                              _sortNewest ? 'Новые' : 'Старые',
                                          active: true,
                                          onTap: pageBusy ? () {} : _selectSort,
                                        ),
                                        if (hasPending) ...[
                                          const SizedBox(width: 8),
                                          AppFilterChip(
                                            icon: Icons.delete_outline_rounded,
                                            label:
                                                pageBusy &&
                                                        _busyItemId == '__all__'
                                                    ? 'Отклоняем...'
                                                    : 'Отклонить все',
                                            danger: true,
                                            onTap:
                                                pageBusy ? () {} : _rejectAll,
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
                                  20,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _RequestsTwoColumnLayout(
                                    applications: applications,
                                    payments: payments,
                                    applicationCardBuilder:
                                        (item) => _requestCard(item, pageBusy),
                                    paymentCardBuilder:
                                        (item) => _requestCard(item, pageBusy),
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

class _ApplicationsOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int totalCount;
  final int applicationsCount;
  final int invitesCount;
  final int paymentsCount;
  final int pendingCount;

  const _ApplicationsOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.totalCount,
    required this.applicationsCount,
    required this.invitesCount,
    required this.paymentsCount,
    required this.pendingCount,
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
                text: 'Заявки',
                color: AppColors.accent,
                icon: CupertinoIcons.mail,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Здесь обрабатываются отклики исполнителей, отправленные приглашения и запросы оплаты по задачам.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Всего',
                  value: totalCount.toString(),
                  icon: Icons.inbox_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Заявки',
                  value: applicationsCount.toString(),
                  icon: Icons.assignment_ind_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Ожидают',
                  value: pendingCount.toString(),
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Приглашения',
                  value: invitesCount.toString(),
                  icon: CupertinoIcons.paperplane,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Оплаты',
                  value: paymentsCount.toString(),
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

class _RequestsTwoColumnLayout extends StatelessWidget {
  final List<_ReqItem> applications;
  final List<_ReqItem> payments;
  final Widget Function(_ReqItem item) applicationCardBuilder;
  final Widget Function(_ReqItem item) paymentCardBuilder;

  const _RequestsTwoColumnLayout({
    required this.applications,
    required this.payments,
    required this.applicationCardBuilder,
    required this.paymentCardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        final left = _RequestsColumn(
          title: 'Заявки и приглашения',
          icon: Icons.assignment_ind_outlined,
          emptyTitle: 'Заявок нет',
          emptySubtitle: 'Отклики и приглашения исполнителям появятся здесь.',
          items: applications,
          cardBuilder: applicationCardBuilder,
        );

        final right = _RequestsColumn(
          title: 'Заявки на оплату',
          icon: Icons.payments_rounded,
          emptyTitle: 'Запросов оплаты нет',
          emptySubtitle: 'После запроса оплаты запись появится здесь.',
          items: payments,
          cardBuilder: paymentCardBuilder,
        );

        if (!wide) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _RequestsColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final String emptyTitle;
  final String emptySubtitle;
  final List<_ReqItem> items;
  final Widget Function(_ReqItem item) cardBuilder;

  const _RequestsColumn({
    required this.title,
    required this.icon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.items,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title, count: items.length),
          const SizedBox(height: 10),
          if (items.isEmpty)
            AppEmptyState(
              icon: icon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: cardBuilder(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _ReqItem item;
  final bool busy;
  final bool itemBusy;
  final String typeLabel;
  final IconData typeIcon;
  final AppStatusPill statusPill;
  final String amountText;
  final String dateText;
  final String positiveButtonText;
  final String rejectButtonText;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onOpenTask;
  final VoidCallback? onOpenActorProfile;
  final VoidCallback onOpenFeedback;

  const _RequestCard({
    required this.item,
    required this.busy,
    required this.itemBusy,
    required this.typeLabel,
    required this.typeIcon,
    required this.statusPill,
    required this.amountText,
    required this.dateText,
    required this.positiveButtonText,
    required this.rejectButtonText,
    required this.onAccept,
    required this.onReject,
    required this.onOpenTask,
    required this.onOpenActorProfile,
    required this.onOpenFeedback,
  });

  bool get _pending => item.status == 'pending';
  bool get _approved => item.status == 'approved';
  bool get _hasTask => item.taskId != null && item.taskId!.isNotEmpty;
  bool get _isCustomerInvite =>
      item.type == _ReqType.application && item.source == 'customer_invite';
  bool get _canLeaveFeedback =>
      item.type == _ReqType.payment && _approved && _hasTask;

  int? get _visibleComplexity {
    return item.complexityFinal ??
        item.complexityProposed ??
        item.orderComplexityAuto;
  }

  String? get _visibleComplexitySource {
    return item.complexitySource ??
        (item.complexityProposed != null ? 'executor_adjusted' : 'auto');
  }

  @override
  Widget build(BuildContext context) {
    final complexity = _visibleComplexity;
    final message = item.message.trim();

    return AppSurfaceCard(
      onTap: _hasTask ? onOpenTask : null,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppProfileAvatar(
                avatarUrl: item.actorPhoto,
                size: 42,
                fallbackIcon: typeIcon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.actorName,
                      style: AppTextStyles.cardTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(typeLabel, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (onOpenActorProfile != null) ...[
                IconButton(
                  tooltip: 'Профиль',
                  onPressed: busy ? null : onOpenActorProfile,
                  icon: const Icon(
                    CupertinoIcons.person_crop_circle,
                    color: AppColors.accent,
                  ),
                ),
              ],
              Text(
                dateText,
                style: AppTextStyles.caption,
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title.trim().isEmpty ? 'Без описания' : item.title,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(message, style: AppTextStyles.body),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              statusPill,
              if (item.type == _ReqType.payment)
                AppTag(icon: Icons.currency_ruble_rounded, label: amountText),
              if (complexity != null)
                AppTag(
                  icon: Icons.bar_chart_rounded,
                  label:
                      'Сложность $complexity/5 · ${OrderComplexityService.sourceLabel(_visibleComplexitySource)}',
                ),
              if (_hasTask)
                const AppTag(
                  icon: CupertinoIcons.doc_text,
                  label: 'Есть задача',
                ),
              if (item.orderOffersPrepayment &&
                  item.type == _ReqType.application)
                AppTag(
                  icon: Icons.payments_outlined,
                  label: 'Возможна предоплата',
                ),
              if (item.requiresPrepayment && item.type == _ReqType.application)
                AppTag(
                  icon: Icons.payments_rounded,
                  label: 'Исполнитель: только по предоплате',
                ),
            ],
          ),
          if (item.prepaymentNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Условие предоплаты: ${item.prepaymentNote}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          if ((item.complexityReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Причина изменения сложности: ${item.complexityReason}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (_pending) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            if (_isCustomerInvite)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon:
                      itemBusy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(CupertinoIcons.xmark_circle),
                  label: Text(rejectButtonText),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon:
                          itemBusy
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                item.type == _ReqType.payment
                                    ? Icons.account_balance_rounded
                                    : CupertinoIcons.checkmark_alt_circle,
                              ),
                      label: Text(positiveButtonText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onReject,
                      icon: const Icon(CupertinoIcons.xmark_circle),
                      label: Text(rejectButtonText),
                    ),
                  ),
                ],
              ),
          ],
          if (!_pending && _hasTask) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            if (_canLeaveFeedback) ...[
              ElevatedButton.icon(
                onPressed: busy ? null : onOpenFeedback,
                icon: const Icon(CupertinoIcons.star_fill),
                label: const Text('Оставить / изменить отзыв'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: busy ? null : onOpenTask,
              icon: const Icon(CupertinoIcons.doc_text),
              label: const Text('Открыть задачу'),
            ),
          ],
        ],
      ),
    );
  }
}
