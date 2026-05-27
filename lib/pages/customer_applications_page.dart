// lib/pages/customer_applications_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

enum _ReqType { application, payment }

class _ReqItem {
  final String id;
  final _ReqType type;
  final String title;
  final String actorName;
  final String? actorPhoto;
  final String status;
  final DateTime createdAt;
  final double? amount;
  final String? orderId;
  final String? executorId;
  final String? taskId;
  final int? complexityAuto;
  final int? complexityProposed;
  final String? complexityReason;

  _ReqItem({
    required this.id,
    required this.type,
    required this.title,
    required this.actorName,
    this.actorPhoto,
    required this.status,
    required this.createdAt,
    this.amount,
    this.orderId,
    this.executorId,
    this.taskId,
    this.complexityAuto,
    this.complexityProposed,
    this.complexityReason,
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

  String _status(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status == 'approved' || status == 'rejected' || status == 'pending') {
      return status!;
    }

    return 'pending';
  }

  bool _isPending(String status) {
    return status.trim().toLowerCase() == 'pending';
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

  Future<String?> _taskIdForOrder(String orderId) async {
    final result = await PocketBaseService.instance.pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final tasks =
        result.items.where((task) {
          final taskOrderId = _relationId(task.data['order_id']);
          return taskOrderId == orderId;
        }).toList();

    if (tasks.isEmpty) return null;

    tasks.sort((a, b) {
      final da = DateTime.tryParse(a.get<String>('created') ?? '');
      final db = DateTime.tryParse(b.get<String>('created') ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    return tasks.first.id;
  }

  Future<void> _rejectOtherApplicationsForOrder({
    required String orderId,
    required String acceptedApplicationId,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final apps = await pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    for (final app in apps.items) {
      if (app.id == acceptedApplicationId) continue;

      final appOrderId = _relationId(app.data['order_id']);
      final appStatus = _status(app.data['status']);

      if (appOrderId == orderId && appStatus == 'pending') {
        await pb
            .collection('applications')
            .update(app.id, body: {'status': 'rejected'});
      }
    }
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
        throw 'Р СњР ВµР В°Р Р†РЎвЂљР С•РЎР‚Р С‘Р В·Р С•Р Р†Р В°Р Р…';
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
      _error = 'Р СњР Вµ РЎС“Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С‘РЎвЂљРЎРЉ Р В·Р В°РЎРЏР Р†Р С”Р С‘ Р С‘ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№: $e';
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
      final complexityAuto = (order['complexity_auto'] as num?)?.toInt();
      final complexityProposed =
          (app.data['complexity_proposed'] as num?)?.toInt() ?? complexityAuto;
      final complexityReason = app.data['complexity_reason'] as String? ?? '';

      loaded.add(
        _ReqItem(
          id: app.id,
          type: _ReqType.application,
          title: order['task_description'] as String? ?? 'РІР‚вЂќ',
          actorName:
              executor?['name'] as String? ??
              executor?['email'] as String? ??
              'Р ВРЎРѓР С—Р С•Р В»Р Р…Р С‘РЎвЂљР ВµР В»РЎРЉ',
          actorPhoto: _userPhotoUrl(executor),
          status: _status(app.data['status']),
          createdAt:
              DateTime.tryParse(app.get<String>('created') ?? '')?.toLocal() ??
              DateTime.now(),
          amount: (order['price'] as num?)?.toDouble(),
          orderId: orderId,
          executorId: executorId,
          taskId: taskId,
          complexityAuto: complexityAuto,
          complexityProposed: complexityProposed,
          complexityReason: complexityReason,
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

      final complexityFinal = (task['complexity_final'] as num?)?.toInt();

      final requestedById = _relationId(payment.data['requested_by']);
      final requestedBy = await _getRecordData('users', requestedById);

      loaded.add(
        _ReqItem(
          id: payment.id,
          type: _ReqType.payment,
          title: order['task_description'] as String? ?? 'РІР‚вЂќ',
          actorName:
              requestedBy?['name'] as String? ??
              requestedBy?['email'] as String? ??
              'Р ВРЎРѓР С—Р С•Р В»Р Р…Р С‘РЎвЂљР ВµР В»РЎРЉ',
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
        ),
      );
    }
  }

  Future<void> _acceptItem(_ReqItem item) async {
    if (item.type == _ReqType.payment) {
      await _openPayment(item);
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
        _error = 'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р С•РЎвЂљР С”РЎР‚РЎвЂ№РЎвЂљР С‘РЎРЏ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№: $e';
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
      final pb = PocketBaseService.instance.pb;
      final newStatus = accept ? 'approved' : 'rejected';

      if (item.type == _ReqType.application) {
        await _decideApplication(pb, item, newStatus, accept);
      } else {
        await _decidePayment(pb, item, newStatus, accept);
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р С•Р В±РЎР‚Р В°Р В±Р С•РЎвЂљР С”Р С‘ Р В·Р В°РЎРЏР Р†Р С”Р С‘: $e';
      });
    }
  }

  Future<void> _decideApplication(
    dynamic pb,
    _ReqItem item,
    String newStatus,
    bool accept,
  ) async {
    await pb
        .collection('applications')
        .update(item.id, body: {'status': newStatus});

    if (!accept) return;

    if (item.orderId == null || item.executorId == null) {
      throw 'Р СњР ВµРЎвЂљ orderId Р С‘Р В»Р С‘ executorId';
    }

    final order = await _getRecordData('orders', item.orderId);
    final currentExecutorId = _relationId(order?['executor_id']);

    if (currentExecutorId != null && currentExecutorId != item.executorId) {
      throw 'Р вЂ”Р В°Р С”Р В°Р В· РЎС“Р В¶Р Вµ Р Р…Р В°Р В·Р Р…Р В°РЎвЂЎР ВµР Р… Р Т‘РЎР‚РЎС“Р С–Р С•Р СРЎС“ Р С‘РЎРѓР С—Р С•Р В»Р Р…Р С‘РЎвЂљР ВµР В»РЎР‹';
    }

    await pb
        .collection('orders')
        .update(item.orderId!, body: {'executor_id': item.executorId});

    await _rejectOtherApplicationsForOrder(
      orderId: item.orderId!,
      acceptedApplicationId: item.id,
    );

    final existingTaskId = await _taskIdForOrder(item.orderId!);
    if (existingTaskId != null) return;

    final statusId = await _firstIdFromCollection('task_statuses', [
      'new',
      'pending',
      'created',
    ]);

    final paymentStatusId = await _firstIdFromCollection('payment_statuses', [
      'none',
      'pending',
      'unpaid',
    ]);
    final orderComplexityAuto = (order?['complexity_auto'] as num?)?.toInt();
    final proposedComplexity =
        item.complexityProposed ?? item.complexityAuto ?? orderComplexityAuto;
    final complexityFinal =
        proposedComplexity == null
            ? null
            : proposedComplexity.clamp(1, 5).toInt();
    final complexitySource =
        complexityFinal != null &&
                orderComplexityAuto != null &&
                complexityFinal != orderComplexityAuto
            ? 'executor_adjusted'
            : 'auto';

    await pb
        .collection('tasks')
        .create(
          body: {
            'order_id': item.orderId,
            'executor_id': item.executorId,
            if (statusId != null) 'status_id': statusId,
            if (paymentStatusId != null) 'payment_status_id': paymentStatusId,
            'estimated_time': 0,
            'time_spent': 0,
            'payment_amount': item.amount ?? 0,
            if (complexityFinal != null) 'complexity_final': complexityFinal,
            if (complexityFinal != null) 'complexity_source': complexitySource,
          },
        );
  }

  Future<void> _decidePayment(
    dynamic pb,
    _ReqItem item,
    String newStatus,
    bool accept,
  ) async {
    await pb
        .collection('payment_requests')
        .update(item.id, body: {'status': newStatus});

    if (!accept || item.taskId == null) return;

    final paidStatusId = await _firstIdFromCollection('payment_statuses', [
      'paid',
      'approved',
      'done',
    ]);

    await pb
        .collection('tasks')
        .update(
          item.taskId!,
          body: {if (paidStatusId != null) 'payment_status_id': paidStatusId},
        );
  }

  void _openTaskDetails(_ReqItem item) {
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty) return;

    context.push('/tasks/details/$taskId');
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
            title: const Text('Р С›РЎвЂљР С”Р В»Р С•Р Р…Р С‘РЎвЂљРЎРЉ Р Р†РЎРѓР Вµ Р С•Р В¶Р С‘Р Т‘Р В°РЎР‹РЎвЂ°Р С‘Р Вµ Р В·Р В°РЎРЏР Р†Р С”Р С‘?'),
            content: const Text(
              'Р вЂ™РЎРѓР Вµ pending-Р В·Р В°РЎРЏР Р†Р С”Р С‘ Р С‘ pending-Р В·Р В°Р С—РЎР‚Р С•РЎРѓРЎвЂ№ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№ Р В±РЎС“Р Т‘РЎС“РЎвЂљ Р С•РЎвЂљР С”Р В»Р С•Р Р…Р ВµР Р…РЎвЂ№.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Р С›РЎвЂљР СР ВµР Р…Р В°'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Р С›РЎвЂљР С”Р В»Р С•Р Р…Р С‘РЎвЂљРЎРЉ'),
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
      final pb = PocketBaseService.instance.pb;

      for (final item in _items.where((e) => _isPending(e.status))) {
        final collection =
            item.type == _ReqType.application
                ? 'applications'
                : 'payment_requests';

        await pb
            .collection(collection)
            .update(item.id, body: {'status': 'rejected'});
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busyItemId = null;
        _error = 'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р С•РЎвЂљР С”Р В»Р С•Р Р…Р ВµР Р…Р С‘РЎРЏ Р В·Р В°РЎРЏР Р†Р С•Р С”: $e';
      });
    }
  }

  Future<void> _selectSort() async {
    await showAppBottomSheet(
      context: context,
      title: 'Р РЋР С•РЎР‚РЎвЂљР С‘РЎР‚Р С•Р Р†Р С”Р В°',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          AppBottomSheetOption(
            title: 'Р СњР С•Р Р†РЎвЂ№Р Вµ',
            selected: _sortNewest,
            onTap: () {
              Navigator.pop(context);
              setState(() => _sortNewest = true);
              _loadAll();
            },
          ),
          AppBottomSheetOption(
            title: 'Р РЋРЎвЂљР В°РЎР‚РЎвЂ№Р Вµ',
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

  int get _pendingCount {
    return _items.where((item) => _isPending(item.status)).length;
  }

  int get _applicationsCount {
    return _items.where((item) => item.type == _ReqType.application).length;
  }

  int get _paymentsCount {
    return _items.where((item) => item.type == _ReqType.payment).length;
  }

  String _typeLabel(_ReqType type) {
    return type == _ReqType.application ? 'Р вЂ”Р В°РЎРЏР Р†Р С”Р В° Р Р…Р В° Р В·Р В°Р С”Р В°Р В·' : 'Р вЂ”Р В°Р С—РЎР‚Р С•РЎРѓ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№';
  }

  IconData _typeIcon(_ReqType type) {
    return type == _ReqType.application
        ? Icons.assignment_ind_outlined
        : Icons.payments_rounded;
  }

  String _positiveButtonText(_ReqItem item) {
    return item.type == _ReqType.payment ? 'Р С›Р С—Р В»Р В°РЎвЂљР С‘РЎвЂљРЎРЉ' : 'Р СџРЎР‚Р С‘Р Р…РЎРЏРЎвЂљРЎРЉ';
  }

  String _formatMoney(double? amount) {
    final value = amount ?? 0;

    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} РІвЂљР…';
    }

    return '${value.toStringAsFixed(2)} РІвЂљР…';
  }

  AppStatusPill _statusPill(_ReqItem item) {
    if (item.status == 'approved') {
      return AppStatusPill.success(
        item.type == _ReqType.payment ? 'Р С›Р С—Р В»Р В°РЎвЂЎР ВµР Р…Р С•' : 'Р СџРЎР‚Р С‘Р Р…РЎРЏРЎвЂљР С•',
      );
    }

    if (item.status == 'rejected') {
      return AppStatusPill.error('Р С›РЎвЂљР С”Р В»Р С•Р Р…Р ВµР Р…Р С•');
    }

    return AppStatusPill.pending('Р С›Р В¶Р С‘Р Т‘Р В°Р ВµРЎвЂљ РЎР‚Р ВµРЎв‚¬Р ВµР Р…Р С‘РЎРЏ');
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _pendingCount > 0;
    final pageBusy = _busyItemId != null;

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
                        title: 'Р вЂ”Р В°РЎРЏР Р†Р С”Р С‘ Р С‘ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№',
                        subtitle: 'Р С›РЎвЂљР С”Р В»Р С‘Р С”Р С‘ Р С‘РЎРѓР С—Р С•Р В»Р Р…Р С‘РЎвЂљР ВµР В»Р ВµР в„– Р С‘ Р В·Р В°Р С—РЎР‚Р С•РЎРѓРЎвЂ№ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№',
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
                                    name: _displayName ?? 'Р вЂ”Р В°Р С”Р В°Р В·РЎвЂЎР С‘Р С”',
                                    avatarUrl: _photo,
                                    totalCount: _items.length,
                                    applicationsCount: _applicationsCount,
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
                                              _sortNewest ? 'Р СњР С•Р Р†РЎвЂ№Р Вµ' : 'Р РЋРЎвЂљР В°РЎР‚РЎвЂ№Р Вµ',
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
                                                    ? 'Р С›РЎвЂљР С”Р В»Р С•Р Р…РЎРЏР ВµР С...'
                                                    : 'Р С›РЎвЂљР С”Р В»Р С•Р Р…Р С‘РЎвЂљРЎРЉ Р Р†РЎРѓР Вµ',
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
                                  8,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: AppSectionHeader(
                                    title: 'Р РЋР С—Р С‘РЎРѓР С•Р С”',
                                    count: _items.length,
                                  ),
                                ),
                              ),
                              if (_items.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon: CupertinoIcons.tray,
                                    title: 'Р вЂ”Р В°РЎРЏР Р†Р С•Р С” Р С—Р С•Р С”Р В° Р Р…Р ВµРЎвЂљ',
                                    subtitle:
                                        'Р С™Р С•Р С–Р Т‘Р В° Р С‘РЎРѓР С—Р С•Р В»Р Р…Р С‘РЎвЂљР ВµР В»РЎРЉ Р С—Р С•Р Т‘Р В°РЎРѓРЎвЂљ Р В·Р В°РЎРЏР Р†Р С”РЎС“ Р С‘Р В»Р С‘ Р В·Р В°Р С—РЎР‚Р С•РЎРѓР С‘РЎвЂљ Р С•Р С—Р В»Р В°РЎвЂљРЎС“, Р В·Р В°Р С—Р С‘РЎРѓРЎРЉ Р С—Р С•РЎРЏР Р†Р С‘РЎвЂљРЎРѓРЎРЏ Р В·Р Т‘Р ВµРЎРѓРЎРЉ.',
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

                                      final itemIndex = index ~/ 2;
                                      final item = _items[itemIndex];

                                      return _RequestCard(
                                        item: item,
                                        busy: pageBusy,
                                        itemBusy: _busyItemId == item.id,
                                        typeLabel: _typeLabel(item.type),
                                        typeIcon: _typeIcon(item.type),
                                        statusPill: _statusPill(item),
                                        amountText: _formatMoney(item.amount),
                                        dateText: _fmt.format(item.createdAt),
                                        positiveButtonText: _positiveButtonText(
                                          item,
                                        ),
                                        onAccept: () => _acceptItem(item),
                                        onReject: () => _decide(item, false),
                                        onOpenTask:
                                            () => _openTaskDetails(item),
                                        onOpenFeedback:
                                            () => _openFeedbackForItem(item),
                                      );
                                    }, childCount: _items.length * 2 - 1),
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
  final int paymentsCount;
  final int pendingCount;

  const _ApplicationsOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.totalCount,
    required this.applicationsCount,
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
                    Text('Р вЂ”Р В°Р С”Р В°Р В·РЎвЂЎР С‘Р С”', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'requests',
                color: AppColors.accent,
                icon: CupertinoIcons.mail,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Р вЂ”Р Т‘Р ВµРЎРѓРЎРЉ Р С—РЎР‚Р С‘Р Р…Р С‘Р СР В°РЎР‹РЎвЂљРЎРѓРЎРЏ Р С‘РЎРѓР С—Р С•Р В»Р Р…Р С‘РЎвЂљР ВµР В»Р С‘ Р С‘ Р С•Р В±РЎР‚Р В°Р В±Р В°РЎвЂљРЎвЂ№Р Р†Р В°РЎР‹РЎвЂљРЎРѓРЎРЏ Р В·Р В°Р С—РЎР‚Р С•РЎРѓРЎвЂ№ Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№ Р С—Р С• Р В·Р В°Р Т‘Р В°РЎвЂЎР В°Р С.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Р вЂ™РЎРѓР ВµР С–Р С•',
                  value: totalCount.toString(),
                  icon: Icons.inbox_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Р вЂ”Р В°РЎРЏР Р†Р С”Р С‘',
                  value: applicationsCount.toString(),
                  icon: Icons.assignment_ind_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Р С›Р В¶Р С‘Р Т‘Р В°РЎР‹РЎвЂљ',
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
                  title: 'Р С›Р С—Р В»Р В°РЎвЂљРЎвЂ№',
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
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onOpenTask;
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
    required this.onAccept,
    required this.onReject,
    required this.onOpenTask,
    required this.onOpenFeedback,
  });

  bool get _pending => item.status == 'pending';
  bool get _approved => item.status == 'approved';
  bool get _hasTask => item.taskId != null && item.taskId!.isNotEmpty;
bool get _canLeaveFeedback =>
    item.type == _ReqType.payment && _approved && _hasTask;

  @override
  Widget build(BuildContext context) {
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
              Text(
                dateText,
                style: AppTextStyles.caption,
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title.trim().isEmpty ? 'Р вЂР ВµР В· Р С•Р С—Р С‘РЎРѓР В°Р Р…Р С‘РЎРЏ' : item.title,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              statusPill,
              if (item.type == _ReqType.payment)
                AppTag(icon: Icons.currency_ruble_rounded, label: amountText),
              if (item.complexityProposed != null)
                AppTag(
                  icon: Icons.bar_chart_rounded,
                  label:
                      'Р РЋР В»Р С•Р В¶Р Р…Р С•РЎРѓРЎвЂљРЎРЉ ${item.complexityProposed}/5 Р’В· ${OrderComplexityService.complexityLabel(item.complexityProposed)}',
                ),
              if (item.type == _ReqType.application &&
                  item.complexityAuto != null &&
                  item.complexityProposed != null &&
                  item.complexityAuto != item.complexityProposed)
                AppTag(
                  icon: Icons.tune_rounded,
                  label: 'Р РЋР С‘РЎРѓРЎвЂљР ВµР СР В° ${item.complexityAuto}/5',
                ),
              if (_hasTask)
                const AppTag(
                  icon: CupertinoIcons.doc_text,
                  label: 'Р вЂўРЎРѓРЎвЂљРЎРЉ Р В·Р В°Р Т‘Р В°РЎвЂЎР В°',
                ),
            ],
          ),
          if (item.type == _ReqType.application &&
              item.complexityReason != null &&
              item.complexityReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Р СџРЎР‚Р С‘РЎвЂЎР С‘Р Р…Р В° Р С‘Р В·Р СР ВµР Р…Р ВµР Р…Р С‘РЎРЏ РЎРѓР В»Р С•Р В¶Р Р…Р С•РЎРѓРЎвЂљР С‘: ${item.complexityReason}',
              style: AppTextStyles.caption,
            ),
          ],
          if (_pending) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                    label: const Text('Р С›РЎвЂљР С”Р В»Р С•Р Р…Р С‘РЎвЂљРЎРЉ'),
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
                label: const Text('Р С›РЎРѓРЎвЂљР В°Р Р†Р С‘РЎвЂљРЎРЉ / Р С‘Р В·Р СР ВµР Р…Р С‘РЎвЂљРЎРЉ Р С•РЎвЂљР В·РЎвЂ№Р Р†'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: busy ? null : onOpenTask,
              icon: const Icon(CupertinoIcons.doc_text),
              label: const Text('Р С›РЎвЂљР С”РЎР‚РЎвЂ№РЎвЂљРЎРЉ Р В·Р В°Р Т‘Р В°РЎвЂЎРЎС“'),
            ),
          ],
        ],
      ),
    );
  }
}
