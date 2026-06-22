import 'package:flutter_freelance_platform/services/application_decision_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class PrepaymentService {
  const PrepaymentService._();

  static const int defaultPercent = 50;

  static bool isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int? parsePercent(String? raw) {
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) return null;

    return value.clamp(10, 100);
  }

  static int resolvePercent(Map<String, dynamic> order) {
    final raw = ApplicationDecisionService.intValue(order['prepayment_percent']);
    return (raw ?? defaultPercent).clamp(10, 100);
  }

  /// Заказчик указал, что готов к предоплате (поле в БД: prepayment_required).
  static bool orderOffersPrepayment(Map<String, dynamic> order) {
    return isTruthy(order['prepayment_required']);
  }

  static bool applicationRequiresPrepayment(Map<String, dynamic> application) {
    return isTruthy(application['requires_prepayment']);
  }

  static bool taskRequiresPrepayment(Map<String, dynamic> task) {
    return isTruthy(task['prepayment_required']);
  }

  /// Предоплата обязательна только если её требует исполнитель в заявке.
  static bool needsPrepayment({
    required Map<String, dynamic> order,
    required Map<String, dynamic> application,
  }) {
    return applicationRequiresPrepayment(application);
  }

  static double prepaymentAmount({required num price, required int percent}) {
    final amount = price * percent / 100;
    return double.parse(amount.toStringAsFixed(2));
  }

  static double remainingAmount({
    required num totalPrice,
    required num prepaymentPaid,
  }) {
    final remaining = totalPrice - prepaymentPaid;
    if (remaining <= 0) return 0;

    return double.parse(remaining.toStringAsFixed(2));
  }

  static String normalizedPaymentType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';

    if (raw == 'prepayment' || raw == 'final') {
      return raw;
    }

    return 'final';
  }

  static String paymentTypeLabel(String type) {
    return normalizedPaymentType(type) == 'prepayment'
        ? 'Предоплата'
        : 'Финальная оплата';
  }

  static String orderOfferBadgeLabel(int percent) {
    return 'Возможна предоплата $percent%';
  }

  static Future<void> createPrepaymentRequestIfNeeded({
    required String taskId,
    required String executorId,
    required Map<String, dynamic> order,
    required Map<String, dynamic> application,
  }) async {
    if (!needsPrepayment(order: order, application: application)) {
      return;
    }

    final pb = PocketBaseService.instance.pb;
    final price = (order['price'] as num?) ?? 0;
    final percent = resolvePercent(order);
    final amount = prepaymentAmount(price: price, percent: percent);

    if (amount <= 0) {
      return;
    }

    final awaitingStatusId = await ApplicationDecisionService.firstIdFromCollection(
      'payment_statuses',
      ['awaiting_prepayment', 'pending', 'none'],
    );

    await pb.collection('payment_requests').create(
      body: {
        'task_id': taskId,
        'requested_by': executorId,
        'status': 'pending',
        'payment_amount': amount,
        'payment_type': 'prepayment',
      },
    );

    if (awaitingStatusId != null) {
      await pb.collection('tasks').update(
        taskId,
        body: {'payment_status_id': awaitingStatusId},
      );
    }
  }

  static Future<double> approvedPrepaymentAmount(String taskId) async {
    final pb = PocketBaseService.instance.pb;

    final result = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    var total = 0.0;

    for (final request in result.items) {
      final requestTaskId = ApplicationDecisionService.relationId(
        request.data['task_id'],
      );

      if (requestTaskId != taskId) continue;

      final type = normalizedPaymentType(request.data['payment_type']);
      final status =
          request.data['status']?.toString().trim().toLowerCase() ?? '';

      if (type != 'prepayment' || status != 'approved') continue;

      total += ((request.data['payment_amount'] as num?) ?? 0).toDouble();
    }

    return double.parse(total.toStringAsFixed(2));
  }

  static Future<bool> hasApprovedFinalPayment(String taskId) async {
    final pb = PocketBaseService.instance.pb;

    final result = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    for (final request in result.items) {
      final requestTaskId = ApplicationDecisionService.relationId(
        request.data['task_id'],
      );

      if (requestTaskId != taskId) continue;

      final type = normalizedPaymentType(request.data['payment_type']);
      final status =
          request.data['status']?.toString().trim().toLowerCase() ?? '';

      if (type == 'final' && status == 'approved') {
        return true;
      }
    }

    return false;
  }
}
