// lib/pages/task_details_page.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/prepayment_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;

  const TaskDetailsPage({required this.taskId, Key? key}) : super(key: key);

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  bool _loading = true;
  bool _silentRefreshing = false;
  bool _requestingPayment = false;
  String? _error;

  Timer? _refreshDebounce;

  String? _title;
  String? _deadline;
  String? _status;
  String? _paymentStatus;
  String? _estimatedTime;
  String? _timeSpent;
  double _paymentAmount = 0;
  int? _complexityFinal;
  String? _complexitySource;

  String? _orderId;
  String? _customerId;
  String? _customerName;
  String? _customerPhoto;
  String? _executorId;
  String? _executorName;
  String? _executorPhoto;

  String? _paymentRequestId;
  String? _paymentRequestStatus;
  String? _paymentRequestType;

  bool _prepaymentRequired = false;
  bool _prepaymentPaid = false;
  bool _hasApprovedFinalPayment = false;
  double _prepaymentPaidAmount = 0;
  int _prepaymentPercent = PrepaymentService.defaultPercent;

  bool _canLeaveFeedback = false;
  bool _feedbackAlreadyLeft = false;
  String? _feedbackTargetName;
  String? _feedbackTargetRole;
  String? _feedbackReviewType;
  String? _feedbackTargetUserId;

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
    pb.collection('tasks').unsubscribe('*');
    pb.collection('orders').unsubscribe('*');
    pb.collection('payment_requests').unsubscribe('*');
    pb.collection('payment_statuses').unsubscribe('*');
    pb.collection('task_statuses').unsubscribe('*');
    pb.collection('feedbacks').unsubscribe('*');

    super.dispose();
  }

  Future<void> _subscribeRealtime() async {
    final pb = PocketBaseService.instance.pb;

    Future<void> onAnyChange(dynamic _) async {
      _scheduleSilentRefresh();
    }

    await pb.collection('tasks').subscribe('*', onAnyChange);
    await pb.collection('orders').subscribe('*', onAnyChange);
    await pb.collection('payment_requests').subscribe('*', onAnyChange);
    await pb.collection('payment_statuses').subscribe('*', onAnyChange);
    await pb.collection('task_statuses').subscribe('*', onAnyChange);
    await pb.collection('feedbacks').subscribe('*', onAnyChange);
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

  Future<String?> _firstIdFromCollection(
    String collection,
    List<String> preferredNames,
  ) async {
    final result = await PocketBaseService.instance.pb
        .collection(collection)
        .getList(page: 1, perPage: 200);

    if (result.items.isEmpty) return null;

    for (final name in preferredNames) {
      for (final item in result.items) {
        final itemName =
            (item.data['name'] as String? ?? '').trim().toLowerCase();

        if (itemName == name.trim().toLowerCase()) {
          return item.id;
        }
      }
    }

    return result.items.first.id;
  }

  Future<void> _loadAll({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await _loadDrawerData();
      await _loadDetail();
      await _loadPaymentRequest();
      await _loadFeedbackState();

      if (!mounted) return;

      setState(() {
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Ошибка загрузки задачи: $e';
      });
    } finally {
      if (mounted && showLoader) {
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
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';

    _photo = PocketBaseFileService.fileUrl(
      collectionName: 'users',
      recordId: user.id,
      fileValue: user.data['photo'],
    );
  }

  Future<void> _loadDetail() async {
    final pb = PocketBaseService.instance.pb;

    final task = await pb.collection('tasks').getOne(widget.taskId);

    _orderId = _relationId(task.data['order_id']);
    _executorId = _relationId(task.data['executor_id']);

    final statusId = _relationId(task.data['status_id']);
    final paymentStatusId = _relationId(task.data['payment_status_id']);

    final order = await _getRecordData('orders', _orderId);
    final status = await _getRecordData('task_statuses', statusId);
    final paymentStatus = await _getRecordData(
      'payment_statuses',
      paymentStatusId,
    );

    _customerId = _relationId(order?['customer_id']);
    _title = order?['task_description'] as String? ?? '—';

    final customer = await _getRecordData('users', _customerId);
    final executor = await _getRecordData('users', _executorId);

    _customerName =
        customer?['name'] as String? ??
        customer?['email'] as String? ??
        'Заказчик';

    _customerPhoto =
        _customerId == null
            ? null
            : PocketBaseFileService.fileUrl(
              collectionName: 'users',
              recordId: _customerId!,
              fileValue: customer?['photo'],
            );

    _executorName =
        executor?['name'] as String? ??
        executor?['email'] as String? ??
        'Исполнитель';

    _executorPhoto =
        _executorId == null
            ? null
            : PocketBaseFileService.fileUrl(
              collectionName: 'users',
              recordId: _executorId!,
              fileValue: executor?['photo'],
            );

    final rawDeadline = order?['deadline'] as String?;
    final parsedDeadline = DateTime.tryParse(rawDeadline ?? '');

    _deadline =
        parsedDeadline == null
            ? '—'
            : DateFormat('dd.MM.yyyy').format(parsedDeadline.toLocal());

    _status = status?['name'] as String? ?? '—';
    _paymentStatus = paymentStatus?['name'] as String? ?? '—';

    _estimatedTime = '${task.data['estimated_time']?.toString() ?? '0'}ч';
    _timeSpent = '${task.data['time_spent']?.toString() ?? '0'}ч';
    _paymentAmount = ((task.data['payment_amount'] as num?) ?? 0).toDouble();
    _complexityFinal = (task.data['complexity_final'] as num?)?.toInt();
    _complexitySource = task.data['complexity_source'] as String?;
    _prepaymentRequired = PrepaymentService.taskRequiresPrepayment(task.data);
    _prepaymentPercent = PrepaymentService.resolvePercent({
      'prepayment_percent':
          task.data['prepayment_percent'] ?? order?['prepayment_percent'],
    });
  }

  Future<void> _loadPaymentRequest() async {
    final pb = PocketBaseService.instance.pb;

    _paymentRequestId = null;
    _paymentRequestStatus = null;
    _paymentRequestType = null;
    _prepaymentPaidAmount = 0;
    _prepaymentPaid = false;
    _hasApprovedFinalPayment = false;

    final result = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    final requests =
        result.items.where((request) {
          final taskId = _relationId(request.data['task_id']);
          return taskId == widget.taskId;
        }).toList();

    if (requests.isEmpty) return;

    for (final request in requests) {
      final type = PrepaymentService.normalizedPaymentType(
        request.data['payment_type'],
      );
      final status =
          request.data['status']?.toString().trim().toLowerCase() ?? '';
      final amount = ((request.data['payment_amount'] as num?) ?? 0).toDouble();

      if (type == 'prepayment' && status == 'approved') {
        _prepaymentPaidAmount += amount;
      }

      if (type == 'final' && status == 'approved') {
        _hasApprovedFinalPayment = true;
      }
    }

    _prepaymentPaidAmount = double.parse(
      _prepaymentPaidAmount.toStringAsFixed(2),
    );
    _prepaymentPaid = _prepaymentPaidAmount > 0;

    final pendingRequests =
        requests
            .where(
              (request) =>
                  (request.data['status']?.toString().trim().toLowerCase() ??
                      '') ==
                  'pending',
            )
            .toList();

    pendingRequests.sort((a, b) {
      final da = DateTime.tryParse(a.get<String>('created') ?? '');
      final db = DateTime.tryParse(b.get<String>('created') ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    if (pendingRequests.isEmpty) return;

    final request = pendingRequests.first;

    _paymentRequestId = request.id;
    _paymentRequestStatus = 'pending';
    _paymentRequestType = PrepaymentService.normalizedPaymentType(
      request.data['payment_type'],
    );
  }

  Future<void> _requestPayment() async {
    if (_requestingPayment) return;

    setState(() => _requestingPayment = true);

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      if (_executorId != userId) {
        throw 'Запросить оплату может только исполнитель задачи';
      }

      await _loadPaymentRequest();
      await _loadFeedbackState();

      if (_paymentRequestStatus == 'pending') {
        throw 'Запрос оплаты уже ожидает решения заказчика';
      }

      if (_isFullyPaid) {
        throw 'Оплата уже подтверждена';
      }

      if (_prepaymentRequired && !_prepaymentPaid) {
        throw 'Сначала заказчик должен внести предоплату';
      }

      if (_prepaymentRequired && _hasApprovedFinalPayment) {
        throw 'Финальная оплата уже подтверждена';
      }

      final pendingStatusId = await _firstIdFromCollection('payment_statuses', [
        'pending',
      ]);

      final paymentAmount =
          _prepaymentRequired && _prepaymentPaid
              ? PrepaymentService.remainingAmount(
                totalPrice: _paymentAmount,
                prepaymentPaid: _prepaymentPaidAmount,
              )
              : _paymentAmount;

      if (paymentAmount <= 0) {
        throw 'Сумма финальной оплаты должна быть больше нуля';
      }

      final request = await service.pb
          .collection('payment_requests')
          .create(
            body: {
              'task_id': widget.taskId,
              'requested_by': userId,
              'status': 'pending',
              'payment_amount': paymentAmount,
              'payment_type': 'final',
            },
          );

      await service.pb
          .collection('tasks')
          .update(
            widget.taskId,
            body: {
              if (pendingStatusId != null) 'payment_status_id': pendingStatusId,
            },
          );

      _paymentRequestId = request.id;
      _paymentRequestStatus = 'pending';
      _paymentRequestType = 'final';

      await _loadAll(showLoader: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _prepaymentRequired
                ? 'Запрос финальной оплаты отправлен заказчику'
                : 'Запрос оплаты отправлен заказчику',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка запроса оплаты: $e')));
    } finally {
      if (mounted) {
        setState(() => _requestingPayment = false);
      }
    }
  }

  Future<void> _openPaymentPage() async {
    final id = _paymentRequestId;
    if (id == null) return;

    final result = await context.push('/payments/mock/$id');

    if (result == true) {
      await _loadAll();
    }
  }

  Future<void> _loadFeedbackState() async {
    _canLeaveFeedback = false;
    _feedbackAlreadyLeft = false;
    _feedbackTargetName = null;
    _feedbackTargetRole = null;
    _feedbackReviewType = null;
    _feedbackTargetUserId = null;

    if (!_isPaid || _orderId == null) return;

    final currentUserId = PocketBaseService.instance.currentUserId;
    if (currentUserId == null) return;

    String? targetUserId;
    String? targetRole;
    String? reviewType;

    if (currentUserId == _customerId && _executorId != null) {
      targetUserId = _executorId;
      targetRole = 'исполнителю';
      reviewType = 'customer_to_executor';
    } else if (currentUserId == _executorId && _customerId != null) {
      targetUserId = _customerId;
      targetRole = 'заказчику';
      reviewType = 'executor_to_customer';
    } else {
      return;
    }

    final targetUser = await _getRecordData('users', targetUserId);

    final feedbacks = await PocketBaseService.instance.pb
        .collection('feedbacks')
        .getList(page: 1, perPage: 200);

    for (final feedback in feedbacks.items) {
      final orderId = _relationId(feedback.data['order_id']);
      final reviewerId = _relationId(feedback.data['reviewer_id']);
      final reviewedUserId = _relationId(feedback.data['reviewed_user_id']);
      final type = feedback.data['type']?.toString();

      final sameLegacyFeedback =
          orderId == _orderId && reviewerId == currentUserId;

      final sameNewFeedback =
          orderId == _orderId &&
          reviewerId == currentUserId &&
          reviewedUserId == targetUserId &&
          type == reviewType;

      if (sameNewFeedback || sameLegacyFeedback) {
        _feedbackAlreadyLeft = true;
        break;
      }
    }

    _canLeaveFeedback = true;
    _feedbackTargetRole = targetRole;
    _feedbackReviewType = reviewType;
    _feedbackTargetUserId = targetUserId;
    _feedbackTargetName =
        targetUser?['name'] as String? ??
        targetUser?['email'] as String? ??
        'пользователю';
  }

  Future<void> _openFeedbackPage() async {
    final result = await context.push('/feedbacks/task/${widget.taskId}');

    if (result == true) {
      await _loadAll();
    }
  }

  void _openCustomerProfile() {
    final id = _customerId;
    if (id == null || id.isEmpty) return;

    context.push('/account/$id');
  }

  void _openExecutorProfile() {
    final id = _executorId;
    if (id == null || id.isEmpty) return;

    context.push('/account/$id');
  }

  bool get _isFullyPaid {
    if (_prepaymentRequired) {
      return _hasApprovedFinalPayment;
    }

    return _isLegacyPaid;
  }

  bool get _isLegacyPaid {
    final status = (_paymentStatus ?? '').trim().toLowerCase();
    final requestStatus = (_paymentRequestStatus ?? '').trim().toLowerCase();

    return status == 'paid' ||
        status == 'approved' ||
        requestStatus == 'approved';
  }

  bool get _isPaid => _isFullyPaid;

  bool get _awaitingPrepayment {
    return _prepaymentRequired && !_prepaymentPaid;
  }

  bool get _hasPendingPaymentRequest {
    return _paymentRequestStatus == 'pending';
  }

  bool get _hasPendingPrepaymentRequest {
    return _hasPendingPaymentRequest &&
        _paymentRequestType == 'prepayment';
  }

  bool get _isExecutorOwner {
    final currentUserId = PocketBaseService.instance.currentUserId;
    return currentUserId != null && currentUserId == _executorId;
  }

  bool get _isCustomerOwner {
    final currentUserId = PocketBaseService.instance.currentUserId;
    return currentUserId != null && currentUserId == _customerId;
  }

  String _complexityText() {
    final value = _complexityFinal;
    if (value == null) return '—';

    final normalized = value.clamp(1, 5).toInt();

    return '$normalized / 5 · ${OrderComplexityService.complexityLabel(normalized)}';
  }

  String _complexitySourceText() {
    return OrderComplexityService.sourceLabel(_complexitySource);
  }

  String _formatMoney(double value) {
    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  AppStatusPill _taskStatusPill() {
    final status = (_status ?? '—').trim().toLowerCase();

    if (status == 'done' || status == 'completed') {
      return AppStatusPill.success(_status ?? 'done');
    }

    if (status == 'in_progress' || status == 'progress') {
      return AppStatusPill.pending(_status ?? 'in_progress');
    }

    return AppStatusPill(
      text: _status ?? '—',
      color: AppColors.textMuted,
      icon: CupertinoIcons.circle,
    );
  }

  AppStatusPill _paymentStatusPill() {
    final status = (_paymentStatus ?? '—').trim().toLowerCase();

    if (_isFullyPaid || status == 'paid' || status == 'approved') {
      return AppStatusPill.success('Оплата подтверждена');
    }

    if (_awaitingPrepayment ||
        status == 'awaiting_prepayment' ||
        _hasPendingPrepaymentRequest) {
      return AppStatusPill.pending('Ожидает предоплаты');
    }

    if (_prepaymentPaid && !_isFullyPaid) {
      return AppStatusPill.pending('Предоплата внесена');
    }

    if (_hasPendingPaymentRequest || status == 'pending') {
      return AppStatusPill.pending('Ожидает оплаты');
    }

    if (status == 'rejected') {
      return AppStatusPill.error('Оплата отклонена');
    }

    return AppStatusPill(
      text: _paymentStatus ?? '—',
      color: AppColors.textMuted,
      icon: CupertinoIcons.creditcard,
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        title: 'Детали задачи',
                        subtitle: 'Статус, сложность, оплата и чат',
                        onBack: _goBack,
                        onRefresh: _loadAll,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadAll,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            children: [
                              _TaskMainCard(
                                title: _title ?? '—',
                                deadline: _deadline ?? '—',
                                taskStatus: _taskStatusPill(),
                                paymentStatus: _paymentStatusPill(),
                                amount: _formatMoney(_paymentAmount),
                              ),
                              const SizedBox(height: 12),
                              _TaskParticipantsCard(
                                customerName: _customerName ?? 'Заказчик',
                                customerPhoto: _customerPhoto,
                                executorName: _executorName ?? 'Исполнитель',
                                executorPhoto: _executorPhoto,
                                onOpenCustomer:
                                    _customerId == null
                                        ? null
                                        : _openCustomerProfile,
                                onOpenExecutor:
                                    _executorId == null
                                        ? null
                                        : _openExecutorProfile,
                              ),
                              const SizedBox(height: 12),
                              _TaskMetricsCard(
                                estimatedTime: _estimatedTime ?? '—',
                                timeSpent: _timeSpent ?? '—',
                                paymentRequestStatus:
                                    _paymentRequestStatus ?? 'запроса нет',
                                paymentStatus: _paymentStatus ?? '—',
                                complexityText: _complexityText(),
                                complexitySourceText: _complexitySourceText(),
                              ),
                              const SizedBox(height: 12),
                              _TaskActionsCard(
                                requestingPayment: _requestingPayment,
                                isPaid: _isFullyPaid,
                                hasPendingPaymentRequest:
                                    _hasPendingPaymentRequest,
                                awaitingPrepayment: _awaitingPrepayment,
                                prepaymentRequired: _prepaymentRequired,
                                prepaymentPaid: _prepaymentPaid,
                                paymentRequestType: _paymentRequestType,
                                isExecutorOwner: _isExecutorOwner,
                                isCustomerOwner: _isCustomerOwner,
                                canLeaveFeedback: _canLeaveFeedback,
                                feedbackAlreadyLeft: _feedbackAlreadyLeft,
                                feedbackTargetName: _feedbackTargetName,
                                feedbackTargetRole: _feedbackTargetRole,
                                onOpenChat: () {
                                  context.push(
                                    '/tasks/communication/${widget.taskId}',
                                  );
                                },
                                onRequestPayment: _requestPayment,
                                onOpenPayment: _openPaymentPage,
                                onOpenFeedback: _openFeedbackPage,
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

class _TaskMainCard extends StatelessWidget {
  final String title;
  final String deadline;
  final AppStatusPill taskStatus;
  final AppStatusPill paymentStatus;
  final String amount;

  const _TaskMainCard({
    required this.title,
    required this.deadline,
    required this.taskStatus,
    required this.paymentStatus,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Задача'),
          const SizedBox(height: 12),
          Text(
            title.trim().isEmpty ? 'Без описания' : title,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [taskStatus, paymentStatus],
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
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskParticipantsCard extends StatelessWidget {
  final String customerName;
  final String? customerPhoto;
  final String executorName;
  final String? executorPhoto;
  final VoidCallback? onOpenCustomer;
  final VoidCallback? onOpenExecutor;

  const _TaskParticipantsCard({
    required this.customerName,
    required this.customerPhoto,
    required this.executorName,
    required this.executorPhoto,
    required this.onOpenCustomer,
    required this.onOpenExecutor,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Участники'),
          const SizedBox(height: 12),
          _ParticipantRow(
            name: customerName,
            role: 'Заказчик',
            avatarUrl: customerPhoto,
            onOpenProfile: onOpenCustomer,
          ),
          const SizedBox(height: 10),
          _ParticipantRow(
            name: executorName,
            role: 'Исполнитель',
            avatarUrl: executorPhoto,
            onOpenProfile: onOpenExecutor,
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final String name;
  final String role;
  final String? avatarUrl;
  final VoidCallback? onOpenProfile;

  const _ParticipantRow({
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onOpenProfile,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      radius: AppRadii.sm,
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? role : name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(role, style: AppTextStyles.caption),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Профиль',
            onPressed: onOpenProfile,
            icon: Icon(
              onOpenProfile == null
                  ? CupertinoIcons.person_crop_circle_badge_exclam
                  : CupertinoIcons.person_crop_circle,
              color:
                  onOpenProfile == null
                      ? AppColors.textMuted
                      : AppColors.accent,
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _TaskMetricsCard extends StatelessWidget {
  final String estimatedTime;
  final String timeSpent;
  final String paymentRequestStatus;
  final String paymentStatus;
  final String complexityText;
  final String complexitySourceText;

  const _TaskMetricsCard({
    required this.estimatedTime,
    required this.timeSpent,
    required this.paymentRequestStatus,
    required this.paymentStatus,
    required this.complexityText,
    required this.complexitySourceText,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Параметры'),
          const SizedBox(height: 12),
          _InfoRow(
            icon: CupertinoIcons.timer,
            label: 'Оценка времени',
            value: estimatedTime,
          ),
          _InfoRow(
            icon: CupertinoIcons.time,
            label: 'Потрачено',
            value: timeSpent,
          ),
          _InfoRow(
            icon: Icons.bar_chart_rounded,
            label: 'Сложность',
            value: complexityText,
          ),
          _InfoRow(
            icon: Icons.tune_rounded,
            label: 'Источник оценки',
            value: complexitySourceText,
          ),
          _InfoRow(
            icon: CupertinoIcons.creditcard,
            label: 'Статус оплаты',
            value: paymentStatus,
          ),
          _InfoRow(
            icon: CupertinoIcons.doc_text,
            label: 'Запрос оплаты',
            value: paymentRequestStatus,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TaskActionsCard extends StatelessWidget {
  final bool requestingPayment;
  final bool isPaid;
  final bool hasPendingPaymentRequest;
  final bool awaitingPrepayment;
  final bool prepaymentRequired;
  final bool prepaymentPaid;
  final String? paymentRequestType;
  final bool isExecutorOwner;
  final bool isCustomerOwner;
  final bool canLeaveFeedback;
  final bool feedbackAlreadyLeft;
  final String? feedbackTargetName;
  final String? feedbackTargetRole;
  final VoidCallback onOpenChat;
  final VoidCallback onRequestPayment;
  final VoidCallback onOpenPayment;
  final VoidCallback onOpenFeedback;

  const _TaskActionsCard({
    required this.requestingPayment,
    required this.isPaid,
    required this.hasPendingPaymentRequest,
    required this.awaitingPrepayment,
    required this.prepaymentRequired,
    required this.prepaymentPaid,
    required this.paymentRequestType,
    required this.isExecutorOwner,
    required this.isCustomerOwner,
    required this.canLeaveFeedback,
    required this.feedbackAlreadyLeft,
    required this.feedbackTargetName,
    required this.feedbackTargetRole,
    required this.onOpenChat,
    required this.onRequestPayment,
    required this.onOpenPayment,
    required this.onOpenFeedback,
  });

  String get _feedbackButtonText {
    if (feedbackAlreadyLeft) {
      return 'Изменить отзыв';
    }

    final targetRole = feedbackTargetRole?.trim();

    if (targetRole == null || targetRole.isEmpty) {
      return 'Оставить отзыв';
    }

    return 'Оставить отзыв $targetRole';
  }

  String get _feedbackHintText {
    if (feedbackAlreadyLeft) {
      return 'Отзыв уже есть. Можно открыть форму и обновить оценку.';
    }

    final targetName = feedbackTargetName?.trim();

    if (targetName == null || targetName.isEmpty) {
      return 'Отзыв будет доступен после подтверждения оплаты.';
    }

    return 'Получатель: $targetName';
  }

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: 'Действия'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onOpenChat,
            icon: const Icon(CupertinoIcons.chat_bubble_2),
            label: const Text('Открыть чат'),
          ),
          if (isExecutorOwner && awaitingPrepayment) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Работа начнётся после предоплаты от заказчика.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
          if (isExecutorOwner && !isPaid && !awaitingPrepayment) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed:
                  requestingPayment || hasPendingPaymentRequest
                      ? null
                      : onRequestPayment,
              icon:
                  requestingPayment
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.payments_rounded),
              label: Text(
                hasPendingPaymentRequest
                    ? 'Запрос оплаты ожидает заказчика'
                    : prepaymentRequired && prepaymentPaid
                    ? 'Запросить финальную оплату'
                    : 'Запросить оплату',
              ),
            ),
          ],
          if (isCustomerOwner && hasPendingPaymentRequest) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onOpenPayment,
              icon: const Icon(Icons.account_balance_rounded),
              label: Text(
                paymentRequestType == 'prepayment'
                    ? 'Оплатить предоплату'
                    : 'Оплатить через банк',
              ),
            ),
          ],
          if (isPaid) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(CupertinoIcons.check_mark_circled),
              label: const Text('Оплата подтверждена'),
            ),
          ],
          if (canLeaveFeedback) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onOpenFeedback,
              icon: Icon(
                feedbackAlreadyLeft
                    ? CupertinoIcons.pencil
                    : CupertinoIcons.star_fill,
              ),
              label: Text(_feedbackButtonText),
            ),
            const SizedBox(height: 6),
            Text(
              _feedbackHintText,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.small)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.small.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
