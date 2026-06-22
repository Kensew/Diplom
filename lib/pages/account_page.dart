import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/utils/pocketbase_date.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class _RadarMetricDetail {
  final String label;
  final IconData icon;
  final double score;
  final String levelLabel;
  final String meaning;
  final String fact;

  const _RadarMetricDetail({
    required this.label,
    required this.icon,
    required this.score,
    required this.levelLabel,
    required this.meaning,
    required this.fact,
  });
}

class _ProfileRadarStats {
  final double orders;
  final double quality;
  final double speed;
  final double complexity;
  final double price;
  final int paidTasksCount;
  final int feedbackCount;
  final double avgRating;
  final double? avgEstimatedHours;
  final double? avgSpentHours;
  final double? avgComplexityRaw;
  final double? avgPriceRub;
  final int speedSampleCount;

  static const _priceBenchmarkRub = 60000.0;
  static const _maxPaidTasksSample = 20;

  const _ProfileRadarStats({
    required this.orders,
    required this.quality,
    required this.speed,
    required this.complexity,
    required this.price,
    required this.paidTasksCount,
    required this.feedbackCount,
    required this.avgRating,
    required this.avgEstimatedHours,
    required this.avgSpentHours,
    required this.avgComplexityRaw,
    required this.avgPriceRub,
    required this.speedSampleCount,
  });

  factory _ProfileRadarStats.empty() {
    return const _ProfileRadarStats(
      orders: 0,
      quality: 0,
      speed: 0,
      complexity: 0,
      price: 0,
      paidTasksCount: 0,
      feedbackCount: 0,
      avgRating: 0,
      avgEstimatedHours: null,
      avgSpentHours: null,
      avgComplexityRaw: null,
      avgPriceRub: null,
      speedSampleCount: 0,
    );
  }

  static String _levelLabel(double score) {
    if (score >= 80) return 'высокий';
    if (score >= 50) return 'средний';
    if (score > 0) return 'ниже среднего';
    return 'нет данных';
  }

  static String _formatHours(double? value) {
    if (value == null) return '—';
    if (value % 1 == 0) return '${value.toInt()} ч';
    return '${value.toStringAsFixed(1)} ч';
  }

  static String _formatRub(double? value) {
    if (value == null) return '—';
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    return '${buffer.toString()} ₽';
  }

  List<_RadarMetricDetail> get metrics {
    final speedFact =
        speedSampleCount == 0
            ? 'Нет задач с заполненным планом и фактом по часам'
            : 'План: ${_formatHours(avgEstimatedHours)}, факт: ${_formatHours(avgSpentHours)} · задач с данными: $speedSampleCount';

    return [
      _RadarMetricDetail(
        label: 'Заказы',
        icon: Icons.task_alt_rounded,
        score: orders,
        levelLabel: _levelLabel(orders),
        meaning:
            '100 — 20 и более оплаченных задач из последних. Чем больше завершённых и оплаченных заказов, тем выше показатель.',
        fact:
            paidTasksCount == 0
                ? 'Оплаченных задач в выборке пока нет'
                : '$paidTasksCount из $_maxPaidTasksSample последних оплаченных задач',
      ),
      _RadarMetricDetail(
        label: 'Качество',
        icon: CupertinoIcons.star_fill,
        score: quality,
        levelLabel: _levelLabel(quality),
        meaning:
            '100 — средняя оценка 5 из 5 по входящим отзывам. Считается по всем отзывам на профиле.',
        fact:
            feedbackCount == 0
                ? 'Отзывов пока нет'
                : 'Средняя оценка ${avgRating.toStringAsFixed(1)} из 5 · отзывов: $feedbackCount',
      ),
      _RadarMetricDetail(
        label: 'Скорость',
        icon: CupertinoIcons.timer,
        score: speed,
        levelLabel: _levelLabel(speed),
        meaning:
            '100 — уложились в план или быстрее (факт ≤ план). Ниже 100 — тратили больше часов, чем планировали.',
        fact: speedFact,
      ),
      _RadarMetricDetail(
        label: 'Сложность',
        icon: Icons.bar_chart_rounded,
        score: complexity,
        levelLabel: _levelLabel(complexity),
        meaning:
            '100 — средняя сложность задач 5/5. Показывает, насколько сложные проекты берёт исполнитель.',
        fact:
            avgComplexityRaw == null
                ? 'Нет данных по сложности оплаченных задач'
                : 'Средняя сложность ${avgComplexityRaw!.toStringAsFixed(1)} из 5',
      ),
      _RadarMetricDetail(
        label: 'Цена',
        icon: Icons.currency_ruble_rounded,
        score: price,
        levelLabel: _levelLabel(price),
        meaning:
            '100 — средний чек от ${_formatRub(_priceBenchmarkRub)} и выше. Показывает уровень стоимости оплаченных задач, а не «дорогой/дешёвый» относительно рынка.',
        fact:
            avgPriceRub == null
                ? 'Нет данных по суммам оплаченных задач'
                : 'Средний чек: ${_formatRub(avgPriceRub)}',
      ),
    ];
  }
}

