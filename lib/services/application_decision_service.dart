// lib/services/application_decision_service.dart

import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class ApplicationDecisionService {
  const ApplicationDecisionService._();

  static String? relationId(dynamic value) {
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

  static int? intValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static String normalizedStatus(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    if (raw == 'approved' || raw == 'rejected' || raw == 'pending') {
      return raw!;
    }

    return 'pending';
  }

  static String normalizedApplicationSource(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    if (raw == 'customer_invite' || raw == 'executor_apply') {
      return raw!;
    }

    return 'executor_apply';
  }

  static String? roleFallbackByEmail(String email) {
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

    return null;
  }

  static String? roleFromUser(Map<String, dynamic> data) {
    String normalize(dynamic value) {
      if (value == null) return '';

      if (value is List && value.isNotEmpty) {
        return value.first.toString().trim().toLowerCase();
      }

      return value.toString().trim().toLowerCase();
    }

    final rawRole = normalize(data['role']);
    final email = normalize(data['email']);
    final name = normalize(data['name']);

    final joined = '$rawRole $email $name';

    if (joined.contains('executor') ||
        joined.contains('исполнитель') ||
        rawRole == '2') {
      return 'executor';
    }

    if (joined.contains('customer') ||
        joined.contains('заказчик') ||
        rawRole == '1') {
      return 'customer';
    }

    if (joined.contains('support') ||
        joined.contains('поддержка') ||
        rawRole == '3') {
      return 'support';
    }

    return roleFallbackByEmail(email);
  }

  static Future<Map<String, dynamic>?> getRecordData(
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
        'updated': record.get<String>('updated') ?? '',
        ...record.data,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<String?> firstIdFromCollection(
    String collection,
    List<String> preferredNames,
  ) async {
    final result = await PocketBaseService.instance.pb
        .collection(collection)
        .getList(page: 1, perPage: 200);

    if (result.items.isEmpty) return null;

    for (final preferredName in preferredNames) {
      final normalizedPreferred = preferredName.trim().toLowerCase();

      for (final item in result.items) {
        final itemName =
            (item.data['name'] as String? ?? '').trim().toLowerCase();

        if (itemName == normalizedPreferred) {
          return item.id;
        }
      }
    }

    return result.items.first.id;
  }

  static Future<String?> taskIdForOrder(String orderId) async {
    final result = await PocketBaseService.instance.pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final tasks =
        result.items.where((task) {
          final taskOrderId = relationId(task.data['order_id']);
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

  static Future<String?> existingApplicationId({
    required String orderId,
    required String executorId,
  }) async {
    final result = await PocketBaseService.instance.pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    for (final app in result.items) {
      final appOrderId = relationId(app.data['order_id']);
      final appExecutorId = relationId(app.data['executor_id']);

      if (appOrderId == orderId && appExecutorId == executorId) {
        return app.id;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> existingApplicationData({
    required String orderId,
    required String executorId,
  }) async {
    final result = await PocketBaseService.instance.pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    for (final app in result.items) {
      final appOrderId = relationId(app.data['order_id']);
      final appExecutorId = relationId(app.data['executor_id']);

      if (appOrderId == orderId && appExecutorId == executorId) {
        return {
          'id': app.id,
          'created': app.get<String>('created') ?? '',
          'updated': app.get<String>('updated') ?? '',
          ...app.data,
        };
      }
    }

    return null;
  }

  static Future<void> rejectOtherApplicationsForOrder({
    required String orderId,
    required String acceptedApplicationId,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final result = await pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    for (final app in result.items) {
      if (app.id == acceptedApplicationId) continue;

      final appOrderId = relationId(app.data['order_id']);
      final status = normalizedStatus(app.data['status']);

      if (appOrderId == orderId && status == 'pending') {
        await pb
            .collection('applications')
            .update(app.id, body: {'status': 'rejected'});
      }
    }
  }

  static int resolveFinalComplexity({
    required Map<String, dynamic> order,
    required Map<String, dynamic> application,
  }) {
    final autoComplexity =
        (intValue(order['complexity_auto'] ?? 3) ?? 3).clamp(1, 5).toInt();

    final proposedComplexity = intValue(application['complexity_proposed']);

    if (proposedComplexity == null) {
      return autoComplexity;
    }

    return OrderComplexityService.clampProposedComplexity(
      autoComplexity: autoComplexity,
      proposedComplexity: proposedComplexity,
    );
  }

  static String resolveComplexitySource({
    required Map<String, dynamic> order,
    required Map<String, dynamic> application,
  }) {
    final autoComplexity =
        (intValue(order['complexity_auto'] ?? 3) ?? 3).clamp(1, 5).toInt();

    final finalComplexity = resolveFinalComplexity(
      order: order,
      application: application,
    );

    if (finalComplexity == autoComplexity) {
      return 'auto';
    }

    return 'executor_adjusted';
  }

  static Future<String> createTaskForApplication({
    required String applicationId,
    required Map<String, dynamic> application,
    required Map<String, dynamic> order,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final orderId = relationId(application['order_id']);
    final executorId = relationId(application['executor_id']);

    if (orderId == null || orderId.isEmpty) {
      throw 'В заявке не указан заказ';
    }

    if (executorId == null || executorId.isEmpty) {
      throw 'В заявке не указан исполнитель';
    }

    final existingTaskId = await taskIdForOrder(orderId);
    if (existingTaskId != null) {
      return existingTaskId;
    }

    final statusId = await firstIdFromCollection('task_statuses', [
      'new',
      'pending',
      'created',
    ]);

    final paymentStatusId = await firstIdFromCollection('payment_statuses', [
      'none',
      'pending',
      'unpaid',
    ]);

    final finalComplexity = resolveFinalComplexity(
      order: order,
      application: application,
    );

    final complexitySource = resolveComplexitySource(
      order: order,
      application: application,
    );

    final price = (order['price'] as num?) ?? 0;

    final task = await pb
        .collection('tasks')
        .create(
          body: {
            'order_id': orderId,
            'executor_id': executorId,
            if (statusId != null) 'status_id': statusId,
            if (paymentStatusId != null) 'payment_status_id': paymentStatusId,
            'estimated_time': 0,
            'time_spent': 0,
            'payment_amount': price,
            'complexity_final': finalComplexity,
            'complexity_source': complexitySource,
          },
        );

    return task.id;
  }

  static Future<String> acceptApplication({
    required String applicationId,
    required String actorUserId,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final appRecord = await pb.collection('applications').getOne(applicationId);

    final application = <String, dynamic>{
      'id': appRecord.id,
      'created': appRecord.get<String>('created') ?? '',
      'updated': appRecord.get<String>('updated') ?? '',
      ...appRecord.data,
    };

    final status = normalizedStatus(application['status']);
    if (status != 'pending') {
      throw 'Заявка уже обработана';
    }

    final orderId = relationId(application['order_id']);
    final executorId = relationId(application['executor_id']);

    if (orderId == null || orderId.isEmpty) {
      throw 'В заявке не указан заказ';
    }

    if (executorId == null || executorId.isEmpty) {
      throw 'В заявке не указан исполнитель';
    }

    final order = await getRecordData('orders', orderId);
    if (order == null) {
      throw 'Заказ не найден';
    }

    final customerId = relationId(order['customer_id']);
    final currentExecutorId = relationId(order['executor_id']);
    final source = normalizedApplicationSource(application['source']);

    if (currentExecutorId != null && currentExecutorId != executorId) {
      throw 'Заказ уже назначен другому исполнителю';
    }

    if (source == 'customer_invite') {
      if (actorUserId != executorId) {
        throw 'Принять приглашение может только приглашённый исполнитель';
      }
    } else {
      if (actorUserId != customerId) {
        throw 'Принять отклик может только заказчик';
      }
    }

    await pb
        .collection('applications')
        .update(applicationId, body: {'status': 'approved'});

    await pb
        .collection('orders')
        .update(orderId, body: {'executor_id': executorId});

    await rejectOtherApplicationsForOrder(
      orderId: orderId,
      acceptedApplicationId: applicationId,
    );

    return createTaskForApplication(
      applicationId: applicationId,
      application: application,
      order: order,
    );
  }

  static Future<void> rejectApplication({
    required String applicationId,
    required String actorUserId,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final appRecord = await pb.collection('applications').getOne(applicationId);

    final application = <String, dynamic>{
      'id': appRecord.id,
      'created': appRecord.get<String>('created') ?? '',
      'updated': appRecord.get<String>('updated') ?? '',
      ...appRecord.data,
    };

    final orderId = relationId(application['order_id']);
    final executorId = relationId(application['executor_id']);

    if (orderId == null || orderId.isEmpty) {
      throw 'В заявке не указан заказ';
    }

    final order = await getRecordData('orders', orderId);
    if (order == null) {
      throw 'Заказ не найден';
    }

    final customerId = relationId(order['customer_id']);
    final source = normalizedApplicationSource(application['source']);

    if (source == 'customer_invite') {
      if (actorUserId != executorId && actorUserId != customerId) {
        throw 'Нет прав на отклонение приглашения';
      }
    } else {
      if (actorUserId != customerId && actorUserId != executorId) {
        throw 'Нет прав на отклонение заявки';
      }
    }

    await pb
        .collection('applications')
        .update(applicationId, body: {'status': 'rejected'});
  }

  static Future<String> createCustomerInvite({
    required String orderId,
    required String executorId,
    required String customerId,
    String? message,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final order = await getRecordData('orders', orderId);
    if (order == null) {
      throw 'Заказ не найден';
    }

    final orderCustomerId = relationId(order['customer_id']);
    final currentExecutorId = relationId(order['executor_id']);

    if (orderCustomerId != customerId) {
      throw 'Приглашать исполнителя может только заказчик заказа';
    }

    if (currentExecutorId != null && currentExecutorId.isNotEmpty) {
      throw 'Заказ уже назначен исполнителю';
    }

    if (executorId == customerId) {
      throw 'Нельзя пригласить самого себя';
    }

    final executor = await getRecordData('users', executorId);
    if (executor == null) {
      throw 'Исполнитель не найден';
    }

    final executorRole = roleFromUser(executor);
    if (executorRole != 'executor') {
      throw 'Выбранный пользователь не является исполнителем';
    }

    final existing = await existingApplicationData(
      orderId: orderId,
      executorId: executorId,
    );

    final safeMessage = message?.trim() ?? '';

    if (existing != null) {
      final existingStatus = normalizedStatus(existing['status']);

      if (existingStatus == 'pending') {
        throw 'Заявка этому исполнителю уже отправлена';
      }

      if (existingStatus == 'approved') {
        throw 'Этот исполнитель уже принят';
      }

      await pb
          .collection('applications')
          .update(
            existing['id'] as String,
            body: {
              'status': 'pending',
              'source': 'customer_invite',
              'initiator_id': customerId,
              'message': safeMessage,
            },
          );

      return existing['id'] as String;
    }

    final created = await pb
        .collection('applications')
        .create(
          body: {
            'order_id': orderId,
            'executor_id': executorId,
            'status': 'pending',
            'source': 'customer_invite',
            'initiator_id': customerId,
            'message': safeMessage,
          },
        );

    return created.id;
  }

  static Future<String> createExecutorApplication({
    required String orderId,
    required String executorId,
    int? proposedComplexity,
    String? complexityReason,
    String? message,
  }) async {
    final pb = PocketBaseService.instance.pb;

    final order = await getRecordData('orders', orderId);
    if (order == null) {
      throw 'Заказ не найден';
    }

    final customerId = relationId(order['customer_id']);
    final currentExecutorId = relationId(order['executor_id']);

    if (customerId == executorId) {
      throw 'Нельзя подать заявку на собственный заказ';
    }

    if (currentExecutorId != null && currentExecutorId.isNotEmpty) {
      throw 'Заказ уже назначен исполнителю';
    }

    final autoComplexity =
        (intValue(order['complexity_auto'] ?? 3) ?? 3).clamp(1, 5).toInt();

    final safeProposedComplexity =
        proposedComplexity == null
            ? autoComplexity
            : OrderComplexityService.clampProposedComplexity(
              autoComplexity: autoComplexity,
              proposedComplexity: proposedComplexity,
            );

    final safeReason = complexityReason?.trim() ?? '';

    if (safeProposedComplexity != autoComplexity && safeReason.isEmpty) {
      throw 'Укажите причину изменения сложности';
    }

    final existing = await existingApplicationData(
      orderId: orderId,
      executorId: executorId,
    );

    if (existing != null) {
      final existingStatus = normalizedStatus(existing['status']);

      if (existingStatus == 'pending') {
        throw 'Заявка уже отправлена';
      }

      if (existingStatus == 'approved') {
        throw 'Заявка уже принята';
      }

      await pb
          .collection('applications')
          .update(
            existing['id'] as String,
            body: {
              'status': 'pending',
              'source': 'executor_apply',
              'initiator_id': executorId,
              'message': message?.trim() ?? '',
              'complexity_proposed': safeProposedComplexity,
              'complexity_reason': safeReason,
            },
          );

      return existing['id'] as String;
    }

    final created = await pb
        .collection('applications')
        .create(
          body: {
            'order_id': orderId,
            'executor_id': executorId,
            'status': 'pending',
            'source': 'executor_apply',
            'initiator_id': executorId,
            'message': message?.trim() ?? '',
            'complexity_proposed': safeProposedComplexity,
            'complexity_reason': safeReason,
          },
        );

    return created.id;
  }
}