class _ExecutorWorkloadStats {
  final int activeTasksCount;
  final int pendingPaymentCount;
  final int completedTasksCount;

  const _ExecutorWorkloadStats({
    required this.activeTasksCount,
    required this.pendingPaymentCount,
    required this.completedTasksCount,
  });

  factory _ExecutorWorkloadStats.empty() {
    return const _ExecutorWorkloadStats(
      activeTasksCount: 0,
      pendingPaymentCount: 0,
      completedTasksCount: 0,
    );
  }
}

class AccountPage extends StatefulWidget {
  final String? userId;

  const AccountPage({Key? key, this.userId}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  String? _profileId;
  String? _profileCreated;
  String? _profileAvatarUrl;

  String? _drawerRole;
  String? _drawerName;
  String? _drawerAvatarUrl;

  List<Map<String, dynamic>> _feedbacks = [];
  double _avgRating = 0;
  int _totalFeedbacks = 0;
  _ProfileRadarStats _radarStats = _ProfileRadarStats.empty();
  _ExecutorWorkloadStats _workloadStats = _ExecutorWorkloadStats.empty();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
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

  String _roleLabel(String role) {
    switch (role) {
      case 'customer':
        return 'Заказчик';
      case 'support':
        return 'Поддержка';
      case 'executor':
        return 'Исполнитель';
      default:
        return 'Пользователь';
    }
  }

  String _feedbackTypeLabel(String? type) {
    switch (type) {
      case 'customer_to_executor':
        return 'Отзыв заказчика';
      case 'executor_to_customer':
        return 'Отзыв исполнителя';
      default:
        return 'Отзыв';
    }
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

  Future<void> _loadDrawerData(String currentUserId) async {
    final user = await PocketBaseService.instance.pb
        .collection('users')
        .getOne(currentUserId);

    _drawerRole = _roleFromUser(user.data);
    _drawerName =
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';

    _drawerAvatarUrl = PocketBaseFileService.fileUrl(
      collectionName: 'users',
      recordId: user.id,
      fileValue: user.data['photo'],
    );
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      await _loadDrawerData(currentUserId);

      final id = widget.userId ?? currentUserId;
      final user = await pb.collection('users').getOne(id);

      _profileId = user.id;
      _profileCreated = user.get<String>('created') ?? '';
      _profile = Map<String, dynamic>.from(user.data);

      _profileAvatarUrl = PocketBaseFileService.fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      await _loadFeedbacks(id);
      await _loadRadarStats(id);
      await _loadWorkloadStats(id);
    } catch (e) {
      _error = 'Ошибка загрузки профиля: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _feedbackDedupKey({
    required String feedbackId,
    required String? orderId,
    required String? reviewerId,
    required String profileUserId,
    required String? reviewedUserId,
    required String? type,
  }) {
    final safeOrderId = orderId ?? feedbackId;
    final safeReviewerId = reviewerId ?? 'unknown_reviewer';
    final safeReviewedUserId = reviewedUserId ?? profileUserId;
    final safeType = type?.trim().isNotEmpty == true ? type!.trim() : 'legacy';

    return '$safeOrderId|$safeReviewerId|$safeReviewedUserId|$safeType';
  }

  bool _isNewerFeedback(
    Map<String, dynamic>? current,
    Map<String, dynamic> candidate,
  ) {
    if (current == null) return true;

    final currentDate = DateTime.tryParse(current['created'] as String? ?? '');
    final candidateDate = DateTime.tryParse(
      candidate['created'] as String? ?? '',
    );

    if (currentDate == null && candidateDate == null) return false;
    if (currentDate == null) return true;
    if (candidateDate == null) return false;

    return candidateDate.isAfter(currentDate);
  }

  Future<void> _loadFeedbacks(String profileUserId) async {
    final pb = PocketBaseService.instance.pb;

    _feedbacks = [];
    _avgRating = 0;
    _totalFeedbacks = 0;

    final feedbacksResult = await pb
        .collection('feedbacks')
        .getList(page: 1, perPage: 200);

    final ordersResult = await pb
        .collection('orders')
        .getList(page: 1, perPage: 200);

    final tasksResult = await pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final ordersById = <String, Map<String, dynamic>>{};
    final legacyExecutorOrderIds = <String>{};

    for (final order in ordersResult.items) {
      final data = {
        'id': order.id,
        'created': order.get<String>('created') ?? '',
        ...order.data,
      };

      ordersById[order.id] = data;

      final executorId = _relationId(order.data['executor_id']);
      if (executorId == profileUserId) {
        legacyExecutorOrderIds.add(order.id);
      }
    }

    for (final task in tasksResult.items) {
      final taskOrderId = _relationId(task.data['order_id']);
      final taskExecutorId = _relationId(task.data['executor_id']);

      if (taskOrderId != null && taskExecutorId == profileUserId) {
        legacyExecutorOrderIds.add(taskOrderId);
      }
    }

    final deduped = <String, Map<String, dynamic>>{};

    for (final feedback in feedbacksResult.items) {
      final reviewedUserId = _relationId(feedback.data['reviewed_user_id']);
      final orderId = _relationId(feedback.data['order_id']);

      final isNewFormat = reviewedUserId != null;
      final isForThisProfile = reviewedUserId == profileUserId;
      final isLegacyForExecutor =
          !isNewFormat &&
          orderId != null &&
          legacyExecutorOrderIds.contains(orderId);

      if (!isForThisProfile && !isLegacyForExecutor) continue;

      final order = orderId == null ? null : ordersById[orderId];

      String? reviewerId = _relationId(feedback.data['reviewer_id']);

      if (reviewerId == null && order != null) {
        reviewerId = _relationId(order['customer_id']);
      }

      final reviewer = await _getRecordData('users', reviewerId);

      final reviewerName =
          reviewer?['name'] as String? ??
          reviewer?['email'] as String? ??
          'Пользователь';

      final reviewerRole =
          reviewer == null
              ? 'Пользователь'
              : _roleLabel(_roleFromUser(reviewer));

      final reviewerAvatarUrl =
          reviewer == null || reviewerId == null
              ? null
              : PocketBaseFileService.fileUrl(
                collectionName: 'users',
                recordId: reviewerId,
                fileValue: reviewer['photo'],
              );

      final orderTitle =
          order?['task_description'] as String? ?? 'Заказ без описания';

      final rawType = feedback.data['type']?.toString();
      final type =
          rawType == null || rawType.trim().isEmpty
              ? (isLegacyForExecutor ? 'customer_to_executor' : null)
              : rawType.trim();

      final item = {
        'id': feedback.id,
        'estimate': feedback.data['estimate'],
        'text': feedback.data['text'] as String? ?? '',
        'created': feedback.created,
        'reviewer_name': reviewerName,
        'reviewer_role': reviewerRole,
        'reviewer_avatar_url': reviewerAvatarUrl,
        'type_label': _feedbackTypeLabel(type),
        'order_title': orderTitle,
      };

      final key = _feedbackDedupKey(
        feedbackId: feedback.id,
        orderId: orderId,
        reviewerId: reviewerId,
        profileUserId: profileUserId,
        reviewedUserId: reviewedUserId,
        type: type,
      );

      if (_isNewerFeedback(deduped[key], item)) {
        deduped[key] = item;
      }
    }

    _feedbacks = deduped.values.toList();

    _feedbacks.sort((a, b) {
      final da = DateTime.tryParse(a['created'] as String? ?? '');
      final db = DateTime.tryParse(b['created'] as String? ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    _totalFeedbacks = _feedbacks.length;

    if (_totalFeedbacks > 0) {
      _avgRating =
          _feedbacks
              .map((f) => (f['estimate'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b) /
          _totalFeedbacks;
    }
  }

  double _clampPercent(num value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value.toDouble();
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

  double _averageOrZero(List<double> values) {
    if (values.isEmpty) return 0;

    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _positiveNumber(dynamic value) {
    final number = (value as num?)?.toDouble();

    if (number == null || number <= 0) return null;

    return number;
  }

  Future<void> _loadRadarStats(String profileUserId) async {
    final pb = PocketBaseService.instance.pb;

    final tasksResult = await pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final ordersResult = await pb
        .collection('orders')
        .getList(page: 1, perPage: 200);

    final applicationsResult = await pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    final paymentStatusesResult = await pb
        .collection('payment_statuses')
        .getList(page: 1, perPage: 200);

    final paymentRequestsResult = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    final ordersById = <String, Map<String, dynamic>>{};
    final paymentStatusById = <String, String>{};
    final paidTaskIdsByRequest = <String>{};
    final complexityByOrderExecutor = <String, int>{};

    for (final order in ordersResult.items) {
      ordersById[order.id] = {
        'id': order.id,
        'created': order.get<String>('created') ?? '',
        ...order.data,
      };
    }

    for (final app in applicationsResult.items) {
      final orderId = _relationId(app.data['order_id']);
      final executorId = _relationId(app.data['executor_id']);
      final proposed = (app.data['complexity_proposed'] as num?)?.toInt();

      if (orderId == null || executorId == null || proposed == null) continue;

      complexityByOrderExecutor['$orderId|$executorId'] =
          proposed.clamp(1, 5).toInt();
    }

    for (final status in paymentStatusesResult.items) {
      paymentStatusById[status.id] =
          (status.data['name'] as String? ?? '').trim().toLowerCase();
    }

    for (final request in paymentRequestsResult.items) {
      final status = (request.data['status'] as String? ?? '').trim();

      if (!_isPaidStatus(status)) continue;

      final taskId = _relationId(request.data['task_id']);
      if (taskId != null) {
        paidTaskIdsByRequest.add(taskId);
      }
    }

    final paidTasks = <Map<String, dynamic>>[];

    for (final task in tasksResult.items) {
      final orderId = _relationId(task.data['order_id']);
      final order = orderId == null ? null : ordersById[orderId];

      final executorId = _relationId(task.data['executor_id']);
      final customerId = _relationId(order?['customer_id']);

      final isParticipant =
          executorId == profileUserId || customerId == profileUserId;

      if (!isParticipant) continue;

      final paymentStatusId = _relationId(task.data['payment_status_id']);
      final paymentStatus =
          paymentStatusId == null
              ? ''
              : paymentStatusById[paymentStatusId] ?? '';

      final isPaid =
          _isPaidStatus(paymentStatus) ||
          paidTaskIdsByRequest.contains(task.id);

      if (!isPaid) continue;

      final appComplexity =
          orderId == null || executorId == null
              ? null
              : complexityByOrderExecutor['$orderId|$executorId'];

      paidTasks.add({
        'id': task.id,
        'created': task.get<String>('created') ?? '',
        'order': order,
        'app_complexity': appComplexity,
        ...task.data,
      });
    }

    paidTasks.sort((a, b) {
      final da = DateTime.tryParse(a['created'] as String? ?? '');
      final db = DateTime.tryParse(b['created'] as String? ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    final recentPaidTasks = paidTasks.take(20).toList();
    final paidCount = recentPaidTasks.length;

    if (paidCount == 0 && _totalFeedbacks == 0) {
      _radarStats = _ProfileRadarStats.empty();
      return;
    }

    final qualityScore = _clampPercent((_avgRating / 5) * 100);
    final ordersScore = _clampPercent(
      (paidCount / _ProfileRadarStats._maxPaidTasksSample) * 100,
    );

    final speedScores = <double>[];
    final estimatedHours = <double>[];
    final spentHours = <double>[];
    final complexityScores = <double>[];
    final complexityRawValues = <double>[];
    final priceValues = <double>[];

    for (final task in recentPaidTasks) {
      final order = task['order'] as Map<String, dynamic>?;

      final estimated = _positiveNumber(task['estimated_time']);
      final spent = _positiveNumber(task['time_spent']);

      if (estimated != null && spent != null) {
        speedScores.add(_clampPercent((estimated / spent) * 100));
        estimatedHours.add(estimated);
        spentHours.add(spent);
      }

      final taskComplexity = _positiveNumber(task['complexity_final']);
      final orderComplexity = _positiveNumber(order?['complexity_auto']);
      final appComplexity = _positiveNumber(task['app_complexity']);

      final complexity =
          taskComplexity ?? orderComplexity ?? appComplexity ?? 3.0;

      complexityRawValues.add(complexity);
      complexityScores.add(_clampPercent((complexity / 5) * 100));

      final taskPrice = _positiveNumber(task['payment_amount']);
      final orderPrice = _positiveNumber(order?['price']);
      final price = taskPrice ?? orderPrice;

      if (price != null) {
        priceValues.add(price);
      }
    }

    final avgPrice =
        priceValues.isEmpty
            ? null
            : priceValues.reduce((a, b) => a + b) / priceValues.length;

    final priceScore =
        avgPrice == null
            ? 0.0
            : _clampPercent(
              (avgPrice / _ProfileRadarStats._priceBenchmarkRub) * 100,
            );

    _radarStats = _ProfileRadarStats(
      orders: ordersScore,
      quality: qualityScore,
      speed: _averageOrZero(speedScores),
      complexity: _averageOrZero(complexityScores),
      price: priceScore,
      paidTasksCount: paidCount,
      feedbackCount: _totalFeedbacks,
      avgRating: _avgRating,
      avgEstimatedHours:
          estimatedHours.isEmpty ? null : _averageOrZero(estimatedHours),
      avgSpentHours: spentHours.isEmpty ? null : _averageOrZero(spentHours),
      avgComplexityRaw:
          complexityRawValues.isEmpty
              ? null
              : _averageOrZero(complexityRawValues),
      avgPriceRub: avgPrice,
      speedSampleCount: speedScores.length,
    );
  }

  Future<void> _loadWorkloadStats(String profileUserId) async {
    final pb = PocketBaseService.instance.pb;

    _workloadStats = _ExecutorWorkloadStats.empty();

    final profileRole = _roleFromUser(_profile ?? const <String, dynamic>{});
    if (profileRole != 'executor') return;

    final tasksResult = await pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final paymentStatusesResult = await pb
        .collection('payment_statuses')
        .getList(page: 1, perPage: 200);

    final paymentRequestsResult = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    final taskStatusesResult = await pb
        .collection('task_statuses')
        .getList(page: 1, perPage: 200);

    final paymentStatusById = <String, String>{};
    final taskStatusById = <String, String>{};
    final paidTaskIdsByRequest = <String>{};
    final pendingPaymentTaskIdsByRequest = <String>{};

    for (final status in paymentStatusesResult.items) {
      paymentStatusById[status.id] =
          (status.data['name'] as String? ?? '').trim().toLowerCase();
    }

    for (final status in taskStatusesResult.items) {
      taskStatusById[status.id] =
          (status.data['name'] as String? ?? '').trim().toLowerCase();
    }

    for (final request in paymentRequestsResult.items) {
      final taskId = _relationId(request.data['task_id']);
      if (taskId == null) continue;

      final status = (request.data['status'] as String? ?? '').trim();

      if (_isPaidStatus(status)) {
        paidTaskIdsByRequest.add(taskId);
      } else if (_isPendingPaymentStatus(status)) {
        pendingPaymentTaskIdsByRequest.add(taskId);
      }
    }

    var activeCount = 0;
    var pendingPaymentCount = 0;
    var completedCount = 0;

    for (final task in tasksResult.items) {
      final executorId = _relationId(task.data['executor_id']);
      if (executorId != profileUserId) continue;

      final taskStatusId = _relationId(task.data['status_id']);
      final paymentStatusId = _relationId(task.data['payment_status_id']);

      final taskStatus =
          taskStatusId == null ? '' : taskStatusById[taskStatusId] ?? '';
      final paymentStatus =
          paymentStatusId == null
              ? ''
              : paymentStatusById[paymentStatusId] ?? '';

      final completed =
          _isPaidStatus(taskStatus) ||
          _isPaidStatus(paymentStatus) ||
          paidTaskIdsByRequest.contains(task.id);

      final pendingPayment =
          !completed &&
          (_isPendingPaymentStatus(paymentStatus) ||
              pendingPaymentTaskIdsByRequest.contains(task.id));

      if (completed) {
        completedCount++;
      } else {
        activeCount++;
        if (pendingPayment) {
          pendingPaymentCount++;
        }
      }
    }

    _workloadStats = _ExecutorWorkloadStats(
      activeTasksCount: activeCount,
      pendingPaymentCount: pendingPaymentCount,
      completedTasksCount: completedCount,
    );
  }

  String _formatAge(String? birthRaw) {
    final birth = DateTime.tryParse(birthRaw ?? '');
    if (birth == null) return '—';

    final now = DateTime.now();
    var age = now.year - birth.year;

    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }

    return '$age лет';
  }

  String _formatDate(String? raw, {String emptyLabel = '—'}) {
    final dt = PocketBaseDate.parse(raw);
    if (dt == null) return emptyLabel;

    return _dateFmt.format(dt.toLocal());
  }

  String _nonEmptyOrDash(dynamic value) {
    if (value is! String) return '—';

    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  bool get _isSelf {
    final currentUserId = PocketBaseService.instance.currentUserId;
    return widget.userId == null || _profileId == currentUserId;
  }

  bool get _isExecutorProfile {
    if (_profile == null) return false;
    return _roleFromUser(_profile!) == 'executor';
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final role = _drawerRole;

    if (role == 'customer') {
      context.go('/customer');
      return;
    }

    if (role == 'support') {
      context.go('/support');
      return;
    }

    context.go('/tasks');
  }

  void _applyUpdatedProfile(Map<String, dynamic> updatedProfile) {
    setState(() {
      _profile = updatedProfile;
      _profileId = updatedProfile['id'] as String? ?? _profileId;
      _profileCreated = updatedProfile['created'] as String? ?? _profileCreated;

      if (_profileId != null) {
        _profileAvatarUrl = PocketBaseFileService.fileUrl(
          collectionName: 'users',
          recordId: _profileId!,
          fileValue: updatedProfile['photo'],
        );
      }

      _drawerName =
          updatedProfile['name'] as String? ??
          updatedProfile['email'] as String? ??
          _drawerName;
      _drawerRole = _roleFromUser(updatedProfile);
      _drawerAvatarUrl = _profileAvatarUrl;
    });

    final id = _profileId;
    if (id != null) {
      _loadWorkloadStats(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSelf ? 'Мой профиль' : 'Профиль';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer:
          (_isSelf && _drawerRole != null && _drawerName != null)
              ? AppDrawer(
                role: _drawerRole!,
                displayName: _drawerName!,
                avatarUrl: _drawerAvatarUrl,
              )
              : null,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadAccountData)
                  : Column(
                    children: [
                      AppTopBar(
                        title: title,
                        subtitle:
                            _isSelf
                                ? 'Данные аккаунта, рейтинг и отзывы'
                                : 'Публичная карточка пользователя',
                        onMenu:
                            _isSelf
                                ? () => _scaffoldKey.currentState?.openDrawer()
                                : null,
                        onBack: _isSelf ? null : _goBack,
                        onRefresh: _loadAccountData,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadAccountData,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            children: [
                              _ProfileHeroCard(
                                profile: _profile!,
                                avatarUrl: _profileAvatarUrl,
                                avgRating: _avgRating,
                                totalFeedbacks: _totalFeedbacks,
                                ageText: _formatAge(
                                  _profile!['birth_date'] as String?,
                                ),
                                roleLabel: _roleLabel(
                                  _profile!['role'] as String? ?? 'executor',
                                ),
                                isSelf: _isSelf,
                                onEdit:
                                    _isSelf
                                        ? () async {
                                          final result = await context.push(
                                            '/account/edit',
                                          );

                                          if (!mounted) return;

                                          if (result is Map) {
                                            _applyUpdatedProfile(
                                              Map<String, dynamic>.from(result),
                                            );
                                            return;
                                          }

                                          await _loadAccountData();
                                        }
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              _ProfileStatsCard(
                                avgRating: _avgRating,
                                totalFeedbacks: _totalFeedbacks,
                                roleLabel: _roleLabel(
                                  _profile!['role'] as String? ?? 'executor',
                                ),
                              ),
                              if (_isExecutorProfile) ...[
                                const SizedBox(height: 12),
                                _ExecutorWorkloadCard(stats: _workloadStats),
                              ],
                              const SizedBox(height: 12),
                              _ProfileRadarCard(stats: _radarStats),
                              const SizedBox(height: 12),
                              _ProfileInfoCard(
                                description: _nonEmptyOrDash(
                                  _profile!['description'],
                                ),
                                birthDate: _formatDate(
                                  _profile!['birth_date'] as String?,
                                ),
                                createdAt: _formatDate(_profileCreated),
                                email: _nonEmptyOrDash(_profile!['email']),
                              ),
                              const SizedBox(height: 12),
                              AppSectionHeader(
                                title: 'Отзывы',
                                count: _feedbacks.length,
                              ),
                              const SizedBox(height: 8),
                              if (_feedbacks.isEmpty)
                                const AppEmptyState(
                                  icon: CupertinoIcons.star,
                                  title: 'Отзывов пока нет',
                                  subtitle:
                                      'Отзывы появятся после оплаченных заказов.',
                                )
                              else
                                ..._feedbacks.map(
                                  (feedback) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _FeedbackCard(
                                      estimate:
                                          (feedback['estimate'] as num?)
                                              ?.toInt() ??
                                          0,
                                      text: feedback['text'] as String? ?? '',
                                      date: _formatDate(
                                        feedback['created'] as String?,
                                        emptyLabel: '',
                                      ),
                                      reviewerName:
                                          feedback['reviewer_name']
                                              as String? ??
                                          'Пользователь',
                                      reviewerAvatarUrl:
                                          feedback['reviewer_avatar_url']
                                              as String?,
                                      typeLabel:
                                          feedback['type_label'] as String? ??
                                          'Отзыв',
                                      orderTitle:
                                          feedback['order_title'] as String? ??
                                          'Заказ',
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

class _ProfileHeroCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String? avatarUrl;
  final double avgRating;
  final int totalFeedbacks;
  final String ageText;
  final String roleLabel;
  final bool isSelf;
  final VoidCallback? onEdit;

  const _ProfileHeroCard({
    required this.profile,
    required this.avatarUrl,
    required this.avgRating,
    required this.totalFeedbacks,
    required this.ageText,
    required this.roleLabel,
    required this.isSelf,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? 'Пользователь';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl, size: 82),
          const SizedBox(height: 12),
          Text(
            name.trim().isEmpty ? 'Пользователь' : name,
            style: AppTextStyles.pageTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            ageText,
            style: AppTextStyles.small,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatusPill(
                text: roleLabel,
                color: AppColors.accent,
                icon: CupertinoIcons.person_crop_circle,
              ),
              AppStatusPill(
                text:
                    totalFeedbacks == 0
                        ? 'нет отзывов'
                        : '${avgRating.toStringAsFixed(1)} / 5',
                color: AppColors.accent,
                icon: CupertinoIcons.star_fill,
              ),
            ],
          ),
          if (isSelf && onEdit != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Редактировать профиль'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStatsCard extends StatelessWidget {
  final double avgRating;
  final int totalFeedbacks;
  final String roleLabel;

  const _ProfileStatsCard({
    required this.avgRating,
    required this.totalFeedbacks,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: CupertinoIcons.star_fill,
              label: 'Рейтинг',
              value: totalFeedbacks == 0 ? '—' : avgRating.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              icon: CupertinoIcons.chat_bubble_text,
              label: 'Отзывы',
              value: totalFeedbacks.toString(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              icon: CupertinoIcons.person_crop_circle,
              label: 'Роль',
              value: roleLabel,
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

class _ExecutorWorkloadCard extends StatelessWidget {
  final _ExecutorWorkloadStats stats;

  const _ExecutorWorkloadCard({required this.stats});

  Color get _levelColor {
    final count = stats.activeTasksCount;

    if (count == 0) return Colors.green;
    if (count <= 2) return AppColors.accent;
    if (count <= 4) return Colors.orange;
    return AppColors.danger;
  }

  String get _levelText {
    final count = stats.activeTasksCount;

    if (count == 0) return 'Свободен';
    if (count <= 2) return 'Нормальная загрузка';
    if (count <= 4) return 'Высокая загрузка';
    return 'Перегруз';
  }

  double get _progress {
    return (stats.activeTasksCount / 5).clamp(0, 1).toDouble();
  }

  String get _hint {
    final count = stats.activeTasksCount;

    if (count == 0) {
      return 'Исполнитель сейчас не ведёт активных задач.';
    }

    if (count <= 2) {
      return 'Исполнитель может брать новые заказы без явного риска перегруза.';
    }

    if (count <= 4) {
      return 'Исполнитель уже занят. Сроки лучше уточнить до назначения.';
    }

    return 'У исполнителя много активных задач. Назначение нового заказа рискованно.';
  }

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Текущая загруженность'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _levelColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: _levelColor.withOpacity(0.45)),
                ),
                alignment: Alignment.center,
                child: Text(
                  stats.activeTasksCount.toString(),
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 24,
                    color: _levelColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppStatusPill(
                      text: _levelText,
                      color: _levelColor,
                      icon: CupertinoIcons.speedometer,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(_levelColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_hint, style: AppTextStyles.body),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.work_outline_rounded,
                  label: 'В работе',
                  value: stats.activeTasksCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Ожидают оплаты',
                  value: stats.pendingPaymentCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: CupertinoIcons.checkmark_seal,
                  label: 'Завершено',
                  value: stats.completedTasksCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileRadarCard extends StatefulWidget {
  final _ProfileRadarStats stats;

  const _ProfileRadarCard({required this.stats});

  @override
  State<_ProfileRadarCard> createState() => _ProfileRadarCardState();
}

class _ProfileRadarCardState extends State<_ProfileRadarCard> {
  int? _hoveredIndex;

  int? _hitTestAxis(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) * 0.31;

    if (distance > radius + 36) return null;

    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    const axisCount = 5;
    const sector = 2 * math.pi / axisCount;
    final index = ((angle + sector / 2) / sector).floor() % axisCount;

    return index;
  }

  void _setHoveredIndex(int? index) {
    if (index == _hoveredIndex) return;
    setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final activeMetric =
        _hoveredIndex == null ? null : stats.metrics[_hoveredIndex!];

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: MouseRegion(
        onExit: (_) => _setHoveredIndex(null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: 'Профиль работы',
              count: stats.paidTasksCount,
            ),
            const SizedBox(height: 8),
            Text(
              'Оценка по последним оплаченным задачам и входящим отзывам. Наведите на сектор диаграммы или тег ниже.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 240,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);

                  return MouseRegion(
                    onHover:
                        (event) => _setHoveredIndex(
                          _hitTestAxis(event.localPosition, size),
                        ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        final index = _hitTestAxis(details.localPosition, size);
                        _setHoveredIndex(
                          _hoveredIndex == index ? null : index,
                        );
                      },
                      child: CustomPaint(
                        painter: _RadarChartPainter(
                          stats: stats,
                          hoveredIndex: _hoveredIndex,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < stats.metrics.length; i++)
                  MouseRegion(
                    onEnter: (_) => _setHoveredIndex(i),
                    child: AppTag(
                      icon: stats.metrics[i].icon,
                      label:
                          '${stats.metrics[i].label} ${stats.metrics[i].score.toStringAsFixed(0)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (activeMetric != null)
              _RadarMetricTooltip(detail: activeMetric),
          ],
        ),
      ),
    );
  }
}

class _RadarMetricTooltip extends StatelessWidget {
  final _RadarMetricDetail detail;

  const _RadarMetricTooltip({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(detail.icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${detail.label}: ${detail.score.toStringAsFixed(0)} · ${detail.levelLabel}',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail.meaning, style: AppTextStyles.body, softWrap: true),
          const SizedBox(height: 6),
          Text(
            detail.fact,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final _ProfileRadarStats stats;
  final int? hoveredIndex;

  _RadarChartPainter({required this.stats, this.hoveredIndex});

  static const _labels = [
    'Заказы',
    'Качество',
    'Скорость',
    'Сложность',
    'Цена',
  ];

  List<double> get _values {
    return [
      stats.orders,
      stats.quality,
      stats.speed,
      stats.complexity,
      stats.price,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final radius = math.min(size.width, size.height) * 0.31;
    const axisCount = 5;
    const startAngle = -math.pi / 2;

    if (hoveredIndex != null) {
      final axisAngle = startAngle + 2 * math.pi * hoveredIndex! / axisCount;
      const halfSector = math.pi / axisCount;
      final highlightPath = Path();

      highlightPath.moveTo(center.dx, center.dy);
      highlightPath.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        axisAngle - halfSector,
        halfSector * 2,
        false,
      );
      highlightPath.close();

      canvas.drawPath(
        highlightPath,
        Paint()
          ..color = AppColors.accent.withOpacity(0.12)
          ..style = PaintingStyle.fill,
      );
    }

    final gridPaint =
        Paint()
          ..color = AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final axisPaint =
        Paint()
          ..color = AppColors.textMuted.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final areaPaint =
        Paint()
          ..color = AppColors.accent.withOpacity(0.24)
          ..style = PaintingStyle.fill;

    final linePaint =
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;

    final pointPaint =
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.fill;

    for (var level = 1; level <= 5; level++) {
      final levelRadius = radius * level / 5;
      final path = Path();

      for (var i = 0; i < axisCount; i++) {
        final angle = startAngle + 2 * math.pi * i / axisCount;
        final point = Offset(
          center.dx + math.cos(angle) * levelRadius,
          center.dy + math.sin(angle) * levelRadius,
        );

        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }

      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < axisCount; i++) {
      final angle = startAngle + 2 * math.pi * i / axisCount;
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      canvas.drawLine(center, end, axisPaint);

      final isActive = hoveredIndex == i;
      final labelOffset = Offset(
        center.dx + math.cos(angle) * (radius + 30),
        center.dy + math.sin(angle) * (radius + 30),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.accent : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 80);

      textPainter.paint(
        canvas,
        Offset(
          labelOffset.dx - textPainter.width / 2,
          labelOffset.dy - textPainter.height / 2,
        ),
      );
    }

    final values = _values;
    final areaPath = Path();

    for (var i = 0; i < axisCount; i++) {
      final value = values[i].clamp(0, 100);
      final pointRadius = radius * value / 100;
      final angle = startAngle + 2 * math.pi * i / axisCount;

      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );

      if (i == 0) {
        areaPath.moveTo(point.dx, point.dy);
      } else {
        areaPath.lineTo(point.dx, point.dy);
      }
    }

    areaPath.close();
    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(areaPath, linePaint);

    for (var i = 0; i < axisCount; i++) {
      final value = values[i].clamp(0, 100);
      final pointRadius = radius * value / 100;
      final angle = startAngle + 2 * math.pi * i / axisCount;

      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );

      canvas.drawCircle(
        point,
        hoveredIndex == i ? 5.5 : 4,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.stats.orders != stats.orders ||
        oldDelegate.stats.quality != stats.quality ||
        oldDelegate.stats.speed != stats.speed ||
        oldDelegate.stats.complexity != stats.complexity ||
        oldDelegate.stats.price != stats.price ||
        oldDelegate.stats.paidTasksCount != stats.paidTasksCount ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String description;
  final String birthDate;
  final String createdAt;
  final String email;

  const _ProfileInfoCard({
    required this.description,
    required this.birthDate,
    required this.createdAt,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Информация'),
          const SizedBox(height: 12),
          _InfoRow(icon: CupertinoIcons.mail, label: 'Email', value: email),
          _InfoRow(
            icon: CupertinoIcons.calendar,
            label: 'Дата рождения',
            value: birthDate,
          ),
          _InfoRow(
            icon: CupertinoIcons.clock,
            label: 'Дата регистрации',
            value: createdAt,
          ),
          _InfoRow(
            icon: CupertinoIcons.text_alignleft,
            label: 'Описание',
            value: description,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final int estimate;
  final String text;
  final String date;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final String typeLabel;
  final String orderTitle;

  const _FeedbackCard({
    required this.estimate,
    required this.text,
    required this.date,
    required this.reviewerName,
    required this.reviewerAvatarUrl,
    required this.typeLabel,
    required this.orderTitle,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date.trim().isNotEmpty;
    final orderLabel = orderTitle.trim();

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppProfileAvatar(avatarUrl: reviewerAvatarUrl, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasDate) Text(date, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < estimate
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              Text('$estimate / 5', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text.trim().isEmpty ? 'Без текста' : text,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
          ),
          if (orderLabel.isNotEmpty &&
              orderLabel != 'Заказ без описания') ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Заказ', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        orderLabel,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
